import 'package:flutter/foundation.dart';

import 'recovery_repository.dart';

enum RecoveryStep { identity, answer, password, success }

class RecoveryController extends ChangeNotifier {
  RecoveryController(this.repository);
  final RecoveryRepository repository;
  RecoveryStep step = RecoveryStep.identity;
  RecoveryAccount? account;
  bool busy = false, _disposed = false;
  String? error, errorField;

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    errorField = null;
    notifyListeners();
    try {
      await action();
    } on RecoveryException catch (e) {
      error = e.message;
      errorField = e.field;
      if (e.restart) {
        repository.clear();
        account = null;
        step = RecoveryStep.identity;
      }
    } catch (_) {
      error = 'Unable to complete password recovery. Please try again.';
    } finally {
      busy = false;
      if (!_disposed) {
        notifyListeners();
      } else {
        repository.clear();
      }
    }
  }

  Future<void> lookup(String identity) async {
    if (step != RecoveryStep.identity) return;
    await _run(() async {
      account = await repository.lookup(identity);
      if (!_disposed) step = RecoveryStep.answer;
    });
  }

  Future<void> verifyAnswer(String answer) async {
    if (step != RecoveryStep.answer) return;
    await _run(() async {
      await repository.verifyAnswer(answer);
      if (!_disposed) step = RecoveryStep.password;
    });
  }

  Future<void> resetPassword(String password, String confirmation) async {
    if (step != RecoveryStep.password) return;
    await _run(() async {
      await repository.resetPassword(password, confirmation);
      if (!_disposed) {
        account = null;
        step = RecoveryStep.success;
      }
    });
  }

  void clearFieldError(String field) {
    if (errorField == field) {
      error = null;
      errorField = null;
      notifyListeners();
    }
  }

  void restart() {
    if (busy) return;
    repository.clear();
    account = null;
    step = RecoveryStep.identity;
    error = null;
    errorField = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.clear();
    super.dispose();
  }
}
