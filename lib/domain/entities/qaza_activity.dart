import 'dart:math' as math;

import '../../core/constants/prayer_types.dart';

/// Minimal projection used by Qaza activity/history.
class QazaActivityRow {
  const QazaActivityRow({
    required this.completedAt,
    required this.prayerType,
  });

  final DateTime completedAt;
  final PrayerType prayerType;
}

class QazaDailyActivity {
  const QazaDailyActivity({
    required this.date,
    required this.completed,
    required this.byPrayer,
    required this.target,
    required this.isFuture,
  });

  final DateTime date;
  final int completed;
  final Map<PrayerType, int> byPrayer;
  final int target;
  final bool isFuture;

  bool get hasGoal => target > 0 && !isFuture;

  bool get goalReached => hasGoal && completed >= target;

  int get remaining => target > 0 ? math.max(target - completed, 0) : 0;

  double get progress =>
      target <= 0 ? 0.0 : (completed / target).clamp(0.0, 1.0).toDouble();
}

class QazaActivityPeriod {
  const QazaActivityPeriod({
    required this.from,
    required this.toExclusive,
    required this.today,
    required this.days,
    this.targetAvailable = true,
    int? dailyTarget,
    this.activeDays = 0,
    this.activeMonths = 0,
  }) : _configuredDailyTarget = dailyTarget;

  final DateTime from;
  final DateTime toExclusive;
  final DateTime today;
  final List<QazaDailyActivity> days;
  final bool targetAvailable;
  final int? _configuredDailyTarget;
  int get dailyTarget =>
      _configuredDailyTarget ?? (days.isEmpty ? 0 : days.first.target);
  final int activeDays;
  final int activeMonths;

  int get totalCompleted =>
      days.fold(0, (total, day) => total + day.completed);

  int? get fullTarget => targetAvailable && dailyTarget > 0
      ? dailyTarget * days.length
      : null;

  int? get remainingTarget {
    final target = fullTarget;
    if (target == null) return null;
    return math.max(target - totalCompleted, 0);
  }

  double get progress {
    final target = fullTarget;
    return target == null || target <= 0
        ? 0.0
        : (totalCompleted / target).clamp(0.0, 1.0).toDouble();
  }

  /// Full selected-period target for compatibility with existing callers.
  int get totalTarget => fullTarget ?? 0;

  int get remaining => remainingTarget ?? 0;

  int get goalDays =>
      days.where((day) => day.hasGoal && day.goalReached).length;

  QazaDailyActivity? dayFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    for (final day in days) {
      if (day.date == key) return day;
    }
    return null;
  }
}
