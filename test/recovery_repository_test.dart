import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/auth/recovery_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';

Map<String, dynamic> recoveryUser() => {
  'id': 1,
  'full_name': 'Alex Morgan',
  'email': 'Alex@Example.com',
  'username': 'Alex',
  'password_hash': 'Old1!',
  'is_active': true,
  'account_type': 'learner',
  'reset_password_question': 'Favorite place?',
  'reset_password_answer': 'New Lagos!',
  'extra': 'keep',
};

class RecoveryFixture {
  RecoveryFixture() {
    client = MockClient((request) async {
      expect(request.headers['X-Access-Key'], 'test');
      if (request.method == 'GET') {
        reads++;
        if (failRead) throw http.ClientException('offline');
        return http.Response(jsonEncode({'record': record}), readStatus);
      }
      expect(request.method, 'PUT');
      writes++;
      if (failWrite) throw http.ClientException('disconnected');
      if (writeStatus == 200) {
        record = jsonDecode(request.body) as Map<String, dynamic>;
      }
      return http.Response('{}', writeStatus);
    });
    store = JsonBinStore(client: client, accessKey: 'test', masterKey: '');
    repository = JsonBinRecoveryRepository(store);
  }
  Map<String, dynamic> record = {
    'last_id': 8,
    'users': [
      recoveryUser(),
      {
        ...recoveryUser(),
        'id': 8,
        'email': 'other@example.com',
        'username': 'other',
        'account_type': 'admin',
      },
    ],
    'extra_record': {'keep': true},
  };
  late final http.Client client;
  late final JsonBinStore store;
  late final JsonBinRecoveryRepository repository;
  int reads = 0, writes = 0, readStatus = 200, writeStatus = 200;
  bool failRead = false, failWrite = false;
  Map<String, dynamic> get user =>
      (record['users'] as List).first as Map<String, dynamic>;
}

