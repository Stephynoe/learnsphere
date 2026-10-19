import '../admin/admin_courses_repository.dart';
import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../data/user_record.dart';

abstract interface class LearnerCoursesRepository {
  Future<List<Course>> list(UserSession actor);
}

class JsonBinLearnerCoursesRepository implements LearnerCoursesRepository {
  JsonBinLearnerCoursesRepository(this.courses, this.users);
  final JsonBinStore courses, users;

  @override
  Future<List<Course>> list(UserSession actor) async {
    final record = await users.read(operation: 'Learner access');
    final matches = validatedUsers(record)
        .where((u) => u['id'] == actor.id)
        .toList();
    if (actor.role != AccountRole.learner ||
        matches.length != 1 ||
        matches.single['account_type'] != 'learner' ||
        matches.single['is_active'] != true) {
      throw const JsonBinException(
        'Learner access is required. Please sign in again.',
      );
    }
    return publishedCourses(
      parseCourses(await courses.read(operation: 'Course discovery')),
    );
  }
}

List<Course> publishedCourses(List<Course> courses) {
  final result = courses.where((c) => c.text('status') == 'Published').toList();
  result.sort((a, b) {
    final ad = DateTime.tryParse(a.text('updated_at'));
    final bd = DateTime.tryParse(b.text('updated_at'));
    final order = ad == null
        ? (bd == null ? 0 : 1)
        : (bd == null ? -1 : bd.compareTo(ad));
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}
