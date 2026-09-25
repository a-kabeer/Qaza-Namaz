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

enum HomePrayerSelectionMode {
  automatic,
  manual,
}

enum HomePrayerSelectionSource {
  manual,
  sahibAlTartib,

  /// Sahib al-Tartib has not resolved, so no Fard prayer may be offered.
  ///
  /// Distinct from [unavailable]: there is nothing wrong with the ledger, the
  /// ordering rule simply is not known yet. Retrying is worthwhile, which is
  /// why the UI tells these two apart.
  tartibUnavailable,

  unavailable,
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

class HomeSelectedPrayerState {
  const HomeSelectedPrayerState({
    required this.mode,
    this.prayer,
    this.source = HomePrayerSelectionSource.unavailable,
  });

  final HomePrayerSelectionMode mode;
  final PrayerType? prayer;
  final HomePrayerSelectionSource source;
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
