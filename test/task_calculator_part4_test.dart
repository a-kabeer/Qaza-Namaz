import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

void main() {
  testWidgets('Prayer History step exposes start-date controls and period summary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await tester.pumpAndSettle();
    final ok = find.text('OK');
    if (ok.hasFound) await tester.tap(ok);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calculator_continue')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer History'), findsOneWidget);
    expect(find.text('Regular prayer start'), findsOneWidget);
    expect(find.textContaining('Estimated prayer-start date:'), findsOneWidget);
    expect(find.text('Qaza period'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });
}
