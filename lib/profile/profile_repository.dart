import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../data/user_record.dart';
import '../registration/registration_data.dart';

class UserProfile {
  UserProfile(Map<String, dynamic> values) : values = Map.of(values);
  factory UserProfile.fromUser(Map<String, dynamic> user) {
    final raw = user['profile'];
    if (user['full_name'] is! String ||
        user['email'] is! String ||
        (raw != null && raw is! Map<String, dynamic>)) {
      throw const ProfileException('The profile record is invalid.');
    }
    final profile = raw as Map<String, dynamic>? ?? {};
    if (textFields.any((k) => profile[k] != null && profile[k] is! String) ||
        (profile['avatar'] != null && !avatars.contains(profile['avatar'])) ||
        (profile['topics'] != null &&
            (profile['topics'] is! List ||
                (profile['topics'] as List).any((e) => e is! String))) ||
        [
          'public_profile',
          'weekly_reminders',
        ].any((k) => profile[k] != null && profile[k] is! bool)) {
      throw const ProfileException('The profile record is invalid.');
    }
    final name = (user['full_name'] as String).trim();
    final split = name.indexOf(' ');
    return UserProfile({
      'first_name': split < 0 ? name : name.substring(0, split),
      'last_name': split < 0 ? '' : name.substring(split + 1),
      for (final key in [
        ...textFields,
        'avatar',
        'topics',
        'public_profile',
        'weekly_reminders',
      ])
        if (profile.containsKey(key)) key: profile[key],
      'email': user['email'],
    });
  }
  final Map<String, dynamic> values;
  static const textFields = [
    'first_name',
    'last_name',
    'headline',
    'organization',
    'bio',
    'linkedin',
    'github',
    'portfolio',
  ];
  static const avatars = ['brainiac', 'owl', 'astronaut', 'fox', 'cat'];
  String text(String key) => values[key] as String? ?? '';
  List<String> get topics => List<String>.from(values['topics'] as List? ?? []);
  bool flag(String key) => values[key] == true;
  String get fullName => '${text('first_name')} ${text('last_name')}'.trim();
  UserProfile normalized() => UserProfile({
    ...values,
    for (final key in [...textFields, 'email'])
      key: key == 'email' ? text(key).trim().toLowerCase() : text(key).trim(),
    'topics': topics.map((e) => e.trim()).toList(),
  });
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (text('first_name').trim().isEmpty) {
      errors['first_name'] = 'First name is required.';
    }
    final emailError = RegistrationValidation.email(text('email'));
    if (emailError != null) errors['email'] = emailError;
    if (text('bio').length > 300) errors['bio'] = 'Use at most 300 characters.';
    for (final key in ['linkedin', 'github']) {
      final value = text(key).trim();
      if (value.isNotEmpty &&
          !RegExp(
            key == 'github'
                ? r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$'
                : r'^[a-zA-Z0-9_-]+$',
          ).hasMatch(value)) {
        errors[key] = 'Enter a valid profile handle.';
      }
    }
    final site = text('portfolio').trim();
    final uri = Uri.tryParse(site);
    if (site.isNotEmpty &&
        (uri == null ||
            !['https', 'http'].contains(uri.scheme) ||
            !uri.host.contains('.') ||
            uri.userInfo.isNotEmpty ||
            site.contains(RegExp(r'\s')))) {
      errors['portfolio'] = 'Enter a complete http or https website URL.';
    }
    final tags = topics.map((e) => e.trim().toLowerCase()).toList();
    if (tags.any((e) => e.isEmpty) || tags.toSet().length != tags.length) {
      errors['topics'] = 'Topics must be nonblank and unique.';
    }
    if (values['avatar'] != null && !avatars.contains(values['avatar'])) {
      errors['avatar'] = 'Choose an available avatar.';
    }
    return errors;
  }

  UserSession session(UserSession previous) => UserSession(
    id: previous.id,
    fullName: fullName,
    email: text('email'),
    username: previous.username,
    role: previous.role,
  );
}

class ProfileException implements Exception {
  const ProfileException(this.message, [this.fields = const {}]);
  final String message;
  final Map<String, String> fields;
}

abstract interface class ProfileRepository {
  Future<UserProfile> load(UserSession session);
  Future<UserProfile> save(UserSession session, UserProfile profile);
}

class JsonBinProfileRepository implements ProfileRepository {
  JsonBinProfileRepository(this.store);
  final JsonBinStore store;
  Map<String, dynamic> _account(
    Map<String, dynamic> record,
    UserSession session,
  ) {
    final matches = validatedUsers(record)
        .where((u) => u['id'] == session.id)
        .toList();
    if (matches.length != 1) {
      throw const ProfileException(
        'Account not found or invalid. Please sign in again.',
      );
    }
    final user = matches.single as Map<String, dynamic>;
    if (user['is_active'] != true ||
        user['account_type'] != session.role.value ||
        user['full_name'] is! String) {
      throw const ProfileException(
        'Account unavailable. Please sign in again.',
      );
    }
    UserProfile.fromUser(user);
    return user;
  }

  @override
  Future<UserProfile> load(UserSession session) async {
    final user = _account(await store.read(operation: 'Profile'), session);
    return UserProfile.fromUser(user);
  }

  @override
  Future<UserProfile> save(UserSession session, UserProfile profile) async {
    final clean = profile.normalized();
    final errors = clean.validate();
    if (errors.isNotEmpty) {
      throw ProfileException('Please update the highlighted fields.', errors);
    }
    final record = await store.read(operation: 'Profile');
    final user = _account(record, session);
    final email = clean.text('email');
    if (validatedUsers(record).any(
      (u) =>
          u['id'] != session.id &&
          ([
            'email',
            'username',
          ].any((key) => (u[key] as String).trim().toLowerCase() == email)),
    )) {
      throw const ProfileException(
        'This email is already used by another account.',
        {'email': 'This email is already used by another account.'},
      );
    }
    user['full_name'] = clean.fullName;
    user['email'] = email;
    user['profile'] = {
      ...?user['profile'] as Map<String, dynamic>?,
      for (final key in UserProfile.textFields) key: clean.text(key),
      'avatar': clean.values['avatar'],
      'topics': clean.topics,
      'public_profile': clean.flag('public_profile'),
      'weekly_reminders': clean.flag('weekly_reminders'),
    };
    await store.write(record, operation: 'Profile');
    return clean;
  }
}
