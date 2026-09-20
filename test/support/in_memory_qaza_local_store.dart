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

  /// Targeted like the Drift store's override, so `saveRecords` keeps
  /// counting whole-ledger rewrites and nothing else.
  @override
  Future<List<String>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    final records = _recordsByUser[userId];
    if (records == null) return const <String>[];
    final wanted = recordIds.toSet();
    final changed = <String>[];
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (!wanted.contains(record.id)) continue;
      if (record.status == QazaStatus.completed &&
          record.completedAt != null &&
          !completedAt.isBefore(record.completedAt!)) {
        continue;
      }
      records[index] = record.copyWith(
          status: QazaStatus.completed,
          completedAt: completedAt,
          updatedAt: completedAt);
      changed.add(record.id);
    }
    return changed;
  }

  @override
  Future<void> appendRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final existing = _recordsByUser.putIfAbsent(userId, () => <QazaRecord>[]);
    final known = {for (final record in existing) record.id};
    for (final record in records) {
      if (known.add(record.id)) existing.add(record);
    }
  }

  @override
  Future<List<PendingSyncOp>> loadOutbox(String userId) async =>
      List<PendingSyncOp>.of(_outboxByUser[userId] ?? const <PendingSyncOp>[]);
  @override
  Future<int> countPendingOutbox(String userId) async =>
      (_outboxByUser[userId] ?? const <PendingSyncOp>[]).length;

  @override
  Future<List<PendingSyncOp>> loadOutboxBatch(String userId,
      {int limit = 400}) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    return List<PendingSyncOp>.of(
      (_outboxByUser[userId] ?? const <PendingSyncOp>[]).take(limit),
    );
  }

  @override
  Future<void> markOutboxBatchRetry({
    required String userId,
    required List<String> ids,
    required String error,
  }) async {
    final wanted = ids.toSet();
    final current = _outboxByUser[userId] ?? const <PendingSyncOp>[];
    _outboxByUser[userId] = [
      for (final op in current)
        wanted.contains(op.id)
            ? op.copyWith(attempts: op.attempts + 1, lastError: error)
            : op,
    ];
  }

  @override
  Future<void> removeOutboxBatch(String userId, List<String> ids) async {
    if (ids.isEmpty) return;
    final wanted = ids.toSet();
    final current = _outboxByUser[userId] ?? const <PendingSyncOp>[];
    _outboxByUser[userId] = [
      for (final op in current)
        if (!wanted.contains(op.id)) op,
    ];
  }


  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    _outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }
  @override
  Future<void> appendRecordsAndOutbox(
      String userId, List<QazaRecord> records, List<PendingSyncOp> ops) async {
    await appendRecords(userId, records);
    if (ops.isEmpty) return;
    final current = _outboxByUser.putIfAbsent(userId, () => <PendingSyncOp>[]);
    current.addAll(ops);
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) async {
    final wanted = ids.toSet();
    return [
      for (final record in _recordsByUser[userId] ?? const <QazaRecord>[])
        if (wanted.contains(record.id)) record,
    ];
  }

  @override
  Future<void> upsertRecords(
      String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final existing = _recordsByUser.putIfAbsent(userId, () => <QazaRecord>[]);
    final byId = {for (final record in existing) record.id: record};
    for (final record in records) {
      if (record.userId == userId) byId[record.id] = record;
    }
    existing
      ..clear()
      ..addAll(byId.values);
  }


  @override
  Future<void> retireUserData({required String userId}) async {
    _recordsByUser.remove(userId);
    _outboxByUser.remove(userId);
    _lastSyncByUser.remove(userId);
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
