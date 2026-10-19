import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/registration/registration_data.dart';

void main() {
  test('required values reject whitespace', () {
    for (final value in [null, '', '  ']) {
      expect(RegistrationValidation.requiredText(value), isNotNull);
    }
    expect(RegistrationValidation.requiredText(' Alex '), isNull);
  });
  test('email validation', () {
    for (final value in ['', 'alex', 'a@b', 'a b@c.com', 'a@@b.com']) {
      expect(RegistrationValidation.email(value), isNotNull);
    }
    expect(RegistrationValidation.email(' Alex+learn@example.com '), isNull);
  });
  test('username boundaries and characters', () {
    for (final value in ['', 'ab', 'a b', 'a@b', 'a' * 31]) {
      expect(RegistrationValidation.username(value), isNotNull);
    }
    for (final value in [' abc ', 'Alex_2.0', 'a' * 30]) {
      expect(RegistrationValidation.username(value), isNull);
    }
  });
  test('password and confirmation rules', () {
    for (final value in [
      '',
      'short1!',
      'password!',
      'password1',
      'password1 ',
    ]) {
      expect(RegistrationValidation.password(value), isNotNull);
    }
    expect(RegistrationValidation.password('Password1!'), isNull);
    expect(RegistrationValidation.passwordRules('Password1!'), [
      true,
      true,
      true,
    ]);
    expect(RegistrationValidation.confirmation('', ''), isNotNull);
    expect(
      RegistrationValidation.confirmation('Password1!', 'password1!'),
      isNotNull,
    );
    expect(
      RegistrationValidation.confirmation('Password1!', 'Password1!'),
      isNull,
    );
  });
}
