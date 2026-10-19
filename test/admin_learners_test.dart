import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/admin/admin_dashboard_repository.dart';
import 'package:learnsphere/admin/admin_dashboard_screen.dart';
import 'package:learnsphere/admin/admin_learners_controller.dart';
import 'package:learnsphere/admin/admin_learners_repository.dart';
import 'package:learnsphere/admin/admin_learners_screen.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/profile/profile_controller.dart';
import 'package:learnsphere/profile/profile_repository.dart';

const actor = UserSession(
  id: 1,
  fullName: 'Admin Alex',
  email: 'admin@example.com',
  username: 'admin',
  role: AccountRole.admin,
);
Map<String, dynamic> account(
  int id, {
  String role = 'learner',
  bool active = true,
  String? name,
}) => {
  'id': id,
  'full_name': name ?? 'Learner $id',
  'email': '$id@example.com',
  'username': 'user$id',
  'account_type': role,
  'is_active': active,
  'password_hash': 'private',
  'reset_password_answer': 'private answer',
  'created_at': '2026-01-02T00:00:00Z',
};

class MemoryLearners implements AdminLearnersRepository {
  List<LearnerDetails> data = [
    for (final id in [2, 3])
      LearnerDetails(
        LearnerSummary.fromUser(account(id, active: id == 2)),
        UserProfile.fromUser(account(id)),
      ),
  ];
  bool fail = false;
  int saves = 0;
  Completer<LearnerDetails>? pending;
  @override
  Future<List<LearnerSummary>> listLearners(UserSession adminSession) async {
    if (fail) throw const ProfileException('Load failed');
    return data.map((e) => e.summary).toList();
  }

  @override
  Future<LearnerDetails> loadLearner(
    UserSession adminSession,
    int learnerId,
  ) async => data.firstWhere((e) => e.summary.id == learnerId);
  @override
  Future<LearnerDetails> saveLearner(
    UserSession adminSession,
    int learnerId,
    LearnerChanges changes,
  ) async {
    saves++;
    if (fail) throw const ProfileException('Save failed');
    if (pending != null) return pending!.future;
    final old = data.firstWhere((e) => e.summary.id == learnerId).summary;
    final p = changes.profile.normalized();
    final result = LearnerDetails(
      LearnerSummary(
        id: old.id,
        name: p.fullName,
        email: p.text('email'),
        username: old.username,
        organization: p.text('organization'),
        active: old.active,
      ),
      p,
    );
    data = [
      for (final value in data)
        if (value.summary.id == learnerId) result else value,
    ];
    return result;
  }
}

class DashboardData implements AdminDashboardRepository {
  @override
  Future<AdminDashboardSummary> loadSummary() async =>
      const AdminDashboardSummary(learnerCount: 2);
}

