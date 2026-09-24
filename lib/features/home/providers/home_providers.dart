import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../prayer_times/domain/prayer_schedule.dart';
import '../../prayer_times/domain/prayer_times_models.dart';
import '../../prayer_times/prayer_times_providers.dart';
import '../../prayer_times/presentation/prayer_times_controller.dart';
import '../home_state.dart';

class HomeQazaPlanNotifier extends Notifier<HomeQazaPlanState> {
  static const _keyPrefix = 'qaza_home_daily_target_';
  int _restoreGeneration = 0;

  @override
  HomeQazaPlanState build() {
    final userId = ref.watch(activeUserIdProvider);
    final generation = ++_restoreGeneration;
    if (userId != null) {
      Future.microtask(() => _restore(userId, generation));
    }
    return const HomeQazaPlanState(
      dailyTarget: HomeQazaPlanState.defaultDailyTarget,
    );
  }

  Future<void> _restore(String userId, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _restoreGeneration ||
          ref.read(activeUserIdProvider) != userId) {
        return;
      }
      final stored = prefs.getInt('$_keyPrefix$userId');
      if (stored == null) return;
      state = HomeQazaPlanState(dailyTarget: _normalizeTarget(stored));
    } catch (_) {
      // Safe default remains active if preferences cannot be read.
    }
  }

  Future<void> setDailyTarget(int value) async {
    final target = _normalizeTarget(value);
    _restoreGeneration++;
    final userId = ref.read(activeUserIdProvider);
    state = state.copyWith(dailyTarget: target);
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_keyPrefix$userId', target);
    } catch (_) {
      // The in-memory selection remains valid when persistence is unavailable.
    }
  }

  /// Atomically claims the congratulation event for a user/day/target.
  ///
  /// Returning false means this exact target completion has already been
  /// celebrated, preventing duplicate dialogs from rebuilds or re-entry.
  Future<bool> claimDailyTargetCelebration({
    required String userId,
    required DateTime date,
    required int target,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final key = 'qaza_home_daily_target_celebrated_$userId';
    final marker = '$dateKey:$target';

    if (prefs.getString(key) == marker) return false;
    await prefs.setString(key, marker);
    return true;
  }

  int _normalizeTarget(int value) => value.clamp(1, 50).toInt();
}

final homeQazaPlanProvider =
    NotifierProvider<HomeQazaPlanNotifier, HomeQazaPlanState>(
  HomeQazaPlanNotifier.new,
);

final homeProgressRangeProvider =
    StateProvider<HomeProgressRange>((ref) => HomeProgressRange.sevenDays);

class HomeProgressWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() =>
      homeProgressWeekStartForDate(ref.watch(homeLocalDateProvider));

  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }

  void previousWeek() {
    state = state.subtract(const Duration(days: 7));
  }

  void resetToCurrentWeek() {
    state = homeProgressWeekStartForDate(ref.read(homeLocalDateProvider));
  }
}

final homeProgressWeekProvider =
    NotifierProvider<HomeProgressWeekNotifier, DateTime>(
  HomeProgressWeekNotifier.new,
);

final homeNowProvider =
    Provider<DateTime>((ref) => ref.watch(prayerTimesClockProvider).now());

