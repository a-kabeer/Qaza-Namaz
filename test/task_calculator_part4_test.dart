import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

Future<void> settleCalculator(WidgetTester tester, [Duration duration = const Duration(milliseconds: 600)]) async {
  await tester.pump(duration);
  await tester.pump();
}

void main() {
  testWidgets('Prayer History step exposes start-date controls and period summary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await settleCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await settleCalculator(tester, const Duration(milliseconds: 250));
    final ok = find.text('OK');
    if (ok.evaluate().isNotEmpty) await tester.tap(ok);
    await settleCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);

    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.text('Regular prayer start'), findsOneWidget);
    expect(find.textContaining('Estimated prayer-start date:'), findsOneWidget);
    expect(find.text('Qaza period'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });
}
