import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/enrollment/enrollment_screens.dart';
import 'package:learnsphere/profile/profile_screen.dart';

import 'profile_test.dart' show MemoryProfile;

import 'enrollment_repository_test.dart' show EnrollmentFixture, learner, admin;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late EnrollmentFixture f;
  setUp(() => f = EnrollmentFixture());
  tearDown(() => f.client.close());
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'enroll, learn, resume, complete, withdraw and restore at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Uri? video;
        await tester.pumpWidget(
          MaterialApp(
            home: EnrollmentCourseScreen(
              repository: f.repo,
              actor: learner,
              courseId: 'c1',
              launcher: (uri) async {
                video = uri;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Enroll'));
        expect(f.enrollments, hasLength(1));
        await tapVisible(tester, find.text('Start learning'));
        expect(find.text('Article'), findsOneWidget);
        await tapVisible(tester, find.text('Mark complete'));
        expect(f.enrollments.single['completed_lesson_ids'], hasLength(1));
        await tapVisible(tester, find.text('Next'));
        await tapVisible(tester, find.text('Open video'));
        expect(video.toString(), 'https://example.com/video');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Resume learning'));
        expect(find.text('Open video'), findsOneWidget);
        await tapVisible(tester, find.text('Mark complete'));
        expect(find.textContaining('Course completed!'), findsOneWidget);
        expect(f.enrollments.single['completed_at'], isNotNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Withdraw'));
        await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
        await tester.pumpAndSettle();
        expect(f.enrollments.single['withdrawn_at'], isNotNull);
        await tapVisible(tester, find.text('Re-enroll'));
        expect(f.enrollments.single['withdrawn_at'], isNull);
        expect(f.enrollments.single['completed_lesson_ids'], hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'video launch failure shows feedback and does not mark complete',
    (tester) async {
      await f.repo.enroll(learner, 2, 'c1');
      final s = await f.repo.load(learner);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            repository: f.repo,
            actor: learner,
            enrollmentId: s.enrollments.single.id,
            course: s.courses.single,
            initialLessonId: s.courses.single.lessons.last['id'] as String,
            launcher: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Open video'));
      expect(
        find.text('Unable to open this video. Please try again.'),
        findsOneWidget,
      );
      expect(f.enrollments.single['completed_lesson_ids'], isEmpty);
    },
  );
  testWidgets('admin assignment, filters, withdrawal and restoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EnrollmentScreen(repository: f.repo, actor: admin, learnerId: 2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign course'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course One').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    expect(f.enrollments, hasLength(1));
    await tapVisible(tester, find.text('Withdraw'));
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Completed').first);
    expect(find.textContaining('No enrollments found'), findsOneWidget);
    await tester.tap(find.text('Withdrawn').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Re-enroll'));
    expect(f.enrollments.single['withdrawn_at'], isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('load and uncertain-save failures offer refresh and retry', (
    tester,
  ) async {
    f.records['enrollments']!['enrollments'] = [{}];
    await tester.pumpWidget(
      MaterialApp(
        home: EnrollmentCourseScreen(
          repository: f.repo,
          actor: learner,
          courseId: 'c1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('record is invalid'), findsOneWidget);
    f.records['enrollments']!['enrollments'] = <dynamic>[];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    f.failWrite = true;
    await tapVisible(tester, find.text('Enroll'));
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    f.failWrite = false;
    await tapVisible(tester, find.text('Retry'));
    await tapVisible(tester, find.text('Enroll'));
    expect(f.enrollments, hasLength(1));
  });
  testWidgets(
    'My Learning shows current progress, dates and unavailable courses',
    (tester) async {
      await f.repo.enroll(learner, 2, 'c1');
      f.courses.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: EnrollmentScreen(repository: f.repo, actor: learner),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Course unavailable'), findsOneWidget);
      expect(find.textContaining('1 enrolled'), findsOneWidget);
      expect(find.textContaining('Enrolled '), findsOneWidget);
      expect(find.text('Course details'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile includes live enrollment summary and course details', (
    tester,
  ) async {
    await f.repo.enroll(learner, 2, 'c1');
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: MemoryProfile(),
          session: learner,
          onSaved: (_) {},
          onSecurity: () {},
          enrollmentContent: EnrollmentPanel(
            repository: f.repo,
            actor: learner,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Course details'));
    expect(find.text('Course Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin pagination and search work at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final template = f.courses.single as Map<String, dynamic>;
    for (var i = 2; i <= 12; i++) {
      f.courses.add({...template, 'id': 'c$i', 'title': 'Course $i'});
    }
    for (var i = 1; i <= 12; i++) {
      await f.repo.enroll(admin, 2, 'c$i');
    }
    await tester.pumpWidget(
      MaterialApp(
        home: EnrollmentScreen(repository: f.repo, actor: admin),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Next page'));
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Course One');
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Course One'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('lesson refresh handles course edits and revoked enrollment', (
    tester,
  ) async {
    await f.repo.enroll(learner, 2, 'c1');
    final s = await f.repo.load(learner);
    final course = s.courses.single;
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          repository: f.repo,
          actor: learner,
          enrollmentId: s.enrollments.single.id,
          course: course,
          initialLessonId: course.lessons.first['id'] as String,
        ),
      ),
    );
    await tester.pumpAndSettle();
    f.courses.single['modules'][0]['lessons'][0]['content'] = 'Updated article';
    await tapVisible(tester, find.text('Mark complete'));
    expect(find.text('Updated article'), findsOneWidget);
    await f.repo.withdraw(admin, s.enrollments.single.id);
    await tapVisible(tester, find.text('Next'));
    await tapVisible(tester, find.text('Refresh and retry'));
    expect(find.text('An active enrollment is required.'), findsOneWidget);
    expect(find.text('Updated article'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
