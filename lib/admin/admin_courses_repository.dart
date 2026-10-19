import 'dart:convert';

import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../data/user_record.dart';

class Course {
  Course(this.data);
  final Map<String, dynamic> data;
  factory Course.empty() => Course({
    'title': '',
    'headline': '',
    'description': '',
    'category': '',
    'difficulty': 'Beginner',
    'duration': '',
    'unit': 'Hours',
    'instructor': '',
    'thumbnail': '',
    'objectives': <dynamic>[],
    'modules': <dynamic>[],
    'status': 'Draft',
  });
  Course copy() => Course(jsonDecode(jsonEncode(data)) as Map<String, dynamic>);
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('id');
  List<Map<String, dynamic>> get lessons => [
    for (final m in modules)
      for (final l in m['lessons'] as List) l as Map<String, dynamic>,
  ];
  void ensureLessonIds() {
    for (var m = 0; m < modules.length; m++) {
      final list = modules[m]['lessons'] as List;
      for (var l = 0; l < list.length; l++) {
        list[l]['id'] ??= 'legacy-$id-$m-$l';
      }
    }
  }

  List<dynamic> get modules => data['modules'] as List<dynamic>;
  int get lessonCount =>
      modules.fold(0, (n, m) => n + (m['lessons'] as List).length);
  List<String> get publishErrors {
    final errors = <String>[];
    for (final key in [
      'title',
      'headline',
      'description',
      'category',
      'instructor',
    ]) {
      if (text(key).trim().isEmpty) errors.add('Add a course $key.');
    }
    final duration = double.tryParse(text('duration'));
    if (duration == null || !duration.isFinite || duration <= 0) {
      errors.add('Set a positive course duration.');
    }
    if ((data['objectives'] as List)
        .where((v) => v.toString().trim().isNotEmpty)
        .isEmpty) {
      errors.add('Add at least one learning objective.');
    }
    if (modules.isEmpty) errors.add('Add at least one module.');
    for (final module in modules) {
      if ((module['title'] as String).trim().isEmpty ||
          (module['lessons'] as List).isEmpty) {
        errors.add('Every module needs a title and at least one lesson.');
      }
      for (final lesson in module['lessons'] as List) {
        if ((lesson['title'] as String).trim().isEmpty ||
            (lesson['content'] as String).trim().isEmpty ||
            (int.tryParse('${lesson['minutes']}') ?? 0) <= 0) {
          errors.add(
            'Every lesson needs a title, content and positive duration.',
          );
        }
        if (lesson['format'] == 'Video Lesson' &&
            !validWebUrl('${lesson['content']}')) {
          errors.add('Video lessons need a valid HTTPS URL.');
        }
      }
    }
    return errors.toSet().toList();
  }
}

bool validWebUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

abstract interface class AdminCoursesRepository {
  Future<List<Course>> list(UserSession actor);
  Future<Course> save(UserSession actor, Course course);
}

class JsonBinAdminCoursesRepository implements AdminCoursesRepository {
  JsonBinAdminCoursesRepository(this.store, this.users);
  final JsonBinStore store, users;
  Future<void> _authorize(UserSession actor) async {
    final record = await users.read(operation: 'Administrator access');
    final matches = validatedUsers(record)
        .where((u) => u['id'] == actor.id)
        .toList();
    if (actor.role != AccountRole.admin ||
        matches.length != 1 ||
        matches.single['account_type'] != 'admin' ||
        matches.single['is_active'] != true) {
      throw const JsonBinException(
        'Administrator access is required. Please sign in again.',
      );
    }
  }

  @override
  Future<List<Course>> list(UserSession actor) async {
    await _authorize(actor);
    return parseCourses(await store.read(operation: 'Courses'));
  }

  @override
  Future<Course> save(UserSession actor, Course course) async {
    await _authorize(actor);
    final saved = course.copy();
    if (saved.text('title').trim().isEmpty) {
      throw const JsonBinException('Enter a course title before saving.');
    }
    if (saved.text('status') == 'Published' && saved.publishErrors.isNotEmpty) {
      throw JsonBinException(saved.publishErrors.join('\n'));
    }
    final record = await store.read(operation: 'Courses');
    final courses = parseCourses(record);
    final index = courses.indexWhere((c) => c.id == saved.id);
    if (saved.id.isNotEmpty && index < 0) {
      throw const JsonBinException(
        'Course no longer exists. Refresh the course list.',
      );
    }
    saved.data['id'] = saved.id.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : saved.id;
    saved.ensureLessonIds();
    saved.data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    saved.data['created_by'] ??= actor.id;
    final records = [...record['courses'] as List];
    if (index < 0) {
      records.add(saved.data);
    } else {
      records[index] = {...courses[index].data, ...saved.data};
    }
    await store.write(
      {...record, 'courses': records},
      operation: 'Courses',
      uncertainMessage: 'The course save could not be confirmed. Refresh Courses before trying again.',
    );
    return saved;
  }
}

List<Course> parseCourses(Map<String, dynamic> record) {
  if (record['courses'] is! List) {
    throw const JsonBinException(
      'The courses record is invalid. Expected a courses list.',
    );
  }
  try {
    final result = (record['courses'] as List).map((v) {
      final course = Course(Map<String, dynamic>.from(v as Map));
      if (course.id.isEmpty ||
          course.data['modules'] is! List ||
          course.data['objectives'] is! List ||
          !['Draft', 'Published', 'Archived'].contains(course.text('status'))) {
        throw const FormatException();
      }
      for (final module in course.modules) {
        if (module['title'] is! String || module['lessons'] is! List) {
          throw const FormatException();
        }
        for (final lesson in module['lessons']) {
          if (lesson['title'] is! String || lesson['content'] is! String) {
            throw const FormatException();
          }
        }
      }
      course.ensureLessonIds();
      final ids = course.lessons.map((l) => l['id']).toList();
      if (ids.any((id) => id is! String || id.isEmpty) ||
          ids.toSet().length != ids.length) {
        throw const FormatException();
      }
      return course;
    }).toList();
    if (result.map((c) => c.id).toSet().length != result.length) {
      throw const FormatException();
    }
    return result;
  } catch (_) {
    throw const JsonBinException(
      'The courses record is invalid. No changes were saved.',
    );
  }
}
