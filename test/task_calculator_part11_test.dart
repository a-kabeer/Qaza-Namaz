import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

Future<void> settleCalculator(WidgetTester tester, [Duration duration = const Duration(milliseconds: 600)]) async {
  await tester.pump(duration);
  await tester.pump();
}

void main() {
  testWidgets('calculator uses dark theme tokens', (tester) async {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const CalculatorScreen()),
    );
    await settleCalculator(tester);

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circle.backgroundColor, theme.colorScheme.primary);
  });

  testWidgets('calculator renders within a narrow width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 320, child: CalculatorScreen()),
        ),
      ),
    );
    await settleCalculator(tester);

    expect(find.text('About You').last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
