import '../data/jsonbin_store.dart';
import '../data/user_record.dart';
import '../registration/registration_data.dart';

class RecoveryAccount {
  const RecoveryAccount({
    required this.id,
    required this.identity,
    required this.question,
  });
  final int id;
  final String identity, question;
}

class RecoveryException implements Exception {
  const RecoveryException(this.message, {this.field, this.restart = false});
  final String message;
  final String? field;
  final bool restart;
}

abstract interface class RecoveryRepository {
  Future<RecoveryAccount> lookup(String identity);
  Future<void> verifyAnswer(String answer);
  Future<void> resetPassword(String password, String confirmation);
  void clear();
}

class JsonBinRecoveryRepository implements RecoveryRepository {
  JsonBinRecoveryRepository(this.store);
  final JsonBinStore store;
  Map<String, dynamic>? _snapshot;
  String? _identity;
  bool _verified = false;
  static const uncertain =
      'The password save could not be confirmed. Try signing in with your new password before resetting again.';
  static const changed =
      'The account or recovery details changed. Please restart password recovery.';

  @override
  void clear() {
    _snapshot = null;
    _identity = null;
    _verified = false;
  }

  Map<String, dynamic> _find(Map<String, dynamic> record, String identity) {
    final users = validatedUsers(record);
    final matches = users
        .where(
          (user) =>
              (user['email'] as String).trim().toLowerCase() == identity ||
              (user['username'] as String).trim().toLowerCase() == identity,
        )
        .toList();
    if (matches.isEmpty) {
      throw const RecoveryException(
        'No account found with that email or username.',
        field: 'identity',
      );
    }
    if (matches.length != 1) {
      throw const RecoveryException(
        'Multiple accounts match these details. Contact the app administrator.',
      );
    }
    final user = matches.single as Map<String, dynamic>;
    if (users.where((other) => other['id'] == user['id']).length != 1) {
      throw const RecoveryException(
        'The account record is ambiguous. Contact the app administrator.',
      );
    }
    if (user['is_active'] != true ||
        !['learner', 'admin'].contains(user['account_type'])) {
      throw const RecoveryException(
        'This account cannot use password recovery. Contact the app administrator.',
      );
    }
    for (final field in [
      'reset_password_question',
      'reset_password_answer',
      'password_hash',
    ]) {
      if (user[field] is! String || (user[field] as String).trim().isEmpty) {
        throw const RecoveryException(
          'Recovery details are missing or invalid. Contact the app administrator.',
        );
      }
    }
    return user;
  }

  @override
  Future<RecoveryAccount> lookup(String identity) async {
    clear();
    final normalized = identity.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const RecoveryException(
        'Enter your email or username.',
        field: 'identity',
      );
    }
    try {
      final user = _find(
        await store.read(operation: 'Password recovery'),
        normalized,
      );
      // Keep only the fields needed to recheck this challenge, never the password.
      _snapshot = {
        for (final field in [
          'id',
          'email',
          'username',
          'account_type',
          'is_active',
          'reset_password_question',
          'reset_password_answer',
        ])
          field: user[field],
      };
      _identity = normalized;
      return RecoveryAccount(
        id: user['id'] as int,
        identity: normalized,
        question: user['reset_password_question'] as String,
      );
    } on JsonBinException catch (e) {
      throw RecoveryException(e.message);
    }
  }

  @override
  Future<void> verifyAnswer(String answer) async {
    _verified = false;
    if (_snapshot == null) {
      throw const RecoveryException('Find your account first.', restart: true);
    }
    if (answer.trim().isEmpty) {
      throw const RecoveryException(
        'Enter your recovery answer.',
        field: 'answer',
      );
    }
    if (answer.trim().toLowerCase() !=
        (_snapshot!['reset_password_answer'] as String).trim().toLowerCase()) {
      throw const RecoveryException(
        'That answer is incorrect. Please try again.',
        field: 'answer',
      );
    }
    _verified = true;
  }

  @override
  Future<void> resetPassword(String password, String confirmation) async {
    if (!_verified || _snapshot == null || _identity == null) {
      throw const RecoveryException(
        'Verify your recovery answer first.',
        restart: true,
      );
    }
    final passwordError = RegistrationValidation.password(password);
    if (passwordError != null) {
      throw RecoveryException(passwordError, field: 'password');
    }
    final confirmationError = RegistrationValidation.confirmation(
      confirmation,
      password,
    );
    if (confirmationError != null) {
      throw RecoveryException(confirmationError, field: 'confirmation');
    }
    try {
      final record = await store.read(operation: 'Password recovery');
      Map<String, dynamic> user;
      try {
        user = _find(record, _identity!);
        if (_snapshot!.entries.any((entry) => user[entry.key] != entry.value)) {
          throw const RecoveryException(changed);
        }
      } on RecoveryException {
        clear();
        throw const RecoveryException(changed, restart: true);
      }
      user['password_hash'] = password;
      await store.write(
        record,
        operation: 'Password recovery',
        uncertainMessage: uncertain,
      );
      clear();
    } on JsonBinException catch (e) {
      if (e.message == uncertain) {
        clear();
        throw RecoveryException(e.message, restart: true);
      }
      throw RecoveryException(e.message);
    }
  }
}
