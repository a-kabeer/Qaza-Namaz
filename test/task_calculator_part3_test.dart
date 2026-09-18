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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpCalculator(WidgetTester tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: TestApp(home: CalculatorScreen())));
    await settleCalculator(tester);
  }

  Future<void> selectDefaultDob(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await settleCalculator(tester, const Duration(milliseconds: 250));
    final ok = find.text('OK');
    expect(ok, findsOneWidget);
    await tester.tap(ok);
    await settleCalculator(tester);
  }

  testWidgets('About You shows DOB and default Baligh age', (tester) async {
    await pumpCalculator(tester);

    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Baligh information'), findsOneWidget);
    expect(find.text('Baligh age (years)'), findsOneWidget);
    expect(find.text('12 years'), findsOneWidget);
    expect(find.text('Current age'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('calculator_continue')))
            .onPressed,
        isNull);
  });

  testWidgets('Selecting DOB calculates age and estimated Baligh date',
      (tester) async {
    await pumpCalculator(tester);
    await selectDefaultDob(tester);

    expect(find.text('Current age'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('calculator_continue')))
            .onPressed,
        isNotNull);
  });

  testWidgets('Exact Baligh mode exposes exact-date selection', (tester) async {
    await pumpCalculator(tester);
    await selectDefaultDob(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('calculator_baligh_mode')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settleCalculator(tester);
    await tester.tap(find.text('Exact date'));
    await settleCalculator(tester);

    expect(
        find.byKey(const Key('calculator_baligh_date_picker')), findsOneWidget);
    expect(find.text('Select exact date'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsNothing);
  });

  testWidgets('Valid Step 1 continues and Back preserves entered information',
      (tester) async {
    await pumpCalculator(tester);

    await selectDefaultDob(tester);
    await tester.tap(find.byKey(const Key('calculator_continue')));
    await settleCalculator(tester);

    expect(find.text('Prayer History'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calculator_back')));
    await settleCalculator(tester);

    expect(find.text('About You'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsOneWidget);
  });
}
