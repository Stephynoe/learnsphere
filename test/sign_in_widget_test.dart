import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/main.dart';
import 'package:learnsphere/auth/sign_in_preferences.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';

import 'sign_in_controller_test.dart'
    show MemoryPreferences, PendingSignIn, session;
import 'widget_test.dart' show FakeRepository, fill, reveal;

Future<void> enterCredentials(WidgetTester tester) async {
  await reveal(tester, find.byKey(const ValueKey('signin_identity')));
  await tester.enterText(
    find.byKey(const ValueKey('signin_identity')),
    ' Alex ',
  );
  await reveal(tester, find.byKey(const ValueKey('signin_password')));
  await tester.enterText(find.byKey(const ValueKey('signin_password')), 'Old1');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'initial screen restores preferences and validates empty fields',
    (tester) async {
      final prefs = MemoryPreferences()
        ..saved = const RememberedIdentity('alex', AccountRole.admin);
      final repo = PendingSignIn();
      await tester.pumpWidget(
        MyApp(preferences: prefs, signInRepository: repo),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to LearnSphere'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signin_identity')),
            )
            .controller!
            .text,
        'alex',
      );
      expect(find.text('Administrator Workspace'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byKey(const ValueKey('remember'))).value,
        isTrue,
      );
      await reveal(tester, find.byKey(const ValueKey('signin_submit')));
      await tester.tap(find.byKey(const ValueKey('signin_submit')));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      expect(repo.calls, 0);
      await reveal(tester, find.byKey(const ValueKey('remember')));
      await tester.tap(find.byKey(const ValueKey('remember')));
      await tester.pumpAndSettle();
      expect(prefs.saved, isNull);
    },
  );

  testWidgets(
    'sign-in keyboard submit, loading guard, welcome, sign-out, no back session',
    (tester) async {
      final repo = PendingSignIn();
      final prefs = MemoryPreferences();
      await tester.pumpWidget(
        MyApp(preferences: prefs, signInRepository: repo),
      );
      await tester.pumpAndSettle();
      await enterCredentials(tester);
      await reveal(tester, find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('signin_password')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repo.calls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('signin_submit')))
            .onPressed,
        isNull,
      );
      repo.pending.complete(session);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Alex'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.text('Welcome back, Alex'))).canPop(),
        isFalse,
      );
      await tester.tap(find.byTooltip('Account profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('signout')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to LearnSphere'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signin_password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        Navigator.of(tester.element(find.text('Welcome to LearnSphere')))
            .canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'authentication failure retains entered values and shows generic error',
    (tester) async {
      final repo = PendingSignIn();
      await tester.pumpWidget(
        MyApp(preferences: MemoryPreferences(), signInRepository: repo),
      );
      await tester.pumpAndSettle();
      await enterCredentials(tester);
      await reveal(tester, find.byKey(const ValueKey('signin_submit')));
      await tester.tap(find.byKey(const ValueKey('signin_submit')));
      await tester.pump();
      repo.pending.completeError(
        const SignInException(SignInException.invalid),
      );
      await tester.pumpAndSettle();
      expect(find.text(SignInException.invalid), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signin_password')),
            )
            .controller!
            .text,
        'Old1',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signin_identity')),
            )
            .controller!
            .text,
        ' Alex ',
      );
    },
  );

  testWidgets('registration links and success return to sign-in', (
    tester,
  ) async {
    final registration = FakeRepository();
    await tester.pumpWidget(
      MyApp(
        repository: registration,
        preferences: MemoryPreferences(),
        signInRepository: PendingSignIn(),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('create_account')));
    await tester.tap(find.byKey(const ValueKey('create_account')));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Already have an account? Sign In'));
    await tester.tap(find.text('Already have an account? Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to LearnSphere'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('create_account')));
    await tester.tap(find.byKey(const ValueKey('create_account')));
    await tester.pumpAndSettle();
    await fill(tester);
    await reveal(tester, find.byKey(const ValueKey('terms')));
    await tester.tap(find.byKey(const ValueKey('terms')));
    await reveal(tester, find.byKey(const ValueKey('submit')));
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pump();
    registration.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Account created!'), findsOneWidget);
    await tester.tap(find.text('Go to Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to LearnSphere'), findsOneWidget);
  });

  testWidgets('compact layout, role selection and coming-soon controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MyApp(
        preferences: MemoryPreferences(),
        signInRepository: PendingSignIn(),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Administrator'));
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();
    expect(find.text('Administrator Workspace'), findsOneWidget);
    await enterCredentials(tester);
    for (final pair in [
      ('Biometric', 'Biometric'),
      ('Google', 'Google'),
      ('Apple', 'Apple'),
      ('SSO', 'SSO'),
    ]) {
      await reveal(tester, find.text(pair.$1));
      await tester.tap(find.text(pair.$1));
      await tester.pumpAndSettle();
      expect(find.text('${pair.$2}: Coming soon'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.text(pair.$1)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
