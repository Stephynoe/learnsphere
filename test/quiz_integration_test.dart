import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/enrollment/enrollment_screens.dart';
import 'package:learnsphere/admin/admin_courses_screen.dart';

import 'enrollment_repository_test.dart' show EnrollmentFixture, learner, admin;
import 'enrollment_widget_test.dart' show tapVisible;
import 'quiz_test.dart' show quizLesson;

void addQuiz(EnrollmentFixture f) {
  final lessons = f.courses[0]['modules'][0]['lessons'] as List;
  lessons[0] = <String, Object>{
    ...lessons[0] as Map<String, Object>,
    ...quizLesson().cast<String, Object>(),
  };
}

void main() {
  test('failed quiz writes do not complete lessons or add attempts', () async {
    final f = EnrollmentFixture();
    addTearDown(f.client.close);
    addQuiz(f);
    await f.repo.enroll(learner, 2, 'c1');
    final snapshot = await f.repo.load(learner);
    f.failWrite = true;
    await expectLater(
      f.repo.openLesson(
        learner,
        snapshot.enrollments.single.id,
        snapshot.courses.first.lessons.first['id'] as String,
        quizAnswers: [0, 0, 0],
      ),
      throwsException,
    );
    expect(f.enrollments.single['quiz_attempts'], isNull);
    expect(f.enrollments.single['completed_lesson_ids'], isEmpty);
  });
  test(
    'attempts persist, completion requires passing, and ownership is checked',
    () async {
      final f = EnrollmentFixture();
      addTearDown(f.client.close);
      addQuiz(f);
      await f.repo.enroll(learner, 2, 'c1');
      final id = f.enrollments.single['id'] as String;
      await expectLater(
        f.repo.openLesson(
          learner,
          id,
          'legacy-c1-0-0',
          quizAnswers: [0, 0, 0],
          quizVersion: 'outdated',
        ),
        throwsException,
      );
      final lesson =
          (await f.repo.load(learner)).courses.first.lessons.first['id']
              as String;
      await expectLater(
        f.repo.openLesson(learner, id, lesson, complete: true),
        throwsException,
      );
      await expectLater(
        f.repo.openLesson(admin, id, lesson, quizAnswers: [0, 0, 0]),
        throwsException,
      );
      await expectLater(
        f.repo.openLesson(learner, id, lesson, quizAnswers: [0]),
        throwsException,
      );
      await f.repo.openLesson(learner, id, lesson, quizAnswers: [0, 0, 1]);
      expect(f.enrollments.single['completed_lesson_ids'], isEmpty);
      expect(f.enrollments.single['quiz_attempts'], hasLength(1));
      await f.repo.openLesson(learner, id, lesson, quizAnswers: [0, 0, 0]);
      final saved = (await f.repo.load(learner)).enrollments.single;
      expect(saved.completed, contains(lesson));
      expect(saved.data['quiz_attempts'], hasLength(2));
      expect(saved.data['quiz_attempts'][1]['passed'], true);
      expect(
        saved.data['quiz_attempts'][0]['feedback'][2]['selected_index'],
        1,
      );
      await f.repo.withdraw(learner, id);
      await expectLater(
        f.repo.openLesson(learner, id, lesson, quizAnswers: [0, 0, 0]),
        throwsException,
      );
    },
  );

  testWidgets('learner submits, sees feedback, retries and reloads history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = EnrollmentFixture();
    addTearDown(f.client.close);
    addQuiz(f);
    await f.repo.enroll(learner, 2, 'c1');
    final snapshot = await f.repo.load(learner);
    final course = snapshot.courses.first;
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          repository: f.repo,
          actor: learner,
          enrollmentId: snapshot.enrollments.single.id,
          course: course,
          initialLessonId: course.lessons.first['id'] as String,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await tapVisible(
        tester,
        find.text(i == 2 ? 'No' : 'Yes').at(i == 2 ? 2 : i),
      );
    }
    await tapVisible(tester, find.text('Submit quiz'));
    expect(find.text('Try again: 2/3 (67%)'), findsOneWidget);
    expect(f.enrollments.single['completed_lesson_ids'], isEmpty);
    await tapVisible(tester, find.text('Try quiz again'));
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('Yes').at(i));
    }
    await tapVisible(tester, find.text('Submit quiz'));
    expect(find.text('Passed: 3/3 (100%)'), findsOneWidget);
    expect(f.enrollments.single['quiz_attempts'], hasLength(2));
    expect(f.enrollments.single['completed_lesson_ids'], hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator can enable quiz and add a question', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LessonEditorScreen(
          lesson: {
            'title': 'Assessment',
            'format': 'Assessment',
            'minutes': 10,
            'content': 'Choose one answer.',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Automatically graded quiz'));
    await tapVisible(tester, find.text('Add question'));
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
