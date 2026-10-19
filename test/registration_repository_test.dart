import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/registration/registration_data.dart';
import 'package:learnsphere/registration/registration_repository.dart';

RegistrationData data({
  String email = ' New@Example.com ',
  String username = ' New.User ',
}) => RegistrationData(
  fullName: ' New Learner ',
  email: email,
  username: username,
  password: ' Secret1! ',
  question: ' Favorite place? ',
  answer: ' Lagos ',
);

void main() {
  for (final withAccessKey in [false, true]) {
    test(
      'master key uses correct header on read and write; access key present: $withAccessKey',
      () async {
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.headers['X-Master-Key'], 'test-master');
          expect(request.headers.containsKey('X-Access-Key'), isFalse);
          if (request.method == 'GET') {
            return http.Response('{"record":{"last_id":0,"users":[]}}', 200);
          }
          expect(request.method, 'PUT');
          return http.Response('{}', 200);
        });
        addTearDown(client.close);
        await JsonBinRegistrationRepository(
          client: client,
          masterKey: ' test-master ',
          accessKey: withAccessKey ? 'test-access' : '',
        ).register(data());
        expect(requests, 2);
      },
    );
  }
  for (final status in [401, 403, 429, 500]) {
    test('failed PUT $status is reported without retry', () async {
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"record":{"last_id":0,"users":[]}}', 200);
        }
        writes++;
        return http.Response('{}', status);
      });
      addTearDown(client.close);
      await expectLater(
        JsonBinRegistrationRepository(
          client: client,
          accessKey: 'test',
        ).register(data()),
        throwsA(isA<RegistrationException>()),
      );
      expect(writes, 1);
    });
  }
  test('read connection failure is recoverable without a write', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      throw http.ClientException('offline');
    });
    addTearDown(client.close);
    await expectLater(
      JsonBinRegistrationRepository(
        client: client,
        accessKey: 'test',
      ).register(data()),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.message,
          'message',
          contains('connection'),
        ),
      ),
    );
  });
  test('write timeout warns that save is uncertain', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('{"record":{"last_id":0,"users":[]}}', 200);
      }
      throw TimeoutException('timed out');
    });
    addTearDown(client.close);
    await expectLater(
      JsonBinRegistrationRepository(
        client: client,
        accessKey: 'test',
      ).register(data()),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.message,
          'message',
          contains('Check whether'),
        ),
      ),
    );
  });
  final admin = {
    'id': 0,
    'email': 'Admin@Example.com',
    'username': 'Admin',
    'account_type': 'admin',
    'password_hash': 'unchanged',
    'is_active': false,
    'extra': {'keep': true},
  };
  test('normalizes identity without changing password', () {
    final user = data().toUser(1, DateTime.utc(2026));
    expect(user['email'], 'new@example.com');
    expect(user['username'], 'new.user');
    expect(user['full_name'], 'New Learner');
    expect(user['password_hash'], ' Secret1! ');
    expect(user['reset_password_answer'], 'Lagos');
    expect(user['reset_password_question'], 'Favorite place?');
  });
  for (final ids in [(0, 0, 1), (1, 8, 9), (12, 8, 13)]) {
    test('allocates ID ${ids.$3} and preserves record and users', () async {
      final existing = {...admin, 'id': ids.$2};
      var reads = 0, writes = 0;
      final client = MockClient((request) async {
        expect(request.headers['X-Access-Key'], 'test-key');
        if (request.method == 'GET') {
          reads++;
          expect(request.url.path, '/v3/b/test-bin/latest');
          return http.Response(
            jsonEncode({
              'record': {
                'last_id': ids.$1,
                'users': [existing],
                'extra_record': 'keep',
              },
              'metadata': {'private': true},
            }),
            200,
          );
        }
        writes++;
        expect(request.method, 'PUT');
        expect(request.url.path, '/v3/b/test-bin');
        final body = jsonDecode(request.body) as Map;
        expect(
          body.keys,
          unorderedEquals(['last_id', 'users', 'extra_record']),
        );
        expect(body['last_id'], ids.$3);
        expect(body['extra_record'], 'keep');
        final users = body['users'] as List;
        expect(users.first, existing);
        expect(users.last, data().toUser(ids.$3, DateTime.utc(2026, 10, 18)));
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      await JsonBinRegistrationRepository(
        client: client,
        binId: 'test-bin',
        accessKey: 'test-key',
        clock: () => DateTime.utc(2026, 10, 18),
      ).register(data());
      expect(reads, 1);
      expect(writes, 1);
    });
  }
  test('duplicates include inactive users and both fields, no PUT', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'record': {
            'last_id': 0,
            'users': [admin],
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    await expectLater(
      JsonBinRegistrationRepository(
        client: client,
        accessKey: 'test',
      ).register(data(email: ' admin@example.com ', username: ' ADMIN ')),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.fields.keys,
          'fields',
          unorderedEquals(['email', 'username']),
        ),
      ),
    );
  });
  for (final body in [
    'invalid',
    '{}',
    '{"record":{"last_id":0,"users":null}}',
    '{"record":{"last_id":0,"users":[{"id":0}]}}',
  ]) {
    test('malformed record prevents write: $body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(body, 200);
      });
      addTearDown(client.close);
      await expectLater(
        JsonBinRegistrationRepository(
          client: client,
          accessKey: 'test',
        ).register(data()),
        throwsA(
          isA<RegistrationException>().having(
            (e) => e.message,
            'message',
            contains('invalid'),
          ),
        ),
      );
    });
  }
  for (final status in [401, 403, 404, 429, 500]) {
    test('read status $status prevents write', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response('{}', status);
      });
      addTearDown(client.close);
      await expectLater(
        JsonBinRegistrationRepository(
          client: client,
          accessKey: 'test',
        ).register(data()),
        throwsA(isA<RegistrationException>()),
      );
    });
  }
  test('missing configuration makes no request', () async {
    final client = MockClient(
      (_) async => fail('Must not request without key'),
    );
    addTearDown(client.close);
    await expectLater(
      JsonBinRegistrationRepository(
        client: client,
        accessKey: '',
      ).register(data()),
      throwsA(isA<RegistrationException>()),
    );
  });
  test('uncertain PUT is not retried', () async {
    var writes = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('{"record":{"last_id":0,"users":[]}}', 200);
      }
      writes++;
      throw http.ClientException('disconnected');
    });
    addTearDown(client.close);
    await expectLater(
      JsonBinRegistrationRepository(
        client: client,
        accessKey: 'test',
      ).register(data()),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.message,
          'message',
          contains('Check whether'),
        ),
      ),
    );
    expect(writes, 1);
  });
}