void main() {
  late RecoveryFixture fixture;
  setUp(() {
    fixture = RecoveryFixture();
  });
  tearDown(() => fixture.client.close());
  for (final identity in [' ALEX@example.com ', ' ALEX ']) {
    test('lookup normalizes $identity and returns question only', () async {
      final account = await fixture.repository.lookup(identity);
      expect(account.id, 1);
      expect(account.question, 'Favorite place?');
      expect(account.identity, identity.trim().toLowerCase());
      expect(fixture.writes, 0);
    });
  }
  test('both active roles recover', () async {
    fixture.user['account_type'] = 'admin';
    await fixture.repository.lookup('alex');
    await fixture.repository.verifyAnswer(' NEW LAGOS! ');
    await fixture.repository.resetPassword(' Newpass1! ', ' Newpass1! ');
    expect(fixture.user['password_hash'], ' Newpass1! ');
  });
  test(
    'reset changes only intended password and preserves complete record',
    () async {
      final before =
          jsonDecode(jsonEncode(fixture.record)) as Map<String, dynamic>;
      await fixture.repository.lookup('alex');
      await fixture.repository.verifyAnswer('new lagos!');
      await fixture.repository.resetPassword('Newpass1!', 'Newpass1!');
      ((before['users'] as List).first as Map)['password_hash'] = 'Newpass1!';
      expect(fixture.record, before);
      expect(fixture.reads, 2);
      expect(fixture.writes, 1);
      await expectLater(
        fixture.repository.resetPassword('Otherpass1!', 'Otherpass1!'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 1);
    },
  );
  test('unknown account is explicit', () async {
    await expectLater(
      fixture.repository.lookup('missing'),
      throwsA(
        isA<RecoveryException>().having(
          (e) => e.message,
          'message',
          'No account found with that email or username.',
        ),
      ),
    );
  });
  for (final scenario in [
    'ambiguous identity',
    'duplicate ID',
    'inactive',
    'unsupported role',
    'missing question',
    'missing answer',
    'malformed answer',
  ]) {
    test('rejects $scenario without writing', () async {
      switch (scenario) {
        case 'ambiguous identity':
          (fixture.record['users'] as List).add({...recoveryUser(), 'id': 9});
        case 'duplicate ID':
          (fixture.record['users'] as List)[1]['id'] = 1;
        case 'inactive':
          fixture.user['is_active'] = false;
        case 'unsupported role':
          fixture.user['account_type'] = 'mentor';
        case 'missing question':
          fixture.user['reset_password_question'] = ' ';
        case 'missing answer':
          fixture.user.remove('reset_password_answer');
        case 'malformed answer':
          fixture.user['reset_password_answer'] = 23;
      }
      await expectLater(
        fixture.repository.lookup('alex'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 0);
    });
  }
  for (final answer in ['new  lagos!', 'new lagos', 'wrong', ' ']) {
    test('rejects answer with significant mismatch: $answer', () async {
      await fixture.repository.lookup('alex');
      await expectLater(
        fixture.repository.verifyAnswer(answer),
        throwsA(
          isA<RecoveryException>().having((e) => e.field, 'field', 'answer'),
        ),
      );
      await expectLater(
        fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 0);
    });
  }
  test('cannot reset before verification or after clearing', () async {
    await expectLater(
      fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
      throwsA(isA<RecoveryException>()),
    );
    await fixture.repository.lookup('alex');
    await expectLater(
      fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
      throwsA(isA<RecoveryException>()),
    );
    await fixture.repository.verifyAnswer('new lagos!');
    fixture.repository.clear();
    await expectLater(
      fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
      throwsA(isA<RecoveryException>()),
    );
    expect(fixture.writes, 0);
  });
  for (final inputs in [
    ('short1!', 'short1!'),
    ('Newpassword!', 'Newpassword!'),
    ('Newpassword1', 'Newpassword1'),
    ('Newpass1!', 'newpass1!'),
  ]) {
    test('validates passwords $inputs before fetching for reset', () async {
      await fixture.repository.lookup('alex');
      await fixture.repository.verifyAnswer('new lagos!');
      await expectLater(
        fixture.repository.resetPassword(inputs.$1, inputs.$2),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 0);
      expect(fixture.reads, 1);
    });
  }
  for (final scenario in [
    'deleted',
    'ID',
    'email',
    'username',
    'role',
    'active',
    'question',
    'answer',
    'duplicate',
  ]) {
    test('changed $scenario requires restart without PUT', () async {
      await fixture.repository.lookup('alex');
      await fixture.repository.verifyAnswer('new lagos!');
      switch (scenario) {
        case 'deleted':
          (fixture.record['users'] as List).removeAt(0);
        case 'ID':
          fixture.user['id'] = 2;
        case 'email':
          fixture.user['email'] = 'changed@example.com';
        case 'username':
          fixture.user['username'] = 'changed';
        case 'role':
          fixture.user['account_type'] = 'admin';
        case 'active':
          fixture.user['is_active'] = false;
        case 'question':
          fixture.user['reset_password_question'] = 'Different?';
        case 'answer':
          fixture.user['reset_password_answer'] = 'Different';
        case 'duplicate':
          (fixture.record['users'] as List).add({...recoveryUser(), 'id': 9});
      }
      await expectLater(
        fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
        throwsA(
          isA<RecoveryException>().having((e) => e.restart, 'restart', isTrue),
        ),
      );
      expect(fixture.writes, 0);
    });
  }
  for (final status in [401, 403, 404, 429, 500]) {
    test('read HTTP $status blocks recovery', () async {
      fixture.readStatus = status;
      await expectLater(
        fixture.repository.lookup('alex'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 0);
    });
    test('write HTTP $status fails without retries', () async {
      await fixture.repository.lookup('alex');
      await fixture.repository.verifyAnswer('new lagos!');
      fixture.writeStatus = status;
      await expectLater(
        fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 1);
    });
  }
  test('reread network failure does not write', () async {
    await fixture.repository.lookup('alex');
    await fixture.repository.verifyAnswer('new lagos!');
    fixture.failRead = true;
    await expectLater(
      fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
      throwsA(isA<RecoveryException>()),
    );
    expect(fixture.writes, 0);
  });
  test(
    'uncertain write gives password-specific guidance and clears verification',
    () async {
      await fixture.repository.lookup('alex');
      await fixture.repository.verifyAnswer('new lagos!');
      fixture.failWrite = true;
      await expectLater(
        fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
        throwsA(
          isA<RecoveryException>().having(
            (e) => e.message,
            'message',
            JsonBinRecoveryRepository.uncertain,
          ),
        ),
      );
      await expectLater(
        fixture.repository.resetPassword('Newpass1!', 'Newpass1!'),
        throwsA(isA<RecoveryException>()),
      );
      expect(fixture.writes, 1);
    },
  );
}
