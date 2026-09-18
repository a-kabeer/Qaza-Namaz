import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

QazaRecord _record(PrayerType prayer) => QazaRecord(
      id: '${prayer.name}_1',
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

void main() {
  Future<ProviderContainer> pumpQazaTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = InMemoryQazaRepository();
    await repository
        .addRecords([for (final p in PrayerType.values) _record(p)]);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith((ref) =>
          Stream.value(const AppUser(id: 'u1', email: 'u1@example.com'))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const TestApp(home: WorkspaceShell()),
    ));
    await tester.pumpAndSettle();

    container.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.qaza;
    await tester.pumpAndSettle();
    return container;
  }

  Finder fab() => find.byKey(const Key('add_actions_fab'));
  Finder addAction() => find.byKey(const Key('fab_action_add_qaza'));
  Finder calculateAction() =>
      find.byKey(const Key('fab_action_calculate_qaza'));

  double turns(WidgetTester tester) =>
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

  group('header', () {
    testWidgets('the Qaza header no longer offers Add', (tester) async {
      await pumpQazaTab(tester);

      expect(find.byKey(const Key('qaza_tracker_add')), findsNothing);
      // The title and the rest of the page are untouched.
      expect(find.text('Qaza'), findsWidgets);
      expect(
          find.byKey(const Key('qaza_tracker_status_filter')), findsOneWidget);
    });
  });

  group('the add menu', () {
    testWidgets('starts closed, showing a plus', (tester) async {
      await pumpQazaTab(tester);

      expect(fab(), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(turns(tester), 0);
      expect(addAction(), findsNothing);
      expect(calculateAction(), findsNothing);
    });

    testWidgets('opens into the two actions and turns the plus to a cross',
        (tester) async {
      await pumpQazaTab(tester);

      await tester.tap(fab());
      await tester.pumpAndSettle();

      expect(addAction(), findsOneWidget);
      expect(calculateAction(), findsOneWidget);
      expect(find.text('Add Qaza'), findsOneWidget);
      expect(find.text('Calculate Qaza'), findsOneWidget);
      // An eighth of a turn is the plus drawn as a cross.
      expect(turns(tester), 0.125);
    });

    testWidgets('the actions sit above the button', (tester) async {
      await pumpQazaTab(tester);
      await tester.tap(fab());
      await tester.pumpAndSettle();

      final fabRect = tester.getRect(fab());
      expect(tester.getRect(calculateAction()).bottom,
          lessThanOrEqualTo(fabRect.top));
      expect(tester.getRect(addAction()).bottom,
          lessThanOrEqualTo(tester.getRect(calculateAction()).top));
    });

    testWidgets('tapping again closes it and restores the plus',
        (tester) async {
      await pumpQazaTab(tester);

      await tester.tap(fab());
      await tester.pumpAndSettle();
      expect(addAction(), findsOneWidget);

      await tester.tap(fab());
      await tester.pumpAndSettle();

      expect(addAction(), findsNothing);
      expect(calculateAction(), findsNothing);
      expect(turns(tester), 0);
    });
  });

  group('the actions navigate', () {
    testWidgets('Add Qaza opens the existing Add Qaza screen', (tester) async {
      await pumpQazaTab(tester);
      await tester.tap(fab());
      await tester.pumpAndSettle();

      await tester.tap(addAction());
      await tester.pumpAndSettle();

      expect(find.byType(AddQazaScreen), findsOneWidget);
    });

    testWidgets('Calculate Qaza opens the existing calculator', (tester) async {
      await pumpQazaTab(tester);
      await tester.tap(fab());
      await tester.pumpAndSettle();

      await tester.tap(calculateAction());
      // Bounded pumps: the calculator keeps an indicator running, so
      // pumpAndSettle would never return.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CalculatorScreen), findsWidgets);
    });

    testWidgets('the menu is closed again on return', (tester) async {
      await pumpQazaTab(tester);
      await tester.tap(fab());
      await tester.pumpAndSettle();
      await tester.tap(addAction());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // AppScaffold draws its own back control, which pageBack cannot find.
      Navigator.of(tester.element(find.byType(AddQazaScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(addAction(), findsNothing);
      expect(turns(tester), 0);
    });
  });
}
