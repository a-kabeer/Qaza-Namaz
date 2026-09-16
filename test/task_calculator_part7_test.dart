import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/calculator/calculator_tracker.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

void main() {
  QazaCalculation calculation({bool includeWitr = false}) => calculateQaza(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 1, 4),
        includeWitr: includeWitr,
      );

  test('tracker expansion matches calculator day and prayer totals', () {
    final result = calculation();

    expect(trackerDates(result).length, result.totalDays);
    expect(trackerPrayerTypes(includeWitr: false), containsAll([
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ]));
    expect(trackerPrayerTypes(includeWitr: false), isNot(contains(PrayerType.witr)));
    expect(trackerRecordCount(result), result.totalPrayers);
  });

  test('Witr adds a separate tracker record per calculated day', () {
    final result = calculation(includeWitr: true);

    expect(trackerPrayerTypes(includeWitr: true).last, PrayerType.witr);
    expect(trackerRecordCount(result), result.totalWithWitr);
    expect(trackerDates(result).last, DateTime(2020, 1, 3));
  });
}
