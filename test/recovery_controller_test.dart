import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/auth/recovery_controller.dart';
import 'package:learnsphere/auth/recovery_repository.dart';

class PendingRecovery implements RecoveryRepository {
  final pending = Completer<RecoveryAccount>();
  int lookups = 0, clears = 0, resets = 0;
  @override
  Future<RecoveryAccount> lookup(String identity) {
    lookups++;
    return pending.future;
  }

  @override
  Future<void> verifyAnswer(String answer) async {
    if (answer != 'correct') {
      throw const RecoveryException('Incorrect', field: 'answer');
    }
  }

  @override
  Future<void> resetPassword(String password, String confirmation) async {
    resets++;
  }

  @override
  void clear() {
    clears++;
  }
}

void main() {
  test(
    'guards stages, blocks duplicate lookup and restart during load',
    () async {
      final repo = PendingRecovery();
      final controller = RecoveryController(repo);
      addTearDown(controller.dispose);
      await controller.resetPassword('password', 'password');
      expect(repo.resets, 0);
      final loading = controller.lookup('alex');
      await controller.lookup('other');
      controller.restart();
      expect(repo.lookups, 1);
      expect(repo.clears, 0);
      repo.pending.complete(
        const RecoveryAccount(id: 1, identity: 'alex', question: 'Question?'),
      );
      await loading;
      expect(controller.step, RecoveryStep.answer);
      await controller.verifyAnswer('wrong');
      expect(controller.errorField, 'answer');
      expect(controller.step, RecoveryStep.answer);
      await controller.verifyAnswer('correct');
      expect(controller.step, RecoveryStep.password);
      controller.restart();
      expect(controller.account, isNull);
      expect(controller.step, RecoveryStep.identity);
      expect(repo.clears, 1);
      await controller.resetPassword('password', 'password');
      expect(repo.resets, 0);
    },
  );
  test(
    'disposal during lookup does not notify or retain recovery state',
    () async {
      final repo = PendingRecovery();
      final controller = RecoveryController(repo);
      final loading = controller.lookup('alex');
      controller.dispose();
      repo.pending.complete(
        const RecoveryAccount(id: 1, identity: 'alex', question: 'Question?'),
      );
      await loading;
      expect(repo.clears, greaterThanOrEqualTo(2));
    },
  );
}
