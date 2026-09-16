import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';

/// Availability of one date + prayer combination.
///
/// `alreadyRecorded` includes both pending and completed Qaza records. A
/// completed record must not be recreated as a duplicate.
enum QazaEligibility {
  available,
  alreadyPrayed,
  alreadyRecorded,
}

/// Stable identity for a Qaza candidate.
///
/// Duplicate identity is intentionally user + date + prayer, never date alone.
class QazaPrayerKey {
  const QazaPrayerKey({
    required this.userId,
    required this.date,
    required this.prayerType,
  });

  final String userId;
  final DateTime date;
  final PrayerType prayerType;

  factory QazaPrayerKey.fromRecord(QazaRecord record) => QazaPrayerKey(
        userId: record.userId,
        date: QazaDate.normalize(record.originalDate),
        prayerType: record.prayerType,
      );

  String get value =>
      '${userId}_${prayerType.name}_${QazaDate.key(date)}';

  @override
  bool operator ==(Object other) =>
      other is QazaPrayerKey &&
      other.userId == userId &&
      other.prayerType == prayerType &&
      other.date == date;

  @override
  int get hashCode => Object.hash(userId, date, prayerType);
}

/// Result of comparing candidate Qaza combinations with the current ledger.
class QazaAvailabilityAnalysis {
  const QazaAvailabilityAnalysis({
    required this.total,
    required this.alreadyRecorded,
    required this.alreadyPrayed,
    required this.newCount,
    required this.candidates,
    required this.newCandidates,
  });

  final int total;
  final int alreadyRecorded;
  final int alreadyPrayed;
  final int newCount;
  final List<QazaPrayerKey> candidates;
  final List<QazaPrayerKey> newCandidates;

  int get unavailableCount => alreadyRecorded + alreadyPrayed;
}

/// Pure availability/duplicate rules shared by Calendar and Calculator.
///
/// The current app has Qaza records but no separate prayer-history data source.
/// `prayedKeys` therefore defaults to empty until a prayer-history source is
/// available. The API still models the rule explicitly so callers cannot
/// accidentally collapse "already prayed" and "already recorded" into a
/// date-level check.
class QazaAvailabilityService {
  const QazaAvailabilityService();

  QazaEligibility eligibility({
    required String userId,
    required DateTime date,
    required PrayerType prayerType,
    Iterable<QazaRecord> existingRecords = const <QazaRecord>[],
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) {
    final key = QazaPrayerKey(
      userId: userId,
      date: QazaDate.normalize(date),
      prayerType: prayerType,
    );

    if (prayedKeys.contains(key)) return QazaEligibility.alreadyPrayed;

    final recordedKeys = {
      for (final record in existingRecords) QazaPrayerKey.fromRecord(record),
    };
    if (recordedKeys.contains(key)) return QazaEligibility.alreadyRecorded;

    return QazaEligibility.available;
  }

  Set<QazaPrayerKey> recordedKeys(Iterable<QazaRecord> records) => {
        for (final record in records) QazaPrayerKey.fromRecord(record),
      };

  List<PrayerType> availablePrayers({
    required String userId,
    required DateTime date,
    required Iterable<QazaRecord> existingRecords,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
    Iterable<PrayerType> prayerTypes = PrayerType.values,
  }) {
    return [
      for (final prayer in prayerTypes)
        if (eligibility(
              userId: userId,
              date: date,
              prayerType: prayer,
              existingRecords: existingRecords,
              prayedKeys: prayedKeys,
            ) ==
            QazaEligibility.available)
          prayer,
    ];
  }

  bool isDateAvailable({
    required String userId,
    required DateTime date,
    required Iterable<QazaRecord> existingRecords,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
    Iterable<PrayerType> prayerTypes = PrayerType.values,
  }) =>
      availablePrayers(
        userId: userId,
        date: date,
        existingRecords: existingRecords,
        prayedKeys: prayedKeys,
        prayerTypes: prayerTypes,
      ).isNotEmpty;

  QazaAvailabilityAnalysis analyze({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayerTypes,
    required Iterable<QazaRecord> existingRecords,
    Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{},
  }) {
    final uniqueDates = dates.map(QazaDate.normalize).toSet().toList()..sort();
    final uniquePrayers = prayerTypes.toSet().toList();
    final candidates = <QazaPrayerKey>[];
    final newCandidates = <QazaPrayerKey>[];
    var alreadyRecorded = 0;
    var alreadyPrayed = 0;
    final recorded = recordedKeys(existingRecords);

    for (final date in uniqueDates) {
      for (final prayer in uniquePrayers) {
        final key = QazaPrayerKey(
          userId: userId,
          date: date,
          prayerType: prayer,
        );
        candidates.add(key);
        if (prayedKeys.contains(key)) {
          alreadyPrayed++;
        } else if (recorded.contains(key)) {
          alreadyRecorded++;
        } else {
          newCandidates.add(key);
        }
      }
    }

    return QazaAvailabilityAnalysis(
      total: candidates.length,
      alreadyRecorded: alreadyRecorded,
      alreadyPrayed: alreadyPrayed,
      newCount: newCandidates.length,
      candidates: List.unmodifiable(candidates),
      newCandidates: List.unmodifiable(newCandidates),
    );
  }
}
