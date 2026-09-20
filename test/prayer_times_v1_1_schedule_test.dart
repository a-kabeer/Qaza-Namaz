import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/domain/prayer_schedule.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

PrayerDay _day(
  DateTime date, {
  String timezone = 'Asia/Karachi',
  PrayerTime fajr = const PrayerTime(hour: 4, minute: 50),
  PrayerTime sunrise = const PrayerTime(hour: 6, minute: 8),
  PrayerTime dhuhr = const PrayerTime(hour: 12, minute: 20),
  PrayerTime asr = const PrayerTime(hour: 16, minute: 45),
  PrayerTime maghrib = const PrayerTime(hour: 18, minute: 28),
  PrayerTime isha = const PrayerTime(hour: 19, minute: 44),
}) {
  return PrayerDay(
    date: date,
    timezone: timezone,
    times: {
      PrayerName.fajr: fajr,
      PrayerName.sunrise: sunrise,
      PrayerName.dhuhr: dhuhr,
      PrayerName.asr: asr,
      PrayerName.maghrib: maghrib,
      PrayerName.isha: isha,
    },
    hijriDate: const HijriDate(
      day: 18,
      month: 'Rabi al-Thani',
      year: 1448,
    ),
    fetchedAt: DateTime.utc(2026, 9, 20),
  );
}

void main() {
  test('converts an instant into the selected location local date', () {
    final localDate = PrayerSchedule.localDate(
      'America/Los_Angeles',
      instant: DateTime.utc(2026, 9, 21, 1),
    );

    expect(localDate, DateTime(2026, 9, 20));
  });

  test('uses full IANA timezone data for global locations', () {
    expect(PrayerSchedule.isKnownTimezone('Asia/Kuala_Lumpur'), isTrue);
    expect(PrayerSchedule.isKnownTimezone('Europe/Oslo'), isTrue);
    expect(PrayerSchedule.isKnownTimezone('America/Phoenix'), isTrue);
    expect(PrayerSchedule.isKnownTimezone('not/a_real_timezone'), isFalse);
  });

  test('handles the 2026 New York spring DST jump in countdown math', () {
    final day = _day(
      DateTime(2026, 3, 8),
      timezone: 'America/New_York',
      fajr: const PrayerTime(hour: 0, minute: 30),
      sunrise: const PrayerTime(hour: 3, minute: 30),
      dhuhr: const PrayerTime(hour: 12, minute: 0),
    );

    final duration = PrayerSchedule.timeUntilNext(
      today: day,
      nowOverride: DateTime.utc(2026, 3, 8, 6, 30),
    );

    expect(duration, const Duration(hours: 1));
  });

  test('keeps local date correct at a London DST boundary', () {
    final before = PrayerSchedule.localDate(
      'Europe/London',
      instant: DateTime.utc(2026, 3, 29, 0, 30),
    );
    final after = PrayerSchedule.localDate(
      'Europe/London',
      instant: DateTime.utc(2026, 3, 30, 0, 30),
    );

    expect(before, DateTime(2026, 3, 29));
    expect(after, DateTime(2026, 3, 30));
  });
}
