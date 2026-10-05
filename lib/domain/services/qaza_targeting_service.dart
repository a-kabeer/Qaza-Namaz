import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';

/// Resolves a Home Qaza target against the latest aggregated pending counts.
///
/// Both Auto Sequence and Prayer Time use this same resolver after establishing
/// their respective starting prayer. It deliberately consumes the canonical
/// [PrayerTypeX.qazaSequence] and never materializes the Qaza ledger.
class QazaTargetingService {
  const QazaTargetingService();

  /// Returns whether [prayer] is currently actionable from the pending
  /// Qaza summary.
  ///
  /// Witr is unavailable when the profile disables it, regardless of its
  /// pending count.
  bool isPrayerPending({
    required QazaProgressSummary summary,
    required PrayerType prayer,
    required bool witrEnabled,
  }) {
    if (!witrEnabled && prayer == PrayerType.witr) return false;
    return (summary.byPrayer[prayer]?.progress.pending ?? 0) > 0;
  }

  /// Returns the first eligible prayer at or after [startPrayer] in canonical
  /// Qaza order whose current pending count is greater than zero.
  ///
  /// The scan wraps exactly once through the canonical sequence. Witr is
  /// skipped when [witrEnabled] is false. A null result means there is no
  /// eligible pending prayer.
  PrayerType? resolveNextPendingPrayer({
    required QazaProgressSummary summary,
    required PrayerType startPrayer,
    required bool witrEnabled,
  }) {
    final sequence = PrayerTypeX.qazaSequence;
    if (sequence.isEmpty) return null;

    final startIndex = startPrayer.qazaSequenceIndex;
    if (startIndex < 0) return null;

    for (var offset = 0; offset < sequence.length; offset++) {
      final candidate = sequence[(startIndex + offset) % sequence.length];

      if (!witrEnabled && candidate == PrayerType.witr) {
        continue;
      }

      if (isPrayerPending(
        summary: summary,
        prayer: candidate,
        witrEnabled: witrEnabled,
      )) {
        return candidate;
      }
    }

    return null;
  }
}
