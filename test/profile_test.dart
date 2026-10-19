import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/profile/profile_repository.dart';
import 'package:learnsphere/profile/profile_controller.dart';
import 'package:learnsphere/profile/profile_screen.dart';

const session = UserSession(
  id: 1,
  fullName: 'Alex Smith',
  email: 'alex@example.com',
  username: 'alex',
  role: AccountRole.learner,
);

class MemoryProfile implements ProfileRepository {
  UserProfile data = UserProfile({
    'first_name': 'Alex',
    'last_name': 'Smith',
    'email': 'alex@example.com',
  });
  bool fail = false;
  Completer<UserProfile>? pending;
  int saves = 0;
  @override
  Future<UserProfile> load(UserSession session) async => data;
  @override
  Future<UserProfile> save(UserSession session, UserProfile profile) async {
    saves++;
    if (fail) throw const ProfileException('Save failed');
    return pending == null ? data = profile.normalized() : pending!.future;
  }
}

void main() {
  test('repository rejects identity collisions, unavailable accounts and transport failures', () async {
    var status = 200;
    var writes = 0;
    final account = <String, dynamic>{
      'id': 1,
      'full_name': 'Alex',
      'email': session.email,
      'username': 'alex',
      'is_active': true,
      'account_type': 'learner',
    };
    final users = <Map<String, dynamic>>[
      account,
      {'id': 2, 'email': 'other@example.com', 'username': 'taken@example.com'},
    ];
    final client = MockClient((r) async {
      if (r.method == 'PUT') {
        writes++;
        return http.Response('{}', status);
      }
      return http.Response(
        jsonEncode({
          'record': {'users': users},
        }),
        status,
      );
    });
    addTearDown(client.close);
    final repository = JsonBinProfileRepository(
      JsonBinStore(client: client, accessKey: 'test'),
    );
    for (final email in ['OTHER@example.com', 'taken@example.com']) {
      await expectLater(
        repository.save(
          session,
          UserProfile({'first_name': 'Alex', 'email': email}),
        ),
        throwsA(isA<ProfileException>()),
      );
    }
    expect(writes, 0);
    account['is_active'] = false;
    await expectLater(
      repository.load(session),
      throwsA(isA<ProfileException>()),
    );
    account['is_active'] = true;
    account['profile'] = {
      'topics': [1],
    };
    await expectLater(
      repository.load(session),
      throwsA(isA<ProfileException>()),
    );
    account.remove('profile');
    users.removeAt(0);
    await expectLater(
      repository.load(session),
      throwsA(isA<ProfileException>()),
    );
    status = 403;
    await expectLater(
      repository.load(session),
      throwsA(isA<JsonBinException>()),
    );
  });
  testWidgets('save updates the session and recovery is reachable', (
    tester,
  ) async {
    final repository = MemoryProfile();
    UserSession? updated;
    var security = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          session: session,
          onSaved: (value) => updated = value,
          onSecurity: () => security = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstName = find.byType(TextField).first;
    await tester.ensureVisible(firstName);
    await tester.enterText(firstName, 'Taylor');
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(updated!.fullName, 'Taylor Smith');
    expect(find.text('Profile saved'), findsOneWidget);
    final recovery = find.text('Password & Security');
    await tester.ensureVisible(recovery);
    await tester.tap(recovery);
    expect(security, true);
    expect(tester.takeException(), isNull);
  });
  for (final role in AccountRole.values) {
    test(
      'JSONBin preserves records and loads legacy defaults for ${role.name}',
      () async {
        final user = {
          'id': 1,
          'full_name': 'Alex Smith',
          'email': session.email,
          'username': 'alex',
          'is_active': true,
          'account_type': role.value,
          'password_hash': 'secret',
          'extra': 42,
        };
        final record = {
          'users': [user],
          'last_id': 9,
          'extra': 'kept',
        };
        Map<String, dynamic>? saved;
        final client = MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(jsonEncode({'record': record}), 200);
          }
          saved = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        });
        addTearDown(client.close);
        final repository = JsonBinProfileRepository(
          JsonBinStore(client: client, accessKey: 'test'),
        );
        final account = UserSession(
          id: 1,
          fullName: session.fullName,
          email: session.email,
          username: session.username,
          role: role,
        );
        final profile = await repository.load(account);
        expect(profile.text('first_name'), 'Alex');
        expect(profile.text('last_name'), 'Smith');
        expect(profile.flag('public_profile'), false);
        await repository.save(
          account,
          UserProfile({
            ...profile.values,
            'first_name': ' New ',
            'email': ' NEW@example.com ',
          }),
        );
        expect(saved!['last_id'], 9);
        expect(saved!['extra'], 'kept');
        expect(saved!['users'][0]['password_hash'], 'secret');
        expect(saved!['users'][0]['extra'], 42);
        expect(saved!['users'][0]['full_name'], 'New Smith');
        expect(saved!['users'][0]['email'], 'new@example.com');
      },
    );
  }
  test('validation rejects invalid links and repeated topics', () {
    final p = UserProfile({
      'first_name': '',
      'email': 'bad',
      'portfolio': 'javascript:alert(1)',
      'github': 'bad/name',
      'topics': ['Flutter', ' flutter '],
    });
    expect(
      p.validate().keys,
      containsAll(['first_name', 'email', 'portfolio', 'github', 'topics']),
    );
  });
  test(
    'controller retains failed edits and prevents concurrent saves',
    () async {
      final repository = MemoryProfile();
      final controller = ProfileController(repository, session);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.dirty, false);
      controller.change('first_name', 'Changed');
      repository.fail = true;
      expect(await controller.save(), false);
      expect(controller.dirty, true);
      expect(controller.profile!.text('first_name'), 'Changed');
      repository.fail = false;
      repository.pending = Completer();
      final save = controller.save();
      expect(await controller.save(), false);
      repository.pending!.complete(controller.profile);
      expect(await save, true);
      expect(controller.dirty, false);
      expect(controller.session.fullName, 'Changed Smith');
      expect(repository.saves, 2);
    },
  );
  testWidgets(
    'profile supports narrow large-text editing, avatars and discard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryProfile();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(
                      repository: repository,
                      session: session,
                      onSaved: (_) {},
                      onSecurity: () {},
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar_owl')));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
