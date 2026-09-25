import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_record.dart';
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

final homeNowProvider = Provider<DateTime>((ref) => DateTime.now());

DateTime homeLocalDateForInstant(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime homeLocalDayStartForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime homeLocalDayEndForDate(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

final homeLocalDateProvider = Provider<DateTime>((ref) {
  return homeLocalDateForInstant(ref.watch(homeNowProvider));
});

final homeDailyProgressProvider =
    FutureProvider.autoDispose<HomeDailyProgress>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final target = ref.watch(homeQazaPlanProvider).dailyTarget;
  final today = ref.watch(homeLocalDateProvider);

  if (userId == null) {
    return HomeDailyProgress(completed: 0, target: target);
  }

  final start = homeLocalDayStartForDate(today);
  final end = homeLocalDayEndForDate(today);
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
              from: homeLocalDayStartForDate(starts[i]),
              to: homeLocalDayStartForDate(
                range == HomeProgressRange.monthly
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

final homeFallbackPendingProvider =
    FutureProvider.autoDispose<QazaRecord?>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return null;
  return ref.read(qazaServiceProvider).oldestPendingOverall(userId: userId);
});

final homeSelectedPrayerProvider =
    Provider.autoDispose<HomeSelectedPrayerState>((ref) {
  final selection = ref.watch(homePrayerSelectionProvider);

  if (selection.mode == HomePrayerSelectionMode.manual) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: selection.manualPrayer,
      source: HomePrayerSelectionSource.manual,
    );
  }

  final tartibAsync = ref.watch(sahibAlTartibProvider);
  final tartib = tartibAsync.valueOrNull;

  if (!tartibAsync.hasValue || tartib == null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: null,
      source: HomePrayerSelectionSource.tartibUnavailable,
    );
  }

  if (tartib.requiresOrder && tartib.nextPrayer != null) {
    return HomeSelectedPrayerState(
      mode: selection.mode,
      prayer: tartib.nextPrayer,
      source: HomePrayerSelectionSource.sahibAlTartib,
    );
  }

  return HomeSelectedPrayerState(
    mode: selection.mode,
    prayer: null,
    source: HomePrayerSelectionSource.unavailable,
  );
});
