import 'package:shared_preferences/shared_preferences.dart';

import 'sign_in_repository.dart';

class RememberedIdentity {
  const RememberedIdentity(this.identity, this.role);
  final String identity;
  final AccountRole role;
}

abstract interface class SignInPreferences {
  Future<RememberedIdentity?> load();
  Future<void> save(RememberedIdentity value);
  Future<void> clear();
}

class LocalSignInPreferences implements SignInPreferences {
  static const identityKey = 'signin.identity', roleKey = 'signin.role';
  @override
  Future<RememberedIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = prefs.getString(identityKey);
    final role = prefs.getString(roleKey);
    if (identity == null ||
        identity.trim().isEmpty ||
        !AccountRole.values.any((item) => item.value == role)) {
      return null;
    }
    return RememberedIdentity(
      identity.trim().toLowerCase(),
      AccountRole.values.firstWhere((item) => item.value == role),
    );
  }

  @override
  Future<void> save(RememberedIdentity value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
          identityKey,
          value.identity.trim().toLowerCase(),
        ) ||
        !await prefs.setString(roleKey, value.role.value)) {
      throw StateError('Preferences unavailable');
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final identityRemoved = await prefs.remove(identityKey);
    final roleRemoved = await prefs.remove(roleKey);
    if (!identityRemoved || !roleRemoved) {
      throw StateError('Preferences unavailable');
    }
  }
}
