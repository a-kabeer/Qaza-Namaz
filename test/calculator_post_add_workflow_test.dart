import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/calculator/calculator_controller.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// What happens to the calculator once `Add to Tracker` has succeeded.
///
/// The defect these cover: the added estimate used to be left sitting on
/// Step 3, and the same Step 3 came back on the next launch.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container(InMemoryQazaRepository repository) {
    final result = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
    ]);
    addTearDown(result.dispose);
    return result;
  }

  Future<CalculatorController> ready(ProviderContainer scope) async {
    scope.listen(calculatorControllerProvider, (_, __) {});
    final controller = scope.read(calculatorControllerProvider.notifier);
    await controller.restore();
    return controller;
  }

  /// Drives the calculator to a finished estimate on Step 3.
  Future<CalculatorController> withEstimate(ProviderContainer scope) async {
    final controller = await ready(scope);
    controller.setDob(DateTime(1990, 1, 1));
    controller.setBalighMode(BalighInputMode.exactDate);
    controller.setBalighDate(DateTime(2002, 1, 1));
    controller.setPrayerStartMode(PrayerStartInputMode.exactDate);
    controller.setPrayerStartDate(DateTime(2002, 1, 11));
    controller.calculate();
    expect(scope.read(calculatorControllerProvider).step, 2);
    return controller;
  }

  /// Lets the queued snapshot write reach SharedPreferences.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('after a successful add', () {
    test('the estimate is finished, not left waiting on Step 3', () async {
      final scope = container(InMemoryQazaRepository());
      final controller = await withEstimate(scope);

      expect(await controller.addToTracker(), isTrue);
      final state = scope.read(calculatorControllerProvider);

      expect(state.addCompleted, isTrue);
      expect(state.addedCount, greaterThan(0));
      // The result, the preflight and the estimate itself are all spent.
      expect(state.calculation, isNull);
      expect(state.preflight, isNull);
      expect(state.error, isNull);
    });

    test('the answers about the user are kept', () async {
      final scope = container(InMemoryQazaRepository());
      final controller = await withEstimate(scope);
      controller.setIncludeWitr(true);

      await controller.addToTracker();
      final state = scope.read(calculatorControllerProvider);

      expect(state.dob, DateTime(1990, 1, 1));
      expect(state.balighDate, DateTime(2002, 1, 1));
      expect(state.balighMode, BalighInputMode.exactDate);
      expect(state.prayerStartDate, DateTime(2002, 1, 11));
      expect(state.prayerStartMode, PrayerStartInputMode.exactDate);
      expect(state.includeWitr, isTrue);
    });

    test('Calculate Again starts a fresh calculation from Step 1', () async {
      final scope = container(InMemoryQazaRepository());
      final controller = await withEstimate(scope);
      await controller.addToTracker();

      controller.startNewCalculation();
      final state = scope.read(calculatorControllerProvider);

      expect(state.step, 0);
      expect(state.hasAddResult, isFalse);
      expect(state.addCompleted, isFalse);
      expect(state.calculation, isNull);
      expect(state.addProcessed, 0);
      expect(state.addTotal, 0);
      // Starting over does not mean filling the form in again.
      expect(state.dob, DateTime(1990, 1, 1));
      expect(state.balighDate, DateTime(2002, 1, 1));
      expect(state.prayerStartDate, DateTime(2002, 1, 11));

      // And the saved inputs still produce a result.
      controller.calculate();
      expect(scope.read(calculatorControllerProvider).calculation, isNotNull);
    });

    test('adding the same estimate again still adds nothing', () async {
      final repository = InMemoryQazaRepository();
      final scope = container(repository);
      final controller = await withEstimate(scope);
      await controller.addToTracker();
      final first = scope.read(calculatorControllerProvider).addedCount!;

      controller.startNewCalculation();
      controller.calculate();
      await controller.addToTracker();

      // Duplicate detection is untouched; the second run finds nothing new.
      expect(scope.read(calculatorControllerProvider).addedCount, 0);
      expect(await repository.getRecords(userId: 'u1'), hasLength(first));
    });
  });

  group('reopening the app', () {
    test('never comes back to an added calculation Step 3', () async {
      final repository = InMemoryQazaRepository();
      final first = container(repository);
      final controller = await withEstimate(first);
      await controller.addToTracker();
      await settle();

      // A new container over the same storage: a restart.
      final second = container(repository);
      await ready(second);
      final state = second.read(calculatorControllerProvider);

      expect(state.step, 0);
      expect(state.calculation, isNull);
      expect(state.hasAddResult, isFalse);
      // The inputs survive the restart, as they always have.
      expect(state.dob, DateTime(1990, 1, 1));
      expect(state.balighDate, DateTime(2002, 1, 1));
      expect(state.prayerStartDate, DateTime(2002, 1, 11));
    });

    test('still restores a calculation that was never added', () async {
      final repository = InMemoryQazaRepository();
      final first = container(repository);
      await withEstimate(first);
      await settle();

      final second = container(repository);
      await ready(second);
      final state = second.read(calculatorControllerProvider);

      expect(state.step, 2);
      expect(state.calculation, isNotNull);
      expect(state.hasAddResult, isFalse);
    });

    test('a half-filled form comes back to its own step', () async {
      final repository = InMemoryQazaRepository();
      final first = container(repository);
      final controller = await ready(first);
      controller.setDob(DateTime(1990, 1, 1));
      controller.setBalighMode(BalighInputMode.exactDate);
      controller.setBalighDate(DateTime(2002, 1, 1));
      controller.next();
      expect(first.read(calculatorControllerProvider).step, 1);
      await settle();

      final second = container(repository);
      await ready(second);

      expect(second.read(calculatorControllerProvider).step, 1);
      expect(second.read(calculatorControllerProvider).calculation, isNull);
    });
  });

  group('the success screen', () {
    /// Pumps a calculator already sitting on a completed add.
    Future<ProviderContainer> pumpAdded(WidgetTester tester) async {
      final scope = container(InMemoryQazaRepository());
      final controller = await withEstimate(scope);
      await controller.addToTracker();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: const TestApp(home: CalculatorScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      return scope;
    }

    testWidgets('shows the count and the two ways on', (tester) async {
      final scope = await pumpAdded(tester);
      final added = scope.read(calculatorControllerProvider).addedCount!;

      expect(find.byKey(const Key('calc_add_success')), findsOneWidget);
      expect(find.text('Estimate added'), findsOneWidget);
      expect(
          find.text('$added records added to your tracker.'), findsOneWidget);
      expect(find.byKey(const Key('calculator_done')), findsOneWidget);
      expect(
          find.byKey(const Key('calculator_calculate_again')), findsOneWidget);
      // No unfinished Step 3 underneath it.
      expect(find.byKey(const Key('calculator_add_to_tracker')), findsNothing);
    });

    testWidgets('Calculate Again returns to Step 1', (tester) async {
      final scope = await pumpAdded(tester);

      await tester.tap(find.byKey(const Key('calculator_calculate_again')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(scope.read(calculatorControllerProvider).step, 0);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('calculator_continue')), findsOneWidget);
      expect(find.byKey(const Key('calc_add_success')), findsNothing);
    });

    testWidgets('Done leaves the calculator and clears it', (tester) async {
      final scope = container(InMemoryQazaRepository());
      final controller = await withEstimate(scope);
      await controller.addToTracker();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: TestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                  ),
                  child: const Text('open calculator'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open calculator'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byKey(const Key('calculator_done')), findsOneWidget);

      await tester.tap(find.byKey(const Key('calculator_done')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Back where it came from, with nothing left over on the calculator.
      expect(find.text('open calculator'), findsOneWidget);
      final state = scope.read(calculatorControllerProvider);
      expect(state.step, 0);
      expect(state.hasAddResult, isFalse);
      expect(state.calculation, isNull);
    });
  });
}
