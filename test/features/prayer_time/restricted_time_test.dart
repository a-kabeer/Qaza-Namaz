import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/restricted_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_settings.dart';

void main() {
  late tz.Location location;
  setUpAll(() {
    tzdata.initializeTimeZones();
    location = tz.getLocation('Asia/Karachi');
  });

  group('PrayerLocation', () {
    test('serializes and restores a manual city location', () {
      const original = PrayerLocation(
        latitude: 24.86,
        longitude: 67.00,
        city: 'Karachi',
        region: 'Sindh',
        country: 'Pakistan',
        countryCode: 'PK',
        timezoneId: 'Asia/Karachi',
        source: PrayerLocationSource.city,
      );

      final restored = PrayerLocation.fromJson(original.toJson());

      expect(restored?.city, 'Karachi');
      expect(restored?.countryCode, 'PK');
      expect(restored?.timezoneId, 'Asia/Karachi');
      expect(restored?.source, PrayerLocationSource.city);
    });

    test('computes a zero distance for the same coordinates', () {
      const location = PrayerLocation(
        latitude: 24.86,
        longitude: 67.00,
        city: 'Karachi',
        region: 'Sindh',
        country: 'Pakistan',
        countryCode: 'PK',
        timezoneId: 'Asia/Karachi',
        source: PrayerLocationSource.current,
      );

      expect(location.distanceKmTo(24.86, 67.00), closeTo(0, 0.001));
    });
  });

  group('RestrictedTimeCalculator', () {
    final day = DateTime.utc(2026, 9, 27);
    final sunrise = DateTime.utc(2026, 9, 27, 1, 21);
    final solarNoon = DateTime.utc(2026, 9, 27, 7, 17);
    final sunset = DateTime.utc(2026, 9, 27, 13, 16);

    final schedule = PrayerSchedule(
      date: day,
      timesUtc: {
        PrayerSlot.fajr: DateTime.utc(2026, 9, 26, 23, 2),
        PrayerSlot.sunrise: sunrise,
        PrayerSlot.dhuhr: solarNoon,
        PrayerSlot.asr: DateTime.utc(2026, 9, 27, 11, 18),
        PrayerSlot.maghrib: sunset,
        PrayerSlot.isha: DateTime.utc(2026, 9, 27, 14, 35),
      },
      astronomicalSunriseUtc: sunrise,
      astronomicalDhuhrUtc: solarNoon,
      astronomicalSunsetUtc: sunset,
    );

    final tomorrow = PrayerSchedule(
      date: day.add(const Duration(days: 1)),
      timesUtc: schedule.timesUtc,
      astronomicalSunriseUtc: sunrise.add(const Duration(days: 1)),
      astronomicalDhuhrUtc: solarNoon.add(const Duration(days: 1)),
      astronomicalSunsetUtc: sunset.add(const Duration(days: 1)),
    );

    const settings = PrayerSettings();
    final snapshot = PrayerTimeSnapshot(
      location: const PrayerLocation(
        latitude: 24.86,
        longitude: 67,
        city: 'Karachi',
        region: 'Sindh',
        country: 'Pakistan',
        countryCode: 'PK',
        timezoneId: 'Asia/Karachi',
        source: PrayerLocationSource.city,
      ),
      settings: settings,
      today: schedule,
      tomorrow: tomorrow,
      updatedAt: DateTime.utc(2026, 9, 27),
    );

    test('reports the sunrise restricted window as active', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 1, 30),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.active?.type, RestrictedTimeType.sunrise);
    });

    test('reports Zawal as active around astronomical solar noon', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 7, 17),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.active?.type, RestrictedTimeType.zawal);
    });

    test('reports the sunset window as active before sunset', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 13, 10),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.active?.type, RestrictedTimeType.sunset);
    });

    test('uses event-specific display instants for the timeline', () {
      const calculator = RestrictedTimeCalculator();

      final windows = calculator.forSchedule(schedule, location);

      final sunriseWindow = windows.firstWhere(
        (window) => window.type == RestrictedTimeType.sunrise,
      );
      final zawalWindow = windows.firstWhere(
        (window) => window.type == RestrictedTimeType.zawal,
      );
      final sunsetWindow = windows.firstWhere(
        (window) => window.type == RestrictedTimeType.sunset,
      );

      expect(sunriseWindow.displayAt, sunriseWindow.startsAt);
      expect(zawalWindow.displayAt, zawalWindow.startsAt);
      expect(
        zawalWindow.timelineDisplayAt,
        tz.TZDateTime.from(solarNoon, location),
      );
      expect(sunsetWindow.displayAt, sunsetWindow.endsAt);
    });

    test('hides the restricted row before Fajr even when Sunrise is upcoming', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 26, 22, 30),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, isEmpty);
    });

    test('shows Sunrise during Fajr before the restricted window begins', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 26, 23, 30),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, hasLength(1));
      expect(windows.single.type, RestrictedTimeType.sunrise);
    });

    test('switches to Zawal after the Sunrise restriction expires', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 1, 41),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, hasLength(1));
      expect(windows.single.type, RestrictedTimeType.zawal);
    });

    test('hides the row after Zuhr plus five minutes', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 7, 22),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, isEmpty);
    });

    test('shows Sunset throughout Asr until Maghrib', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 11, 30),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, hasLength(1));
      expect(windows.single.type, RestrictedTimeType.sunset);
    });

    test('hides the row at Maghrib', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 13, 16),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
      );

      expect(windows, isEmpty);
    });

    test('shows all three rows when the toggle is on', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 4, 0),
        location,
      );
      final windows = const RestrictedTimeCalculator().timelineWindowsForSchedule(
        schedule: schedule,
        location: location,
        now: now,
        showAll: true,
      );

      expect(
        windows.map((window) => window.type),
        [
          RestrictedTimeType.sunrise,
          RestrictedTimeType.zawal,
          RestrictedTimeType.sunset,
        ],
      );
    });

    test('reports the next restricted window when none is active', {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 4, 0),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.active, isNull);
      expect(state.next, isNotNull);
    });

    test('derives remaining time from the active window end', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 1, 30),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.remainingAt(now), const Duration(minutes: 11));
    });

    test('derives remaining time until the next window when inactive', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 4, 0),
        location,
      );
      final state = const RestrictedTimeCalculator().stateFor(
        snapshot: snapshot,
        now: now,
      );

      expect(state.remainingAt(now), const Duration(hours: 3, minutes: 12));
    });

    test('clamps an expired restricted countdown to zero', () {
      final now = tz.TZDateTime.from(
        DateTime.utc(2026, 9, 27, 1, 30),
        location,
      );
      final expired = RestrictedTimeState(
        active: RestrictedTimeWindow(
          type: RestrictedTimeType.sunrise,
          startsAt: now.subtract(const Duration(minutes: 20)),
          endsAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

      expect(expired.remainingAt(now), Duration.zero);
    });
  });
}
