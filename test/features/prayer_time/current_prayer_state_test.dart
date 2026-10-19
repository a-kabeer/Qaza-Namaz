import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/prayer_time/application/current_prayer_state.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_settings.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';

void main() {
  late tz.Location karachi;
  setUpAll(() {
    timezone_data.initializeTimeZones();
    karachi = tz.getLocation('Asia/Karachi');
  });

  PrayerSchedule makeSchedule(DateTime date) {
    DateTime utc(int hour, int minute) => tz.TZDateTime(
          karachi,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        ).toUtc();
    final fajr = utc(5, 0);
    final sunrise = utc(6, 20);
    final dhuhr = utc(12, 0);
    final asr = utc(16, 0);
    final maghrib = utc(18, 0);
    final isha = utc(19, 30);
    return PrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      timesUtc: {
        PrayerSlot.fajr: fajr,
        PrayerSlot.sunrise: sunrise,
        PrayerSlot.dhuhr: dhuhr,
        PrayerSlot.asr: asr,
        PrayerSlot.maghrib: maghrib,
        PrayerSlot.isha: isha,
      },
      astronomicalSunriseUtc: sunrise,
      astronomicalDhuhrUtc: dhuhr,
      astronomicalSunsetUtc: maghrib,
    );
  }

  PrayerTimeSnapshot makeSnapshot(DateTime today, DateTime tomorrow) =>
      PrayerTimeSnapshot(
        location: const PrayerLocation(
          latitude: 24.8607,
          longitude: 67.0011,
          city: 'Karachi',
          region: 'Sindh',
          country: 'Pakistan',
          countryCode: 'PK',
          timezoneId: 'Asia/Karachi',
          source: PrayerLocationSource.city,
        ),
        settings: const PrayerSettings(),
        today: makeSchedule(today),
        tomorrow: makeSchedule(tomorrow),
        updatedAt: DateTime.utc(2026, 10, 11),
        calculationMadhab: Madhab.hanafi,
      );

  DateTime local(int d, int h) =>
      tz.TZDateTime(karachi, 2026, 10, d, h).toUtc();

  test('sunrise countdown starts at Fajr and ends exactly at sunrise', () {
    final schedule = makeSchedule(DateTime(2026, 10, 11));
    final fajr = schedule.localFor(PrayerSlot.fajr, karachi);
    final sunrise = schedule.localAstronomicalSunrise(karachi);

    bool targetsSunrise(DateTime now) => shouldUseSunriseCountdownTarget(
          schedule: schedule,
          location: karachi,
          now: now,
        );

    expect(
      targetsSunrise(fajr.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(targetsSunrise(fajr), isTrue);
    expect(
      targetsSunrise(sunrise.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(targetsSunrise(sunrise), isFalse);
    expect(
      targetsSunrise(sunrise.add(const Duration(minutes: 15))),
      isFalse,
    );
  });

  test('Isha points to Fajr on the following day', () {
    final state = resolveCurrentPrayerState(
      snapshot: makeSnapshot(DateTime(2026, 10, 11), DateTime(2026, 10, 12)),
      now: local(11, 21),
    );
    expect(state?.current, PrayerSlot.isha);
    expect(state?.next, PrayerSlot.fajr);
    expect(state?.nextAt, tz.TZDateTime(karachi, 2026, 10, 12, 5));
  });

  test('rollover never reuses the old schedule Fajr', () {
    final snapshot = makeSnapshot(
      DateTime(2026, 10, 10),
      DateTime(2026, 10, 11),
    );
    final state = resolveCurrentPrayerState(
      snapshot: snapshot,
      now: local(11, 21),
    );
    expect(state?.current, PrayerSlot.isha);
    expect(state?.next, PrayerSlot.fajr);
    expect(state?.nextAt, isNull);
    expect(
      prayerTimeSnapshotCoversDate(snapshot, DateTime(2026, 10, 11)),
      isFalse,
    );
  });

  test('stale schedule cannot masquerade as today', () {
    final state = resolveCurrentPrayerState(
      snapshot: makeSnapshot(DateTime(2026, 10, 9), DateTime(2026, 10, 10)),
      now: local(11, 21),
    );
    expect(state, isNull);
  });

  test('at midnight, Isha remains focus while Fajr countdown stays accurate',
      () {
    final snapshot = makeSnapshot(
      DateTime(2026, 10, 11),
      DateTime(2026, 10, 12),
    );
    final midnight = local(11, 0).add(const Duration(minutes: 32));

    final state = resolveCurrentPrayerState(
      snapshot: snapshot,
      now: midnight,
    );

    expect(state, isNotNull);
    expect(state!.current, isNull);
    expect(state.focusPrayer, PrayerSlot.isha);
    expect(state.next, PrayerSlot.fajr);
    expect(state.nextAt, tz.TZDateTime(karachi, 2026, 10, 11, 5));
    expect(
      state.nextAt!.difference(midnight),
      const Duration(hours: 4, minutes: 28),
    );
  });

  test('before Fajr, Isha remains focus phase and Fajr is next boundary', () {
    final snapshot = makeSnapshot(
      DateTime(2026, 10, 11),
      DateTime(2026, 10, 12),
    );

    final state = resolveCurrentPrayerState(
      snapshot: snapshot,
      now: local(11, 4),
    );

    expect(state, isNotNull);
    expect(state!.current, isNull);
    expect(state.focusPrayer, PrayerSlot.isha);
    expect(state.next, PrayerSlot.fajr);
    expect(state.nextAt, tz.TZDateTime(karachi, 2026, 10, 11, 5));
  });

  test('cache window requires today and the immediately following day', () {
    final currentWindow = makeSnapshot(
      DateTime(2026, 10, 11),
      DateTime(2026, 10, 12),
    );
    final rolledWindow = makeSnapshot(
      DateTime(2026, 10, 10),
      DateTime(2026, 10, 11),
    );

    expect(
      prayerTimeSnapshotCoversDate(currentWindow, DateTime(2026, 10, 11)),
      isTrue,
    );
    expect(
      prayerTimeSnapshotCoversDate(rolledWindow, DateTime(2026, 10, 11)),
      isFalse,
    );
  });
}
