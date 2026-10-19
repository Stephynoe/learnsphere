import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/learner/learner_dashboard_screen.dart';
import 'package:learnsphere/profile/enrollment_unavailable.dart';

import '../tool/lesson_content.dart';
import '../tool/seed_data.dart';
import '../tool/update_seed_content.dart';

Record legacyCourses() {
  final source = buildSeed([
    {
      'users': [
        {
          'id': 1,
          'email': 'admin@example.com',
          'username': 'admin',
          'full_name': 'Admin',
          'account_type': 'admin',
          'is_active': true,
        },
      ],
      'last_id': 1,
    },
    {'courses': <dynamic>[]},
    {'enrollments': <dynamic>[]},
  ], DateTime.utc(2026, 10, 18)).after[1];
  for (var c = 0; c < 10; c++) {
    for (var m = 0; m < 3; m++) {
      for (var l = 0; l < 3; l++) {
        source['courses'][c]['modules'][m]['lessons'][l]['content'] =
            originalLessonContent(subjects[c][0], subjects[c][m + 3], l);
      }
    }
  }
  return source;
}

void main() {
  testWidgets('catalog fallback disables enrollment', (tester) async {
    final course = Course.empty()..data['title'] = 'Preview course';
    await tester.pumpWidget(
      MaterialApp(home: LearnerCourseDetails(course: course)),
    );
    await tester.scrollUntilVisible(find.text('Enrollment unavailable'), 200);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enrollment unavailable'),
    );
    expect(button.onPressed, isNull);
  });

  test('successful save verifies read-back and rejects a mismatch', () async {
    for (final mismatch in [false, true]) {
      var gets = 0, writes = 0;
      final before = <String, dynamic>{'courses': []};
      final after = <String, dynamic>{
        'courses': ['updated'],
      };
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          writes++;
          expect(jsonDecode(request.body), after);
          return http.Response('{}', 200);
        }
        gets++;
        return http.Response(
          jsonEncode({'record': gets == 1 || mismatch ? before : after}),
          200,
        );
      });
      final store = JsonBinStore(
        client: client,
        binId: 'test',
        accessKey: 'test',
      );
      if (mismatch) {
        await expectLater(
          saveContent(store, before, after),
          throwsFormatException,
        );
      } else {
        await saveContent(store, before, after);
      }
      expect(writes, 1);
      expect(gets, 2);
      client.close();
    }
  });
  test(
    'updates 90 lessons, preserves all other fields, and reruns cleanly',
    () {
      final source = legacyCourses()..['custom'] = 'retain';
      final before = jsonEncode(source);
      final update = updateContent(source);
      expect(update.updated, 90);
      expect(update.skipped, 0);
      expect(jsonEncode(source), before);
      final contents = <String>{};
      for (var c = 0; c < 10; c++) {
        for (var m = 0; m < 3; m++) {
          for (var l = 0; l < 3; l++) {
            final changed =
                update.record['courses'][c]['modules'][m]['lessons'][l]
                    as Record;
            expect(changed['content'], lessonContent(c, m, l));
            contents.add(changed['content'] as String);
            changed['content'] =
                source['courses'][c]['modules'][m]['lessons'][l]['content'];
          }
        }
      }
      expect(contents.length, 90);
      expect(update.record, source);
      final first = updateContent(source);
      final repeat = updateContent(first.record);
      expect(repeat.updated, 0);
      expect(repeat.current, 90);
      expect(repeat.record, first.record);
    },
  );
  test('preserves edited, missing, and unrelated legacy lessons', () {
    final source = legacyCourses();
    source['courses'][0]['modules'][0]['lessons'][0]['content'] = 'My edits';
    (source['courses'][0]['modules'][0]['lessons'] as List).removeAt(1);
    (source['courses'] as List).add({
      'id': 'other',
      'status': 'Draft',
      'objectives': [],
      'modules': [
        {
          'title': 'Legacy',
          'lessons': [
            {'title': 'Old', 'content': 'Keep'},
          ],
        },
      ],
    });
    final update = updateContent(source);
    expect(update.updated, 88);
    expect(update.skipped, 2);
    expect(
      update.record['courses'][0]['modules'][0]['lessons'][0]['content'],
      'My edits',
    );
    expect(
      (update.record['courses'] as List).last,
      (source['courses'] as List).last,
    );
  });
  test('save failures and concurrent edits do not trigger retries', () async {
    for (final changed in [false, true]) {
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'record': changed
                  ? {
                      'courses': ['changed'],
                    }
                  : {'courses': []},
            }),
            200,
          );
        }
        writes++;
        return http.Response('{}', 500);
      });
      final store = JsonBinStore(
        client: client,
        binId: 'test',
        accessKey: 'test',
      );
      await expectLater(
        saveContent(
          store,
          {'courses': []},
          {
            'courses': ['new'],
          },
        ),
        throwsA(changed ? isA<FormatException>() : isA<JsonBinException>()),
      );
      expect(writes, changed ? 0 : 1);
      client.close();
    }
  });
  testWidgets('unavailable view shows unknown enrollment counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EnrollmentUnavailable())),
    );
    expect(find.text('Enrollment data is unavailable.'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.textContaining('Courses Enrolled:'), findsOneWidget);
  });
}
