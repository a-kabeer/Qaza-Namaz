import '../../core/constants/prayer_types.dart';

class HomeQazaPlanState {
  const HomeQazaPlanState({required this.dailyTarget});

  static const int defaultDailyTarget = 5;

  final int dailyTarget;

  HomeQazaPlanState copyWith({int? dailyTarget}) =>
      HomeQazaPlanState(dailyTarget: dailyTarget ?? this.dailyTarget);
}

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

enum HomeProgressRange {
  oneDay,
  threeDays,
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

enum HomePrayerSelectionMode {
  automatic,
  manual,
}

class HomePrayerSelectionState {
  const HomePrayerSelectionState({
    this.mode = HomePrayerSelectionMode.automatic,
    this.manualPrayer,
  });

  final HomePrayerSelectionMode mode;
  final PrayerType? manualPrayer;

  PrayerType? get selectedPrayer =>
      mode == HomePrayerSelectionMode.manual ? manualPrayer : null;

  HomePrayerSelectionState copyWith({
    HomePrayerSelectionMode? mode,
    PrayerType? manualPrayer,
    bool clearManualPrayer = false,
  }) {
    return HomePrayerSelectionState(
      mode: mode ?? this.mode,
      manualPrayer:
          clearManualPrayer ? null : (manualPrayer ?? this.manualPrayer),
    );
  }
}

class HomeCurrentPrayerState {
  const HomeCurrentPrayerState({this.prayer});

  final PrayerType? prayer;
}

class HomeSelectedPrayerState {
  const HomeSelectedPrayerState({
    required this.mode,
    this.prayer,
  });

  final HomePrayerSelectionMode mode;
  final PrayerType? prayer;
}

int homeDaysUntilCompletion({
  required int pending,
  required int dailyTarget,
  required int completedToday,
}) {
  if (pending <= 0 || dailyTarget <= 0) return 0;
  final capacityToday =
      (dailyTarget - completedToday).clamp(0, dailyTarget).toInt();
  final afterToday = pending - capacityToday;
  if (afterToday <= 0) return 0;
  return (afterToday + dailyTarget - 1) ~/ dailyTarget;
}

DateTime homeEstimatedCompletionDate({
  required DateTime now,
  required int pending,
  required int dailyTarget,
  required int completedToday,
}) => DateTime(now.year, now.month, now.day).add(
      Duration(
        days: homeDaysUntilCompletion(
          pending: pending,
          dailyTarget: dailyTarget,
          completedToday: completedToday,
        ),
      ),
    );