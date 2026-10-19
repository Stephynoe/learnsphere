import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/main.dart';
import 'package:learnsphere/registration/registration_data.dart';
import 'package:learnsphere/registration/registration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRepository implements RegistrationRepository {
  int calls = 0;
  final pending = Completer<void>();
  RegistrationData? submitted;
  @override
  Future<void> register(RegistrationData data) {
    calls++;
    submitted = data;
    return pending.future;
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> openRegistration(
  WidgetTester tester,
  RegistrationRepository repository,
) async {
  await tester.pumpWidget(MyApp(repository: repository));
  await tester.pumpAndSettle();
  await reveal(tester, find.byKey(const ValueKey('create_account')));
  await tester.tap(find.byKey(const ValueKey('create_account')));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  final values = {
    'full_name': ' Alex Morgan ',
    'email': ' Alex@Example.com ',
    'username': ' Alex.Morgan ',
    'password': 'Password1!',
    'confirm': 'Password1!',
    'question': ' Favorite place? ',
    'answer': ' Lagos ',
  };
  for (final entry in values.entries) {
    final field = find.byKey(ValueKey(entry.key));
    await reveal(tester, field);
    await tester.enterText(field, entry.value);
  }
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('invalid fields and missing terms prevent registration', (
    tester,
  ) async {
    final repo = FakeRepository();
    await openRegistration(tester, repo);
    await reveal(tester, find.byKey(const ValueKey('submit')));
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Accept the terms to create your account.'),
      findsOneWidget,
    );
    expect(repo.calls, 0);
    expect(find.text('Email is required.'), findsOneWidget);
    await fill(tester);
    await reveal(tester, find.byKey(const ValueKey('submit')));
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
  });
  testWidgets('valid submission stays busy, prevents repeat, then succeeds', (
    tester,
  ) async {
    final repo = FakeRepository();
    await openRegistration(tester, repo);
    await fill(tester);
    await reveal(tester, find.byKey(const ValueKey('terms')));
    await tester.tap(find.byKey(const ValueKey('terms')));
    await reveal(tester, find.byKey(const ValueKey('submit')));
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pump();
    expect(repo.calls, 1);
    expect(repo.submitted!.email, 'alex@example.com');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit')))
          .onPressed,
      isNull,
    );
    expect(find.text('Account created!'), findsNothing);
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Account created!'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('duplicate field errors retain form and clear when edited', (
    tester,
  ) async {
    final repo = FakeRepository();
    await openRegistration(tester, repo);
    await fill(tester);
    await reveal(tester, find.byKey(const ValueKey('terms')));
    await tester.tap(find.byKey(const ValueKey('terms')));
    await reveal(tester, find.byKey(const ValueKey('submit')));
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pump();
    repo.pending.completeError(
      const RegistrationException(
        'Update email.',
        fields: {'email': 'Already registered'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account created!'), findsNothing);
    expect(find.text('Already registered'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('email')));
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'another@example.com',
    );
    await tester.pumpAndSettle();
    expect(find.text('Already registered'), findsNothing);
  });
  testWidgets('compact layout, keyboard, social dummy and policy dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openRegistration(tester, FakeRepository());
    await fill(tester);
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google: Coming soon'), findsOneWidget);
    await reveal(tester, find.text('Terms of Service'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service — placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
