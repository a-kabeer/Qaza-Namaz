import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';

/// Ephemeral QazaLocalStore used by tests as a deterministic local-store double.
class InMemoryQazaLocalStore extends QazaLocalStore {
  final Map<String, List<QazaRecord>> _recordsByUser = {};
  final Map<String, List<PendingSyncOp>> _outboxByUser = {};
  final Map<String, DateTime> _lastSyncByUser = {};

  int loadCalls = 0;
  int historyPageCalls = 0;
  int progressSummaryCalls = 0;

  @override
  Future<OfflineCacheSnapshot> load() async {
    loadCalls++;
    return OfflineCacheSnapshot(
      recordsByUser: {
        for (final entry in _recordsByUser.entries)
          entry.key: List<QazaRecord>.of(entry.value),
      },
      outboxByUser: {
        for (final entry in _outboxByUser.entries)
          entry.key: List<PendingSyncOp>.of(entry.value),
      },
      lastSyncByUser: Map<String, DateTime>.of(_lastSyncByUser),
    );
  }

  @override
  Future<LocalQazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    }
    var records = (_recordsByUser[userId] ?? const <QazaRecord>[])
        .where(
            (record) => prayerType == null || record.prayerType == prayerType)
        .where((record) => status == null || record.status == status)
        .where((record) => from == null || !record.originalDate.isBefore(from))
        .where((record) => to == null || !record.originalDate.isAfter(to))
        .where(
          (record) =>
              afterOriginalDate == null ||
              record.originalDate.isAfter(afterOriginalDate) ||
              (record.originalDate.isAtSameMomentAs(afterOriginalDate) &&
                  record.id.compareTo(afterId!) > 0),
        )
        .toList()
      ..sort((a, b) {
        final byDate = a.originalDate.compareTo(b.originalDate);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    final hasMore = records.length > limit;
    return LocalQazaPage(
      records:
          (hasMore ? records.take(limit) : records).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final page = await getPage(
      userId: userId,
      limit: 1,
      prayerType: prayerType,
      status: QazaStatus.pending,
    );
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<LocalQazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    historyPageCalls++;
    var records = _recordsByUser[userId] ?? const <QazaRecord>[];
    records = records
        .where(
            (record) => prayerType == null || record.prayerType == prayerType)
        .where((record) => status == null || record.status == status)
        .where((record) => from == null || !record.originalDate.isBefore(from))
        .where((record) => to == null || !record.originalDate.isAfter(to))
        .where(
          (record) =>
              beforeOriginalDate == null ||
              record.originalDate.isBefore(beforeOriginalDate) ||
              (record.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                  record.id.compareTo(beforeId!) < 0),
        )
        .toList()
      ..sort((a, b) {
        final byDate = b.originalDate.compareTo(a.originalDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    final hasMore = records.length > limit;
    return LocalQazaHistoryPage(
      records:
          (hasMore ? records.take(limit) : records).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    progressSummaryCalls++;
    return QazaProgressSummary.fromRecords(
      _recordsByUser[userId] ?? const <QazaRecord>[],
    );
  }

  /// Bounded like the Drift store's override, so `loadCalls` keeps measuring
  /// full-snapshot reads rather than counting this probe as one.
  @override
  Future<bool> hasPendingReset(String userId) async =>
      (_outboxByUser[userId] ?? const <PendingSyncOp>[])
          .any((op) => op.type == SyncOpType.reset);

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    _recordsByUser[userId] = List<QazaRecord>.of(records);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    _outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    if (lastSync == null) {
      _lastSyncByUser.remove(userId);
    } else {
      _lastSyncByUser[userId] = lastSync;
    }
  }
}
