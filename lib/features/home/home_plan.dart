import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../domain/entities/qaza_record.dart';

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

  int get remainingToTarget => (target - completed).clamp(0, target).toInt();

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

final homeNextQazaProvider =
    FutureProvider.autoDispose<QazaRecord?>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return null;
  return ref.read(qazaServiceProvider).oldestPendingOverall(userId: userId);
});

int homeDaysUntilCompletion({
  required int pending,
  required int dailyTarget,
  required int completedToday,
}) {
  if (pending <= 0 || dailyTarget <= 0) return 0;
  final capacityToday =
      (dailyTarget - completedToday).clamp(0, dailyTarget);
  final afterToday = pending - capacityToday;
  if (afterToday <= 0) return 0;
  return (afterToday + dailyTarget - 1) ~/ dailyTarget;
}

DateTime homeEstimatedCompletionDate({
  required DateTime now,
  required int pending,
  required int dailyTarget,
  required int completedToday,
}) =>
    DateTime(now.year, now.month, now.day).add(
      Duration(
        days: homeDaysUntilCompletion(
          pending: pending,
          dailyTarget: dailyTarget,
          completedToday: completedToday,
        ),
      ),
    );
