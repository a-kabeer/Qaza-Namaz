import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import 'database/app_database.dart';
import 'database/tables/qaza_records.dart';
import 'database/tables/sync_outbox.dart';
import 'qaza_local_store.dart';
import 'shared_preferences_qaza_local_store.dart';

class DriftQazaLocalStore implements QazaLocalStore {
  DriftQazaLocalStore({required AppDatabase database, SharedPreferencesQazaLocalStore? legacyStore})
      : _database = database,
        _legacyStore = legacyStore ?? SharedPreferencesQazaLocalStore();

  final AppDatabase _database;
  final SharedPreferencesQazaLocalStore _legacyStore;

  @override
  Future<OfflineCacheSnapshot> load() async {
    final users = await _database.qazaRecordsDao.userIds();
    final outboxUsers = await _database.syncOutboxDao.userIds();
    final allUsers = {...users, ...outboxUsers};
    final recordsByUser = <String, List<QazaRecord>>{};
    final outboxByUser = <String, List<PendingSyncOp>>{};
    final legacy = await _legacyStore.load();
    for (final userId in allUsers) {
      final records = await _database.qazaRecordsDao.getAll(userId: userId);
      final ops = await _database.syncOutboxDao.getPending(userId: userId);
      recordsByUser[userId] = List<QazaRecord>.unmodifiable(records);
      outboxByUser[userId] = ops.map(_toDomainOp).toList(growable: false);
    }
    return OfflineCacheSnapshot(
      recordsByUser: recordsByUser,
      outboxByUser: outboxByUser,
      lastSyncByUser: legacy.lastSyncByUser,
    );
  }

  @override
  Future<LocalQazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? afterOriginalDate,
    String? afterId,
  }) async {
    final page = await _database.qazaRecordsDao.getKeysetPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType?.name,
      status: status?.name,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
    );
    return LocalQazaPage(records: page.records, hasMore: page.hasMore);
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
    final page = await _database.qazaRecordsDao.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType?.name,
      status: status?.name,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    return LocalQazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    final counts = await _database.qazaRecordsDao.getProgressCounts(userId: userId);
    final pending = <PrayerType, int>{for (final prayer in PrayerType.values) prayer: 0};
    final completed = <PrayerType, int>{for (final prayer in PrayerType.values) prayer: 0};

    for (final entry in counts.entries) {
      pending[entry.key] = entry.value[QazaStatus.pending] ?? 0;
      completed[entry.key] = entry.value[QazaStatus.completed] ?? 0;
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

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    await _database.transaction(() async {
      await _database.qazaRecordsDao.replaceUserRecords(
        userId: userId,
        records: records.map(_toCompanion).toList(growable: false),
      );
    });
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    await _database.transaction(() async {
      await _database.syncOutboxDao.removeAll(userId: userId);
      await _database.syncOutboxDao.putAll(
        ops.map(_toOpCompanion).toList(growable: false),
      );
    });
  }

  @override
  Future<void> saveRecordsAndOutbox(
    String userId,
    List<QazaRecord> records,
    List<PendingSyncOp> ops,
  ) async {
    await _database.transaction(() async {
      await _database.qazaRecordsDao.replaceUserRecords(
        userId: userId,
        records: records.map(_toCompanion).toList(growable: false),
      );
      await _database.syncOutboxDao.removeAll(userId: userId);
      await _database.syncOutboxDao.putAll(
        ops.map(_toOpCompanion).toList(growable: false),
      );
    });
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) =>
      _legacyStore.saveLastSync(userId, lastSync);

  PendingSyncOp _toDomainOp(SyncOutboxData row) => PendingSyncOp(
        id: row.id,
        type: SyncOpType.values.firstWhere((value) => value.name == row.type),
        userId: row.userId,
        queuedAt: row.queuedAt,
        record: row.recordJson == null
            ? null
            : QazaRecord.fromJson(
                jsonDecode(row.recordJson!) as Map<String, dynamic>,
              ),
        targetRecordId: row.targetRecordId,
        completedAt: row.completedAt,
        attempts: row.attempts,
        lastError: row.lastError,
      );

  QazaRecordsCompanion _toCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
        id: record.id,
        userId: record.userId,
        prayerType: record.prayerType.name,
        originalDate: record.originalDate,
        status: record.status.name,
        completedAt: record.completedAt == null
            ? const Value.absent()
            : Value(record.completedAt),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );

  SyncOutboxCompanion _toOpCompanion(PendingSyncOp op) =>
      SyncOutboxCompanion.insert(
        id: op.id,
        userId: op.userId,
        type: op.type.name,
        queuedAt: op.queuedAt,
        recordJson: op.record == null
            ? const Value.absent()
            : Value(jsonEncode(op.record!.toJson())),
        targetRecordId: op.targetRecordId == null
            ? const Value.absent()
            : Value(op.targetRecordId),
        completedAt: op.completedAt == null
            ? const Value.absent()
            : Value(op.completedAt),
        attempts: Value(op.attempts),
        lastError: op.lastError == null
            ? const Value.absent()
            : Value(op.lastError),
      );
}
