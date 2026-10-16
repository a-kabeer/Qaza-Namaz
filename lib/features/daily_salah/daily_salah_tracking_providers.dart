import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../prayer_time/application/current_prayer_state.dart';
import '../prayer_time/application/prayer_time_providers.dart';
import '../prayer_time/domain/prayer_time.dart';
import 'daily_salah_tracking_service.dart';

final dailySalahTrackingServiceProvider =
    Provider<DailySalahTrackingService>((ref) {
  return DailySalahTrackingService(
    database: ref.watch(appDatabaseProvider),
    qazaService: ref.watch(qazaServiceProvider),
  );
});

final dailySalahTrackingEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(dailySalahTrackingServiceProvider).isEnabled();
});

final dailySalahTrackingSetupDismissedProvider = FutureProvider<bool>((ref) {
  return ref.watch(dailySalahTrackingServiceProvider).isSetupDismissed();
});

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

PrayerSchedule? _scheduleForDate(
  PrayerTimeSnapshot snapshot,
  DateTime date,
) {
  final target = _dayOnly(date);
  if (_dayOnly(snapshot.today.date) == target) return snapshot.today;
  if (_dayOnly(snapshot.tomorrow.date) == target) return snapshot.tomorrow;
  return null;
}

/// The tracking day changes at Fajr in the configured prayer location's
/// timezone, not at device midnight.
DateTime dailySalahTrackingDateForInstant({
  required PrayerTimeSnapshot? snapshot,
  required DateTime now,
}) {
  if (snapshot == null) return _dayOnly(now);

  final location = tz.getLocation(snapshot.location.timezoneId);
  final localNow = tz.TZDateTime.from(now, location);
  final localDate = _dayOnly(localNow);
  final schedule = _scheduleForDate(snapshot, localDate);
  if (schedule == null) return localDate;

  final fajr = schedule.localFor(PrayerSlot.fajr, location);
  return localNow.isBefore(fajr)
      ? localDate.subtract(const Duration(days: 1))
      : localDate;
}

final dailySalahTrackingDateProvider = Provider<DateTime>((ref) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final now = ref.watch(prayerTimeClockProvider).valueOrNull ?? DateTime.now();

  // Like the Prayer Time page, refresh a cached schedule once it no longer
  // covers both the current location-local day and the following day.
  if (snapshot != null) {
    final location = tz.getLocation(snapshot.location.timezoneId);
    final localNow = tz.TZDateTime.from(now, location);
    final localDate = _dayOnly(localNow);
    if (!prayerTimeSnapshotCoversDate(snapshot, localDate)) {
      Future.microtask(
        () => ref
            .read(prayerTimeControllerProvider.notifier)
            .refreshForDateIfNeeded(localDate),
      );
    }
  }

  return dailySalahTrackingDateForInstant(snapshot: snapshot, now: now);
});

typedef DailySalahPrayerAvailabilityRequest = ({
  DateTime date,
  DateTime trackingDate,
  PrayerType prayerType,
});

/// Returns whether a prayer can be recorded yet. Historical days are editable;
/// on the current Gregorian date each prayer unlocks at its scheduled start
/// time. Prayer times are read from the existing Prayer Time snapshot.
bool dailySalahPrayerTimeHasPassed({
  required DateTime date,
  required DateTime trackingDate,
  required PrayerType prayerType,
  required PrayerTimeSnapshot? snapshot,
  required DateTime now,
}) {
  final requestedDate = _dayOnly(date);
  final currentTrackingDate = _dayOnly(trackingDate);
  if (requestedDate.isBefore(currentTrackingDate)) return true;
  if (requestedDate.isAfter(currentTrackingDate) || snapshot == null) {
    return false;
  }

  final location = tz.getLocation(snapshot.location.timezoneId);
  final localNow = tz.TZDateTime.from(now, location);
  final localCalendarDate = _dayOnly(localNow);

  // Before Fajr the active tracking date is yesterday; its prayers have
  // already passed even though the location's Gregorian date has advanced.
  if (requestedDate.isBefore(localCalendarDate)) return true;
  if (requestedDate.isAfter(localCalendarDate)) return false;

  final schedule = _scheduleForDate(snapshot, requestedDate);
  if (schedule == null) return false;

  final slot = switch (prayerType) {
    PrayerType.fajr => PrayerSlot.fajr,
    PrayerType.zuhr => PrayerSlot.dhuhr,
    PrayerType.asr => PrayerSlot.asr,
    PrayerType.maghrib => PrayerSlot.maghrib,
    PrayerType.isha => PrayerSlot.isha,
    PrayerType.witr => PrayerSlot.isha,
  };
  return !localNow.isBefore(schedule.localFor(slot, location));
}

final dailySalahPrayerAvailableProvider =
    Provider.family<bool, DailySalahPrayerAvailabilityRequest>(
        (ref, request) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final now = ref.watch(prayerTimeClockProvider).valueOrNull ?? DateTime.now();
  return dailySalahPrayerTimeHasPassed(
    date: request.date,
    trackingDate: request.trackingDate,
    prayerType: request.prayerType,
    snapshot: snapshot,
    now: now,
  );
});

final dailySalahTrackingLogsProvider =
    FutureProvider.family<Map<PrayerType, DailySalahLog>, DateTime>(
        (ref, date) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return const <PrayerType, DailySalahLog>{};
  return ref.watch(dailySalahTrackingServiceProvider).logsForDate(
        userId: userId,
        date: date,
        includeWitr: ref.watch(effectiveWitrProvider),
      );
});
