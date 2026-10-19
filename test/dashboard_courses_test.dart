import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/admin/admin_courses_screen.dart';
import 'package:learnsphere/admin/admin_dashboard_controller.dart';
import 'package:learnsphere/admin/admin_dashboard_repository.dart';
import 'package:learnsphere/admin/admin_dashboard_screen.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';

import 'admin_dashboard_test.dart' show admin, PendingDashboard;
import 'widget_test.dart' show reveal;

class Courses implements AdminCoursesRepository {
  List<Course> items = [];
  Completer<List<Course>>? pending;
  bool fail = false;
  int calls = 0;
  @override
  Future<List<Course>> list(UserSession actor) async {
    calls++;
    if (fail) throw const JsonBinException('Course request failed');
    return pending == null ? items : pending!.future;
  }

  @override
  Future<Course> save(UserSession actor, Course course) async => course;
}

Course course(String id, String status, [String date = '']) => Course.empty()
  ..data.addAll({
    'id': id,
    'title': 'Course $id',
    'category': 'Development',
    'status': status,
    'updated_at': date,
  });

void main() {
  test('course failure does not block learner success and manual refresh retries both', () async {
    final learners = PendingDashboard()
      ..pending.complete(const AdminDashboardSummary(learnerCount: 7));
    final repo = Courses()..fail = true;
    final controller = AdminDashboardController(
      learners,
      coursesRepository: repo,
      session: admin,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.summary!.learnerCount, 7);
    expect(controller.courses, isNull);
    expect(controller.courseError, isNotNull);
    repo.fail = false;
    repo.items = [course('created', 'Draft')];
    await controller.load();
    expect(controller.courses!.length, 1);
    expect(controller.courseError, isNull);
    expect(learners.calls, 2);
    expect(repo.calls, 2);
  });

  test(
    'counts statuses and sorts recent non-archived courses with stable ties',
    () async {
      final repo = Courses()
        ..items = [
          course('a', 'Draft'),
          course('b', 'Published', 'bad'),
          course('c', 'Published', '2026-10-01'),
          course('d', 'Draft', '2026-10-02'),
          course('z', 'Archived', '2026-10-03'),
        ];
      final controller = AdminDashboardController(
        PendingDashboard(),
        coursesRepository: repo,
        session: admin,
      );
      addTearDown(controller.dispose);
      await controller.loadCourses();
      expect(controller.courses!.length, 5);
      expect(controller.courseCount('Draft'), 2);
      expect(controller.courseCount('Published'), 2);
      expect(controller.courseCount('Archived'), 1);
      expect(controller.recentCourses.map((c) => c.id), ['d', 'c', 'a']);
      repo.items = [course('x', 'Archived')];
      await controller.loadCourses();
      expect(controller.recentCourses, isEmpty);
      repo.items = [];
      await controller.loadCourses();
      expect(controller.courses, isEmpty);
    },
  );

  test(
    'independent requests, duplicate guard, stale cache, retry and disposal',
    () async {
      final learners = PendingDashboard();
      final repo = Courses()..pending = Completer();
      final controller = AdminDashboardController(
        learners,
        coursesRepository: repo,
        session: admin,
      );
      final loading = controller.load();
      await controller.loadCourses();
      expect(repo.calls, 1);
      repo.pending!.complete([course('a', 'Draft')]);
      learners.pending.completeError(const JsonBinException('Learners failed'));
      await loading;
      expect(controller.error, 'Learners failed');
      expect(controller.courses!.length, 1);
      repo.pending = null;
      repo.fail = true;
      await controller.loadCourses();
      expect(controller.courseError, 'Course request failed');
      expect(controller.courses!.length, 1);
      repo.fail = false;
      await controller.loadCourses();
      expect(controller.courseError, isNull);
      repo.pending = Completer();
      final refresh = controller.loadCourses();
      controller.dispose();
      repo.pending!.complete([course('b', 'Published')]);
      await refresh;
      expect(controller.courses, isEmpty);
    },
  );

  for (final width in [320.0, 430.0, 1440.0]) {
    testWidgets(
      'course cards, editor, View All, refresh and errors at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final learners = PendingDashboard()
          ..pending.complete(const AdminDashboardSummary(learnerCount: 9));
        final repo = Courses()
          ..items = [
            course('a', 'Draft')
              ..data['thumbnail'] = 'https://example.invalid/image.png',
          ];
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: AdminDashboardScreen(
              repository: learners,
              coursesRepository: repo,
              session: admin,
              onSignOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('0 Published · 1 Draft · 0 Archived'), findsOneWidget);
        final card = find.byKey(const ValueKey('recent_course_a'));
        await reveal(tester, card);
        expect(
          find.descendant(
            of: card,
            matching: find.byIcon(Icons.menu_book_outlined),
          ),
          findsOneWidget,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(CourseEditorScreen), findsOneWidget);
        repo.items = [course('b', 'Published')];
        Navigator.of(tester.element(find.byType(CourseEditorScreen))).pop();
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('recent_course_b')));
        expect(find.text('Course b'), findsOneWidget);
        await reveal(tester, find.text('View All'));
        await tester.tap(find.text('View All'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminCoursesScreen), findsOneWidget);
        repo.fail = true;
        Navigator.of(tester.element(find.byType(AdminCoursesScreen))).pop();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Retry courses'));
        expect(
          find.text('Showing the last loaded course data.'),
          findsOneWidget,
        );
        repo.fail = false;
        repo.items = [];
        await tester.tap(find.text('Retry courses'));
        await tester.pumpAndSettle();
        expect(
          find.text('No recent courses yet. Create a course to get started.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
