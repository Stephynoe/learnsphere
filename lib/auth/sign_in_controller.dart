import 'package:flutter/foundation.dart';

import 'sign_in_preferences.dart';
import 'sign_in_repository.dart';

class SignInController extends ChangeNotifier {
  SignInController(this.repository, this.preferences);
  final SignInRepository repository;
  final SignInPreferences preferences;
  bool initializing = true, busy = false, remember = false, _disposed = false;
  AccountRole role = AccountRole.learner;
  String identity = '';
  String? error, preferenceWarning;
  UserSession? session;
  Future<void> _preferenceQueue = Future.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final saved = await preferences.load();
      if (saved != null) {
        identity = saved.identity;
        role = saved.role;
        remember = true;
      }
    } catch (_) {
      preferenceWarning = 'Saved sign-in details could not be loaded.';
    }
    initializing = false;
    _notify();
  }

  Future<void> setRemember(bool value) async {
    remember = value;
    _notify();
    if (!value) {
      _preferenceQueue = _preferenceQueue.then((_) async {
        try {
          await preferences.clear();
          preferenceWarning = null;
        } catch (_) {
          preferenceWarning = 'Saved sign-in details could not be removed.';
        }
      });
      await _preferenceQueue;
      _notify();
    }
  }

  Future<UserSession?> submit(String identity, String password) async {
    if (busy || initializing || session != null) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final signedIn = await repository.signIn(
        identity.trim().toLowerCase(),
        password,
        role,
      );
      await _preferenceQueue;
      try {
        if (remember) {
          await preferences.save(
            RememberedIdentity(identity.trim().toLowerCase(), role),
          );
        } else {
          await preferences.clear();
        }
        preferenceWarning = null;
      } catch (_) {
        preferenceWarning =
            'Signed in, but your remember-me preference could not be saved.';
      }
      if (_disposed) return null;
      session = signedIn;
      return signedIn;
    } on SignInException catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'Unable to sign in right now. Please try again.';
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
