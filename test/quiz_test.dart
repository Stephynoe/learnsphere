import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/quiz/quiz.dart';

Map<String, dynamic> quizLesson() => {
  'format': 'Assessment',
  'quiz': {
    'pass_percent': 70,
    'questions': [
      for (var i = 0; i < 3; i++)
        {
          'prompt': 'Question $i',
          'choices': ['Yes', 'No'],
          'correct_index': 0,
          'explanation': 'Yes is correct.',
        },
    ],
  },
};

void main() {
  test('grades all answers and compares unrounded percentage', () {
    final quiz = Quiz.fromLesson(quizLesson())!;
    expect(quiz.grade([0, 0, 1])['passed'], false);
    expect(quiz.grade([0, 0, 0])['passed'], true);
    expect(quiz.grade([0, 0, 1])['correct'], 2);
    expect(() => quiz.grade([0]), throwsException);
    expect(() => quiz.grade([0, 0, 2]), throwsException);
  });
  test('legacy assessments are optional; malformed quizzes fail closed', () {
    expect(Quiz.fromLesson({'format': 'Assessment'}), isNull);
    final lesson = quizLesson();
    (lesson['quiz'] as Map)['pass_percent'] = 101;
    expect(() => Quiz.fromLesson(lesson), throwsException);
    final duplicate = quizLesson();
    ((duplicate['quiz'] as Map)['questions'] as List)[0]['choices'] = [
      'Yes',
      ' yes ',
    ];
    expect(() => Quiz.fromLesson(duplicate), throwsException);
  });
}
