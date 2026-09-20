import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/domain/prayer_schedule.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

PrayerDay _day(DateTime date) => PrayerDay(
      date: date,
      timezone: 'Asia/Karachi',
      times: const {
        PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
        PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
        PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
        PrayerName.asr: PrayerTime(hour: 16, minute: 45),
        PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
        PrayerName.isha: PrayerTime(hour: 19, minute: 44),
      },
      hijriDate: HijriDate(
        day: 18,
        month: 'Rabi al-Thani',
        year: 1448,
      ),
      fetchedAt: DateTime.utc(2026, 9, 20),
    );

void main() {
  final today = _day(DateTime(2026, 9, 20));
  final tomorrow = _day(DateTime(2026, 9, 21));

  test('finds current and next prayer during daytime', () {
    final result = PrayerSchedule.evaluate(
      today: today,
      nowOverride: DateTime.utc(2026, 9, 20, 6),
    );

    expect(result.current, PrayerName.fajr);
    expect(result.next, PrayerName.dhuhr);
    expect(result.nextIsTomorrow, isFalse);
  });

  test('uses Isha as the active night prayer before Fajr', () {
    final result = PrayerSchedule.evaluate(
      today: today,
      nowOverride: DateTime.utc(2026, 9, 19, 23),
    );

    expect(result.current, PrayerName.isha);
    expect(result.next, PrayerName.fajr);
    expect(result.nextIsTomorrow, isFalse);
  });

  test('uses tomorrow Fajr after Isha', () {
    final result = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 15),
    );

    expect(result.current, PrayerName.isha);
    expect(result.next, PrayerName.fajr);
    expect(result.nextIsTomorrow, isTrue);

    final duration = PrayerSchedule.timeUntilNext(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 15),
    );

    expect(duration, isNotNull);
    expect(duration!.inMinutes, 440);
    expect(duration.isNegative, isFalse);
  });
}
