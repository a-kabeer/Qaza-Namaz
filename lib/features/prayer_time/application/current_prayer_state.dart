import 'package:timezone/timezone.dart' as tz;

import '../domain/prayer_time.dart';

/// The prayer that is active now and the next prayer boundary.
///
/// [nextAt] is null only when the snapshot does not contain the date required
/// to calculate the next boundary (for example, Isha after a cached snapshot's
/// final day). Callers must not substitute an already elapsed Fajr time.
class CurrentPrayerState {
  const CurrentPrayerState({
    this.current,
    this.next,
    this.currentStartedAt,
    this.nextAt,
  });

  final PrayerSlot? current;
  final PrayerSlot? next;
  final DateTime? currentStartedAt;
  final DateTime? nextAt;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whether [snapshot] contains the requested local date and the immediately
/// following local date. A schedule with an old or gapped date window must be
/// refreshed before it is treated as the current two-day schedule.
bool prayerTimeSnapshotCoversDate(
  PrayerTimeSnapshot snapshot,
  DateTime localDate,
) {
  final today = _dateOnly(localDate);
  return _dateOnly(snapshot.today.date) == today &&
      _dateOnly(snapshot.tomorrow.date) == today.add(const Duration(days: 1));
}

PrayerSchedule? _scheduleForDate(
  PrayerTimeSnapshot snapshot,
  DateTime date,
) {
  final target = _dateOnly(date);
  if (_dateOnly(snapshot.today.date) == target) return snapshot.today;
  if (_dateOnly(snapshot.tomorrow.date) == target) return snapshot.tomorrow;
  return null;
}

/// Resolves prayer state against the schedule whose date matches the clock in
/// the selected prayer location's timezone.
///
/// In particular, after Isha the next Fajr is only taken from a schedule whose
/// date is exactly the following local day. A stale snapshot is never allowed
/// to reuse its old `tomorrow` schedule as though it represented tomorrow
/// again after midnight.
CurrentPrayerState? resolveCurrentPrayerState({
  required PrayerTimeSnapshot snapshot,
  required DateTime now,
}) {
  final location = tz.getLocation(snapshot.location.timezoneId);
  final localNow = tz.TZDateTime.from(now, location);
  final localDate = _dateOnly(localNow);
  final today = _scheduleForDate(snapshot, localDate);
  if (today == null) return null;

  final tomorrow = _scheduleForDate(
    snapshot,
    localDate.add(const Duration(days: 1)),
  );

  const prayers = [
    PrayerSlot.fajr,
    PrayerSlot.dhuhr,
    PrayerSlot.asr,
    PrayerSlot.maghrib,
    PrayerSlot.isha,
  ];

  for (var i = prayers.length - 1; i >= 0; i--) {
    final prayer = prayers[i];
    final time = today.localFor(prayer, location);
    if (!localNow.isBefore(time)) {
      final next = i + 1 < prayers.length ? prayers[i + 1] : PrayerSlot.fajr;
      final DateTime? nextAt = i + 1 < prayers.length
          ? today.localFor(next, location)
          : tomorrow?.localFor(PrayerSlot.fajr, location);
      return CurrentPrayerState(
        current: prayer,
        next: next,
        currentStartedAt: time,
        nextAt: nextAt,
      );
    }
  }

  return CurrentPrayerState(
    next: PrayerSlot.fajr,
    nextAt: today.localFor(PrayerSlot.fajr, location),
  );
}
