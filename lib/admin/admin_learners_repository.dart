import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../data/user_record.dart';
import '../profile/profile_repository.dart';

class LearnerSummary {
  const LearnerSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.organization,
    required this.active,
    this.avatar,
    this.registeredAt,
  });
  final int id;
  final String name, email, username, organization;
  final bool active;
  final String? avatar, registeredAt;
  factory LearnerSummary.fromUser(Map<String, dynamic> user) {
    final profile = UserProfile.fromUser(user);
    if (user['is_active'] is! bool ||
        (user['created_at'] != null && user['created_at'] is! String)) {
      throw const ProfileException('The learner account record is invalid.');
    }
    return LearnerSummary(
      id: user['id'] as int,
      name: user['full_name'] as String,
      email: user['email'] as String,
      username: user['username'] as String,
      organization: profile.text('organization'),
      active: user['is_active'] as bool,
      avatar: profile.values['avatar'] as String?,
      registeredAt: user['created_at'] as String?,
    );
  }
}

class LearnerDetails {
  const LearnerDetails(this.summary, this.profile);
  final LearnerSummary summary;
  final UserProfile profile;
}

/// Only the fields an administrator is allowed to change cross this boundary.
class LearnerChanges {
  LearnerChanges(UserProfile profile)
    : profile = UserProfile({
        for (final key in [...UserProfile.textFields, 'email'])
          key: profile.text(key),
        'topics': profile.topics,
      });
  final UserProfile profile;
}

abstract interface class AdminLearnersRepository {
  Future<List<LearnerSummary>> listLearners(UserSession adminSession);
  Future<LearnerDetails> loadLearner(UserSession adminSession, int learnerId);
  Future<LearnerDetails> saveLearner(
    UserSession adminSession,
    int learnerId,
    LearnerChanges changes,
  );
}

class JsonBinAdminLearnersRepository implements AdminLearnersRepository {
  JsonBinAdminLearnersRepository(this.store);
  final JsonBinStore store;
  Future<Map<String, dynamic>> _read(UserSession actor) async {
    final record = await store.read(operation: 'Learners');
    final users = validatedUsers(record);
    final matches = users.where((u) => u['id'] == actor.id).toList();
    if (actor.role != AccountRole.admin ||
        matches.length != 1 ||
        matches.single['account_type'] != 'admin' ||
        matches.single['is_active'] != true) {
      throw const ProfileException(
        'Administrator access is required. Please sign in again.',
      );
    }
    final ids = <int>{};
    for (final user in users) {
      if (!ids.add(user['id'] as int) || user['account_type'] is! String) {
        throw const ProfileException(
          'The user record is invalid. No changes were saved.',
        );
      }
    }
    return record;
  }

  Map<String, dynamic> _target(Map<String, dynamic> record, int id) {
    final matches = validatedUsers(record).where((u) => u['id'] == id).toList();
    if (matches.length == 1 && matches.single['account_type'] == 'admin') {
      throw const ProfileException(
        'Administrator accounts cannot be edited from learner management.',
      );
    }
    if (matches.length != 1 || matches.single['account_type'] != 'learner') {
      throw const ProfileException(
        'Learner not found. Refresh the learner list.',
      );
    }
    return matches.single as Map<String, dynamic>;
  }

  LearnerDetails _details(Map<String, dynamic> user) =>
      LearnerDetails(LearnerSummary.fromUser(user), UserProfile.fromUser(user));
  @override
  Future<List<LearnerSummary>> listLearners(UserSession adminSession) async {
    final record = await _read(adminSession);
    final learners = validatedUsers(record)
        .where((u) => u['account_type'] == 'learner')
        .map((u) => LearnerSummary.fromUser(u as Map<String, dynamic>))
        .toList();
    learners.sort((a, b) {
      final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return learners;
  }

  @override
  Future<LearnerDetails> loadLearner(
    UserSession adminSession,
    int learnerId,
  ) async => _details(_target(await _read(adminSession), learnerId));
  @override
  Future<LearnerDetails> saveLearner(
    UserSession adminSession,
    int learnerId,
    LearnerChanges changes,
  ) async {
    final clean = changes.profile.normalized();
    final errors = clean.validate();
    if (errors.isNotEmpty) {
      throw ProfileException('Please update the highlighted fields.', errors);
    }
    final record = await _read(adminSession);
    final target = _target(record, learnerId);
    _details(target);
    if (validatedUsers(record).any(
      (u) =>
          u['id'] != learnerId &&
          ['email', 'username'].any(
            (key) =>
                (u[key] as String).trim().toLowerCase() == clean.text('email'),
          ),
    )) {
      throw const ProfileException(
        'This email is already used by another account.',
        {'email': 'This email is already used by another account.'},
      );
    }
    target['full_name'] = clean.fullName;
    target['email'] = clean.text('email');
    target['profile'] = {
      ...?target['profile'] as Map<String, dynamic>?,
      for (final key in UserProfile.textFields) key: clean.text(key),
      'topics': clean.topics,
    };
    await store.write(record, operation: 'Learners');
    return _details(target);
  }
}

/// Reuses profile form state while keeping the acting administrator separate.
class AdminLearnerProfileAdapter implements ProfileRepository {
  AdminLearnerProfileAdapter(
    this.repository,
    this.actor,
    this.id,
    this.onLoaded,
  );
  final AdminLearnersRepository repository;
  final UserSession actor;
  final int id;
  final void Function(LearnerDetails) onLoaded;
  @override
  Future<UserProfile> load(UserSession session) async {
    final result = await repository.loadLearner(actor, id);
    onLoaded(result);
    return result.profile;
  }

  @override
  Future<UserProfile> save(UserSession session, UserProfile profile) async {
    final result = await repository.saveLearner(
      actor,
      id,
      LearnerChanges(profile),
    );
    onLoaded(result);
    return result.profile;
  }
}
