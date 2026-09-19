import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/calculator/calculator_controller.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';
import 'package:qaza_namaz/features/calculator/calculator_validation.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// The calculator's boundaries and the rules for moving between its steps.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final today = CalculatorState.today;

  group('Baligh boundaries', () {
    test('the exact-date window is the ninth to the eighteenth year', () {
      final dob = DateTime(2010, 6, 15);

      expect(CalculatorBounds.balighDateMin(dob), DateTime(2019, 1, 1));
      expect(CalculatorBounds.balighDateMax(dob), DateTime(2028, 12, 31));
    });

    test('the window is not cut short by today', () {
      // Someone who is still a child: their eighteenth year is ahead of them
      // and the window says so.
      final dob = DateTime(today.year - 10, 6, 15);
      final max = CalculatorBounds.balighDateMax(dob);

      expect(max.isAfter(today), isTrue);
      expect(
        validateBalighDate(dob: dob, balighDate: max),
        isNull,
        reason: 'a future date inside the window is allowed',
      );
    });

    test('dates on either edge are accepted', () {
      final dob = DateTime(2010, 6, 15);

      expect(validateBalighDate(dob: dob, balighDate: DateTime(2019, 1, 1)),
          isNull);
      expect(validateBalighDate(dob: dob, balighDate: DateTime(2028, 12, 31)),
          isNull);
    });

    test('a date outside the window is rejected with the range', () {
      final dob = DateTime(2010, 6, 15);

      expect(
        validateBalighDate(dob: dob, balighDate: DateTime(2018, 12, 31)),
        'Baligh date must be between 01/01/2019 and 31/12/2028.',
      );
      expect(
        validateBalighDate(dob: dob, balighDate: DateTime(2029, 1, 1)),
        'Baligh date must be between 01/01/2019 and 31/12/2028.',
      );
    });

    test('a date before birth is named for what it is', () {
      final dob = DateTime(2010, 6, 15);

      expect(
        validateBalighDate(dob: dob, balighDate: DateTime(2009, 1, 1)),
        'Baligh date cannot be before your date of birth.',
      );
    });

    test('the age range is nine to eighteen', () {
      expect(CalculatorBounds.minBalighAge, 9);
      expect(CalculatorBounds.maxBalighAge, 18);
      expect(validateBalighAge(9), isNull);
      expect(validateBalighAge(18), isNull);
      expect(validateBalighAge(8), isNotNull);
      expect(validateBalighAge(19), isNotNull);
      expect(CalculatorBounds.clampBalighAge(4), 9);
      expect(CalculatorBounds.clampBalighAge(40), 18);
    });
  });

  group('prayer-start boundaries', () {
    test('the date window runs from Baligh to today', () {
      final baligh = DateTime(2020, 3, 4);

      expect(CalculatorBounds.prayerStartDateMin(baligh), baligh);
      expect(CalculatorBounds.prayerStartDateMax(today), today);
    });

    test('a date before Baligh or after today is rejected', () {
      final dob = DateTime(2000, 1, 1);
      final baligh = DateTime(2012, 1, 1);

      expect(
        validatePrayerStart(
          dob: dob,
          effectiveBalighDate: baligh,
          prayerStartDate: DateTime(2011, 12, 31),
          today: today,
        ),
        'Prayer start cannot be before the Baligh date.',
      );
      expect(
        validatePrayerStart(
          dob: dob,
          effectiveBalighDate: baligh,
          prayerStartDate: today.add(const Duration(days: 1)),
          today: today,
        ),
        'Prayer start cannot be in the future.',
      );
      expect(
        validatePrayerStart(
          dob: dob,
          effectiveBalighDate: baligh,
          prayerStartDate: baligh,
          today: today,
        ),
        isNull,
      );
    });

    test('the age range runs from the Baligh age to the current age', () {
      final dob = DateTime(2000, 1, 1);

      expect(
        CalculatorBounds.prayerStartAgeMin(dob, DateTime(2009, 1, 1)),
        9,
        reason: 'when Baligh is 9 the minimum is 9',
      );
      expect(
        CalculatorBounds.prayerStartAgeMax(dob, DateTime(2026, 6, 1)),
        26,
      );
    });
  });

  group('the calculator state keeps its inputs inside the rules', () {
    ProviderContainer container() {
      final result = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
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

    test('a Baligh age outside the range is corrected', () async {
      final scope = container();
      final controller = await ready(scope);

      controller.setBalighAge(40);
      expect(scope.read(calculatorControllerProvider).balighAge, 18);

      controller.setBalighAge(2);
      expect(scope.read(calculatorControllerProvider).balighAge, 9);
    });

    test('changing the date of birth drops a now-invalid Baligh date',
        () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(2000, 5, 10));
      controller.setBalighMode(BalighInputMode.exactDate);
      controller.setBalighDate(DateTime(2012, 5, 10));
      expect(scope.read(calculatorControllerProvider).balighDate, isNotNull);

      // A birth thirty years later puts that Baligh date out of the window.
      controller.setDob(DateTime(2020, 5, 10));

      expect(scope.read(calculatorControllerProvider).balighDate, isNull);
      expect(scope.read(calculatorControllerProvider).step1Valid, isFalse);
    });

    test('changing Baligh drops a prayer start that now precedes it', () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(2000, 5, 10));
      controller.setPrayerStartMode(PrayerStartInputMode.exactDate);
      controller.setPrayerStartDate(DateTime(2013, 5, 10));
      expect(
          scope.read(calculatorControllerProvider).prayerStartDate, isNotNull);

      // Baligh moves past the stored prayer-start date.
      controller.setBalighAge(18);

      expect(scope.read(calculatorControllerProvider).prayerStartDate, isNull);
    });

    test('the prayer-start age is pulled inside its own range', () async {
      final scope = container();
      final controller = await ready(scope);

      // Fourteen years old: the default of eighteen cannot stand.
      controller.setDob(DateTime(today.year - 14, 1, 1));
      final state = scope.read(calculatorControllerProvider);

      expect(state.prayerStartAgeMax, 14);
      expect(state.prayerStartAgeMin, 12);
      expect(state.prayerStartAge, lessThanOrEqualTo(14));
      expect(state.prayerStartAge, greaterThanOrEqualTo(12));
    });

    test('a Baligh age of nine lowers the prayer-start floor to nine',
        () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(today.year - 20, 1, 1));

      controller.setBalighAge(9);

      expect(scope.read(calculatorControllerProvider).prayerStartAgeMin, 9);
      expect(scope.read(calculatorControllerProvider).prayerStartAgeMax, 20);
    });

    test('a child younger than their Baligh age has no age to pick', () async {
      final scope = container();
      final controller = await ready(scope);

      controller.setDob(DateTime(today.year - 10, 1, 1));
      controller.setBalighAge(14);

      expect(scope.read(calculatorControllerProvider).hasPrayerStartAgeRange,
          isFalse);
      expect(scope.read(calculatorControllerProvider).step2Valid, isFalse);
    });
  });

  group('step navigation', () {
    ProviderContainer container() {
      final result = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
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

    test('nothing but Step 1 is open to begin with', () async {
      final scope = container();
      final controller = await ready(scope);
      final state = scope.read(calculatorControllerProvider);

      expect(state.canOpenStep(0), isTrue);
      expect(state.canOpenStep(1), isFalse);
      expect(state.canOpenStep(2), isFalse);

      controller.goToStep(1);
      expect(scope.read(calculatorControllerProvider).step, 0);
      controller.goToStep(2);
      expect(scope.read(calculatorControllerProvider).step, 0);
    });

    test('Step 2 opens once Step 1 is valid, Step 3 only with a result',
        () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(today.year - 25, 1, 1));

      expect(scope.read(calculatorControllerProvider).canOpenStep(1), isTrue);
      expect(scope.read(calculatorControllerProvider).canOpenStep(2), isFalse);

      controller.goToStep(2);
      expect(scope.read(calculatorControllerProvider).step, 0,
          reason: 'a step ahead of the work cannot be opened');

      controller.goToStep(1);
      expect(scope.read(calculatorControllerProvider).step, 1);

      controller.calculate();
      expect(scope.read(calculatorControllerProvider).step, 2);
      expect(scope.read(calculatorControllerProvider).canOpenStep(2), isTrue);
    });

    test('a step already reached stays reachable', () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(today.year - 25, 1, 1));
      controller.goToStep(1);
      controller.calculate();

      // Looking back at an earlier step does not throw the result away.
      controller.goToStep(0);
      expect(scope.read(calculatorControllerProvider).step, 0);
      expect(scope.read(calculatorControllerProvider).calculation, isNotNull);
      expect(scope.read(calculatorControllerProvider).canOpenStep(2), isTrue);

      controller.goToStep(2);
      expect(scope.read(calculatorControllerProvider).step, 2);
    });

    test('editing an input closes Step 3 again', () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(today.year - 25, 1, 1));
      controller.goToStep(1);
      controller.calculate();
      controller.goToStep(0);

      controller.setBalighAge(15);

      expect(scope.read(calculatorControllerProvider).calculation, isNull);
      expect(scope.read(calculatorControllerProvider).canOpenStep(2), isFalse);
    });

    test('the step a user is on is always their own', () async {
      final scope = container();
      final controller = await ready(scope);
      controller.setDob(DateTime(today.year - 25, 1, 1));
      controller.goToStep(1);
      controller.calculate();
      await controller.addToTracker();

      // The added estimate leaves Step 3 as a success state with no
      // calculation behind it; it is still the step in hand.
      final state = scope.read(calculatorControllerProvider);
      expect(state.step, 2);
      expect(state.canOpenStep(2), isTrue);
      expect(state.canOpenStep(0), isTrue);
    });
  });

  group('the step indicator', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    }

    testWidgets('names every step and only opens the ones that are ready',
        (tester) async {
      await tester.pumpWidget(
          const ProviderScope(child: TestApp(home: CalculatorScreen())));
      await settle(tester);

      for (final name in ['About You', 'Prayer History', 'Result']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('calculator_step_tab_1')))
            .onTap,
        isNull,
        reason: 'Step 2 is not ready yet',
      );

      await tester.tap(find.byKey(const Key('calculator_dob_picker')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      await tester.tap(find.byKey(const Key('calculator_step_tab_1')));
      await settle(tester);
      expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);

      // Step 3 is still closed: there is no calculation yet.
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('calculator_step_tab_2')))
            .onTap,
        isNull,
      );

      await tester.tap(find.byKey(const Key('calculator_calculate')));
      await settle(tester);
      expect(
          find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);

      // And now every step is open, including the way back.
      await tester.tap(find.byKey(const Key('calculator_step_tab_0')));
      await settle(tester);
      expect(find.byKey(const Key('calculator_continue')), findsOneWidget);
      await tester.tap(find.byKey(const Key('calculator_step_tab_2')));
      await settle(tester);
      expect(
          find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);
    });

    testWidgets('the Result step no longer offers Keep as Estimate',
        (tester) async {
      await tester.pumpWidget(
          const ProviderScope(child: TestApp(home: CalculatorScreen())));
      await settle(tester);
      await tester.tap(find.byKey(const Key('calculator_dob_picker')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('calculator_continue')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('calculator_calculate')));
      await settle(tester);

      expect(find.byKey(const Key('calculator_keep_estimate')), findsNothing);
      expect(find.text('Keep as Estimate'), findsNothing);
      expect(find.text('Estimated calculation'), findsNothing);
      expect(find.text('Based on exact dates'), findsNothing);
      // What the result is for is still there.
      expect(
          find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);
      expect(find.text('Prayer breakdown'), findsOneWidget);
    });
  });
}
