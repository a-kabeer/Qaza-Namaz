import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../entities/qaza_completion_result.dart';

class QazaPage {
  const QazaPage({required this.records, required this.hasMore});

  final List<QazaRecord> records;
  final bool hasMore;

  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
  DateTime? get nextCompletedAt =>
      records.isEmpty ? null : records.last.completedAt;
  String? get nextId => records.isEmpty ? null : records.last.id;
  PrayerType? get nextPrayerType =>
      records.isEmpty ? null : records.last.prayerType;
}

abstract interface class QazaRepository {
  /// Legacy full-ledger API. New production UI should use [getPage].
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  });

  /// Bounded keyset page for scalable ledger screens.
  ///
  /// Pending pages use [from]/[to] as an inclusive original-Qaza-date range.
  /// Completed pages use [from]/[toExclusive] against [completedAt], keeping
  /// the selected calendar end date inclusive without losing completion times
  /// later on that day.
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? toExclusive,
    DateTime? afterOriginalDate,
    String? afterId,
    PrayerType? afterPrayerType,
    DateTime? beforeOriginalDate,
    String? beforeId,
    PrayerType? beforePrayerType,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  });

  /// Returns the oldest pending record directly from the data source.
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  });

  /// Returns only the requested records by id.
  ///
  /// Implementations may override this with an indexed/direct lookup. The
  /// default remains bounded so lightweight repositories keep the contract.
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    var remaining = recordIds.toSet();
    if (remaining.isEmpty) return const <QazaRecord>[];

    final result = <QazaRecord>[];
    DateTime? afterDate;
    PrayerType? afterPrayerType;
    String? afterId;
    while (remaining.isNotEmpty) {
      final page = await getPage(
        userId: userId,
        limit: 500,
        status: null,
        afterOriginalDate: afterDate,
        afterId: afterId,
        afterPrayerType: afterPrayerType,
      );
      if (page.records.isEmpty) break;
      for (final record in page.records) {
        if (remaining.remove(record.id)) result.add(record);
      }
      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
      afterPrayerType = page.nextPrayerType;
    }
    return result;
  }

  /// Resolves only the requested pending records using bounded keyset pages.
  ///
  /// Implementations can override this with a direct indexed lookup. The
  /// default keeps the contract available to lightweight repositories without
  /// requiring them to materialize the full ledger.
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    var remaining = recordIds.toSet();
    if (remaining.isEmpty) return const <QazaRecord>[];

    final result = <QazaRecord>[];
    DateTime? afterDate;
    PrayerType? afterPrayerType;
    String? afterId;

    while (remaining.isNotEmpty) {
      final page = await getPage(
        userId: userId,
        limit: 500,
        status: QazaStatus.pending,
        afterOriginalDate: afterDate,
        afterId: afterId,
        afterPrayerType: afterPrayerType,
      );
      if (page.records.isEmpty) break;

      for (final record in page.records) {
        if (remaining.remove(record.id)) result.add(record);
      }

      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
      afterPrayerType = page.nextPrayerType;
    }

    return result;
  }

  Future<QazaProgressSummary> getProgressSummary({required String userId});

  /// Counts Qaza records completed in the half-open local time range [from, to).
  ///
  /// This is intentionally a targeted aggregate rather than a full-ledger read,
  /// so Home remains responsive with very large Qaza histories.
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  });

  Future<void> addRecord(QazaRecord record);
  Future<void> addRecords(List<QazaRecord> records);

  /// Updates only the editable fields of a Qaza record while preserving its identity.
  Future<bool> updateRecord({required QazaRecord record});

  /// Permanently deletes one Qaza record owned by [userId].
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  });

  /// Attempts to complete one record and reports the persistence outcome.
  ///
  /// Expected stale-state outcomes are returned; unexpected technical failures
  /// remain exceptions.
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,

    /// Exact completion marker to persist for a single-record completion.
    /// Bulk callers leave this null so each record receives its own marker.
    String? completionId,
  });

  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  });

  /// Safely moves selected completed records back to pending when each
  /// completion marker still matches the selected state.
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  });

  /// Permanently deletes every Qaza record belonging to [userId], resetting
  /// that user's Qaza counter to zero.
  ///
  /// Pending and completed records are both removed; records belonging to any
  /// other user are never touched. Implementations must be idempotent so a
  /// replayed reset is harmless.
  Future<void> resetUserRecords({required String userId});
}
