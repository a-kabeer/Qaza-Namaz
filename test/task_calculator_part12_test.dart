import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/features/calculator/calculator_screen.dart';
import 'package:qaza_namaz/features/calculator/calculator_validation.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';

Future<void> _selectDob(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calculator_dob_picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _reachResult(WidgetTester tester) async {
  await _selectDob(tester);
  await tester.tap(find.byKey(const Key('calculator_continue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calculator_calculate')));
  await tester.pumpAndSettle();
}

/// The step's own heading, told apart from the same name on the step
/// indicator above it.
Finder stepHeading(String text) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(text),
    );

void main() {
  group('calculator domain regression', () {
    test('five prayers are represented exactly once and Witr is separate', () {
      final result = calculateQaza(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 1, 11),
        includeWitr: true,
      );

      expect(result.dailyPrayerCount, 5);
      expect(result.prayerBreakdown.keys.length, 5);
      expect(
        result.prayerBreakdown.keys,
        containsAll(<PrayerType>[
          PrayerType.fajr,
          PrayerType.zuhr,
          PrayerType.asr,
          PrayerType.maghrib,
          PrayerType.isha,
        ]),
      );
      expect(result.prayerBreakdown.keys, isNot(contains(PrayerType.witr)));
      expect(result.totalPrayers, 50);
      expect(result.witrCount, 10);
      expect(result.totalWithWitr, 60);
    });

    test('calculator period spans leap-day boundaries exactly', () {
      final result = calculateQaza(
        startDate: DateTime(2024, 2, 27),
        endDate: DateTime(2024, 3, 2),
      );

      expect(result.totalDays, 4);
      expect(result.totalPrayers, 20);
    });

    test('validation accepts same-day boundaries and rejects invalid ordering',
        () {
      final valid = validateCalculatorDates(
        today: DateTime(2026, 9, 16),
        dob: DateTime(2010, 9, 16),
        balighDate: DateTime(2022, 9, 16),
        prayerStartDate: DateTime(2022, 9, 16),
      );
      expect(valid.isValid, isTrue);

      final invalid = validateCalculatorDates(
        today: DateTime(2026, 9, 16),
        dob: DateTime(2010, 9, 16),
        balighDate: DateTime(2022, 9, 17),
        prayerStartDate: DateTime(2022, 9, 16),
      );
      expect(invalid.isValid, isFalse);
      expect(invalid.error, 'Prayer start cannot be before the Baligh date.');
    });
  });

  testWidgets(
    'calculator remains a single three-step surface after full-flow regression',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: TestApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      expect(stepHeading('About You'), findsOneWidget);
      await _reachResult(tester);
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(stepHeading('Result'), findsOneWidget);
      expect(find.byKey(const Key('calculator_step_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('calculator_step_tab_1')), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );
}
