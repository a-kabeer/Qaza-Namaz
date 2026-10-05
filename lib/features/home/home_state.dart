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
  prayerSelection,
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
  /// Advances Auto Sequence from the prayer that was actually targeted.
  ///
  /// Normally that is the persisted cursor prayer. When pending-aware fallback
  /// resolves past a zero-pending cursor, [targetWasAutoSequence] lets the
  /// caller advance from the resolved prayer instead. Callers completing a
  /// target outside Auto Sequence leave it false.
  HomePrayerSelectionState afterSuccessfulCompletion(
    PrayerType completedPrayer, {
    bool witrEnabled = true,
    bool targetWasAutoSequence = false,
  }) {
    switch (mode) {
      case HomePrayerSelectionMode.prayerTime:
      case HomePrayerSelectionMode.prayerSelection:
        return this;
      case HomePrayerSelectionMode.autoSequence:
        if (!targetWasAutoSequence && completedPrayer != autoSequencePrayer) {
          return this;
        }
        return copyWith(
          autoSequencePrayer:
              completedPrayer.nextInQazaSequenceSkippingWitr(
            witrEnabled: witrEnabled,
          ),
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
