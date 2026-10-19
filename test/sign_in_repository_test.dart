import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';

void main() {
  final learner = <String, dynamic>{
    'id': 1,
    'full_name': 'Alex Morgan',
    'email': 'Alex@Example.com',
    'username': 'Alex.Morgan',
    'password_hash': 'Old1',
    'account_type': 'learner',
    'is_active': true,
    'reset_password_answer': 'secret',
  };

  JsonBinSignInRepository repository(List<dynamic> users) {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path.endsWith('/latest'), isTrue);
      expect(request.headers['X-Master-Key'], 'master');
      return http.Response(
        jsonEncode({
          'record': {'last_id': 1, 'users': users},
        }),
        200,
      );
    });
    addTearDown(client.close);
    return JsonBinSignInRepository(
      JsonBinStore(client: client, masterKey: 'master'),
    );
  }

  for (final identity in [' ALEX@example.com ', ' ALEX.MORGAN ']) {
    test('signs in by normalized identity: $identity', () async {
      final session = await repository([learner])
          .signIn(identity, 'Old1', AccountRole.learner);
      expect(session.fullName, 'Alex Morgan');
      expect(session.id, 1);
      expect(session.role, AccountRole.learner);
    });
  }
  test('administrator sign-in', () async {
    final session = await repository([
      {...learner, 'account_type': 'admin'},
    ]).signIn('alex.morgan', 'Old1', AccountRole.admin);
    expect(session.role, AccountRole.admin);
  });
  for (final scenario in [
    'password case',
    'password spaces',
    'unknown identity',
    'inactive',
    'role mismatch',
    'ambiguous',
    'empty password',
  ]) {
    test('generic rejection for $scenario', () async {
      final users = [
        if (scenario == 'inactive')
          {...learner, 'is_active': false}
        else
          learner,
        if (scenario == 'ambiguous')
          {...learner, 'id': 2, 'email': 'different@example.com'},
      ];
      await expectLater(
        repository(users).signIn(
          scenario == 'unknown identity' ? 'unknown' : 'alex.morgan',
          switch (scenario) {
            'password case' => 'old1',
            'password spaces' => ' Old1 ',
            'empty password' => '',
            _ => 'Old1',
          },
          scenario == 'role mismatch' ? AccountRole.admin : AccountRole.learner,
        ),
        throwsA(
          isA<SignInException>().having(
            (e) => e.message,
            'message',
            SignInException.invalid,
          ),
        ),
      );
    });
  }
  for (final field in [
    'full_name',
    'password_hash',
    'is_active',
    'account_type',
    'id',
    'email',
  ]) {
    test('rejects malformed $field', () async {
      await expectLater(
        repository([
          {...learner, field: null},
        ]).signIn('alex.morgan', 'Old1', AccountRole.learner),
        throwsA(isA<SignInException>()),
      );
    });
  }
  for (final status in [401, 403, 404, 429, 500]) {
    test('handles HTTP $status without writing', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response('{}', status);
      });
      addTearDown(client.close);
      await expectLater(
        JsonBinSignInRepository(JsonBinStore(client: client, accessKey: 'key'))
            .signIn('alex', 'pass', AccountRole.learner),
        throwsA(isA<SignInException>()),
      );
    });
  }
  test('network failure', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      JsonBinSignInRepository(JsonBinStore(client: client, accessKey: 'key'))
          .signIn('alex', 'pass', AccountRole.learner),
      throwsA(
        isA<SignInException>().having(
          (e) => e.message,
          'message',
          contains('connection'),
        ),
      ),
    );
  });
  test('configuration checked before network', () async {
    final client = MockClient((_) async => fail('No network without key'));
    addTearDown(client.close);
    await expectLater(
      JsonBinSignInRepository(
        JsonBinStore(client: client, accessKey: '', masterKey: ''),
      ).signIn('alex', 'pass', AccountRole.learner),
      throwsA(
        isA<SignInException>().having(
          (e) => e.message,
          'message',
          contains('not configured'),
        ),
      ),
    );
  });
  test('malformed JSON', () async {
    final client = MockClient((_) async => http.Response('invalid', 200));
    addTearDown(client.close);
    await expectLater(
      JsonBinSignInRepository(JsonBinStore(client: client, accessKey: 'key'))
          .signIn('alex', 'pass', AccountRole.learner),
      throwsA(isA<SignInException>()),
    );
  });
}
