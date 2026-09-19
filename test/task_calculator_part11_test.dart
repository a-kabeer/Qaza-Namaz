import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

Future<void> settleCalculator(WidgetTester tester,
    [Duration duration = const Duration(milliseconds: 600)]) async {
  await tester.pump(duration);
  await tester.pump();
}

/// The step's own heading, told apart from the same name on the step
/// indicator above it.
Finder stepHeading(String text) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(text),
    );

void main() {
  testWidgets('calculator uses dark theme tokens', (tester) async {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
          child: TestApp(theme: theme, home: const CalculatorScreen())),
    );
    await settleCalculator(tester);

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circle.backgroundColor, theme.colorScheme.primary);
  });

  testWidgets('calculator renders within a narrow width', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TestApp(
          home: Center(
            child: SizedBox(width: 320, child: CalculatorScreen()),
          ),
        ),
      ),
    );
    await settleCalculator(tester);

    expect(stepHeading('About You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
