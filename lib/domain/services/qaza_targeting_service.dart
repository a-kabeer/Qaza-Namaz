import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';

/// Resolves a Home Qaza target against the latest aggregated pending counts.
///
/// Both Auto Sequence and Prayer Time use this same resolver after establishing
/// their respective starting prayer. It deliberately consumes the canonical
/// [PrayerTypeX.qazaSequence] and never materializes the Qaza ledger.
class QazaTargetingService {
  const QazaTargetingService();

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

      final pending =
          summary.byPrayer[candidate]?.progress.pending ?? 0;
      if (pending > 0) return candidate;
    }

    return null;
  }
}
