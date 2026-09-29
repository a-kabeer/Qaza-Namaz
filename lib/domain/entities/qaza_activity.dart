import 'dart:math' as math;

import '../../core/constants/prayer_types.dart';

/// Minimal projection used by Qaza activity/history.
///
/// Only the completion instant and prayer type cross the data boundary.
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

  int get remaining => math.max(target - completed, 0);

  double get progress =>
      target <= 0 ? 0.0 : (completed / target).clamp(0.0, 1.0).toDouble();
}

class QazaActivityPeriod {
  const QazaActivityPeriod({
    required this.from,
    required this.toExclusive,
    required this.today,
    required this.days,
  });

  final DateTime from;
  final DateTime toExclusive;
  final DateTime today;
  final List<QazaDailyActivity> days;

  int get totalCompleted =>
      days.fold(0, (total, day) => total + day.completed);

  /// Future calendar days do not contribute to the target total.
  int get totalTarget =>
      days.fold(0, (total, day) => total + (day.hasGoal ? day.target : 0));

  int get remaining => math.max(totalTarget - totalCompleted, 0);

  double get progress => totalTarget <= 0
      ? 0.0
      : (totalCompleted / totalTarget).clamp(0.0, 1.0).toDouble();

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
