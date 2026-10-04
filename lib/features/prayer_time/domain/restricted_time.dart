import 'package:timezone/timezone.dart' as tz;

import 'prayer_time.dart';

enum RestrictedTimeType {
  sunrise,
  zawal,
  sunset,
}

class RestrictedTimeWindow {
  const RestrictedTimeWindow({
    required this.type,
    required this.startsAt,
    required this.endsAt,
  });

  final RestrictedTimeType type;
  final tz.TZDateTime startsAt;
  final tz.TZDateTime endsAt;

  /// Canonical timeline instant used by shared Home/Qaza restricted rows.
  tz.TZDateTime get displayAt => switch (type) {
        RestrictedTimeType.sunrise => startsAt,
        RestrictedTimeType.zawal => startsAt,
        RestrictedTimeType.sunset => endsAt,
      };

  /// Event instant used by the Prayer Time timeline.
  ///
  /// Unlike [displayAt], Zawal is shown at astronomical solar noon rather
  /// than the beginning of its five-minute-before / five-minute-after window.
  tz.TZDateTime get timelineDisplayAt => switch (type) {
        RestrictedTimeType.sunrise => startsAt,
        RestrictedTimeType.zawal => startsAt.add(const Duration(minutes: 5)),
        RestrictedTimeType.sunset => endsAt,
      };

  bool contains(tz.TZDateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);
}

class RestrictedTimeState {
  const RestrictedTimeState({
    this.active,
    this.next,
  });

  final RestrictedTimeWindow? active;
  final RestrictedTimeWindow? next;

  bool get isActive => active != null;

  /// Returns the remaining time for the active restriction, or until
  /// the next restriction starts when the state is inactive.
  Duration? remainingAt(tz.TZDateTime now) {
    final window = active ?? next;
    if (window == null) return null;

    final target = active != null ? window.endsAt : window.startsAt;
    final remaining = target.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class RestrictedTimeCalculator {
  const RestrictedTimeCalculator();

  // Centralized practical Hanafi policy for Qaza completion gating.
  static const sunriseAfter = Duration(minutes: 15);
  static const zawalBefore = Duration(minutes: 5);
  static const zawalAfter = Duration(minutes: 5);
  static const sunsetBefore = Duration(minutes: 15);

  List<RestrictedTimeWindow> forSchedule(
    PrayerSchedule schedule,
    tz.Location location,
  ) {
    final sunrise = schedule.localAstronomicalSunrise(location);
    final zawal = schedule.localAstronomicalDhuhr(location);
    final sunset = schedule.localAstronomicalSunset(location);

    return [
      RestrictedTimeWindow(
        type: RestrictedTimeType.sunrise,
        startsAt: sunrise,
        endsAt: sunrise.add(sunriseAfter),
      ),
      RestrictedTimeWindow(
        type: RestrictedTimeType.zawal,
        startsAt: zawal.subtract(zawalBefore),
        endsAt: zawal.add(zawalAfter),
      ),
      RestrictedTimeWindow(
        type: RestrictedTimeType.sunset,
        startsAt: sunset.subtract(sunsetBefore),
        endsAt: sunset,
      ),
    ];
  }

  /// Returns the restricted-time rows that should be exposed by the main
  /// Prayer Time timeline.
  ///
  /// OFF/default mode follows the requested transitions:
  /// Fajr → Sunrise restriction expiry: Sunrise
  /// Sunrise restriction expiry → Zuhr + 5 min: Zawal
  /// Zuhr + 5 min → Asr: hidden
  /// Asr → Maghrib: Sunset
  /// Maghrib → next Fajr: hidden
  ///
  /// ON mode exposes Sunrise, Zawal and Sunset for the selected schedule.
  List<RestrictedTimeWindow> timelineWindowsForSchedule({
    required PrayerSchedule schedule,
    required tz.Location location,
    required tz.TZDateTime now,
    bool showAll = false,
  }) {
    final windows = forSchedule(schedule, location);
    if (showAll) return List.unmodifiable(windows);

    final sunrise = windows.firstWhere(
      (window) => window.type == RestrictedTimeType.sunrise,
    );
    final zawal = windows.firstWhere(
      (window) => window.type == RestrictedTimeType.zawal,
    );
    final sunset = windows.firstWhere(
      (window) => window.type == RestrictedTimeType.sunset,
    );

    final fajr = schedule.localFor(PrayerSlot.fajr, location);
    final asr = schedule.localFor(PrayerSlot.asr, location);
    final maghrib = schedule.localFor(PrayerSlot.maghrib, location);

    if (!now.isBefore(fajr) && now.isBefore(sunrise.endsAt)) {
      return [sunrise];
    }
    final zawalVisibleUntil = zawal.endsAt;

    if (!now.isBefore(sunrise.endsAt) && now.isBefore(zawalVisibleUntil)) {
      return [zawal];
    }
    if (!now.isBefore(asr) && now.isBefore(maghrib)) {
      return [sunset];
    }

    return const <RestrictedTimeWindow>[];
  }

  RestrictedTimeState stateFor({
    required PrayerTimeSnapshot snapshot,
    required tz.TZDateTime now,
  }) {
    final location = tz.getLocation(snapshot.location.timezoneId);
    final windows = [
      ...forSchedule(snapshot.today, location),
      ...forSchedule(snapshot.tomorrow, location),
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    RestrictedTimeWindow? active;
    RestrictedTimeWindow? next;
    for (final window in windows) {
      if (window.contains(now)) {
        active = window;
        break;
      }
      if (next == null && window.startsAt.isAfter(now)) {
        next = window;
      }
    }
    return RestrictedTimeState(active: active, next: next);
  }
}
