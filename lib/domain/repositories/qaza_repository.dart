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
  String? get nextId => records.isEmpty ? null : records.last.id;
}

class QazaHistoryPage {
  const QazaHistoryPage({required this.records, required this.hasMore});

  final List<QazaRecord> records;
  final bool hasMore;

  DateTime? get nextOriginalDate =>
      records.isEmpty ? null : records.last.originalDate;
  String? get nextId => records.isEmpty ? null : records.last.id;
}

abstract interface class QazaRepository {
  /// Legacy full-ledger API. New production UI should use [getPage].
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  });

  /// Bounded ascending keyset page for scalable ledger screens.
  ///
  /// [from] and [to] bound the original Qaza date inclusively, so status,
  /// prayer and date filtering all happen in the data source rather than in
  /// Dart over a materialized ledger.
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  });

  /// Returns the oldest pending record directly from the data source.
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  });

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
    String? afterId;

    while (remaining.isNotEmpty) {
      final page = await getPage(
        userId: userId,
        limit: 500,
        status: QazaStatus.pending,
        afterOriginalDate: afterDate,
        afterId: afterId,
      );
      if (page.records.isEmpty) break;

      for (final record in page.records) {
        if (remaining.remove(record.id)) result.add(record);
      }

      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }

    return result;
  }

  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  });

  Future<QazaProgressSummary> getProgressSummary({required String userId});

  /// Counts Qaza records completed in the half-open local time range [from, to).
  ///
  /// This is intentionally a targeted aggregate rather than a full-ledger read,
  /// so Home remains responsive with very large Qaza histories.
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  Future<void> addRecord(QazaRecord record);
  Future<void> addRecords(List<QazaRecord> records);

  /// Updates only the editable fields of a Qaza record while preserving its identity.
  Future<void> updateRecord({required QazaRecord record});

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
  });

  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  });

  /// Permanently deletes every Qaza record belonging to [userId], resetting
  /// that user's Qaza counter to zero.
  ///
  /// Pending and completed records are both removed; records belonging to any
  /// other user are never touched. Implementations must be idempotent so a
  /// replayed reset is harmless.
  Future<void> resetUserRecords({required String userId});
}