DateTime homeLocalDateForLocation({
  required PrayerLocation? location,
  required DateTime instant,
}) {
  final timezone = location?.timezone;
  if (timezone != null &&
      timezone.isNotEmpty &&
      PrayerSchedule.isKnownTimezone(timezone)) {
    final local = PrayerSchedule.now(timezone, instant: instant);
    return DateTime(local.year, local.month, local.day);
  }
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime homeLocalDayStartForLocation({
  required PrayerLocation? location,
  required DateTime instant,
}) {
  final timezone = location?.timezone;
  if (timezone != null &&
      timezone.isNotEmpty &&
      PrayerSchedule.isKnownTimezone(timezone)) {
    final local = PrayerSchedule.now(timezone, instant: instant);
    final zone = tz.getLocation(timezone);
    return tz.TZDateTime(zone, local.year, local.month, local.day);
  }
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime homeLocalDayStartForDate({
  required PrayerLocation? location,
  required DateTime date,
}) {
  final timezone = location?.timezone;
  if (timezone != null &&
      timezone.isNotEmpty &&
      PrayerSchedule.isKnownTimezone(timezone)) {
    final zone = tz.getLocation(timezone);
    return tz.TZDateTime(zone, date.year, date.month, date.day);
  }
  return DateTime(date.year, date.month, date.day);
}

DateTime homeLocalDayEndForDate({
  required PrayerLocation? location,
  required DateTime date,
}) =>
    homeLocalDayStartForDate(
      location: location,
      date: DateTime(date.year, date.month, date.day + 1),
    );

final homeLocalDateProvider = Provider<DateTime>((ref) {
  final now = ref.watch(homeNowProvider);
  final location = ref.watch(prayerTimesControllerProvider).location;
  return homeLocalDateForLocation(location: location, instant: now);
});

final homeDailyProgressProvider =
    FutureProvider.autoDispose<HomeDailyProgress>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final target = ref.watch(homeQazaPlanProvider).dailyTarget;
  final today = ref.watch(homeLocalDateProvider);

  if (userId == null) {
    return HomeDailyProgress(completed: 0, target: target);
  }

  final location = ref.watch(prayerTimesControllerProvider).location;
  final start = homeLocalDayStartForDate(
    location: location,
    date: today,
  );
  final end = homeLocalDayEndForDate(
    location: location,
    date: today,
  );
  final completed = await ref.read(qazaServiceProvider).countCompletedBetween(
        userId: userId,
        from: start,
        to: end,
      );
  return HomeDailyProgress(completed: completed, target: target);
});

final homeProgressHistoryProvider = FutureProvider.autoDispose
    .family<List<HomeProgressPoint>, HomeProgressRange>(
  (ref, range) async {
    final userId = ref.watch(activeUserIdProvider);
    final today = ref.watch(homeLocalDateProvider);
    final weekStart = ref.watch(homeProgressWeekProvider);
    final location = ref.watch(prayerTimesControllerProvider).location;
    if (userId == null) return const <HomeProgressPoint>[];

    List<DateTime> starts;
    switch (range) {
      case HomeProgressRange.sevenDays:
        starts = [
          for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
        ];
      case HomeProgressRange.thirtyDays:
        starts = [
          for (var i = 29; i >= 0; i--) today.subtract(Duration(days: i)),
        ];
      case HomeProgressRange.monthly:
        final firstThisMonth = DateTime(today.year, today.month);
        starts = [
          for (var i = 11; i >= 0; i--)
            DateTime(firstThisMonth.year, firstThisMonth.month - i),
        ];
    }

    final counts = await Future.wait([
      for (var i = 0; i < starts.length; i++)
        ref.read(qazaServiceProvider).countCompletedBetween(
              userId: userId,
              from: homeLocalDayStartForDate(
                location: location,
                date: starts[i],
              ),
              to: homeLocalDayStartForDate(
                location: location,
                date: range == HomeProgressRange.monthly
                    ? DateTime(starts[i].year, starts[i].month + 1)
                    : DateTime(
                        starts[i].year,
                        starts[i].month,
                        starts[i].day + 1,
                      ),
              ),
            ),
    ]);

    return [
      for (var i = 0; i < starts.length; i++)
        HomeProgressPoint(start: starts[i], count: counts[i]),
    ];
  },
);

class HomePrayerSelectionNotifier extends Notifier<HomePrayerSelectionState> {
  @override
  HomePrayerSelectionState build() => const HomePrayerSelectionState();

  void selectPrayer(PrayerType prayer) {
    state = HomePrayerSelectionState(
      mode: HomePrayerSelectionMode.manual,
      manualPrayer: prayer,
    );
  }

  void useAutomatic() {
    state = const HomePrayerSelectionState(
      mode: HomePrayerSelectionMode.automatic,
    );
  }
}

final homePrayerSelectionProvider =
    NotifierProvider<HomePrayerSelectionNotifier, HomePrayerSelectionState>(
  HomePrayerSelectionNotifier.new,
);

