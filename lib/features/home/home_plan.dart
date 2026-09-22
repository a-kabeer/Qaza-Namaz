export '../../core/theme/app_theme.dart' show AppChartColors;
export 'home_qaza_completion.dart' show HomeSelectedPrayerState, homeSelectedPrayerProvider;
export '../qaza/qaza_undo_banner.dart' show showQazaUndoSnackBar;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';

class HomeQazaPlanState {
  const HomeQazaPlanState({required this.dailyTarget});

  static const int defaultDailyTarget = 5;

  final int dailyTarget;

  HomeQazaPlanState copyWith({int? dailyTarget}) =>
      HomeQazaPlanState(dailyTarget: dailyTarget ?? this.dailyTarget);
}

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

  int _normalizeTarget(int value) => value.clamp(1, 50).toInt();
}

final homeQazaPlanProvider =
    NotifierProvider<HomeQazaPlanNotifier, HomeQazaPlanState>(
  HomeQazaPlanNotifier.new,
);

final homeNowProvider = Provider<DateTime>((ref) => DateTime.now());

class HomeDailyProgress {
  const HomeDailyProgress({
    required this.completed,
    required this.target,
  });

  final int completed;
  final int target;

  double get percentage {
    if (target <= 0) return 0;
    return (completed / target).clamp(0, 1).toDouble();
  }
}

final homeDailyProgressProvider =
    FutureProvider.autoDispose<HomeDailyProgress>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final target = ref.watch(homeQazaPlanProvider).dailyTarget;
  final now = ref.watch(homeNowProvider);

  if (userId == null) {
    return HomeDailyProgress(completed: 0, target: target);
  }

  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  final completed = await ref.read(qazaServiceProvider).countCompletedBetween(
        userId: userId,
        from: start,
        to: end,
      );
  return HomeDailyProgress(completed: completed, target: target);
});

enum HomeProgressRange {
  sevenDays,
  thirtyDays,
  monthly,
}

class HomeProgressPoint {
  const HomeProgressPoint({
    required this.start,
    required this.count,
  });

  final DateTime start;
  final int count;
}

final homeProgressHistoryProvider =
    FutureProvider.autoDispose.family<List<HomeProgressPoint>, HomeProgressRange>(
  (ref, range) async {
    final userId = ref.watch(activeUserIdProvider);
    final now = ref.watch(homeNowProvider);
    if (userId == null) return const <HomeProgressPoint>[];

    final today = DateTime(now.year, now.month, now.day);

    List<DateTime> starts;
    switch (range) {
      case HomeProgressRange.sevenDays:
        starts = [
          for (var i = 6; i >= 0; i--)
            today.subtract(Duration(days: i)),
        ];
      case HomeProgressRange.thirtyDays:
        starts = [
          for (var i = 29; i >= 0; i--)
            today.subtract(Duration(days: i)),
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
              from: starts[i],
              to: range == HomeProgressRange.monthly
                  ? DateTime(starts[i].year, starts[i].month + 1)
                  : starts[i].add(const Duration(days: 1)),
            ),
    ]);

    return [
      for (var i = 0; i < starts.length; i++)
        HomeProgressPoint(start: starts[i], count: counts[i]),
    ];
  },
);
