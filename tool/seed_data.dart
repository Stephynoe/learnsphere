import 'lesson_content.dart';

import 'dart:convert';

import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/data/user_record.dart';
import 'package:learnsphere/enrollment/enrollment_repository.dart';
import 'package:learnsphere/profile/profile_repository.dart';
import 'package:learnsphere/registration/registration_data.dart';

const seedTag = 'learnsphere-demo-v1';
const seedPassword = 'LearnSphere123!';

const people = [
  'Ada Okafor',
  'Tunde Adebayo',
  'Zainab Bello',
  'Chiamaka Eze',
  'Ibrahim Musa',
  'Temitope Johnson',
  'Fatima Yusuf',
  'Emeka Nwosu',
  'Aisha Mohammed',
  'Samuel Adeyemi',
  'Grace Mensah',
  'Daniel Owusu',
  'Nneka Obi',
  'David Peters',
  'Halima Sani',
  'Kofi Asante',
  'Blessing Udo',
  'Joseph Makinde',
  'Mariam Lawal',
  'Victor Osei',
];

// Topic, category, instructor, three concrete module subjects.
const subjects = [
  [
    'Flutter App Development',
    'Development',
    'Ada Martins',
    'Widget composition',
    'State and navigation',
    'Responsive layouts',
  ],
  [
    'Dart Programming',
    'Development',
    'Tobi Cole',
    'Types and collections',
    'Async programming',
    'Error handling',
  ],
  [
    'Web Development Essentials',
    'Development',
    'Sarah Mensah',
    'Semantic HTML',
    'CSS layouts',
    'Accessible forms',
  ],
  [
    'Python for Automation',
    'Development',
    'Daniel Obi',
    'Functions and data',
    'File processing',
    'Automation workflows',
  ],
  [
    'SQL for Everyday Work',
    'Data Science',
    'Fatima Cole',
    'Filtering records',
    'Joining tables',
    'Aggregating results',
  ],
  [
    'Practical Data Analysis',
    'Data Science',
    'Kofi James',
    'Cleaning datasets',
    'Exploratory analysis',
    'Communicating findings',
  ],
  [
    'UI/UX Design Foundations',
    'Design',
    'Nneka Brown',
    'User research',
    'Wireframes and flows',
    'Usability testing',
  ],
  [
    'Project Management Basics',
    'Business',
    'Grace Okeke',
    'Planning scope',
    'Managing delivery',
    'Reviewing outcomes',
  ],
  [
    'Cybersecurity Awareness',
    'Technology',
    'Ibrahim West',
    'Recognizing phishing',
    'Securing accounts',
    'Responding to incidents',
  ],
  [
    'Communication at Work',
    'Business',
    'Zainab Green',
    'Clear written updates',
    'Active listening',
    'Constructive feedback',
  ],
];

typedef Record = Map<String, dynamic>;

class SeedPlan {
  SeedPlan(this.before, this.after, this.added);
  final List<Record> before, after;
  final List<int> added;
}

