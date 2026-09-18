import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

void main() {
  test('calculates five daily prayers per elapsed day', () {
    final result = calculateQaza(
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2020, 1, 11),
    );

    expect(result.totalDays, 10);
    expect(result.totalPrayers, 50);
    expect(result.dailyPrayerCount, 5);
    for (final prayer in [
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ]) {
      expect(result.prayerBreakdown[prayer], 10);
    }
    expect(result.includeWitr, isFalse);
    expect(result.witrCount, 0);
  });

  test('keeps Witr separate when included', () {
    final result = calculateQaza(
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2020, 1, 11),
      includeWitr: true,
    );

    expect(result.totalPrayers, 50);
    expect(result.witrCount, 10);
    expect(result.totalWithWitr, 60);
    expect(result.prayerBreakdown.containsKey(PrayerType.witr), isFalse);
  });

  test('decomposes a multi-year period into calendar years and remaining days',
      () {
    final result = calculateQaza(
      startDate: DateTime(2020, 1, 1),
      endDate: DateTime(2022, 1, 2),
    );

    expect(result.calendarYears, 2);
    expect(result.remainingDays, 1);
    expect(result.totalDays, 732);
  });
}
