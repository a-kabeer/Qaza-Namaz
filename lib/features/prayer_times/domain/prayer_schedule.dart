import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_times_models.dart';

class PrayerScheduleResult {
  const PrayerScheduleResult({
    required this.current,
    required this.next,
    required this.now,
    this.nextIsTomorrow = false,
  });

  final PrayerName? current;
  final PrayerName? next;
  final tz.TZDateTime now;
  final bool nextIsTomorrow;
}

class PrayerSchedule {
  static bool _timezoneInitialized = false;

  static void ensureTimezoneDatabase() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }

  static tz.TZDateTime now(
    String timezone, {
    DateTime? instant,
  }) {
    ensureTimezoneDatabase();
    final location = _location(timezone);
    if (instant == null) return tz.TZDateTime.now(location);
    return tz.TZDateTime.from(instant, location);
  }

  static DateTime localDate(
    String timezone, {
    DateTime? instant,
  }) {
    final local = now(timezone, instant: instant);
    return DateTime(local.year, local.month, local.day);
  }

  static bool isKnownTimezone(String timezone) {
    ensureTimezoneDatabase();
    try {
      tz.getLocation(timezone);
      return true;
    } catch (_) {
      return false;
    }
  }

  static tz.TZDateTime moment(PrayerDay day, PrayerName prayer) {
    ensureTimezoneDatabase();
    final location = _location(day.timezone);
    final time = day.times[prayer]!;
    return tz.TZDateTime(
      location,
      day.date.year,
      day.date.month,
      day.date.day,
      time.hour,
      time.minute,
    );
  }

  static PrayerScheduleResult evaluate({
    required PrayerDay today,
    PrayerDay? tomorrow,
    DateTime? nowOverride,
  }) {
    final currentNow = _resolveNow(today.timezone, nowOverride);
    final ordered =
        PrayerName.values.where((item) => item.isCyclePrayer).toList();

    PrayerName? current;
    PrayerName? next;

    for (final prayer in ordered) {
      final time = moment(today, prayer);
      if (currentNow.isBefore(time)) {
        next = prayer;
        break;
      }
      current = prayer;
    }

    if (current == null && next != null) {
      current = PrayerName.isha;
    }

    final nextIsTomorrow = next == null && tomorrow != null;
    if (nextIsTomorrow) {
      current = PrayerName.isha;
      next = PrayerName.fajr;
    }

    return PrayerScheduleResult(
      current: current,
      next: next,
      now: currentNow,
      nextIsTomorrow: nextIsTomorrow,
    );
  }

  static Duration? timeUntilNext({
    required PrayerDay today,
    PrayerDay? tomorrow,
    DateTime? nowOverride,
  }) {
    final result = evaluate(
      today: today,
      tomorrow: tomorrow,
      nowOverride: nowOverride,
    );
    if (result.next == null) return null;

    final nextDay = result.nextIsTomorrow && tomorrow != null ? tomorrow : today;
    final nextMoment = moment(nextDay, result.next!);
    final difference = nextMoment.difference(result.now);
    return difference.isNegative ? Duration.zero : difference;
  }

  static tz.TZDateTime _resolveNow(String timezone, DateTime? override) {
    final location = _location(timezone);
    if (override == null) return tz.TZDateTime.now(location);
    return tz.TZDateTime.from(override, location);
  }

  static tz.Location _location(String timezone) {
    ensureTimezoneDatabase();
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.UTC;
    }
  }
}
