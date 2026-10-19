import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/admin/admin_dashboard_controller.dart';
import 'package:learnsphere/admin/admin_dashboard_repository.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';
import 'package:learnsphere/enrollment/enrollment_repository.dart';

const learner = UserSession(
  id: 2,
  fullName: 'Learner',
  email: 'l@example.com',
  username: 'learner',
  role: AccountRole.learner,
);
const admin = UserSession(
  id: 1,
  fullName: 'Admin',
  email: 'a@example.com',
  username: 'admin',
  role: AccountRole.admin,
);

class EnrollmentDashboardFixture implements AdminDashboardRepository {
  @override
  Future<AdminDashboardSummary> loadSummary() async =>
      const AdminDashboardSummary(learnerCount: 2);
}

class EnrollmentFixture {
  EnrollmentFixture() {
    client = MockClient((request) async {
      final domain = request.url.pathSegments[2];
      if (request.method == 'PUT') {
        writes++;
        if (failWrite) return http.Response('', 500);
        records[domain] = jsonDecode(request.body) as Map<String, dynamic>;
      }
      return http.Response(jsonEncode({'record': records[domain]}), 200);
    });
    repo = JsonBinEnrollmentRepository(
      store('enrollments'),
      store('users'),
      store('courses'),
    );
  }
  late final MockClient client;
  late final JsonBinEnrollmentRepository repo;
  int writes = 0;
  bool failWrite = false;
  final records = <String, Map<String, dynamic>>{
    'users': {
      'users': [
        {
          'id': 1,
          'full_name': 'Admin',
          'email': 'a@example.com',
          'username': 'admin',
          'account_type': 'admin',
          'is_active': true,
        },
        {
          'id': 2,
          'full_name': 'Learner',
          'email': 'l@example.com',
          'username': 'learner',
          'account_type': 'learner',
          'is_active': true,
        },
        {
          'id': 3,
          'full_name': 'Other',
          'email': 'o@example.com',
          'username': 'other',
          'account_type': 'learner',
          'is_active': true,
        },
      ],
    },
    'courses': {
      'courses': [
        Course.empty().data..addAll({
          'id': 'c1',
          'title': 'Course One',
          'status': 'Published',
          'modules': [
            {
              'title': 'Basics',
              'lessons': [
                {
                  'title': 'First',
                  'format': 'Article / Text',
                  'minutes': 3,
                  'content': 'Article',
                },
                {
                  'title': 'Second',
                  'format': 'Video Lesson',
                  'minutes': 5,
                  'content': 'https://example.com/video',
                },
              ],
            },
          ],
        }),
      ],
    },
    'enrollments': {
      'enrollments': <dynamic>[],
      'keep': {'unknown': true},
    },
  };
  JsonBinStore store(String id) =>
      JsonBinStore(client: client, binId: id, accessKey: 'test');
  List<dynamic> get enrollments =>
      records['enrollments']!['enrollments'] as List;
  List<dynamic> get courses => records['courses']!['courses'] as List;
}

