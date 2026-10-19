import '../data/jsonbin_store.dart';
import '../data/user_record.dart';

class AdminDashboardSummary {
  const AdminDashboardSummary({required this.learnerCount});
  final int learnerCount;
}

abstract interface class AdminDashboardRepository {
  Future<AdminDashboardSummary> loadSummary();
}

class JsonBinAdminDashboardRepository implements AdminDashboardRepository {
  JsonBinAdminDashboardRepository(this.store);
  final JsonBinStore store;

  @override
  Future<AdminDashboardSummary> loadSummary() async {
    final record = await store.read(operation: 'Dashboard');
    final users = validatedUsers(record);
    if (users.any((user) => user['account_type'] is! String)) {
      throw const JsonBinException(
        'The user record is invalid. Contact the app administrator.',
      );
    }
    return AdminDashboardSummary(
      learnerCount: users
          .where((user) => user['account_type'] == 'learner')
          .length,
    );
  }
}
