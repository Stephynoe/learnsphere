import '../data/jsonbin_store.dart';
import '../data/user_record.dart';

enum AccountRole {
  learner('learner', 'Learner'),
  admin('admin', 'Administrator');

  const AccountRole(this.value, this.label);
  final String value, label;
}

class UserSession {
  const UserSession({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
  });
  final int id;
  final String fullName, email, username;
  final AccountRole role;
}

class SignInException implements Exception {
  const SignInException(this.message);
  final String message;
  static const invalid =
      'Unable to sign in. Check your credentials, account status, and selected role.';
}

abstract interface class SignInRepository {
  Future<UserSession> signIn(
    String identity,
    String password,
    AccountRole role,
  );
}

class JsonBinSignInRepository implements SignInRepository {
  JsonBinSignInRepository(this.store);
  final JsonBinStore store;
  @override
  Future<UserSession> signIn(
    String identity,
    String password,
    AccountRole role,
  ) async {
    try {
      final record = await store.read(operation: 'Sign-in');
      final normalized = identity.trim().toLowerCase();
      final matches = validatedUsers(record)
          .where(
            (user) =>
                (user['email'] as String).trim().toLowerCase() == normalized ||
                (user['username'] as String).trim().toLowerCase() == normalized,
          )
          .toList();
      if (normalized.isEmpty || password.isEmpty || matches.length != 1) {
        throw const SignInException(SignInException.invalid);
      }
      final user = matches.single as Map<String, dynamic>;
      if (user['full_name'] is! String ||
          (user['full_name'] as String).trim().isEmpty ||
          user['password_hash'] is! String ||
          user['is_active'] is! bool ||
          user['account_type'] is! String) {
        throw const SignInException(
          'The account record is invalid. Contact the app administrator.',
        );
      }
      if (user['password_hash'] != password ||
          user['is_active'] != true ||
          user['account_type'] != role.value) {
        throw const SignInException(SignInException.invalid);
      }
      return UserSession(
        id: user['id'] as int,
        fullName: user['full_name'] as String,
        email: user['email'] as String,
        username: user['username'] as String,
        role: role,
      );
    } on JsonBinException catch (e) {
      throw SignInException(e.message);
    }
  }
}
