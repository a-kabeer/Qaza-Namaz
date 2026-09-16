import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

void main() {
  test('age-based inputs are represented as estimates', () {
    final result = calculateQaza(
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2022, 1, 1),
    );

    expect(result.totalDays, 731);
    expect(result.totalPrayers, 3655);
    expect(result.includeWitr, isFalse);
  });

  test('exact-date calculation changes the period deterministically', () {
    final result = calculateQaza(
      startDate: DateTime(2020, 1, 2),
      endDate: DateTime(2020, 1, 10),
    );

    expect(result.totalDays, 8);
    expect(result.totalPrayers, 40);
    expect(result.prayerBreakdown.values.every((value) => value == 8), isTrue);
  });

  test('Witr remains separate from the five daily prayers', () {
    final withoutWitr = calculateQaza(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 11),
    );
    final withWitr = calculateQaza(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 11),
      includeWitr: true,
    );

    expect(withoutWitr.totalPrayers, 50);
    expect(withoutWitr.witrCount, 0);
    expect(withWitr.totalPrayers, 50);
    expect(withWitr.witrCount, 10);
    expect(withWitr.totalWithWitr, 60);
  });
}
