import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_times_models.dart';

class PrayerScheduleResult {
  const PrayerScheduleResult({
    required this.current,
    required this.next,
    required this.now,
  });

  final PrayerName? current;
  final PrayerName? next;
  final tz.TZDateTime now;
}

class PrayerSchedule {
  static bool _timezoneInitialized = false;

  static void ensureTimezoneDatabase() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }

  static tz.TZDateTime now(String timezone) {
    ensureTimezoneDatabase();
    try {
      return tz.TZDateTime.now(tz.getLocation(timezone));
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC);
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
  }) {
    final currentNow = now(today.timezone);
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

    if (next == null && tomorrow != null) {
      current = PrayerName.isha;
      next = PrayerName.fajr;
    }

    return PrayerScheduleResult(
      current: current,
      next: next,
      now: currentNow,
    );
  }

  static Duration? timeUntilNext({
    required PrayerDay today,
    PrayerDay? tomorrow,
  }) {
    final result = evaluate(today: today, tomorrow: tomorrow);
    if (result.next == null) return null;

    final nextDay = result.current == PrayerName.isha &&
            tomorrow != null &&
            !result.now.isBefore(moment(today, PrayerName.isha))
        ? tomorrow
        : today;
    final nextMoment = moment(nextDay, result.next!);
    final difference = nextMoment.difference(result.now);
    return difference.isNegative ? Duration.zero : difference;
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
