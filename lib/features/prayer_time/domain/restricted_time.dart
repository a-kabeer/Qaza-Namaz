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
\n  /// Returns the remaining time for the active restriction, or until
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
  static const sunriseAfter = Duration(minutes: 20);
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
