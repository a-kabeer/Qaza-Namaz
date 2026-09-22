import '../../core/constants/prayer_types.dart';
import 'qaza_record.dart';

class QazaProgress {
  const QazaProgress({
    required this.pending,
    required this.completed,
  });

  final int pending;
  final int completed;

  int get total => pending + completed;

  double get percentage {
    if (total == 0) return 0;
    return completed / total;
  }
}

class PrayerProgress {
  const PrayerProgress({
    required this.prayerType,
    required this.progress,
  });

  final PrayerType prayerType;
  final QazaProgress progress;
}

/// Aggregated progress data returned without materializing the Qaza ledger.
class QazaProgressSummary {
  const QazaProgressSummary({
    required this.overall,
    required this.byPrayer,
  });

  final QazaProgress overall;
  final Map<PrayerType, PrayerProgress> byPrayer;

  factory QazaProgressSummary.empty() {
    return QazaProgressSummary(
      overall: const QazaProgress(pending: 0, completed: 0),
      byPrayer: {
        for (final prayer in PrayerType.values)
          prayer: PrayerProgress(
            prayerType: prayer,
            progress: const QazaProgress(pending: 0, completed: 0),
          ),
      },
    );
  }

  factory QazaProgressSummary.fromRecords(Iterable<QazaRecord> records) {
    final pending = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0,
    };
    final completed = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0,
    };

    for (final record in records) {
      if (record.status == QazaStatus.deleted) continue;
      if (record.status == QazaStatus.completed) {
        completed[record.prayerType] = completed[record.prayerType]! + 1;
      } else {
        pending[record.prayerType] = pending[record.prayerType]! + 1;
      }
    }

    return QazaProgressSummary(
      overall: QazaProgress(
        pending: pending.values.fold(0, (total, count) => total + count),
        completed: completed.values.fold(0, (total, count) => total + count),
      ),
      byPrayer: {
        for (final prayer in PrayerType.values)
          prayer: PrayerProgress(
            prayerType: prayer,
            progress: QazaProgress(
              pending: pending[prayer]!,
              completed: completed[prayer]!,
            ),
          ),
      },
    );
  }
}
