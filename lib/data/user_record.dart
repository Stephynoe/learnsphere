import 'jsonbin_store.dart';

/// User schema validation shared by repositories, independent of bin transport.
List<dynamic> validatedUsers(Map<String, dynamic> record) {
  final users = record['users'];
  if (users is! List ||
      users.any(
        (user) =>
            user is! Map<String, dynamic> ||
            user['id'] is! int ||
            (user['id'] as int) < 0 ||
            user['email'] is! String ||
            user['username'] is! String,
      )) {
    throw const JsonBinException(
      'The user record is invalid. No changes were saved. Contact the app administrator.',
    );
  }
  return users;
}
