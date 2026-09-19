import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

Future<void> settleCalculator(WidgetTester tester,
    [Duration duration = const Duration(milliseconds: 600)]) async {
  await tester.pump(duration);
  await tester.pump();
}

Future<void> _selectDefaultDob(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calculator_dob_picker')));
  await settleCalculator(tester, const Duration(milliseconds: 250));
  await tester.tap(find.text('OK'));
  await settleCalculator(tester);
}

Future<void> _calculateDefaultResult(WidgetTester tester) async {
  await _selectDefaultDob(tester);
  await tester.tap(find.byKey(const Key('calculator_continue')));
  await settleCalculator(tester);
  await tester.tap(find.byKey(const Key('calculator_calculate')));
  await settleCalculator(tester);
}

/// The step's own heading, told apart from the same name on the step
/// indicator above it.
Finder stepHeading(String text) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(text),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'calculator presents three steps and supports forward/back navigation',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: TestApp(home: CalculatorScreen())));
    await settleCalculator(tester);

    expect(stepHeading('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_continue')), findsOneWidget);

    await _selectDefaultDob(tester);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('calculator_continue')))
            .onPressed,
        isNotNull);
    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);

    expect(stepHeading('Prayer History'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
    expect(find.byKey(const Key('calculator_back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_calculate')));
    await settleCalculator(tester);

    expect(stepHeading('Result'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);
    expect(find.byKey(const Key('calculator_back')), findsOneWidget);

    // The Result step carries no edit buttons; the stepper is the way back.
    expect(find.byKey(const Key('calculator_edit_about')), findsNothing);
    expect(
        find.byKey(const Key('calculator_edit_prayer_history')), findsNothing);

    await tester.tap(find.byKey(const Key('calculator_step_tab_1')));
    await settleCalculator(tester);
    expect(stepHeading('Prayer History'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });

  testWidgets('the stepper returns to the relevant step and recalculates',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: TestApp(home: CalculatorScreen())));
    await settleCalculator(tester);

    await _calculateDefaultResult(tester);

    await tester.tap(find.byKey(const Key('calculator_step_tab_0')));
    await settleCalculator(tester);
    expect(stepHeading('About You'), findsOneWidget);
    expect(find.byKey(const Key('calculator_dob_picker')), findsOneWidget);
    expect(find.text('Current age'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsNothing);

    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);
    expect(stepHeading('Prayer History'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_calculate')));
    await settleCalculator(tester);
    expect(stepHeading('Result'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_step_tab_1')));
    await settleCalculator(tester);
    expect(stepHeading('Prayer History'), findsOneWidget);
    expect(
        find.byKey(const Key('calculator_prayer_start_age')), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });

  testWidgets('calculator progress remains theme-derived', (tester) async {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );

    await tester.pumpWidget(
      ProviderScope(
          child: TestApp(theme: theme, home: const CalculatorScreen())),
    );
    await settleCalculator(tester);

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circle.backgroundColor, theme.colorScheme.primary);
  });
}
