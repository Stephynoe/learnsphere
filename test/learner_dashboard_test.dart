import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/learner/learner_courses_repository.dart';
import 'package:learnsphere/learner/learner_dashboard_screen.dart';

const learner = UserSession(
  id: 7,
  fullName: 'Alex Morgan',
  email: 'alex@example.com',
  username: 'alex',
  role: AccountRole.learner,
);
Course course(
  String id, {
  String status = 'Published',
  String date = '',
  String category = 'Design',
  String level = 'Beginner',
}) => Course.empty()
  ..data.addAll({
    'id': id,
    'title': 'Course $id',
    'headline': 'Learn skills',
    'instructor': 'Taylor',
    'category': category,
    'difficulty': level,
    'status': status,
    'updated_at': date,
    'modules': [
      {
        'title': 'Introduction',
        'lessons': [
          {'title': 'First lesson', 'content': 'Private lesson content'},
        ],
      },
    ],
  });

class Catalog implements LearnerCoursesRepository {
  List<Course> items = [
    course('one'),
    course('two', category: 'Technology', level: 'Advanced'),
  ];
  bool fail = false;
  Completer<List<Course>>? pending;
  @override
  Future<List<Course>> list(UserSession actor) async {
    if (fail) throw const JsonBinException('Discovery failed');
    return pending == null ? items : pending!.future;
  }
}

final verticalScroll = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);
void main() {
  test('published catalog ordering handles invalid dates and ID ties', () {
    expect(
      publishedCourses([
        course('z'),
        course('draft', status: 'Draft'),
        course('a'),
        course('new', date: '2026-10-18'),
        course('old', date: '2025-01-01'),
        course('archived', status: 'Archived'),
      ]).map((c) => c.id),
      ['new', 'old', 'a', 'z'],
    );
  });
  test(
    'learner repository authorizes, validates and only performs GET',
    () async {
      var active = true, duplicate = false, malformed = false;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final user = {
          'id': 7,
          'email': learner.email,
          'username': 'alex',
          'account_type': 'learner',
          'is_active': active,
        };
        final record = request.url.path.contains('/users/')
            ? {
                'users': [user, if (duplicate) user],
              }
            : {
                'courses': malformed
                    ? [{}]
                    : [
                        course('published').data,
                        course('draft', status: 'Draft').data,
                      ],
              };
        return http.Response(jsonEncode({'record': record}), 200);
      });
      addTearDown(client.close);
      JsonBinStore store(String id) =>
          JsonBinStore(client: client, binId: id, accessKey: 'test');
      final repository = JsonBinLearnerCoursesRepository(
        store('courses'),
        store('users'),
      );
      expect((await repository.list(learner)).single.id, 'published');
      malformed = true;
      await expectLater(
        repository.list(learner),
        throwsA(isA<JsonBinException>()),
      );
      malformed = false;
      active = false;
      await expectLater(
        repository.list(learner),
        throwsA(isA<JsonBinException>()),
      );
      active = true;
      duplicate = true;
      await expectLater(
        repository.list(learner),
        throwsA(isA<JsonBinException>()),
      );
      duplicate = false;
      await expectLater(
        repository.list(
          const UserSession(
            id: 7,
            fullName: 'Admin',
            email: '',
            username: '',
            role: AccountRole.admin,
          ),
        ),
        throwsA(isA<JsonBinException>()),
      );
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    },
  );
  Future<void> open(
    WidgetTester tester,
    Catalog repo, {
    VoidCallback? signOut,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerDashboardScreen(
          repository: repo,
          session: learner,
          onSignOut: signOut ?? () {},
          onEditProfile: (_) async => const UserSession(
            id: 7,
            fullName: 'Updated Learner',
            email: 'new@example.com',
            username: 'alex',
            role: AccountRole.learner,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Explore search, category and difficulty combine and retain state; details hide content',
    (tester) async {
      final repo = Catalog();
      await open(tester, repo);
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('search-1')), 'Taylor');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter courses'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Design').first);
      await tester.pumpAndSettle();
      expect(find.text('No matching courses'), findsOneWidget);
      await tester.tap(find.text('All categories').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Course two'),
        200,
        scrollable: verticalScroll,
      );
      await tester.tap(find.text('Course two'));
      await tester.pumpAndSettle();
      expect(find.text('Course Details'), findsOneWidget);
      expect(find.text('Private lesson content'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Taylor'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Updated'), findsOneWidget);
    },
  );
  testWidgets('loading, initial failure, retry and cached refresh failure', (
    tester,
  ) async {
    final repo = Catalog()..pending = Completer<List<Course>>();
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerDashboardScreen(
          repository: repo,
          session: learner,
          onSignOut: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Explore'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pending!.completeError(const JsonBinException('Discovery failed'));
    await tester.pumpAndSettle();
    expect(find.text('Discovery failed'), findsOneWidget);
    repo.pending = null;
    await tester.scrollUntilVisible(
      find.text('Retry'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    repo.fail = true;
    await tester.scrollUntilVisible(
      find.byTooltip('Refresh courses'),
      250,
      scrollable: verticalScroll,
    );
    await tester.tap(find.byTooltip('Refresh courses'));
    await tester.pumpAndSettle();
    expect(find.text('Discovery failed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Course one').last,
      200,
      scrollable: verticalScroll,
    );
    expect(find.text('Course one').last, findsOneWidget);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('empty catalog and account at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var signedOut = false;
      await open(
        tester,
        Catalog()..items = [],
        signOut: () => signedOut = true,
      );
      await tester.scrollUntilVisible(
        find.text('No published courses yet'),
        250,
        scrollable: verticalScroll,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Account profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('signout')));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
    });
  }
}
