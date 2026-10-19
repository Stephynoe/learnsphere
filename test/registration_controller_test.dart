import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/registration/registration_controller.dart';
import 'package:learnsphere/registration/registration_data.dart';
import 'package:learnsphere/registration/registration_repository.dart';

class PendingRepository implements RegistrationRepository {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> register(RegistrationData data) {
    calls++;
    return pending.future;
  }
}

void main() {
  test('controller prevents repeated submissions and tolerates disposal during save', () async {
    final repository = PendingRepository();
    final controller = RegistrationController(repository);
    final data = RegistrationData(
      fullName: 'Learner',
      email: 'a@b.com',
      username: 'learner',
      password: 'Password1!',
      question: 'Question?',
      answer: 'Answer',
    );
    final saving = controller.submit(data);
    await controller.submit(data);
    expect(repository.calls, 1);
    expect(controller.busy, isTrue);
    controller.dispose();
    repository.pending.complete();
    await saving;
    expect(controller.succeeded, isTrue);
    await controller.submit(data);
    expect(repository.calls, 1);
  });
}
