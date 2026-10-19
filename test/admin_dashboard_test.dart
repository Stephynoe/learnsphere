import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/admin/admin_dashboard_controller.dart';
import 'package:learnsphere/admin/admin_dashboard_repository.dart';
import 'package:learnsphere/admin/admin_dashboard_screen.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/main.dart';

import 'sign_in_controller_test.dart' show MemoryPreferences, PendingSignIn;
import 'sign_in_widget_test.dart' show enterCredentials;
import 'widget_test.dart' show reveal;

class PendingDashboard implements AdminDashboardRepository {
  Completer<AdminDashboardSummary> pending = Completer();
  int calls = 0;
  @override
  Future<AdminDashboardSummary> loadSummary() {
    calls++;
    return pending.future;
  }
}

const admin = UserSession(
  id: 2,
  fullName: 'Admin Alex',
  email: 'admin@example.com',
  username: 'admin',
  role: AccountRole.admin,
);

void main() {
  group('read-only repository', () {
    JsonBinAdminDashboardRepository repository(
      Object? users, {
      int status = 200,
    }) {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/latest'), isTrue);
        return http.Response(
          jsonEncode({
            'record': {'users': users},
          }),
          status,
        );
      });
      addTearDown(client.close);
      return JsonBinAdminDashboardRepository(
        JsonBinStore(client: client, accessKey: 'test'),
      );
    }

    Map<String, dynamic> user(int id, String role, bool active) => {
      'id': id,
      'email': '$id@example.com',
      'username': 'user$id',
      'account_type': role,
      'is_active': active,
    };
    test('counts active and inactive learners and excludes admins', () async {
      final result = await repository([
        user(1, 'learner', true),
        user(2, 'learner', false),
        user(3, 'admin', true),
      ]).loadSummary();
      expect(result.learnerCount, 2);
    });
    test('empty users returns zero', () async {
      expect((await repository([]).loadSummary()).learnerCount, 0);
    });
    test(
      'invalid users and missing role fail instead of returning zero',
      () async {
        for (final users in [
          null,
          [42],
          [
            {'id': 1, 'email': 'a', 'username': 'b'},
          ],
        ]) {
          await expectLater(
            repository(users).loadSummary(),
            throwsA(isA<JsonBinException>()),
          );
        }
      },
    );
    test('request failure propagates', () async {
      await expectLater(
        repository([], status: 403).loadSummary(),
        throwsA(isA<JsonBinException>()),
      );
    });
  });

  test(
    'controller loads, guards duplicates, refreshes, fails and retries',
    () async {
      final repo = PendingDashboard();
      final controller = AdminDashboardController(repo);
      addTearDown(controller.dispose);
      final first = controller.load();
      await controller.load();
      expect(repo.calls, 1);
      expect(controller.busy, isTrue);
      repo.pending.complete(const AdminDashboardSummary(learnerCount: 3));
      await first;
      expect(controller.summary!.learnerCount, 3);
      repo.pending = Completer();
      final refresh = controller.load();
      repo.pending.completeError(const JsonBinException('Offline'));
      await refresh;
      expect(controller.error, 'Offline');
      expect(controller.summary!.learnerCount, 3);
      repo.pending = Completer();
      final retry = controller.load();
      repo.pending.complete(const AdminDashboardSummary(learnerCount: 4));
      await retry;
      expect(controller.error, isNull);
      expect(controller.summary!.learnerCount, 4);
    },
  );

  test('controller ignores completion after disposal', () async {
    final repo = PendingDashboard();
    final controller = AdminDashboardController(repo);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final pending = controller.load();
    controller.dispose();
    repo.pending.complete(const AdminDashboardSummary(learnerCount: 3));
    await pending;
    await controller.load();
    expect(notifications, 1);
    expect(controller.summary, isNull);
    expect(repo.calls, 1);
  });

  testWidgets('loading, failure, retry and empty sections', (tester) async {
    final repo = PendingDashboard();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          repository: repo,
          session: admin,
          onSignOut: () {},
          warning: 'Preference warning',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Preference warning'), findsOneWidget);
    repo.pending.completeError(const JsonBinException('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
    repo.pending = Completer();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    repo.pending.complete(const AdminDashboardSummary(learnerCount: 0));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    await reveal(tester, find.text('Enrollment data is unavailable.').last);
    expect(find.text('Enrollment data is unavailable.'), findsWidgets);
  });

  for (final width in [320.0, 430.0, 1440.0]) {
    testWidgets('responsive dashboard and controls at $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PendingDashboard()
        ..pending.complete(const AdminDashboardSummary(learnerCount: 12));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: AdminDashboardScreen(
            repository: repo,
            session: admin,
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in [
        'Create Course',
        'Add Learner',
        'Review',
        'Export',
        'View All',
      ]) {
        await reveal(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('$label: Coming soon'), findsOneWidget);
      }
      for (final label in ['Courses', 'Learners', 'Enrollments']) {
        // The metric label also says Learners; the navigation label is last.
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(find.text('$label: Coming soon'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications: Coming soon'), findsOneWidget);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Admin Alex'), findsOneWidget);
      expect(find.text('admin@example.com'), findsOneWidget);
      Navigator.of(tester.element(find.text('admin@example.com'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin_nav_more')));
      await tester.pumpAndSettle();
      expect(find.text('Admin Alex'), findsOneWidget);
      expect(find.text('admin@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('signout')), findsOneWidget);
      expect(find.text('More: Coming soon'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin sign-in opens dashboard and sign-out clears history', (
    tester,
  ) async {
    final auth = PendingSignIn();
    final repo = PendingDashboard()
      ..pending.complete(const AdminDashboardSummary(learnerCount: 7));
    await tester.pumpWidget(
      MyApp(
        signInRepository: auth,
        preferences: MemoryPreferences(),
        adminDashboardRepository: repo,
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Administrator'));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    await enterCredentials(tester);
    await reveal(tester, find.byKey(const ValueKey('signin_submit')));
    await tester.tap(find.byKey(const ValueKey('signin_submit')));
    await tester.pump();
    auth.pending.complete(admin);
    await tester.pumpAndSettle();
    expect(find.text('Admin Workspace'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Admin Workspace'))).canPop(),
      isFalse,
    );
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('signout')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to LearnSphere'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Welcome to LearnSphere')))
          .canPop(),
      isFalse,
    );
  });
}
