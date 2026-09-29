import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/prayer_types.dart';
import '../../../core/platform/app_location_settings.dart';

import '../data/offline_city_resolver.dart';
import '../data/prayer_location_repository.dart';
import '../data/prayer_time_cache.dart';
import '../domain/prayer_time_calculator.dart';
import '../domain/prayer_location.dart';
import '../domain/prayer_time.dart';
import '../domain/restricted_time.dart';
import 'prayer_time_controller.dart';

final prayerTimeCacheProvider = Provider<PrayerTimeCache>(
  (ref) => PrayerTimeCache(),
);

final offlineCityResolverProvider = Provider<OfflineCityResolver>(
  (ref) => OfflineCityResolver(),
);

final offlineCityCatalogProvider = FutureProvider<OfflineCityCatalog>((ref) async {
  final catalog = OfflineCityCatalog();
  await catalog.load();
  return catalog;
});

final appLocationSettingsProvider = Provider<AppLocationSettings>(
  (ref) => const AppLocationSettings(),
);

final prayerLocationRepositoryProvider = Provider<PrayerLocationRepository>(
  (ref) => PrayerLocationRepository(
    ref.read(offlineCityResolverProvider),
    locationSettings: ref.read(appLocationSettingsProvider),
  ),
);

final prayerTimeCalculatorProvider = Provider<PrayerTimeCalculator>(
  (ref) => const PrayerTimeCalculator(),
);

final restrictedTimeCalculatorProvider = Provider<RestrictedTimeCalculator>(
  (ref) => const RestrictedTimeCalculator(),
);

final prayerTimeRefreshProvider = StateProvider<bool>((ref) => false);

final prayerTimeControllerProvider = AsyncNotifierProvider<
    PrayerTimeController, PrayerTimeSnapshot?>(PrayerTimeController.new);

final prayerTimeClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 1));
    yield DateTime.now();
  }
});

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

PrayerSchedule _scheduleForLocalDate(
  PrayerTimeSnapshot snapshot,
  tz.TZDateTime localNow,
) {
  final date = _dateOnly(DateTime(localNow.year, localNow.month, localNow.day));
  if (snapshot.today.date == date) return snapshot.today;
  if (snapshot.tomorrow.date == date) return snapshot.tomorrow;
  return snapshot.today;
}

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

final currentPrayerStateProvider =
    Provider.autoDispose<CurrentPrayerState?>((ref) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final now = ref.watch(prayerTimeClockProvider).valueOrNull;
  if (snapshot == null || now == null) return null;

  final location = tz.getLocation(snapshot.location.timezoneId);
  final localNow = tz.TZDateTime.from(now, location);
  final today = _scheduleForLocalDate(snapshot, localNow);
  final tomorrow = snapshot.tomorrow;

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
      final next = i + 1 < prayers.length
          ? prayers[i + 1]
          : PrayerSlot.fajr;
      final nextAt = i + 1 < prayers.length
          ? today.localFor(next, location)
          : tomorrow.localFor(PrayerSlot.fajr, location);
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
});

/// The current Qaza prayer derived from the Prayer Time state.
///
/// Returns the current prayer during an active prayer period, or the upcoming
/// Fajr before Fajr begins. Because this provider returns a single enum value,
/// consumers do not rebuild every second while the clock is inside one prayer
/// period.
final currentQazaPrayerTypeProvider = Provider.autoDispose<PrayerType?>((ref) {
  final state = ref.watch(currentPrayerStateProvider);
  return (state?.current ?? state?.next)?.qazaPrayerType;
});

final restrictedTimeStateProvider =
    Provider.autoDispose<RestrictedTimeState?>((ref) {
  final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
  final now = ref.watch(prayerTimeClockProvider).valueOrNull;
  if (snapshot == null || now == null) return null;

  final location = tz.getLocation(snapshot.location.timezoneId);
  final localNow = tz.TZDateTime.from(now, location);
  return ref.read(restrictedTimeCalculatorProvider).stateFor(
        snapshot: snapshot,
        now: localNow,
      );
});

final qazaCompletionRestrictedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(restrictedTimeStateProvider)?.isActive ?? false;
});
