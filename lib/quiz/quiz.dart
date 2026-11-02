import 'dart:convert';

import '../data/jsonbin_store.dart';

/// Optional structured assessment data. Existing instruction-only lessons omit it.
class Quiz {
  Quiz(this.data);
  final Map<String, dynamic> data;
  String get version => jsonEncode(data);
  int get passPercent => data['pass_percent'] as int;
  List<Map<String, dynamic>> get questions =>
      (data['questions'] as List).cast<Map<String, dynamic>>();

  static Quiz? fromLesson(Map<String, dynamic> lesson) {
    if (lesson['format'] != 'Assessment' || lesson['quiz'] == null) return null;
    try {
      final quiz = Quiz(Map<String, dynamic>.from(lesson['quiz'] as Map));
      if (quiz.passPercent < 1 ||
          quiz.passPercent > 100 ||
          quiz.questions.isEmpty ||
          quiz.questions.length > 50) {
        throw const FormatException();
      }
      for (final q in quiz.questions) {
        final choices = (q['choices'] as List).cast<String>();
        final correct = q['correct_index'] as int;
        if ((q['prompt'] as String).trim().isEmpty ||
            choices.length < 2 ||
            choices.length > 6 ||
            choices.any((c) => c.trim().isEmpty) ||
            choices.map((c) => c.trim().toLowerCase()).toSet().length !=
                choices.length ||
            correct < 0 ||
            correct >= choices.length ||
            (q['explanation'] as String).trim().isEmpty) {
          throw const FormatException();
        }
      }
      return quiz;
    } catch (_) {
      throw const JsonBinException(
        'This quiz is invalid. Ask the administrator to update it.',
      );
    }
  }

  Map<String, dynamic> grade(List<int> answers) {
    if (answers.length != questions.length) {
      throw const JsonBinException('Answer every question before submitting.');
    }
    var correct = 0;
    final feedback = <Map<String, dynamic>>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final choices = q['choices'] as List;
      if (answers[i] < 0 || answers[i] >= choices.length) {
        throw const JsonBinException(
          'Select a valid answer for every question.',
        );
      }
      if (answers[i] == q['correct_index']) correct++;
      feedback.add({
        ...q,
        'choices': [...choices],
        'selected_index': answers[i],
      });
    }
    return {
      'correct': correct,
      'total': questions.length,
      'percent': (100 * correct / questions.length).round(),
      'pass_percent': passPercent,
      'passed': correct * 100 >= passPercent * questions.length,
      'feedback': feedback,
    };
  }
}
