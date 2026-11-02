import 'package:flutter/material.dart';

import 'quiz.dart';

class QuizPlayer extends StatefulWidget {
  const QuizPlayer({
    super.key,
    required this.quiz,
    required this.attempts,
    required this.busy,
    required this.onSubmit,
  });
  final Quiz quiz;
  final List<Map<String, dynamic>> attempts;
  final bool busy;
  final Future<bool> Function(List<int>) onSubmit;
  @override
  State<QuizPlayer> createState() => _QuizPlayerState();
}

class _QuizPlayerState extends State<QuizPlayer> {
  late final answers = List<int>.filled(widget.quiz.questions.length, -1);
  bool showingResult = false;
  bool submitting = false;
  @override
  Widget build(BuildContext context) {
    final latest = widget.attempts.lastOrNull;
    final locked = widget.busy || submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pass mark: ${widget.quiz.passPercent}% • Unlimited attempts'),
        if (!showingResult) ...[
          for (var i = 0; i < widget.quiz.questions.length; i++) ...[
            const SizedBox(height: 20),
            Text(
              '${i + 1}. ${widget.quiz.questions[i]['prompt']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (
              var j = 0;
              j < (widget.quiz.questions[i]['choices'] as List).length;
              j++
            )
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: locked
                      ? null
                      : () => setState(() => answers[i] = j),
                  icon: Icon(
                    answers[i] == j
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  label: Text('${widget.quiz.questions[i]['choices'][j]}'),
                ),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: locked || answers.contains(-1)
                ? null
                : () async {
                    setState(() => submitting = true);
                    final saved = await widget.onSubmit([...answers]);
                    if (mounted) {
                      setState(() {
                        submitting = false;
                        showingResult = saved;
                      });
                    }
                  },
            child: Text(submitting ? 'Saving attempt…' : 'Submit quiz'),
          ),
          if (answers.contains(-1))
            const Text('Answer every question to submit.'),
        ],
        if (showingResult && latest != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              '${latest['passed'] == true ? 'Passed' : 'Try again'}: ${latest['correct']}/${latest['total']} (${latest['percent']}%)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final q in latest['feedback'] as List)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                q['selected_index'] == q['correct_index']
                    ? Icons.check_circle
                    : Icons.cancel_outlined,
              ),
              title: Text('${q['prompt']}'),
              subtitle: Text(
                'Your answer: ${q['choices'][q['selected_index']]}\nCorrect answer: ${q['choices'][q['correct_index']]}\n${q['explanation']}',
              ),
            ),
          OutlinedButton(
            onPressed: locked
                ? null
                : () => setState(() {
                    answers.fillRange(0, answers.length, -1);
                    showingResult = false;
                  }),
            child: const Text('Try quiz again'),
          ),
        ],
        if (widget.attempts.isNotEmpty)
          ExpansionTile(
            title: Text('Saved attempts (${widget.attempts.length})'),
            children: [
              for (final a in widget.attempts.reversed)
                ListTile(
                  title: Text(
                    '${a['percent']}% • ${a['passed'] == true ? 'Passed' : 'Not passed'}',
                  ),
                  subtitle: Text('${a['submitted_at']}'),
                ),
            ],
          ),
      ],
    );
  }
}