void main() {
  late List<Map<String, dynamic>> users;
  late Map<String, dynamic> record;
  late JsonBinAdminLearnersRepository repository;
  var writes = 0;
  var status = 200;
  setUp(() {
    users = [
      account(1, role: 'admin'),
      account(2, active: false),
      account(3, name: 'Aaron'),
    ];
    users[1]['profile'] = {
      'avatar': 'owl',
      'public_profile': true,
      'weekly_reminders': true,
      'unknown': 'preserved',
    };
    record = {'users': users, 'last_id': 20, 'unknown': 'top-level'};
    writes = 0;
    status = 200;
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        writes++;
        record = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', status);
      }
      return http.Response(jsonEncode({'record': record}), status);
    });
    addTearDown(client.close);
    repository = JsonBinAdminLearnersRepository(
      JsonBinStore(client: client, accessKey: 'test'),
    );
  });
  test('list excludes admins, sorts learners and loads inactive and legacy details', () async {
    final list = await repository.listLearners(actor);
    expect(list.map((e) => e.id), [3, 2]);
    expect(list.last.active, false);
    final detail = await repository.loadLearner(actor, 2);
    expect(detail.profile.text('first_name'), 'Learner');
    expect(detail.profile.text('last_name'), '2');
    expect(detail.profile.values.containsKey('password_hash'), false);
    expect(detail.profile.values.containsKey('unknown'), false);
    expect(writes, 0);
  });
  test(
    'inactive learner saves preserve all restricted data and other accounts',
    () async {
      final beforeOther = jsonEncode(users[2]);
      final changes = LearnerChanges(
        UserProfile({
          'first_name': ' New ',
          'last_name': 'Name',
          'email': ' NEW@example.com ',
          'avatar': 'cat',
          'public_profile': false,
          'weekly_reminders': false,
          'topics': [' Flutter '],
        }),
      );
      final detail = await repository.saveLearner(actor, 2, changes);
      final saved = record['users'][1];
      expect(saved['full_name'], 'New Name');
      expect(saved['email'], 'new@example.com');
      expect(saved['is_active'], false);
      expect(saved['username'], 'user2');
      expect(saved['account_type'], 'learner');
      expect(saved['password_hash'], 'private');
      expect(saved['reset_password_answer'], 'private answer');
      expect(saved['profile']['avatar'], 'owl');
      expect(saved['profile']['public_profile'], true);
      expect(saved['profile']['weekly_reminders'], true);
      expect(saved['profile']['unknown'], 'preserved');
      expect(saved['profile']['topics'], ['Flutter']);
      expect(jsonEncode(record['users'][2]), beforeOther);
      expect(record['last_id'], 20);
      expect(record['unknown'], 'top-level');
      expect(detail.summary.active, false);
      expect(actor.fullName, 'Admin Alex');
    },
  );
  test(
    'other administrators are excluded and cannot be loaded or saved',
    () async {
      users.add(account(4, role: 'admin'));
      final before = jsonEncode(record);
      expect(
        (await repository.listLearners(actor)).map((u) => u.id),
        isNot(contains(4)),
      );
      await expectLater(
        repository.loadLearner(actor, 4),
        throwsA(isA<ProfileException>()),
      );
      await expectLater(
        repository.saveLearner(
          actor,
          4,
          LearnerChanges(
            UserProfile({
              'first_name': 'Changed',
              'email': 'changed@example.com',
            }),
          ),
        ),
        throwsA(isA<ProfileException>()),
      );
      expect(writes, 0);
      expect(jsonEncode(record), before);
    },
  );
  test(
    'a learner promoted to administrator cannot be saved from a stale editor',
    () async {
      final details = await repository.loadLearner(actor, 2);
      users[1]['account_type'] = 'admin';
      await expectLater(
        repository.saveLearner(actor, 2, LearnerChanges(details.profile)),
        throwsA(isA<ProfileException>()),
      );
      expect(writes, 0);
    },
  );
  test('every operation rechecks active admin and learner target', () async {
    users[0]['is_active'] = false;
    final changes = LearnerChanges(
      UserProfile({'first_name': 'Alex', 'email': 'new@example.com'}),
    );
    await expectLater(
      repository.listLearners(actor),
      throwsA(isA<ProfileException>()),
    );
    await expectLater(
      repository.loadLearner(actor, 2),
      throwsA(isA<ProfileException>()),
    );
    await expectLater(
      repository.saveLearner(actor, 2, changes),
      throwsA(isA<ProfileException>()),
    );
    users[0]['is_active'] = true;
    await expectLater(
      repository.loadLearner(actor, 1),
      throwsA(isA<ProfileException>()),
    );
    await expectLater(
      repository.saveLearner(actor, 99, changes),
      throwsA(isA<ProfileException>()),
    );
    users.add(account(2));
    await expectLater(
      repository.loadLearner(actor, 2),
      throwsA(isA<ProfileException>()),
    );
    expect(writes, 0);
  });
  test('a learner session cannot act as an administrator', () async {
    const learner = UserSession(
      id: 2,
      fullName: 'Learner',
      email: '2@example.com',
      username: 'user2',
      role: AccountRole.learner,
    );
    await expectLater(
      repository.listLearners(learner),
      throwsA(isA<ProfileException>()),
    );
    await expectLater(
      repository.loadLearner(learner, 3),
      throwsA(isA<ProfileException>()),
    );
    await expectLater(
      repository.saveLearner(
        learner,
        3,
        LearnerChanges(
          UserProfile({'first_name': 'Name', 'email': 'new@example.com'}),
        ),
      ),
      throwsA(isA<ProfileException>()),
    );
    expect(writes, 0);
  });
  testWidgets(
    'narrow large-text layout retries, filters, and confirms discarded edits',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final memory = MemoryLearners()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: AdminLearnersScreen(
            repository: memory,
            session: actor,
            onAccount: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Load failed'), findsOneWidget);
      memory.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(find.text('Learner 3'), findsNothing);
      final edit = find.text('Edit Profile');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Status: Active'), findsOneWidget);
      final name = find.byType(TextField).first;
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Discard me');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(memory.saves, 0);
      expect(find.text('Learner 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'email and username conflicts, malformed profiles and transport failures',
    () async {
      for (final email in ['3@EXAMPLE.com', 'user3']) {
        // user3 is not an email, so validate it as an email-shaped username below.
        if (email == 'user3') users[2]['username'] = 'taken@example.com';
        await expectLater(
          repository.saveLearner(
            actor,
            2,
            LearnerChanges(
              UserProfile({
                'first_name': 'Name',
                'email': email == 'user3' ? 'taken@example.com' : email,
              }),
            ),
          ),
          throwsA(isA<ProfileException>()),
        );
      }
      users[1]['profile'] = {
        'topics': [42],
      };
      await expectLater(
        repository.loadLearner(actor, 2),
        throwsA(isA<ProfileException>()),
      );
      expect(writes, 0);
      status = 403;
      await expectLater(
        repository.listLearners(actor),
        throwsA(isA<JsonBinException>()),
      );
    },
  );
  test('search, filters and failed refresh retain data', () async {
    final memory = MemoryLearners();
    final controller = AdminLearnersController(memory, actor);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.visible.length, 2);
    controller.search('USER3');
    expect(controller.visible.single.id, 3);
    controller.select(LearnerFilter.active);
    expect(controller.visible, isEmpty);
    controller.search('');
    expect(controller.visible.single.id, 2);
    controller.select(LearnerFilter.inactive);
    expect(controller.visible.single.id, 3);
    memory.fail = true;
    await controller.load();
    expect(controller.error, 'Load failed');
    expect(controller.visible.single.id, 3);
  });
  test(
    'admin editing retains failed edits and guards duplicate submissions',
    () async {
      final memory = MemoryLearners();
      final adapter = AdminLearnerProfileAdapter(memory, actor, 3, (_) {});
      final controller = ProfileController(adapter, actor);
      addTearDown(controller.dispose);
      await controller.load();
      controller.change('first_name', 'Updated');
      memory.fail = true;
      expect(await controller.save(), false);
      expect(controller.dirty, true);
      memory.fail = false;
      memory.pending = Completer();
      final save = controller.save();
      expect(await controller.save(), false);
      memory.pending!.complete(
        LearnerDetails(memory.data.last.summary, controller.profile!),
      );
      expect(await save, true);
      expect(controller.dirty, false);
      expect(memory.saves, 2);
      expect(actor.email, 'admin@example.com');
    },
  );
  testWidgets(
    'Learners navigation edits inactive learners and returns to the same list',
    (tester) async {
      final memory = MemoryLearners();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            repository: DashboardData(),
            session: actor,
            learnersRepository: memory,
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin_nav_learners')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLearnersScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'user3');
      await tester.pumpAndSettle();
      final edit = find.text('Edit Profile');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Edit Learner Profile'), findsOneWidget);
      expect(find.text('Status: Inactive'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Password & Security'), findsNothing);
      final name = find.byType(TextField).first;
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Updated');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      final toggle = find.byType(SwitchListTile).first;
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Updated 3'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'user3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin_nav_dashboard')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLearnersScreen), findsNothing);
      expect(actor.fullName, 'Admin Alex');
    },
  );
}
