import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

/// The calculator's date-boundary contract is **start inclusive, end
/// exclusive**. These tests pin that rule so it cannot be inferred from, or
/// silently changed by, the implementation.
void main() {
  QazaCalculation between(DateTime start, DateTime end, {bool witr = false}) =>
      calculateQaza(startDate: start, endDate: end, includeWitr: witr);

  group('boundary rule', () {
    test('same day is a zero-day period', () {
      final result = between(DateTime(2024, 3, 12), DateTime(2024, 3, 12));
      expect(result.totalDays, 0);
      expect(result.totalPrayers, 0);
      expect(result.witrCount, 0);
    });

    test('one calendar day apart is exactly one day', () {
      final result = between(DateTime(2024, 3, 12), DateTime(2024, 3, 13));
      expect(result.totalDays, 1);
      expect(result.totalPrayers, 5);
    });

    test('the end date is excluded and the start date is included', () {
      final result = between(DateTime(2024, 3, 12), DateTime(2024, 3, 15));
      expect(result.totalDays, 3);
    });

    test('reversed dates are rejected rather than negated', () {
      expect(
        () => between(DateTime(2024, 3, 15), DateTime(2024, 3, 12)),
        throwsArgumentError,
      );
    });

    test('time of day never shifts the period', () {
      final result = calculateQaza(
        startDate: DateTime(2024, 3, 12, 23, 59),
        endDate: DateTime(2024, 3, 14, 0, 1),
        includeWitr: false,
      );
      expect(result.totalDays, 2);
    });
  });

  group('calendar boundaries', () {
    test('crosses a month boundary', () {
      final result = between(DateTime(2023, 1, 30), DateTime(2023, 2, 2));
      expect(result.totalDays, 3);
    });

    test('crosses a year boundary', () {
      final result = between(DateTime(2022, 12, 30), DateTime(2023, 1, 2));
      expect(result.totalDays, 3);
    });

    test('counts the leap day in a leap year', () {
      final result = between(DateTime(2024, 2, 28), DateTime(2024, 3, 1));
      expect(result.totalDays, 2);
    });

    test('a non-leap year has no 29 February', () {
      final result = between(DateTime(2023, 2, 28), DateTime(2023, 3, 1));
      expect(result.totalDays, 1);
    });

    test('a full leap year is 366 days', () {
      final result = between(DateTime(2024, 1, 1), DateTime(2025, 1, 1));
      expect(result.totalDays, 366);
      expect(result.calendarYears, 1);
      expect(result.remainingDays, 0);
    });

    test('a full common year is 365 days', () {
      final result = between(DateTime(2023, 1, 1), DateTime(2024, 1, 1));
      expect(result.totalDays, 365);
      expect(result.calendarYears, 1);
    });

    test('a 29 February start survives the transition to a common year', () {
      final result = between(DateTime(2024, 2, 29), DateTime(2025, 3, 1));
      expect(result.totalDays, 366);
      expect(result.calendarYears, 1);
    });
  });

  group('prayer expansion', () {
    test('estimated and exact inputs use the same rule', () {
      final dob = DateTime(2005, 3, 12);
      final estimated = between(
        DateTime(dob.year + 12, dob.month, dob.day),
        DateTime(dob.year + 18, dob.month, dob.day),
      );
      final exact = between(DateTime(2017, 3, 12), DateTime(2023, 3, 12));
      expect(estimated.totalDays, exact.totalDays);
      expect(estimated.totalPrayers, exact.totalPrayers);
    });

    test('Witr off keeps the five daily prayers and no Witr count', () {
      final result = between(DateTime(2024, 1, 1), DateTime(2024, 1, 11));
      expect(result.dailyPrayerCount, 5);
      expect(result.totalPrayers, 50);
      expect(result.witrCount, 0);
      expect(result.includeWitr, isFalse);
      expect(result.totalWithWitr, 50);
    });

    test('Witr on adds one independent prayer per day', () {
      final result =
          between(DateTime(2024, 1, 1), DateTime(2024, 1, 11), witr: true);
      expect(result.dailyPrayerCount, 5);
      expect(result.totalPrayers, 50);
      expect(result.witrCount, 10);
      expect(result.includeWitr, isTrue);
      expect(result.totalWithWitr, 60);
    });

    test('calculated day count remains exact across larger periods', () {
      for (final days in [0, 1, 31, 366, 1000]) {
        final result = between(
          DateTime(2020, 1, 1),
          DateTime(2020, 1, 1).add(Duration(days: days)),
        );
        expect(result.totalDays, days);
      }
    });
  });
}
