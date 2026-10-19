import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsphere/admin/admin_learners_controller.dart';
import 'package:learnsphere/admin/admin_learners_repository.dart';
import 'package:learnsphere/admin/admin_learners_screen.dart';
import 'package:learnsphere/profile/profile_repository.dart';

import 'admin_learners_test.dart' show MemoryLearners, actor, account;

MemoryLearners sample(int count) {
  final memory = MemoryLearners();
  memory.data = List.generate(count, (i) {
    final user = account(
      i + 2,
      name: 'Learner ${i.toString().padLeft(3, '0')}',
      active: i.isEven,
    );
    return LearnerDetails(
      LearnerSummary.fromUser(user),
      UserProfile.fromUser(user),
    );
  });
  return memory;
}

void main() {
  test('page sizes, bounds, final page and All', () async {
    final c = AdminLearnersController(sample(42), actor);
    addTearDown(c.dispose);
    await c.load();
    expect(c.pageSize, 10);
    expect(c.pageCount, 5);
    expect(c.pageLearners.length, 10);
    expect(c.rangeStart, 1);
    expect(c.rangeEnd, 10);
    c.goToPage(5);
    expect(c.pageLearners.length, 2);
    expect(c.rangeStart, 41);
    expect(c.rangeEnd, 42);
    c.goToPage(999);
    expect(c.page, 5);
    c.goToPage(-1);
    expect(c.page, 1);
    c.setPageSize(25);
    expect(c.pageCount, 2);
    c.goToPage(2);
    expect(c.pageLearners.length, 17);
    c.setPageSize(50);
    expect(c.page, 1);
    expect(c.pageLearners.length, 42);
    c.setPageSize(0);
    expect(c.pageCount, 1);
    expect(c.pageLearners.length, 42);
    expect(c.rangeEnd, 42);
  });
  test('search/filter reset page; updates and refresh clamp page; failure retains state', () async {
    final memory = sample(21);
    final c = AdminLearnersController(memory, actor);
    addTearDown(c.dispose);
    await c.load();
    c.goToPage(3);
    c.search('Learner');
    expect(c.page, 1);
    c.goToPage(3);
    c.select(LearnerFilter.active);
    expect(c.page, 1);
    expect(c.matchingCount, 11);
    c.goToPage(2);
    final last = c.pageLearners.single;
    c.update(
      LearnerSummary(
        id: last.id,
        name: last.name,
        email: last.email,
        username: last.username,
        organization: '',
        active: false,
      ),
    );
    expect(c.page, 1);
    expect(c.matchingCount, 10);
    c.select(LearnerFilter.all);
    c.goToPage(3);
    memory.fail = true;
    await c.load();
    expect(c.page, 3);
    expect(c.matchingCount, 21);
    memory.fail = false;
    memory.data = memory.data.take(4).toList();
    await c.load();
    expect(c.page, 1);
    expect(c.matchingCount, 4);
    c.search('no match');
    expect(c.pageCount, 0);
    expect(c.pageLearners, isEmpty);
    expect(c.rangeStart, 0);
    expect(c.rangeEnd, 0);
    c.setPageSize(0);
    expect(c.pageCount, 0);
  });
  testWidgets('page controls, sizes and edit return preserve pagination', (
    tester,
  ) async {
    final memory = sample(12);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminLearnersScreen(
          repository: memory,
          session: actor,
          onAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Learner 010'), findsNothing);
    final next = find.widgetWithText(OutlinedButton, 'Next');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–10 of 12'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Learner 010'), findsOneWidget);
    expect(find.text('Learner 000'), findsNothing);
    await tester.ensureVisible(find.text('Edit Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
    final selector = find.byKey(const ValueKey('learner_page_size'));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    for (final label in ['25', '50', 'All']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Learner 000'), findsOneWidget);
    expect(find.text('Learner 011'), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty controls fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: AdminLearnersScreen(
          repository: sample(0),
          session: actor,
          onAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Showing 0 of 0'), findsOneWidget);
    expect(find.text('Page 0 of 0'), findsOneWidget);
    for (final label in ['Previous', 'Next']) {
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
            .onPressed,
        isNull,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
