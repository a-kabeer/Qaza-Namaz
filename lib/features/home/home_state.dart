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
///
/// Manual prayer selection is an override inside the selected mode; it is not
/// presented as a third user-facing mode.
enum HomePrayerSelectionMode {
  prayerTime,
  autoSequence,
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
    this.mode = HomePrayerSelectionMode.prayerTime,
    this.manualPrayer,
    this.autoSequencePrayer = PrayerType.fajr,
  });

  final HomePrayerSelectionMode mode;

  /// A user-selected target that temporarily overrides the current mode.
  final PrayerType? manualPrayer;

  /// The current cursor for Auto Sequence mode.
  final PrayerType autoSequencePrayer;

  bool get hasManualOverride => manualPrayer != null;

  HomePrayerSelectionState copyWith({
    HomePrayerSelectionMode? mode,
    PrayerType? manualPrayer,
    PrayerType? autoSequencePrayer,
    bool clearManualPrayer = false,
  }) {
    return HomePrayerSelectionState(
      mode: mode ?? this.mode,
      manualPrayer:
          clearManualPrayer ? null : (manualPrayer ?? this.manualPrayer),
      autoSequencePrayer: autoSequencePrayer ?? this.autoSequencePrayer,
    );
  }

  /// Advances Auto Sequence only after a successful completion.
  HomePrayerSelectionState afterSuccessfulCompletion(
    PrayerType completedPrayer,
  ) {
    if (mode == HomePrayerSelectionMode.prayerTime) {
      return copyWith(clearManualPrayer: true);
    }

    return copyWith(
      autoSequencePrayer: completedPrayer.nextInQazaSequence,
      clearManualPrayer: true,
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
