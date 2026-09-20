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
      hijriDate: HijriDate(day: 18, month: 'Rabi al-Thani', year: 1448),
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

  test('uses Fajr as next prayer before the first prayer of the day', () {
    final result = PrayerSchedule.evaluate(
      today: today,
      nowOverride: DateTime.utc(2026, 9, 19, 23),
    );

    expect(result.current, PrayerName.isha);
    expect(result.next, PrayerName.fajr);
    expect(result.nextIsTomorrow, isFalse);
  });

  test('uses tomorrow Fajr after Isha and calculates countdown', () {
    final result = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 17),
    );

    expect(result.current, PrayerName.maghrib);
    expect(result.next, PrayerName.isha);
    expect(result.nextIsTomorrow, isFalse);

    final afterIsha = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 15),
    );
    expect(afterIsha.current, PrayerName.asr);

    final late = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 15, 30),
    );
    expect(late.current, PrayerName.asr);

    final justAfterIsha = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 14, 45),
    );
    expect(justAfterIsha.current, PrayerName.asr);

    final postIsha = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 16),
    );
    expect(postIsha.current, PrayerName.asr);

    final afterLocalIsha = PrayerSchedule.evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: DateTime.utc(2026, 9, 20, 15),
    );
    expect(afterLocalIsha.next, PrayerName.maghrib);
  });

  test('prevents negative countdown values', () {
    final duration = PrayerSchedule.timeUntilNext(
      today: today,
      nowOverride: DateTime.utc(2026, 9, 20, 7),
    );

    expect(duration, isNotNull);
    expect(duration!.isNegative, isFalse);
  });
}
