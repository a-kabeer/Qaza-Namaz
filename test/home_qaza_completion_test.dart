import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/home/home_qaza_completion.dart';
import 'package:qaza_namaz/features/prayer_times/domain/prayer_times_models.dart';

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

  test('maps Prayer Time Fajr to Qaza Fajr', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 0),
      ),
      PrayerType.fajr,
    );
  });

  test('maps Prayer Time Dhuhr to Qaza Zuhr', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 7, 30),
      ),
      PrayerType.zuhr,
    );
  });

  test('maps Prayer Time Asr to Qaza Asr', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 12),
      ),
      PrayerType.asr,
    );
  });

  test('maps Prayer Time Maghrib to Qaza Maghrib', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 14),
      ),
      PrayerType.maghrib,
    );
  });

  test('maps Prayer Time Isha to Qaza Isha', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 15),
      ),
      PrayerType.isha,
    );
  });

  test('night after Isha remains Isha until Fajr', () {
    expect(
      currentHomePrayerForSchedule(
        today: today,
        now: DateTime.utc(2026, 9, 20, 20),
      ),
      PrayerType.isha,
    );
  });
}
