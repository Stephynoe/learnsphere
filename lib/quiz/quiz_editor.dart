import 'package:flutter/material.dart';

class QuizEditor extends StatefulWidget {
  const QuizEditor({super.key, required this.initial, required this.onChanged});
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  @override
  State<QuizEditor> createState() => _QuizEditorState();
}

class _QuizEditorState extends State<QuizEditor> {
  late bool enabled = widget.initial != null;
  late int pass = widget.initial?['pass_percent'] as int? ?? 70;
  late final List<Map<String, dynamic>> questions = [
    for (final q in widget.initial?['questions'] as List? ?? [])
      {
        ...q as Map<String, dynamic>,
        'choices': [...q['choices'] as List],
      },
  ];
  void changed() {
    widget.onChanged(
      enabled ? {'pass_percent': pass, 'questions': questions} : null,
    );
    setState(() {});
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'This field is required' : null;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Automatically graded quiz'),
        subtitle: const Text('Learners must pass to complete this assessment.'),
        value: enabled,
        onChanged: (v) {
          enabled = v;
          changed();
        },
      ),
      if (enabled) ...[
        TextFormField(
          initialValue: '$pass',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Pass mark (%)'),
          validator: (v) =>
              (int.tryParse(v ?? '') ?? 0) < 1 ||
                  (int.tryParse(v ?? '') ?? 101) > 100
              ? 'Enter 1–100'
              : null,
          onChanged: (v) {
            pass = int.tryParse(v) ?? 0;
            changed();
          },
        ),
        for (var i = 0; i < questions.length; i++)
          Padding(
            key: ObjectKey(questions[i]),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Question ${i + 1}')),
                    IconButton(
                      tooltip: 'Remove question ${i + 1}',
                      onPressed: () {
                        questions.removeAt(i);
                        changed();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: questions[i]['prompt'] as String,
                  decoration: const InputDecoration(labelText: 'Question'),
                  validator: requiredText,
                  onChanged: (v) {
                    questions[i]['prompt'] = v;
                    changed();
                  },
                ),
                for (
                  var j = 0;
                  j < (questions[i]['choices'] as List).length;
                  j++
                )
                  TextFormField(
                    initialValue: questions[i]['choices'][j] as String,
                    decoration: InputDecoration(labelText: 'Answer ${j + 1}'),
                    validator: (v) {
                      if (requiredText(v) != null) return requiredText(v);
                      final choices = questions[i]['choices'] as List;
                      if (choices
                              .where(
                                (c) =>
                                    c.toString().trim().toLowerCase() ==
                                    v!.trim().toLowerCase(),
                              )
                              .length >
                          1) {
                        return 'Answers must be different';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      questions[i]['choices'][j] = v;
                      changed();
                    },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: questions[i]['correct_index'] as int,
                  decoration: const InputDecoration(
                    labelText: 'Correct answer',
                  ),
                  items: [
                    for (
                      var j = 0;
                      j < (questions[i]['choices'] as List).length;
                      j++
                    )
                      DropdownMenuItem(
                        value: j,
                        child: Text('Answer ${j + 1}'),
                      ),
                  ],
                  onChanged: (v) {
                    questions[i]['correct_index'] = v;
                    changed();
                  },
                ),
                TextFormField(
                  initialValue: questions[i]['explanation'] as String,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Explanation after submission',
                  ),
                  validator: requiredText,
                  onChanged: (v) {
                    questions[i]['explanation'] = v;
                    changed();
                  },
                ),
              ],
            ),
          ),
        if (questions.isEmpty) const Text('Add at least one question.'),
        OutlinedButton.icon(
          onPressed: questions.length >= 50
              ? null
              : () {
                  questions.add({
                    'prompt': '',
                    'choices': ['', '', '', ''],
                    'correct_index': 0,
                    'explanation': '',
                  });
                  changed();
                },
          icon: const Icon(Icons.add),
          label: const Text('Add question'),
        ),
      ],
    ],
  );
}
