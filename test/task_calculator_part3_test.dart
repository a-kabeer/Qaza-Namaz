import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

void main() {
  Future<void> pumpCalculator(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CalculatorScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseDay(WidgetTester tester, String day) async {
    final matches = find.text(day);
    expect(matches, findsWidgets);
    await tester.tap(matches.last);
    await tester.pumpAndSettle();
    final ok = find.text('OK');
    if (ok.evaluate().isNotEmpty) {
      await tester.tap(ok);
      await tester.pumpAndSettle();
    }
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
      tester.widget<FilledButton>(find.byKey(const Key('calculator_continue'))).onPressed,
      isNull,
    );
  });

  testWidgets('Selecting DOB calculates age and estimated Baligh date', (tester) async {
    await pumpCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await tester.pumpAndSettle();
    await chooseDay(tester, '15');

    expect(find.text('Current age'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('calculator_continue'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('Exact Baligh mode exposes exact-date selection', (tester) async {
    await pumpCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await tester.pumpAndSettle();
    await chooseDay(tester, '15');

    await tester.tap(find.text('Exact date'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calculator_baligh_date_picker')), findsOneWidget);
    expect(find.text('Select exact date'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsNothing);
  });

  testWidgets('Valid Step 1 continues and Back preserves entered information', (tester) async {
    await pumpCalculator(tester);

    await tester.tap(find.byKey(const Key('calculator_dob_picker')));
    await tester.pumpAndSettle();
    await chooseDay(tester, '15');
    await tester.tap(find.byKey(const Key('calculator_continue')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer History'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calculator_back')));
    await tester.pumpAndSettle();

    expect(find.text('About You'), findsOneWidget);
    expect(find.textContaining('Estimated Baligh date:'), findsOneWidget);
  });
}
