import '../../core/constants/prayer_types.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';

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

  Future<void> addRecord(QazaRecord record);
  Future<void> addRecords(List<QazaRecord> records);

  Future<void> completeRecord({
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
