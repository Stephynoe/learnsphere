import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/enrollment/enrollment_repository.dart';
import 'package:learnsphere/profile/profile_repository.dart';
import '../tool/seed_data.dart';
import '../tool/seed_jsonbin.dart';

List<Record> initial() => [
  {
    'users': [
      {
        'id': 7,
        'email': 'admin@example.com',
        'username': 'admin',
        'full_name': 'Test Admin',
        'account_type': 'admin',
        'is_active': true,
      },
    ],
    'last_id': 9,
    'custom': 'keep',
  },
  {'courses': <dynamic>[], 'custom': 'keep'},
  {'enrollments': <dynamic>[]},
];

void main() {
  final now = DateTime.utc(2026, 10, 18);
  test('realistic counts, references, statuses and profiles', () {
    final plan = buildSeed(initial(), now);
    expect(plan.added, [20, 10, 60]);
    final users = records(plan.after[0], 'users').skip(1).toList();
    expect(users.where((u) => u['is_active'] == true).length, 18);
    for (final user in users) {
      expect(UserProfile.fromUser(user).validate(), isEmpty);
      expect(
        DateTime.parse(user['created_at'] as String).isBefore(now),
        isTrue,
      );
    }
    final courses = parseCourses(plan.after[1]);
    expect(courses.where((c) => c.text('status') == 'Published').length, 8);
    for (final c in courses) {
      expect(c.publishErrors, isEmpty);
      expect(c.lessonCount, 9);
    }
    final statuses = <String, int>{};
    final entries = records(
      plan.after[2],
      'enrollments',
    ).map(Enrollment.new).toList();
    for (final e in entries) {
      final status = e.status(courses.firstWhere((c) => c.id == e.courseId));
      statuses[status] = (statuses[status] ?? 0) + 1;
      final user = users.firstWhere((u) => u['id'] == e.learnerId);
      expect(
        DateTime.parse(e.data['enrolled_at'] as String)
            .isBefore(DateTime.parse(user['created_at'] as String)),
        isFalse,
      );
    }
    expect(statuses, {
      'Not started': 15,
      'In progress': 25,
      'Completed': 15,
      'Withdrawn': 5,
    });
    expect(
      users.where((u) => !entries.any((e) => e.learnerId == u['id'])).length,
      2,
    );
  });

  test('preserves existing records and edited seed data on repeat', () {
    final source = initial();
    final first = buildSeed(source, now);
    expect(source[0]['last_id'], 9);
    expect(first.after[0]['custom'], 'keep');
    expect(
      (first.after[0]['users'] as List).first,
      (source[0]['users'] as List).first,
    );
    (first.after[0]['users'] as List)[1]['full_name'] = 'Edited Name';
    final repeat = buildSeed(first.after, now.add(const Duration(days: 10)));
    expect(repeat.added, [0, 0, 0]);
    expect(repeat.after, first.after);
  });

  test('rejects conflicting identities before changes', () {
    final source = initial();
    (source[0]['users'] as List).add({
      'id': 8,
      'email': 'demo.ada.okafor@example.com',
      'username': 'other',
      'full_name': 'Existing User',
    });
    expect(() => buildSeed(source, now), throwsFormatException);
  });

  test('configuration rejects missing and overlapping bins', () {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    expect(() => configuredStores({}, client), throwsFormatException);
    expect(
      () => configuredStores({
        'JSONBIN_MASTER_KEY': 'secret',
        for (final d in domains) 'JSONBIN_${d.toUpperCase()}_BIN_ID': 'same',
      }, client),
      throwsFormatException,
    );
    final stores = configuredStores({
      'JSONBIN_MASTER_KEY': 'shared',
      'JSONBIN_COURSES_MASTER_KEY': '',
      'JSONBIN_COURSES_ACCESS_KEY': 'specific',
      for (final d in domains) 'JSONBIN_${d.toUpperCase()}_BIN_ID': d,
    }, client);
    expect(stores[1].masterKey, isEmpty);
    expect(stores[1].accessKey, 'specific');
  });

  test(
    'partial failure stops after users and reports confirmed writes',
    () async {
      final plan = buildSeed(initial(), now);
      final puts = <String>[];
      final client = MockClient((request) async {
        final domain = request.url.pathSegments[2];
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'record': plan.before[domains.indexOf(domain)]}),
            200,
          );
        }
        puts.add(domain);
        return http.Response('{}', domain == 'courses' ? 500 : 200);
      });
      addTearDown(client.close);
      final stores = configuredStores({
        'JSONBIN_MASTER_KEY': 'test',
        for (final d in domains) 'JSONBIN_${d.toUpperCase()}_BIN_ID': d,
      }, client);
      await expectLater(
        applySeed(stores, plan),
        throwsA(
          isA<SeedApplyException>()
              .having((e) => e.confirmed, 'confirmed', ['users'])
              .having((e) => e.domain, 'failed', 'courses'),
        ),
      );
      expect(puts, ['users', 'courses']);
    },
  );
}
