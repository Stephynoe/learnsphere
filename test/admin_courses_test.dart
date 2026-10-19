import 'package:flutter/material.dart';
import 'package:learnsphere/admin/admin_courses_screen.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';

const admin = UserSession(
  id: 1,
  fullName: 'Admin',
  email: 'admin@example.com',
  username: 'admin',
  role: AccountRole.admin,
);
void main() {
  testWidgets('lesson editor saves content back to course at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(builder: (_) => const LessonEditorScreen()),
                );
              },
              child: const Text('Open lesson'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'First lesson');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Learn the essentials.',
    );
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.text('Save Lesson to Course'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save Lesson to Course'));
    await tester.pumpAndSettle();
    expect(saved?['title'], 'First lesson');
    expect(saved?['content'], 'Learn the essentials.');
    expect(find.text('Open lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('publishing requires complete modules and valid video content', () {
    final course = Course.empty();
    expect(course.publishErrors, isNotEmpty);
    course.data.addAll({
      'title': 'Course',
      'headline': 'Headline',
      'description': 'Description',
      'category': 'Design',
      'instructor': 'Alex',
      'duration': '2',
      'objectives': ['Learn design'],
      'modules': [
        {
          'title': 'Module',
          'lessons': [
            {
              'title': 'Lesson',
              'format': 'Video Lesson',
              'minutes': 10,
              'content': 'invalid',
            },
          ],
        },
      ],
    });
    expect(
      course.publishErrors,
      contains('Video lessons need a valid HTTPS URL.'),
    );
    course.modules[0]['lessons'][0]['content'] = 'https://example.com/video';
    expect(course.publishErrors, isEmpty);
    final copy = course.copy();
    copy.modules.clear();
    expect(course.modules, hasLength(1));
  });
  test('draft save preserves record metadata and other courses', () async {
    Map<String, dynamic>? written;
    final existing = Course.empty()
      ..data.addAll({'id': 'existing', 'title': 'Existing'});
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        written = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      final record = request.url.path.contains('/users/')
          ? {
              'users': [
                {
                  'id': 1,
                  'full_name': 'Admin',
                  'email': 'admin@example.com',
                  'username': 'admin',
                  'account_type': 'admin',
                  'is_active': true,
                },
              ],
            }
          : {
              'metadata': 'preserve',
              'courses': [existing.data],
            };
      return http.Response(jsonEncode({'record': record}), 200);
    });
    final repo = JsonBinAdminCoursesRepository(
      JsonBinStore(client: client, binId: 'courses', accessKey: 'test'),
      JsonBinStore(client: client, binId: 'users', accessKey: 'test'),
    );
    final draft = Course.empty()..data['title'] = 'New draft';
    final saved = await repo.save(admin, draft);
    expect(saved.id, isNotEmpty);
    expect(written!['metadata'], 'preserve');
    expect(written!['courses'], hasLength(2));
    expect((written!['courses'] as List).first['title'], 'Existing');
    draft.data['status'] = 'Published';
    await expectLater(
      repo.save(admin, draft),
      throwsA(isA<JsonBinException>()),
    );
    client.close();
  });
}
