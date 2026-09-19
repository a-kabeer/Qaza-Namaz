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

/// The step's own heading, told apart from the same name on the step
/// indicator above it.
Finder stepHeading(String text) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(text),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Prayer History step exposes start-date controls and period summary',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: TestApp(home: CalculatorScreen())));
    await settleCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await settleCalculator(tester, const Duration(milliseconds: 250));
    final ok = find.text('OK');
    expect(ok, findsOneWidget);
    await tester.tap(ok);
    await settleCalculator(tester);

    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('calculator_continue')))
            .onPressed,
        isNotNull);
    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);

    expect(stepHeading('Prayer History'), findsOneWidget);
    expect(find.text('Regular prayer start'), findsOneWidget);
    expect(find.textContaining('Estimated prayer-start date:'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('calculator_qaza_period_summary')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settleCalculator(tester);
    expect(find.text('Qaza period'), findsOneWidget);
    expect(find.byKey(const Key('calculator_calculate')), findsOneWidget);
  });
}