PrayerType? currentHomePrayerForSchedule({
  required PrayerDay today,
  PrayerDay? tomorrow,
  required DateTime now,
}) {
  final result = PrayerSchedule.evaluate(
    today: today,
    tomorrow: tomorrow,
    nowOverride: now,
  );

  return switch (result.current) {
    PrayerName.fajr => PrayerType.fajr,
    PrayerName.dhuhr => PrayerType.zuhr,
    PrayerName.asr => PrayerType.asr,
    PrayerName.maghrib => PrayerType.maghrib,
    PrayerName.isha => PrayerType.isha,
    PrayerName.sunrise || null => null,
  };
}

class HomeCurrentPrayerNotifier
    extends AutoDisposeNotifier<HomeCurrentPrayerState> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  HomeCurrentPrayerState build() {
    PrayerTimesState? prayerTimesState;
    try {
      prayerTimesState = ref.watch(prayerTimesControllerProvider);
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            'home_current_prayer_state_read_failed',
            error,
            stack: stack,
          );
      prayerTimesState = null;
    }

    _stopTicker();

    final initial = _safeResolve(
      prayerTimesState,
      ref.read(prayerTimesClockProvider).now(),
    );

    _startTicker();
    ref.onCancel(_stopTicker);
    ref.onResume(_startTicker);
    ref.onDispose(_stopTicker);

    return HomeCurrentPrayerState(prayer: initial);
  }

  void _startTicker() {
    // Flutter widget tests use FakeAsync and must not inherit a real periodic
    // timer that remains pending until the test finishes. Production and
    // interactive debug builds retain the 30-second refresh behavior.
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    if (_timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _tick(),
    );
    _lifecycle = AppLifecycleListener(
      onResume: _tick,
    );
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _tick() {
    PrayerTimesState? prayerTimesState;
    try {
      prayerTimesState = ref.read(prayerTimesControllerProvider);
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            'home_current_prayer_state_read_failed',
            error,
            stack: stack,
          );
      prayerTimesState = null;
    }

    state = HomeCurrentPrayerState(
      prayer: _safeResolve(
        prayerTimesState,
        ref.read(prayerTimesClockProvider).now(),
      ),
    );
  }

  PrayerType? _safeResolve(
    PrayerTimesState? state,
    DateTime now,
  ) {
    try {
      final today = state?.today;
      if (state == null || !state.hasData || today == null) return null;

      return currentHomePrayerForSchedule(
        today: today,
        tomorrow: state.tomorrow,
        now: now,
      );
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            'home_current_prayer_resolution_failed',
            error,
            stack: stack,
          );
      // Home remains usable while Prayer Times is unavailable or booting.
      return null;
    }
  }
}

final homeCurrentPrayerProvider = AutoDisposeNotifierProvider<
    HomeCurrentPrayerNotifier, HomeCurrentPrayerState>(
  HomeCurrentPrayerNotifier.new,
);

final homeFallbackPendingProvider =
    FutureProvider.autoDispose<QazaRecord?>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return null;
  return ref.read(qazaServiceProvider).oldestPendingOverall(userId: userId);
});

final homeSelectedPrayerProvider =
    Provider.autoDispose<HomeSelectedPrayerState>((ref) {
  final selection = ref.watch(homePrayerSelectionProvider);
  final currentPrayer = ref.watch(homeCurrentPrayerProvider).prayer;

  if (selection.mode == HomePrayerSelectionMode.manual) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: selection.manualPrayer,
      currentPrayer: currentPrayer,
      source: HomePrayerSelectionSource.manual,
    );
  }

  final tartibAsync = ref.watch(sahibAlTartibProvider);
  final tartib = tartibAsync.valueOrNull;

  // Automatic selection is held to the same rule as manual selection. Until
  // Sahib al-Tartib has resolved, the ordering constraint is unknown, so
  // offering the current prayer could propose a Fard the rule forbids. The
  // manual menu already refuses in this state; this is where automatic used
  // to disagree with it.
  if (!tartibAsync.hasValue || tartib == null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      currentPrayer: currentPrayer,
      source: HomePrayerSelectionSource.tartibUnavailable,
    );
  }

  if (tartib.requiresOrder && tartib.nextPrayer != null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: tartib.nextPrayer,
      currentPrayer: currentPrayer,
      source: HomePrayerSelectionSource.sahibAlTartib,
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: currentPrayer,
    currentPrayer: currentPrayer,
    source: currentPrayer == null
        ? HomePrayerSelectionSource.unavailable
        : HomePrayerSelectionSource.currentPrayer,
  );
});
