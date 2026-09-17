import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import 'database/app_database.dart';
import 'database/tables/qaza_records.dart';
import 'database/tables/sync_outbox.dart';
import 'qaza_local_store.dart';

/// SQLite-backed local store used by the production offline-first repository.
///
/// Records and outbox entries are normalized and user-scoped. Legacy
/// SharedPreferences data is migrated before this store becomes active.
class DriftQazaLocalStore implements QazaLocalStore {
  DriftQazaLocalStore({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  @override
  Future<OfflineCacheSnapshot> load() async {
    final users = await _database.qazaRecordsDao.userIds();
    final outboxUsers = await _database.syncOutboxDao.userIds();
    final allUsers = {...users, ...outboxUsers};
    final recordsByUser = <String, List<QazaRecord>>{};
    final outboxByUser = <String, List<PendingSyncOp>>{};

    for (final userId in allUsers) {
      final records = await _database.qazaRecordsDao.getAll(userId: userId);
      final ops = await _database.syncOutboxDao.getPending(userId: userId);
      recordsByUser[userId] = records.map(_toDomain).toList(growable: false);
      outboxByUser[userId] = ops.map(_toDomainOp).toList(growable: false);
    }

    return OfflineCacheSnapshot(
      recordsByUser: recordsByUser,
      outboxByUser: outboxByUser,
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
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    // Sync metadata is maintained by the repository until its dedicated
    // metadata table is introduced in the schema-versioning phase.
    // No SharedPreferences writes occur on the production path.
  }

  QazaRecord _toDomain(dynamic row) => QazaRecord(
        id: row.id as String,
        userId: row.userId as String,
        prayerType: PrayerType.values.firstWhere((v) => v.name == row.prayerType),
        originalDate: row.originalDate as DateTime,
        status: QazaStatus.values.firstWhere((v) => v.name == row.status),
        completedAt: row.completedAt as DateTime?,
        createdAt: row.createdAt as DateTime,
        updatedAt: row.updatedAt as DateTime,
      );

  PendingSyncOp _toDomainOp(dynamic row) => PendingSyncOp(
        id: row.id as String,
        type: SyncOpType.values.firstWhere((v) => v.name == row.type),
        userId: row.userId as String,
        queuedAt: row.queuedAt as DateTime,
        record: row.recordJson == null
            ? null
            : QazaRecord.fromJson(jsonDecode(row.recordJson as String) as Map<String, dynamic>),
        targetRecordId: row.targetRecordId as String?,
        completedAt: row.completedAt as DateTime?,
        attempts: row.attempts as int,
        lastError: row.lastError as String?,
      );

  QazaRecordsCompanion _toCompanion(QazaRecord record) => QazaRecordsCompanion.insert(
        id: record.id,
        userId: record.userId,
        prayerType: record.prayerType.name,
        originalDate: record.originalDate,
        status: record.status.name,
        completedAt: record.completedAt == null ? const Value.absent() : Value(record.completedAt),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );

  SyncOutboxCompanion _toOpCompanion(PendingSyncOp op) => SyncOutboxCompanion.insert(
        id: op.id,
        userId: op.userId,
        type: op.type.name,
        queuedAt: op.queuedAt,
        recordJson: op.record == null ? const Value.absent() : Value(jsonEncode(op.record!.toJson())),
        targetRecordId: op.targetRecordId == null ? const Value.absent() : Value(op.targetRecordId),
        completedAt: op.completedAt == null ? const Value.absent() : Value(op.completedAt),
        attempts: Value(op.attempts),
        lastError: op.lastError == null ? const Value.absent() : Value(op.lastError),
      );
}
