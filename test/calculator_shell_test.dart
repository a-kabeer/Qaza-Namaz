import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

Future<void> settleCalculator(WidgetTester tester, [Duration duration = const Duration(milliseconds: 600)]) async {
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('calculator presents three steps and supports forward/back navigation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await settleCalculator(tester);

    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_continue')), findsOneWidget);

    await _selectDefaultDob(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('calculator_continue'))).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);

    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
    expect(find.byKey(const Key('calculator_back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_calculate')));
    await settleCalculator(tester);

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);

    expect(find.byKey(const Key('calculator_edit_about')), findsOneWidget);
    expect(find.byKey(const Key('calculator_edit_prayer_history')), findsOneWidget);

    expect(find.byKey(const Key('calculator_back')), findsNothing);
    await tester.tap(find.byKey(const Key('calculator_edit_prayer_history')));
    await settleCalculator(tester);
    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });

  testWidgets('calculator edit actions return to the relevant step and recalculate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await settleCalculator(tester);

    await _calculateDefaultResult(tester);

    await tester.tap(find.byKey(const Key('calculator_edit_about')));
    await settleCalculator(tester);
    expect(find.text('About You'), findsOneWidget);
    expect(find.byKey(const Key('calculator_dob_picker')), findsOneWidget);
    expect(find.text('Current age'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsNothing);

    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);
    expect(find.text('Prayer History'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_calculate')));
    await settleCalculator(tester);
    expect(find.text('Result'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_edit_prayer_history')));
    await settleCalculator(tester);
    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.byKey(const Key('calculator_prayer_start_age')), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });

  testWidgets('calculator progress remains theme-derived', (tester) async {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const CalculatorScreen()),
    );
    await settleCalculator(tester);

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circle.backgroundColor, theme.colorScheme.primary);
  });
}
