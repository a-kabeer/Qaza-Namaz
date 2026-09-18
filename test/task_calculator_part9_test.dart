import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/calculator_validation.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

void main() {
  final today = DateTime(2026, 9, 16);

  test('rejects a future DOB', () {
    final result = validateCalculatorDates(
      today: today,
      dob: DateTime(2026, 9, 17),
      balighDate: DateTime(2026, 9, 17),
      prayerStartDate: DateTime(2026, 9, 17),
    );
    expect(result.isValid, isFalse);
    expect(result.error, 'Date of birth cannot be in the future.');
  });

  test('rejects Baligh before DOB', () {
    final result = validateCalculatorDates(
      today: today,
      dob: DateTime(2000, 5, 10),
      balighDate: DateTime(2000, 5, 9),
      prayerStartDate: DateTime(2020, 5, 10),
    );
    expect(result.error, 'Baligh date cannot be before your date of birth.');
  });

  test('rejects future Baligh date', () {
    final result = validateCalculatorDates(
      today: today,
      dob: DateTime(2000, 5, 10),
      balighDate: DateTime(2027, 5, 10),
      prayerStartDate: DateTime(2027, 5, 10),
    );
    expect(result.error, 'Baligh date cannot be in the future.');
  });

  test('rejects prayer start before Baligh', () {
    final result = validateCalculatorDates(
      today: today,
      dob: DateTime(2000, 5, 10),
      balighDate: DateTime(2012, 5, 10),
      prayerStartDate: DateTime(2011, 5, 10),
    );
    expect(result.error, 'Prayer start cannot be before the Baligh date.');
  });

  test('rejects future prayer start', () {
    final result = validateCalculatorDates(
      today: today,
      dob: DateTime(2000, 5, 10),
      balighDate: DateTime(2012, 5, 10),
      prayerStartDate: DateTime(2027, 5, 10),
    );
    expect(result.error, 'Prayer start cannot be in the future.');
  });

  test('allows a zero-day period and keeps all totals zero', () {
    final date = DateTime(2026, 1, 1);
    final result =
        calculateQaza(startDate: date, endDate: date, includeWitr: true);

    expect(result.totalDays, 0);
    expect(result.totalPrayers, 0);
    expect(result.witrCount, 0);
    expect(result.totalWithWitr, 0);
    expect(result.prayerBreakdown.values.every((value) => value == 0), isTrue);
  });

  test('normalizes time components before validation', () {
    final result = validateCalculatorDates(
      today: DateTime(2026, 9, 16, 23, 59),
      dob: DateTime(2000, 1, 1, 18),
      balighDate: DateTime(2012, 1, 1, 1),
      prayerStartDate: DateTime(2020, 1, 1, 23),
    );
    expect(result.isValid, isTrue);
  });

  test('rejects reversed calculation dates', () {
    expect(
      () => calculateQaza(
        startDate: DateTime(2020, 1, 2),
        endDate: DateTime(2020, 1, 1),
      ),
      throwsArgumentError,
    );
  });
}
