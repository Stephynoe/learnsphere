class RegistrationData {
  RegistrationData({
    required String fullName,
    required String email,
    required String username,
    required this.password,
    required String question,
    required String answer,
  }) : fullName = fullName.trim(),
       email = email.trim().toLowerCase(),
       username = username.trim().toLowerCase(),
       question = question.trim(),
       answer = answer.trim();

  final String fullName, email, username, password, question, answer;

  Map<String, dynamic> toUser(int id, DateTime now) => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'username': username,
    'password_hash': password,
    'account_type': 'learner',
    'reset_password_question': question,
    'reset_password_answer': answer,
    'is_active': true,
    'created_at': now.toUtc().toIso8601String(),
  };
}

class RegistrationValidation {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  static String? email(String? value) {
    if (requiredText(value) != null) return 'Email is required.';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address.';
  }

  static String? username(String? value) =>
      RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Use 3–30 letters, numbers, underscores or periods.';

  static List<bool> passwordRules(String value) => [
    value.length >= 8,
    RegExp(r'[0-9]').hasMatch(value),
    RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value),
  ];

  static String? password(String? value) =>
      passwordRules(value ?? '').every((rule) => rule)
      ? null
      : 'Use 8+ characters, a number and a symbol.';

  static String? confirmation(String? value, String password) =>
      value == null || value.isEmpty
      ? 'Confirm your password.'
      : value != password
      ? 'Passwords do not match.'
      : null;
}
