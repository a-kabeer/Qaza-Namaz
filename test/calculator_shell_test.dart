import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

void main() {
  testWidgets('calculator presents three steps and supports forward/back navigation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CalculatorScreen()),
    );

    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_continue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_continue')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
    expect(find.byKey(const Key('calculator_back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_calculate')));
    await tester.pumpAndSettle();

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calculator_back')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });

  testWidgets('calculator progress remains theme-derived', (tester) async {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const CalculatorScreen()),
    );

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circle.backgroundColor, theme.colorScheme.primary);
  });
}
