import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/data/jsonbin_stores.dart';

void main() {
  test(
    'independent stores target their bins and preserve arbitrary records',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'record': {'courses': [], 'extra': 'preserved'},
          }),
          200,
        );
      });
      addTearDown(client.close);
      final courses = JsonBinStore(
        client: client,
        binId: 'courses',
        accessKey: 'course-key',
      );
      final enrollments = JsonBinStore(
        client: client,
        binId: 'enrollments',
        accessKey: 'enrollment-key',
      );
      final record = await courses.read(operation: 'Courses');
      expect(record['extra'], 'preserved');
      await enrollments.write({
        'enrollments': [],
        'extra': 'kept',
      }, operation: 'Enrollments');
      expect(requests[0].url.path, '/v3/b/courses/latest');
      expect(requests[0].headers['X-Access-Key'], 'course-key');
      expect(requests[1].url.path, '/v3/b/enrollments');
      expect(requests[1].headers['X-Access-Key'], 'enrollment-key');
      expect(jsonDecode(requests[1].body)['extra'], 'kept');
    },
  );

  test('named stores resolve compile-time configuration independently', () {
    final client = MockClient((_) async => http.Response('', 500));
    addTearDown(client.close);
    final stores = JsonBinStores(client: client);
    expect(stores.users.binId, JsonBinStores.usersBinId);
    expect(
      stores.courses.binId,
      const String.fromEnvironment('JSONBIN_COURSES_BIN_ID'),
    );
    expect(
      stores.enrollments.binId,
      const String.fromEnvironment('JSONBIN_ENROLLMENTS_BIN_ID'),
    );
    expect(
      stores.courses.accessKey,
      const String.fromEnvironment(
        'JSONBIN_COURSES_ACCESS_KEY',
        defaultValue: JsonBinStores.sharedAccessKey,
      ),
    );
  });

  test('unconfigured optional bin fails before making a request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 500);
    });
    addTearDown(client.close);
    final store = JsonBinStore(client: client, binId: '', accessKey: 'test');
    await expectLater(
      store.read(operation: 'Courses'),
      throwsA(isA<JsonBinException>()),
    );
    expect(calls, 0);
  });

  test(
    'transport rejects malformed envelopes without requiring a user schema',
    () async {
      for (final body in ['invalid', '{}', '{"record": []}']) {
        final client = MockClient((_) async => http.Response(body, 200));
        addTearDown(client.close);
        await expectLater(
          JsonBinStore(
            client: client,
            accessKey: 'test',
          ).read(operation: 'Courses'),
          throwsA(isA<JsonBinException>()),
        );
      }
    },
  );
}
