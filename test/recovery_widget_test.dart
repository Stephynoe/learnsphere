import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/main.dart';
import 'package:learnsphere/auth/recovery_repository.dart';
import 'package:learnsphere/auth/recovery_screen.dart';
import 'package:learnsphere/auth/sign_in_repository.dart';

import 'recovery_repository_test.dart' show RecoveryFixture;
import 'recovery_controller_test.dart' show PendingRecovery;
import 'sign_in_controller_test.dart' show MemoryPreferences;
import 'widget_test.dart' show reveal;

Future<void> input(WidgetTester tester, String id, String value) async {
  final finder = find.byKey(ValueKey(id));
  await reveal(tester, finder);
  await tester.enterText(finder, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> proceed(WidgetTester tester) async {
  await reveal(tester, find.byKey(const ValueKey('recovery_submit')));
  await tester.tap(find.byKey(const ValueKey('recovery_submit')));
  await tester.pumpAndSettle();
}

Future<void> openRecovery(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Forgot Password?'));
  await tester.tap(find.text('Forgot Password?'));
  await tester.pumpAndSettle();
}

void main() {
  late RecoveryFixture fixture;
  setUp(() => fixture = RecoveryFixture());
  tearDown(() => fixture.client.close());
  Future<void> app(WidgetTester tester) => tester.pumpWidget(
    MyApp(
      preferences: MemoryPreferences(),
      recoveryRepository: fixture.repository,
      signInRepository: JsonBinSignInRepository(fixture.store),
    ),
  );

  testWidgets(
    'full recovery returns to sign-in, clears secrets, new password authenticates',
    (tester) async {
      final prefs = MemoryPreferences();
      await tester.pumpWidget(
        MyApp(
          preferences: prefs,
          recoveryRepository: fixture.repository,
          signInRepository: JsonBinSignInRepository(fixture.store),
        ),
      );
      await tester.pumpAndSettle();
      await input(tester, 'signin_identity', 'Alex');
      await input(tester, 'signin_password', 'wrong');
      await reveal(tester, find.byKey(const ValueKey('remember')));
      await tester.tap(find.byKey(const ValueKey('remember')));
      await openRecovery(tester);
      await input(tester, 'recovery_identity', ' ALEX@example.com ');
      await proceed(tester);
      expect(find.text('Favorite place?'), findsOneWidget);
      await input(tester, 'recovery_answer', 'wrong');
      await proceed(tester);
      expect(
        find.text('That answer is incorrect. Please try again.'),
        findsOneWidget,
      );
      await input(tester, 'recovery_answer', ' NEW LAGOS! ');
      final answerController = tester
          .widget<TextFormField>(find.byKey(const ValueKey('recovery_answer')))
          .controller!;
      await proceed(tester);
      expect(answerController.text, isEmpty);
      await input(tester, 'recovery_password', 'short');
      await input(tester, 'recovery_confirmation', 'different');
      await proceed(tester);
      expect(fixture.writes, 0);
      expect(
        find.text('Use 8+ characters, a number and a symbol.'),
        findsOneWidget,
      );
      await input(tester, 'recovery_password', 'Newpass1!');
      await input(tester, 'recovery_confirmation', 'Newpass1!');
      final passwordController = tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('recovery_password')),
          )
          .controller!;
      await reveal(tester, find.byTooltip('Show New password'));
      await tester.tap(find.byTooltip('Show New password'));
      await tester.pumpAndSettle();
      await proceed(tester);
      expect(find.text('Password updated!'), findsOneWidget);
      expect(passwordController.text, isEmpty);
      expect(fixture.writes, 1);
      expect(prefs.saved, isNull);
      await tester.tap(find.text('Back to Sign In'));
      await tester.pumpAndSettle();
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
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signin_identity')),
            )
            .controller!
            .text,
        'Alex',
      );
      expect(
        tester.widget<Checkbox>(find.byKey(const ValueKey('remember'))).value,
        isTrue,
      );
      await input(tester, 'signin_password', 'Newpass1!');
      await reveal(tester, find.byKey(const ValueKey('signin_submit')));
      await tester.tap(find.byKey(const ValueKey('signin_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Alex'), findsOneWidget);
    },
  );

  testWidgets(
    'compact layout validates identity, unknown account, restart and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await app(tester);
      await openRecovery(tester);
      await proceed(tester);
      expect(find.text('This field is required.'), findsOneWidget);
      await input(tester, 'recovery_identity', 'missing');
      await proceed(tester);
      expect(
        find.text('No account found with that email or username.'),
        findsOneWidget,
      );
      await input(tester, 'recovery_identity', 'alex');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Favorite place?'), findsOneWidget);
      await input(tester, 'recovery_answer', 'new lagos!');
      await proceed(tester);
      await input(tester, 'recovery_password', 'Newpass1!');
      final passwordController = tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('recovery_password')),
          )
          .controller!;
      await reveal(tester, find.text('Use a different account'));
      await tester.tap(find.text('Use a different account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recovery_identity')), findsOneWidget);
      expect(passwordController.text, isEmpty);
      expect(fixture.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy lookup disables submit, navigation and repeat actions', (
    tester,
  ) async {
    final repository = PendingRecovery();
    await tester.pumpWidget(
      MaterialApp(home: RecoveryScreen(repository: repository)),
    );
    await input(tester, 'recovery_identity', 'alex');
    await reveal(tester, find.byKey(const ValueKey('recovery_submit')));
    await tester.tap(find.byKey(const ValueKey('recovery_submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('recovery_submit')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Back to Sign In',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(repository.lookups, 1);
    repository.pending.complete(
      const RecoveryAccount(id: 1, identity: 'alex', question: 'Question?'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Question?'), findsOneWidget);
  });

  testWidgets('changed recovery details restart the flow without saving', (
    tester,
  ) async {
    await app(tester);
    await openRecovery(tester);
    await input(tester, 'recovery_identity', 'alex');
    await proceed(tester);
    await input(tester, 'recovery_answer', 'new lagos!');
    await proceed(tester);
    fixture.user['reset_password_question'] = 'Changed?';
    await input(tester, 'recovery_password', 'Newpass1!');
    await input(tester, 'recovery_confirmation', 'Newpass1!');
    await proceed(tester);
    expect(find.byKey(const ValueKey('recovery_identity')), findsOneWidget);
    expect(find.text(JsonBinRecoveryRepository.changed), findsOneWidget);
    expect(fixture.writes, 0);
  });
}