List<Record> records(Record record, String key) {
  final value = record[key];
  if (value is! List) throw FormatException('Expected a $key list.');
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

void validateDataset(List<Record> bins) {
  final users = validatedUsers(bins[0]).cast<Record>();
  if (bins[0]['last_id'] is! int || (bins[0]['last_id'] as int) < 0) {
    throw const FormatException('Invalid last_id.');
  }
  final ids = <int>{};
  final identities = <String, int>{};
  for (final u in users) {
    final id = u['id'] as int;
    if (!ids.add(id)) throw const FormatException('Duplicate user ID.');
    for (final key in ['email', 'username']) {
      final identity = (u[key] as String).trim().toLowerCase();
      if (identities.containsKey(identity) && identities[identity] != id) {
        throw const FormatException('Conflicting user identities.');
      }
      identities[identity] = id;
    }
    UserProfile.fromUser(u);
  }
  final courses = parseCourses(bins[1]);
  final enrollmentIds = <String>{}, pairs = <String>{};
  for (final raw in records(bins[2], 'enrollments')) {
    final e = Enrollment(raw);
    final course = courses.where((c) => c.id == e.courseId).firstOrNull;
    if (!enrollmentIds.add(e.id) ||
        !pairs.add('${e.learnerId}/${e.courseId}') ||
        !users.any(
          (u) => u['id'] == e.learnerId && u['account_type'] == 'learner',
        ) ||
        course == null) {
      throw const FormatException('Invalid enrollment identity or reference.');
    }
    final enrolled = DateTime.parse(raw['enrolled_at'] as String);
    final updated = DateTime.parse(raw['updated_at'] as String);
    if (updated.isBefore(enrolled) ||
        !e.completed.every((id) => course.lessons.any((l) => l['id'] == id))) {
      throw const FormatException('Invalid enrollment progress or dates.');
    }
    for (final key in ['completed_at', 'withdrawn_at']) {
      if (raw[key] != null &&
          DateTime.parse(raw[key] as String).isBefore(enrolled)) {
        throw const FormatException('Invalid enrollment dates.');
      }
    }
    final last = raw['last_opened_lesson_id'];
    if (last != null && !course.lessons.any((l) => l['id'] == last)) {
      throw const FormatException('Invalid resume lesson.');
    }
  }
}

SeedPlan buildSeed(List<Record> source, DateTime now) {
  final before = (jsonDecode(jsonEncode(source)) as List).cast<Record>();
  final after = (jsonDecode(jsonEncode(source)) as List).cast<Record>();
  // Accept only the legacy empty templates already supported by the app.
  if (after[2].isEmpty ||
      (after[2].length == 2 &&
          after[2]['last_id'] == 0 &&
          after[2]['users'] is List &&
          (after[2]['users'] as List).isEmpty)) {
    after[2]['enrollments'] = <dynamic>[];
  }
  validateDataset(after);
  final users = records(after[0], 'users');
  final courses = records(after[1], 'courses');
  final enrollments = records(after[2], 'enrollments');
  final admin = users
      .where((u) => u['account_type'] == 'admin' && u['is_active'] == true)
      .firstOrNull;
  if (admin == null) {
    throw const FormatException('An active administrator is required.');
  }
  var highest = after[0]['last_id'] as int;
  for (final u in users) {
    if ((u['id'] as int) > highest) highest = u['id'] as int;
  }
  final counts = [users.length, courses.length, enrollments.length];
  final learnerIds = <int>[];
  String date(int days) =>
      now.toUtc().subtract(Duration(days: days)).toIso8601String();
  for (var i = 0; i < 20; i++) {
    final marker = '$seedTag-learner-${i + 1}';
    final existing = users.where((u) => u['seed_id'] == marker).toList();
    if (existing.length > 1 ||
        (existing.isNotEmpty && existing.single['account_type'] != 'learner')) {
      throw const FormatException('Conflicting seeded learner.');
    }
    if (existing.isNotEmpty) {
      learnerIds.add(existing.single['id'] as int);
      continue;
    }
    final username = 'demo.${people[i].toLowerCase().replaceAll(' ', '.')}';
    final email = '$username@example.com';
    if (users.any(
      (u) => ['email', 'username'].any(
        (k) =>
            [username, email].contains((u[k] as String).trim().toLowerCase()),
      ),
    )) {
      throw const FormatException(
        'A demo identity already belongs to another account.',
      );
    }
    final user = RegistrationData(
      fullName: people[i],
      email: email,
      username: username,
      password: seedPassword,
      question: 'What is your favourite learning platform?',
      answer: 'LearnSphere',
    ).toUser(++highest, now.subtract(Duration(days: 175 - i * 7)));
    user.addAll({
      'seed_id': marker,
      'is_active': i < 18,
      'profile': {
        'first_name': people[i].split(' ').first,
        'last_name': people[i].split(' ').last,
        'headline': [
          'Junior developer',
          'Product designer',
          'Operations analyst',
          'Student',
          'Project coordinator',
        ][i % 5],
        'organization': [
          'Lagos Digital Academy',
          'Northstar Studio',
          'Greenfield Services',
          'Abuja Learning Hub',
        ][i % 4],
        'bio':
            'Building practical skills in ${subjects[i % 10][0].toLowerCase()} through projects and regular study.',
        'avatar': UserProfile.avatars[i % 5],
        'topics': [subjects[i % 10][1], subjects[(i + 3) % 10][0]],
        'public_profile': i % 3 != 0,
        'weekly_reminders': i % 4 != 0,
      },
    });
    learnerIds.add(highest);
    users.add(user);
  }
  for (var i = 0; i < 10; i++) {
    final id = '$seedTag-course-${i + 1}';
    final existing = courses.where((c) => c['id'] == id).firstOrNull;
    if (existing != null) {
      if (existing['seed_id'] != id) {
        throw const FormatException('Conflicting seeded course ID.');
      }
      continue;
    }
    final subject = subjects[i];
    final modules = <Record>[];
    for (var m = 0; m < 3; m++) {
      final topic = subject[m + 3];
      modules.add({
        'title': topic,
        'lessons': [
          {
            'id': '$id-m$m-intro',
            'title': '$topic: concepts',
            'format': 'Article / Text',
            'minutes': 20,
            'content': lessonContent(i, m, 0),
          },
          {
            'id': '$id-m$m-lab',
            'title': 'Practice: ${topic.toLowerCase()}',
            'format': 'Interactive Lab',
            'minutes': 30,
            'content': lessonContent(i, m, 1),
          },
          {
            'id': '$id-m$m-check',
            'title': 'Review: ${topic.toLowerCase()}',
            'format': 'Assessment',
            'minutes': 10,
            'content': lessonContent(i, m, 2),
          },
        ],
      });
    }
    final course = Course({
      'id': id,
      'seed_id': id,
      'title': subject[0],
      'headline':
          'Build confidence through practical ${subject[0].toLowerCase()} projects.',
      'description':
          'A practical introduction to ${subject[0].toLowerCase()} for learners developing workplace skills. Work through ${subject[3].toLowerCase()}, ${subject[4].toLowerCase()}, and ${subject[5].toLowerCase()} with guided reading, exercises, and self-assessment.',
      'category': subject[1],
      'difficulty': ['Beginner', 'Intermediate', 'Advanced'][i % 3],
      'duration': '3',
      'unit': 'Hours',
      'instructor': subject[2],
      'thumbnail': '',
      'objectives': [
        for (final topic in subject.skip(3))
          'Apply ${topic.toLowerCase()} to a practical scenario.',
      ],
      'modules': modules,
      'status': i == 8
          ? 'Draft'
          : i == 9
          ? 'Archived'
          : 'Published',
      'created_by': admin['id'],
      'created_at': date(190),
      'updated_at': date(i == 9 ? 5 : 150),
    });
    if (course.publishErrors.isNotEmpty) {
      throw FormatException(course.publishErrors.join(' '));
    }
    courses.add(course.data);
  }
  for (var i = 0; i < 60; i++) {
    final learner = learnerIds[i % 18];
    final round = i ~/ 18;
    final courseIndex = ((i % 18) + round * 2) % 9;
    // Index 8 maps to the archived course; the draft has no enrollments.
    final courseId =
        '$seedTag-course-${courseIndex == 8 ? 10 : courseIndex + 1}';
    final id = '$learner/$courseId';
    final marker = '$seedTag-enrollment-${i + 1}';
    final matches = enrollments
        .where(
          (e) =>
              e['id'] == id ||
              e['seed_id'] == marker ||
              (e['learner_id'] == learner && e['course_id'] == courseId),
        )
        .toList();
    if (matches.isNotEmpty) {
      if (matches.length != 1 ||
          matches.single['seed_id'] != marker ||
          matches.single['id'] != id) {
        throw const FormatException('Conflicting seeded enrollment.');
      }
      continue;
    }
    final course = Course(courses.firstWhere((c) => c['id'] == courseId));
    final lessons = course.lessons.map((l) => l['id'] as String).toList();
    final done = i < 15
        ? 0
        : i < 40
        ? 1 + i % 7
        : i < 55
        ? lessons.length
        : i % 4;
    final enrolled = date(25 + i % 30);
    enrollments.add({
      'id': id,
      'seed_id': marker,
      'learner_id': learner,
      'course_id': courseId,
      'enrolled_at': enrolled,
      'created_at': enrolled,
      'updated_at': i < 15 ? enrolled : date(6 + i % 15),
      'created_by': admin['id'],
      'updated_by': i < 15 ? admin['id'] : learner,
      'completed_lesson_ids': lessons.take(done).toList(),
      'last_opened_lesson_id': done == 0 ? null : lessons[done - 1],
      'completed_at': i >= 40 && i < 55 ? date(6 + i % 15) : null,
      'withdrawn_at': i >= 55 ? date(6 + i % 15) : null,
    });
  }
  after[0].addAll({'users': users, 'last_id': highest});
  after[1]['courses'] = courses;
  after[2]['enrollments'] = enrollments;
  validateDataset(after);
  return SeedPlan(before, after, [
    users.length - counts[0],
    courses.length - counts[1],
    enrollments.length - counts[2],
  ]);
}
