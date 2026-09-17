import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import 'database/app_database.dart';
import 'database/tables/sync_outbox.dart';
import 'qaza_local_store.dart';
import 'shared_preferences_qaza_local_store.dart';

/// Transitional local store used during the database migration.
///
/// Qaza records remain in the existing SharedPreferences cache until Part 6,
/// while the synchronization outbox is durable in SQLite. Existing legacy
/// outbox entries are imported on first load so queued work cannot disappear
/// when the provider switches to this store.
class DriftQazaLocalStore implements QazaLocalStore {
  DriftQazaLocalStore({
    required AppDatabase database,
    SharedPreferencesQazaLocalStore? legacyStore,
  })  : _database = database,
        _legacyStore = legacyStore ?? SharedPreferencesQazaLocalStore();

  final AppDatabase _database;
  final SharedPreferencesQazaLocalStore _legacyStore;

  @override
  Future<OfflineCacheSnapshot> load() async {
    final legacy = await _legacyStore.load();
    final outboxByUser = <String, List<PendingSyncOp>>{};
    final users = legacy.recordsByUser.keys
        .followedBy(legacy.outboxByUser.keys)
        .toSet();

    for (final userId in users) {
      final legacyOps = legacy.outboxByUser[userId] ?? const <PendingSyncOp>[];
      final existing = await _database.syncOutboxDao.getPending(userId: userId);

      // Import the legacy queue only when SQLite does not already contain it.
      // This makes the provider transition one-way without duplicating rows.
      if (existing.isEmpty && legacyOps.isNotEmpty) {
        await _database.syncOutboxDao.putAll(
          legacyOps.map(_toCompanion).toList(growable: false),
        );
      }

      final rows = existing.isEmpty && legacyOps.isNotEmpty
          ? await _database.syncOutboxDao.getPending(userId: userId)
          : existing;
      outboxByUser[userId] = rows.map(_toDomain).toList(growable: false);
    }

    return OfflineCacheSnapshot(
      recordsByUser: legacy.recordsByUser,
      outboxByUser: outboxByUser,
      lastSyncByUser: legacy.lastSyncByUser,
    );
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) {
    return _legacyStore.saveRecords(userId, records);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    await _database.syncOutboxDao.removeAll(userId: userId);
    if (ops.isEmpty) return;
    await _database.syncOutboxDao.putAll(
      ops.map(_toCompanion).toList(growable: false),
    );
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) {
    return _legacyStore.saveLastSync(userId, lastSync);
  }

  PendingSyncOp _toDomain(SyncOutboxData row) {
    return PendingSyncOp(
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
  }

  SyncOutboxCompanion _toCompanion(PendingSyncOp op) {
    return SyncOutboxCompanion.insert(
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
}
