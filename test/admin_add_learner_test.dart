import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/main.dart';
import 'package:learnsphere/registration/registration_repository.dart';
import 'package:learnsphere/registration/registration_screen.dart';

import 'admin_dashboard_test.dart' show PendingDashboard, admin;
import 'sign_in_controller_test.dart' show MemoryPreferences, PendingSignIn;
import 'sign_in_widget_test.dart' show enterCredentials;
import 'widget_test.dart' show FakeRepository, fill, reveal;
import 'registration_repository_test.dart' show data;

import 'package:learnsphere/admin/admin_dashboard_repository.dart';

void main() {
  test('administrator creates only an active learner and preserves existing records', () async {
    final old = {
      'id': 2,
      'email': 'admin@example.com',
      'username': 'admin',
      'account_type': 'admin',
      'is_active': true,
      'extra': 'kept',
    };
    Map<String, dynamic>? saved;
    final client = MockClient((r) async {
      if (r.method == 'GET') {
        return http.Response(
          jsonEncode({
            'record': {
              'users': [old],
              'last_id': 8,
              'extra': 42,
            },
          }),
          200,
        );
      }
      saved = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await JsonBinRegistrationRepository(
      client: client,
      store: JsonBinStore(client: client, accessKey: 'test'),
      administrator: admin,
    ).register(data());
    expect(saved!['last_id'], 9);
    expect(saved!['extra'], 42);
    expect(saved!['users'][0], old);
    expect(saved!['users'][1]['account_type'], 'learner');
    expect(saved!['users'][1]['is_active'], true);
    expect(saved!['users'][1]['email'], 'new@example.com');
  });
  for (final state in ['missing', 'inactive', 'learner', 'duplicate']) {
    test('creation rejects $state administrator without writing', () async {
      final user = {
        'id': admin.id,
        'email': admin.email,
        'username': admin.username,
        'account_type': state == 'learner' ? 'learner' : 'admin',
        'is_active': state != 'inactive',
      };
      var writes = 0;
      final client = MockClient((r) async {
        if (r.method == 'PUT') writes++;
        return http.Response(
          jsonEncode({
            'record': {
              'last_id': 2,
              'users': state == 'missing'
                  ? []
                  : [user, if (state == 'duplicate') user],
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await expectLater(
        JsonBinRegistrationRepository(
          client: client,
          store: JsonBinStore(client: client, accessKey: 'test'),
          administrator: admin,
        ).register(data()),
        throwsA(isA<RegistrationException>()),
      );
      expect(writes, 0);
    });
  }
  testWidgets(
    'dashboard Add Learner creates an account and retains admin session',
    (tester) async {
      final auth = PendingSignIn();
      final registration = FakeRepository();
      final dashboard = PendingDashboard()
        ..pending.complete(const AdminDashboardSummary(learnerCount: 7));
      await tester.pumpWidget(
        MyApp(
          signInRepository: auth,
          preferences: MemoryPreferences(),
          adminDashboardRepository: dashboard,
          adminLearnerRegistration: (actor) {
            expect(actor.id, admin.id);
            return registration;
          },
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
      await reveal(tester, find.text('Add Learner'));
      await tester.tap(find.text('Add Learner'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('terms')), findsNothing);
      expect(find.text('OR SIGN UP WITH'), findsNothing);
      await fill(tester);
      await reveal(tester, find.byKey(const ValueKey('submit')));
      await tester.tap(find.byKey(const ValueKey('submit')));
      await tester.pump();
      expect(registration.calls, 1);
      expect(registration.submitted!.fullName, 'Alex Morgan');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit')))
            .onPressed,
        isNull,
      );
      registration.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Learner added successfully'), findsOneWidget);
      expect(find.byType(RegistrationScreen), findsNothing);
      expect(dashboard.calls, 2);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text(admin.email), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