void main() {
  late EnrollmentFixture f;
  setUp(() => f = EnrollmentFixture());
  tearDown(() => f.client.close());
  test(
    'enrollment is idempotent and concurrent local requests preserve pairs',
    () async {
      await Future.wait([
        f.repo.enroll(learner, 2, 'c1'),
        f.repo.enroll(learner, 2, 'c1'),
        f.repo.enroll(admin, 3, 'c1'),
      ]);
      expect(f.enrollments, hasLength(2));
      expect(f.records['enrollments']!['keep'], {'unknown': true});
      expect((await f.repo.load(learner)).enrollments, hasLength(1));
      expect((await f.repo.load(admin)).enrollments, hasLength(2));
    },
  );
  test('withdrawal and restoration retain completion and resume', () async {
    await f.repo.enroll(learner, 2, 'c1');
    final s = await f.repo.load(learner), e = s.enrollments.single;
    final lesson = s.courses.single.lessons.first['id'] as String;
    e.data['custom'] = 'preserve';
    f.enrollments.single['custom'] = 'preserve';
    await f.repo.openLesson(learner, e.id, lesson, complete: true);
    await f.repo.withdraw(learner, e.id);
    await expectLater(
      f.repo.openLesson(learner, e.id, lesson),
      throwsA(isA<JsonBinException>()),
    );
    await f.repo.enroll(learner, 2, 'c1');
    final restored = (await f.repo.load(learner)).enrollments.single;
    expect(restored.completed, {lesson});
    expect(restored.data['last_opened_lesson_id'], lesson);
    expect(restored.data['custom'], 'preserve');
    expect(restored.withdrawn, false);
  });
  test(
    'completion, dates, curriculum additions, and removed lessons',
    () async {
      await f.repo.enroll(learner, 2, 'c1');
      var s = await f.repo.load(learner);
      for (final l in s.courses.single.lessons) {
        await f.repo.openLesson(
          learner,
          s.enrollments.single.id,
          l['id'] as String,
          complete: true,
        );
      }
      s = await f.repo.load(learner);
      final date = s.enrollments.single.data['completed_at'];
      expect(date, isNotNull);
      expect(s.enrollments.single.progress(s.courses.single), 1);
      await f.repo.openLesson(
        learner,
        s.enrollments.single.id,
        s.courses.single.lessons.first['id'] as String,
        complete: true,
      );
      expect(
        (await f.repo.load(learner)).enrollments.single.data['completed_at'],
        date,
      );
      final lessons = f.courses.single['modules'][0]['lessons'] as List;
      lessons.add({
        'id': 'new',
        'title': 'New',
        'content': 'New text',
        'format': 'Article / Text',
        'minutes': 2,
      });
      s = await f.repo.load(learner);
      expect(
        s.enrollments.single.progress(s.courses.single),
        closeTo(2 / 3, 0.001),
      );
      expect(s.enrollments.single.data['completed_at'], isNull);
      lessons.removeLast();
      lessons.removeLast();
      s = await f.repo.load(learner);
      expect(s.enrollments.single.progress(s.courses.single), 1);
    },
  );
  test('legacy IDs persist after editing and reordering', () {
    final c = parseCourses(f.records['courses']!).single;
    final firstId = c.lessons.first['id'];
    final lessons = c.modules.first['lessons'] as List;
    final first = lessons.removeAt(0);
    lessons.add(first);
    final reread = parseCourses({
      'courses': [c.data],
    }).single;
    expect(reread.lessons.last['id'], firstId);
  });
  test(
    'ownership, administrator lesson writes, and inactive access rejected',
    () async {
      await expectLater(
        f.repo.enroll(learner, 3, 'c1'),
        throwsA(isA<JsonBinException>()),
      );
      await f.repo.enroll(admin, 3, 'c1');
      final e = (await f.repo.load(admin)).enrollments.single;
      await expectLater(
        f.repo.withdraw(learner, e.id),
        throwsA(isA<JsonBinException>()),
      );
      await expectLater(
        f.repo.openLesson(admin, e.id, 'legacy-c1-0-0'),
        throwsA(isA<JsonBinException>()),
      );
      f.records['users']!['users'][1]['is_active'] = false;
      await expectLater(f.repo.load(learner), throwsA(isA<JsonBinException>()));
      await expectLater(
        f.repo.enroll(admin, 2, 'c1'),
        throwsA(isA<JsonBinException>()),
      );
    },
  );
  test(
    'unpublished courses prevent enrollment while existing access remains',
    () async {
      await f.repo.enroll(learner, 2, 'c1');
      f.courses.single['status'] = 'Archived';
      final s = await f.repo.load(learner);
      expect(s.courses, hasLength(1));
      await f.repo.openLesson(
        learner,
        s.enrollments.single.id,
        s.courses.single.lessons.first['id'] as String,
      );
      await expectLater(
        f.repo.enroll(admin, 3, 'c1'),
        throwsA(isA<JsonBinException>()),
      );
      await f.repo.withdraw(learner, s.enrollments.single.id);
      expect((await f.repo.load(learner)).courses, hasLength(1));
      await expectLater(
        f.repo.enroll(learner, 2, 'c1'),
        throwsA(isA<JsonBinException>()),
      );
    },
  );
  test('missing course does not break enrollment list', () async {
    await f.repo.enroll(learner, 2, 'c1');
    f.courses.clear();
    final s = await f.repo.load(learner);
    expect(s.enrollments, hasLength(1));
    expect(s.course('c1'), isNull);
  });
  test('invalid records do not write', () async {
    f.records['enrollments']!['enrollments'] = [{}];
    await expectLater(
      f.repo.enroll(learner, 2, 'c1'),
      throwsA(isA<JsonBinException>()),
    );
    expect(f.writes, 0);
  });
  test(
    'empty users template loads without writing and initializes on enrollment',
    () async {
      f.records['enrollments'] = {'last_id': 0, 'users': <dynamic>[]};
      expect((await f.repo.load(learner)).enrollments, isEmpty);
      expect(f.writes, 0);
      await f.repo.enroll(learner, 2, 'c1');
      expect(f.enrollments, hasLength(1));
      expect(f.records['enrollments']!['last_id'], 0);
      expect(f.records['enrollments']!['users'], isEmpty);
    },
  );
  test('empty object initializes but populated or malformed templates cannot be overwritten', () async {
    f.records['enrollments'] = {};
    expect((await f.repo.load(learner)).enrollments, isEmpty);
    await f.repo.enroll(learner, 2, 'c1');
    expect(f.enrollments, hasLength(1));
    final writes = f.writes;
    for (final record in <Map<String, dynamic>>[
      {
        'last_id': 1,
        'users': [
          {'id': 1},
        ],
      },
      {'last_id': 0, 'users': [], 'courses': []},
      {'enrollments': null},
      {'enrollments': {}},
    ]) {
      f.records['enrollments'] = record;
      await expectLater(
        f.repo.enroll(learner, 2, 'c1'),
        throwsA(isA<JsonBinException>()),
      );
    }
    expect(f.writes, writes);
  });
  test('uncertain saves require refresh before retry', () async {
    f.failWrite = true;
    await expectLater(
      f.repo.enroll(learner, 2, 'c1'),
      throwsA(isA<JsonBinException>()),
    );
    f.failWrite = false;
    await expectLater(
      f.repo.enroll(learner, 2, 'c1'),
      throwsA(isA<JsonBinException>()),
    );
    expect(f.writes, 1);
    await f.repo.load(learner);
    await f.repo.enroll(learner, 2, 'c1');
    expect(f.enrollments, hasLength(1));
  });
  test(
    'dashboard metrics use active enrollments and current progress',
    () async {
      await f.repo.enroll(admin, 2, 'c1');
      await f.repo.enroll(admin, 3, 'c1');
      final s = await f.repo.load(learner);
      await f.repo.openLesson(
        learner,
        s.enrollments.single.id,
        s.courses.single.lessons.first['id'] as String,
        complete: true,
      );
      final controller = AdminDashboardController(
        EnrollmentDashboardFixture(),
        enrollmentsRepository: f.repo,
        session: admin,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.activeEnrollments, hasLength(2));
      expect(controller.averageCompletion, '25%');
      await f.repo.withdraw(admin, '3/c1');
      await controller.loadEnrollments();
      expect(controller.averageCompletion, '50%');
      f.records['enrollments']!['enrollments'] = [{}];
      await controller.loadEnrollments();
      expect(controller.enrollmentError, isNotNull);
      expect(controller.averageCompletion, '50%');
      expect(controller.summary!.learnerCount, 2);
    },
  );
}
