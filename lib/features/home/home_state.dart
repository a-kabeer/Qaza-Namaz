import '../../core/constants/prayer_types.dart';

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

/// How Home determines the next Complete Qaza target.
enum HomePrayerSelectionMode {
  prayerTime,
  autoSequence,
  prayerSelection,
}

enum HomePrayerSelectionSource {
  prayerTime,
  autoSequence,
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
    this.mode = HomePrayerSelectionMode.autoSequence,
    this.selectedPrayer,
    this.autoSequencePrayer = PrayerType.fajr,
  });

  final HomePrayerSelectionMode mode;

  /// Explicit Prayer Selection target. It is sticky until the user changes it.
  final PrayerType? selectedPrayer;

  /// The current cursor for Auto Sequence mode.
  final PrayerType autoSequencePrayer;

  HomePrayerSelectionState copyWith({
    HomePrayerSelectionMode? mode,
    PrayerType? selectedPrayer,
    PrayerType? autoSequencePrayer,
    bool clearSelectedPrayer = false,
  }) {
    return HomePrayerSelectionState(
      mode: mode ?? this.mode,
      selectedPrayer:
          clearSelectedPrayer ? null : (selectedPrayer ?? this.selectedPrayer),
      autoSequencePrayer: autoSequencePrayer ?? this.autoSequencePrayer,
    );
  }

  /// Updates targeting after a successful completion.
  ///
  /// Prayer Selection is sticky. Prayer Time is resolved from the live
  /// Prayer Time provider, so completion does not mutate its target.
  /// Auto Sequence advances only when its own cursor prayer is completed.
  /// Sahib al-Tartib overrides the actionable prayer without changing this
  /// underlying state.
  HomePrayerSelectionState afterSuccessfulCompletion(
    PrayerType completedPrayer,
  ) {
    switch (mode) {
      case HomePrayerSelectionMode.prayerTime:
      case HomePrayerSelectionMode.prayerSelection:
        return this;
      case HomePrayerSelectionMode.autoSequence:
        if (completedPrayer != autoSequencePrayer) return this;
        return copyWith(
          autoSequencePrayer: completedPrayer.nextInQazaSequence,
        );
    }
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
