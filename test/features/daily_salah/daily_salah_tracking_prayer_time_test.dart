import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_settings.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  final today = DateTime(2026, 10, 16);
  final tomorrow = DateTime(2026, 10, 17);

  PrayerSchedule scheduleFor(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    final times = <PrayerSlot, DateTime>{
      PrayerSlot.fajr: utcDay,
      PrayerSlot.sunrise: utcDay.add(const Duration(hours: 1)),
      PrayerSlot.dhuhr: utcDay.add(const Duration(hours: 7)),
      PrayerSlot.asr: utcDay.add(const Duration(hours: 10)),
      PrayerSlot.maghrib: utcDay.add(const Duration(hours: 12)),
      PrayerSlot.isha: utcDay.add(const Duration(hours: 14)),
    };
    return PrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      timesUtc: times,
      astronomicalSunriseUtc: times[PrayerSlot.sunrise]!,
      astronomicalDhuhrUtc: times[PrayerSlot.dhuhr]!,
      astronomicalSunsetUtc: times[PrayerSlot.maghrib]!,
    );
  }

  late PrayerTimeSnapshot snapshot;

  setUp(() {
    snapshot = PrayerTimeSnapshot(
      location: const PrayerLocation(
        latitude: 24.86,
        longitude: 67.01,
        city: 'Karachi',
        region: 'Sindh',
        country: 'Pakistan',
        countryCode: 'PK',
        timezoneId: 'Asia/Karachi',
        source: PrayerLocationSource.city,
      ),
      settings: const PrayerSettings(),
      today: scheduleFor(today),
      tomorrow: scheduleFor(tomorrow),
      updatedAt: DateTime.utc(2026, 10, 16),
    );
  });

  test('tracking date stays on the previous day until local Fajr', () {
    expect(
      dailySalahTrackingDateForInstant(
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 15, 23, 59),
      ),
      DateTime(2026, 10, 15),
    );
    expect(
      dailySalahTrackingDateForInstant(
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 16),
      ),
      today,
    );
  });

  test('prayer actions unlock at their own prayer-time boundary', () {
    expect(
      dailySalahPrayerTimeHasPassed(
        date: today,
        trackingDate: today,
        prayerType: PrayerType.fajr,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 15, 23, 59),
      ),
      isFalse,
    );
    expect(
      dailySalahPrayerTimeHasPassed(
        date: today,
        trackingDate: today,
        prayerType: PrayerType.fajr,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 16),
      ),
      isTrue,
    );
    expect(
      dailySalahPrayerTimeHasPassed(
        date: today,
        trackingDate: today,
        prayerType: PrayerType.zuhr,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 16, 6, 59),
      ),
      isFalse,
    );
    expect(
      dailySalahPrayerTimeHasPassed(
        date: today,
        trackingDate: today,
        prayerType: PrayerType.zuhr,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 16, 7),
      ),
      isTrue,
    );
  });

  test('all prayers on historical tracking dates remain editable', () {
    expect(
      dailySalahPrayerTimeHasPassed(
        date: DateTime(2026, 10, 15),
        trackingDate: today,
        prayerType: PrayerType.isha,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 15, 23, 59),
      ),
      isTrue,
    );
  });

  test('future dates remain locked', () {
    expect(
      dailySalahPrayerTimeHasPassed(
        date: tomorrow,
        trackingDate: today,
        prayerType: PrayerType.fajr,
        snapshot: snapshot,
        now: DateTime.utc(2026, 10, 16, 0),
      ),
      isFalse,
    );
  });
}
