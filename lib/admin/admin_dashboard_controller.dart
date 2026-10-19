import 'package:flutter/foundation.dart';

import '../enrollment/enrollment_repository.dart';

import '../data/jsonbin_store.dart';
import 'admin_dashboard_repository.dart';
import 'admin_courses_repository.dart';
import '../auth/sign_in_repository.dart';

class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController(
    this.repository, {
    this.coursesRepository,
    this.session,
    this.enrollmentsRepository,
  });
  final AdminCoursesRepository? coursesRepository;
  final UserSession? session;
  final EnrollmentRepository? enrollmentsRepository;
  EnrollmentSnapshot? enrollmentSnapshot;
  String? enrollmentError;
  List<Enrollment> get activeEnrollments =>
      enrollmentSnapshot?.enrollments.where((e) => !e.withdrawn).toList() ?? [];
  String get averageCompletion {
    final entries = activeEnrollments
        .where((e) => enrollmentSnapshot!.course(e.courseId) != null)
        .toList();
    return entries.isEmpty
        ? '0%'
        : '${(entries.fold<double>(0, (sum, e) => sum + e.progress(enrollmentSnapshot!.course(e.courseId))) * 100 / entries.length).round()}%';
  }

  Future<void> loadEnrollments() async {
    if (_disposed || enrollmentsRepository == null || session == null) return;
    try {
      final result = await enrollmentsRepository!.load(session!);
      if (!_disposed) {
        enrollmentSnapshot = result;
        enrollmentError = null;
      }
    } catch (e) {
      if (!_disposed) {
        enrollmentError = e is JsonBinException
            ? e.message
            : 'Unable to load enrollments.';
      }
    }
    if (!_disposed) notifyListeners();
  }

  List<Course>? courses;
  String? courseError;
  bool coursesBusy = false;
  bool get loading => busy || coursesBusy;
  int courseCount(String status) =>
      courses?.where((c) => c.text('status') == status).length ?? 0;
  List<Course> get recentCourses {
    final result =
        courses?.where((c) => c.text('status') != 'Archived').toList() ??
        <Course>[];
    result.sort((a, b) {
      final aDate = DateTime.tryParse(a.text('updated_at'));
      final bDate = DateTime.tryParse(b.text('updated_at'));
      final byDate = aDate == null
          ? (bDate == null ? 0 : 1)
          : bDate == null
          ? -1
          : bDate.compareTo(aDate);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return result.take(3).toList();
  }

  final AdminDashboardRepository repository;
  AdminDashboardSummary? summary;
  String? error;
  bool busy = false;
  bool _disposed = false;

  Future<void> load() async {
    await Future.wait([loadLearners(), loadCourses(), loadEnrollments()]);
  }

  Future<void> loadCourses() async {
    if (_disposed ||
        coursesBusy ||
        coursesRepository == null ||
        session == null) {
      return;
    }
    coursesBusy = true;
    courseError = null;
    notifyListeners();
    try {
      final result = await coursesRepository!.list(session!);
      if (!_disposed) courses = result;
    } catch (e) {
      if (!_disposed) {
        courseError = e is JsonBinException
            ? e.message
            : 'Unable to load courses. Please try again.';
      }
    } finally {
      if (!_disposed) {
        coursesBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadLearners() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.loadSummary();
      if (!_disposed) summary = result;
    } catch (e) {
      if (!_disposed) {
        error = e is JsonBinException
            ? e.message
            : 'Unable to load the dashboard. Please try again.';
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
