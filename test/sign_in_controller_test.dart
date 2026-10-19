import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learnsphere/auth/sign_in_controller.dart';
import 'package:learnsphere/auth/sign_in_preferences.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';

class MemoryPreferences implements SignInPreferences {
  RememberedIdentity? saved;
  bool fail = false;
  @override
  Future<RememberedIdentity?> load() async {
    if (fail) throw StateError('failed');
    return saved;
  }

  @override
  Future<void> save(RememberedIdentity value) async {
    if (fail) throw StateError('failed');
    saved = value;
  }

  @override
  Future<void> clear() async {
    if (fail) throw StateError('failed');
    saved = null;
  }
}

class PendingSignIn implements SignInRepository {
  final pending = Completer<UserSession>();
  int calls = 0;
  String? identity, password;
  @override
  Future<UserSession> signIn(
    String identity,
    String password,
    AccountRole role,
  ) {
    calls++;
    this.identity = identity;
    this.password = password;
    return pending.future;
  }
}

const session = UserSession(
  id: 1,
  fullName: 'Alex',
  email: 'a@b.com',
  username: 'alex',
  role: AccountRole.learner,
);
void main() {
  test(
    'restores identity and role; unchecking removes stored fields',
    () async {
      final prefs = MemoryPreferences()
        ..saved = const RememberedIdentity('alex', AccountRole.admin);
      final controller = SignInController(PendingSignIn(), prefs);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.identity, 'alex');
      expect(controller.role, AccountRole.admin);
      expect(controller.remember, isTrue);
      await controller.setRemember(false);
      expect(prefs.saved, isNull);
    },
  );
  test('normalizes identity, preserves password, prevents duplicate submits, saves identity only', () async {
    final prefs = MemoryPreferences();
    final repo = PendingSignIn();
    final controller = SignInController(repo, prefs);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setRemember(true);
    final pending = controller.submit(' ALEX ', ' Secret ');
    expect(await controller.submit('alex', 'Secret'), isNull);
    expect(repo.calls, 1);
    expect(repo.identity, 'alex');
    expect(repo.password, ' Secret ');
    repo.pending.complete(session);
    expect(await pending, session);
    expect(prefs.saved!.identity, 'alex');
    expect(prefs.saved!.role, AccountRole.learner);
  });
  test('preference failures never block authentication', () async {
    final prefs = MemoryPreferences()..fail = true;
    final repo = PendingSignIn();
    final controller = SignInController(repo, prefs);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.initializing, isFalse);
    expect(controller.preferenceWarning, isNotNull);
    await controller.setRemember(true);
    final pending = controller.submit('alex', 'pass');
    repo.pending.complete(session);
    expect(await pending, session);
    expect(controller.preferenceWarning, contains('could not be saved'));
  });
  test('failed auth does not save identity and permits retry', () async {
    final prefs = MemoryPreferences();
    final repo = PendingSignIn();
    final controller = SignInController(repo, prefs);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.setRemember(true);
    final pending = controller.submit('alex', 'wrong');
    repo.pending.completeError(const SignInException(SignInException.invalid));
    expect(await pending, isNull);
    expect(controller.error, SignInException.invalid);
    expect(controller.busy, isFalse);
    expect(prefs.saved, isNull);
  });
  test(
    'local preferences persist only two allowed keys and can be removed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = LocalSignInPreferences();
      expect(await prefs.load(), isNull);
      await prefs.save(const RememberedIdentity(' ALEX ', AccountRole.admin));
      final raw = await SharedPreferences.getInstance();
      expect(raw.getKeys(), {
        LocalSignInPreferences.identityKey,
        LocalSignInPreferences.roleKey,
      });
      expect((await prefs.load())!.identity, 'alex');
      expect((await prefs.load())!.role, AccountRole.admin);
      await prefs.clear();
      expect(raw.getKeys(), isEmpty);
    },
  );
}
