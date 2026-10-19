import 'dart:convert';

import '../admin/admin_courses_repository.dart';
import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../data/user_record.dart';

class Enrollment {
  Enrollment(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get learnerId => data['learner_id'] as int;
  String get courseId => data['course_id'] as String;
  bool get withdrawn => data['withdrawn_at'] != null;
  Set<String> get completed =>
      (data['completed_lesson_ids'] as List).cast<String>().toSet();
  double progress(Course? course) {
    final ids = course?.lessons.map((l) => l['id']).toSet() ?? {};
    return ids.isEmpty
        ? 0
        : completed.intersection(ids.cast<String>()).length / ids.length;
  }

  String status(Course? course) => withdrawn
      ? 'Withdrawn'
      : progress(course) == 1
      ? 'Completed'
      : completed.isEmpty && data['last_opened_lesson_id'] == null
      ? 'Not started'
      : 'In progress';
}

class EnrollmentSnapshot {
  EnrollmentSnapshot(
    this.enrollments,
    this.courses,
    this.learners, {
    this.activeLearnerIds = const {},
  });
  final List<Enrollment> enrollments;
  final List<Course> courses;
  final Map<int, String> learners;
  final Set<int> activeLearnerIds;
  Course? course(String id) => courses.where((c) => c.id == id).firstOrNull;
}

abstract interface class EnrollmentRepository {
  Future<EnrollmentSnapshot> load(UserSession actor);
  Future<void> enroll(UserSession actor, int learnerId, String courseId);
  Future<void> withdraw(UserSession actor, String enrollmentId);
  Future<void> openLesson(
    UserSession actor,
    String enrollmentId,
    String lessonId, {
    bool complete = false,
  });
}

class JsonBinEnrollmentRepository implements EnrollmentRepository {
  JsonBinEnrollmentRepository(this.store, this.users, this.courses);
  final JsonBinStore store, users, courses;
  Future<void>? _pending;
  bool _uncertain = false;
  Future<void> _queue(Future<void> Function() action) {
    final result = (_pending ?? Future<void>.value()).then((_) => action());
    _pending = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, dynamic>> _authorize(UserSession actor) async {
    final record = await users.read(operation: 'Enrollment access');
    final ids = <int>{};
    if (validatedUsers(record).any((u) => !ids.add(u['id'] as int))) {
      throw const JsonBinException(
        'The user record contains duplicate IDs. No changes were saved.',
      );
    }
    final matches = validatedUsers(record)
        .where((u) => u['id'] == actor.id)
        .toList();
    if (matches.length != 1 ||
        matches.single['is_active'] != true ||
        matches.single['account_type'] != actor.role.name) {
      throw const JsonBinException(
        'Active account access is required. Please sign in again.',
      );
    }
    return record;
  }

  List<Enrollment> _parse(Map<String, dynamic> record) {
    // Older setup instructions used the empty users template for new bins.
    // Only recognise that exact empty shape; never reinterpret populated data.
    if (record.isEmpty ||
        (!record.containsKey('enrollments') &&
            record.keys.every((key) => key == 'users' || key == 'last_id') &&
            record['users'] is List &&
            (record['users'] as List).isEmpty &&
            record['last_id'] == 0)) {
      return [];
    }
    try {
      final ids = <String>{}, pairs = <String>{};
      return (record['enrollments'] as List).map((v) {
        final e = Enrollment(Map<String, dynamic>.from(v as Map));
        if (e.id.isEmpty ||
            e.learnerId < 0 ||
            e.courseId.isEmpty ||
            !ids.add(e.id) ||
            !pairs.add('${e.learnerId}/${e.courseId}') ||
            e.completed.any((s) => s.isEmpty)) {
          throw const FormatException();
        }
        for (final key in ['enrolled_at', 'updated_at']) {
          if (DateTime.tryParse(e.data[key] as String) == null) {
            throw const FormatException();
          }
        }
        for (final key in ['withdrawn_at', 'completed_at']) {
          if (e.data[key] != null &&
              DateTime.tryParse(e.data[key] as String) == null) {
            throw const FormatException();
          }
        }
        if (e.data['last_opened_lesson_id'] != null &&
            e.data['last_opened_lesson_id'] is! String) {
          throw const FormatException();
        }
        return e;
      }).toList();
    } catch (_) {
      throw const JsonBinException(
        'The enrollments record is invalid. No changes were saved.',
      );
    }
  }

  @override
  Future<EnrollmentSnapshot> load(UserSession actor) async {
    if (_pending != null) await _pending;
    final accounts = validatedUsers(await _authorize(actor))
        .cast<Map<String, dynamic>>();
    final catalog = parseCourses(
      await courses.read(operation: 'Enrollment courses'),
    );
    final entries = _parse(await store.read(operation: 'Enrollments'));
    _uncertain = false;
    final visible = entries
        .where(
          (e) => actor.role == AccountRole.admin || e.learnerId == actor.id,
        )
        .toList();
    for (final e in visible) {
      if (e.progress(catalog.where((c) => c.id == e.courseId).firstOrNull) !=
          1) {
        e.data['completed_at'] = null;
      }
    }
    return EnrollmentSnapshot(
      visible,
      catalog
          .where(
            (c) =>
                actor.role == AccountRole.admin ||
                c.text('status') == 'Published' ||
                visible.any((e) => e.courseId == c.id),
          )
          .toList(),
      {
        for (final u in accounts.where(
          (u) =>
              u['account_type'] == 'learner' &&
              (actor.role == AccountRole.admin || u['id'] == actor.id),
        ))
          u['id'] as int:
              '${u['full_name']}${u['is_active'] == true ? '' : ' (inactive)'}',
      },
      activeLearnerIds: accounts
          .where(
            (u) => u['account_type'] == 'learner' && u['is_active'] == true,
          )
          .map((u) => u['id'] as int)
          .toSet(),
    );
  }

  Future<void> _mutate(
    UserSession actor,
    void Function(List<Enrollment>, List<Course>, List<Map<String, dynamic>>)
    change,
  ) => _queue(() async {
    if (_uncertain) {
      throw const JsonBinException(
        'Refresh enrollments before trying another change.',
      );
    }
    final accounts = validatedUsers(await _authorize(actor))
        .cast<Map<String, dynamic>>();
    final catalog = parseCourses(
      await courses.read(operation: 'Enrollment courses'),
    );
    final record = await store.read(operation: 'Enrollments');
    final entries = _parse(record);
    final before = jsonEncode(record);
    change(entries, catalog, accounts);
    final updated = {
      ...record,
      'enrollments': entries.map((e) => e.data).toList(),
    };
    if (jsonEncode(updated) == before) return;
    try {
      await store.write(
        updated,
        operation: 'Enrollments',
        uncertainMessage: 'The enrollment save could not be confirmed. Refresh enrollments before trying again.',
      );
    } catch (_) {
      _uncertain = true;
      rethrow;
    }
  });
  void _own(UserSession actor, Enrollment e) {
    if (actor.role != AccountRole.admin && actor.id != e.learnerId) {
      throw const JsonBinException(
        'You cannot change another learner’s enrollment.',
      );
    }
  }

  String get _now => DateTime.now().toUtc().toIso8601String();
  @override
  Future<void> enroll(UserSession actor, int learnerId, String courseId) =>
      _mutate(actor, (entries, catalog, accounts) {
        if (actor.role != AccountRole.admin && learnerId != actor.id) {
          throw const JsonBinException('You can only enroll yourself.');
        }
        if (!accounts.any(
          (u) =>
              u['id'] == learnerId &&
              u['account_type'] == 'learner' &&
              u['is_active'] == true,
        )) {
          throw const JsonBinException('Select an active learner.');
        }
        final previous = entries
            .where((e) => e.learnerId == learnerId && e.courseId == courseId)
            .firstOrNull;
        if (previous != null && !previous.withdrawn) return;
        if (!catalog.any(
          (c) => c.id == courseId && c.text('status') == 'Published',
        )) {
          throw const JsonBinException(
            'Only published courses are available for enrollment.',
          );
        }
        if (previous != null) {
          previous.data['completed_at'] =
              previous.progress(catalog.firstWhere((c) => c.id == courseId)) ==
                  1
              ? previous.data['completed_at'] ?? _now
              : null;
          previous.data.addAll({
            'withdrawn_at': null,
            'updated_at': _now,
            'updated_by': actor.id,
          });
        } else {
          entries.add(
            Enrollment({
              'id': '$learnerId/$courseId',
              'learner_id': learnerId,
              'course_id': courseId,
              'enrolled_at': _now,
              'created_at': _now,
              'updated_at': _now,
              'created_by': actor.id,
              'updated_by': actor.id,
              'withdrawn_at': null,
              'completed_lesson_ids': <String>[],
              'last_opened_lesson_id': null,
              'completed_at': null,
            }),
          );
        }
      });
  @override
  Future<void> withdraw(UserSession actor, String enrollmentId) =>
      _mutate(actor, (entries, _, _) {
        final e = entries.where((e) => e.id == enrollmentId).firstOrNull;
        if (e == null) {
          throw const JsonBinException(
            'Enrollment no longer exists. Refresh and try again.',
          );
        }
        _own(actor, e);
        e.data.addAll({
          'withdrawn_at': e.data['withdrawn_at'] ?? _now,
          'updated_at': _now,
          'updated_by': actor.id,
        });
      });
  @override
  Future<void> openLesson(
    UserSession actor,
    String enrollmentId,
    String lessonId, {
    bool complete = false,
  }) => _mutate(actor, (entries, catalog, _) {
    final e = entries.where((e) => e.id == enrollmentId).firstOrNull;
    if (e == null) throw const JsonBinException('Enrollment no longer exists.');
    _own(actor, e);
    if (actor.role != AccountRole.learner || e.withdrawn) {
      throw const JsonBinException('An active learner enrollment is required.');
    }
    final course = catalog.where((c) => c.id == e.courseId).firstOrNull;
    if (course == null || !course.lessons.any((l) => l['id'] == lessonId)) {
      throw const JsonBinException(
        'This lesson is unavailable. Refresh the course.',
      );
    }
    final wasComplete = e.progress(course) == 1;
    final completed = e.completed;
    if (complete) completed.add(lessonId);
    e.data.addAll({
      'completed_lesson_ids': completed.toList(),
      'last_opened_lesson_id': lessonId,
      'updated_at': _now,
      'updated_by': actor.id,
    });
    e.data['completed_at'] = e.progress(course) == 1
        ? (wasComplete ? e.data['completed_at'] ?? _now : _now)
        : null;
  });
}
