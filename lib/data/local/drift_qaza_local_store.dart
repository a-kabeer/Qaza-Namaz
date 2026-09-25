import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_recovery_repository.dart';
import 'database/app_database.dart';
import 'qaza_local_store.dart';

/// Production local store backed exclusively by Drift/SQLite.
///
/// SharedPreferences is intentionally not part of the runtime persistence
/// path. It is retained only by the one-time migration bootstrap so existing
/// installations can be upgraded safely.
class DriftQazaLocalStore extends QazaLocalStore {
  DriftQazaLocalStore({required AppDatabase database}) : _database = database;

  final AppDatabase _database;
  final Map<String, DateTime?> _lastSyncByUser = <String, DateTime?>{};

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
      recordsByUser[userId] = List<QazaRecord>.unmodifiable(records);
      outboxByUser[userId] = ops.map(_toDomainOp).toList(growable: false);
    }

    return OfflineCacheSnapshot(
      recordsByUser: recordsByUser,
      outboxByUser: outboxByUser,
      lastSyncByUser: {
        for (final entry in _lastSyncByUser.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
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
    final page = await _database.qazaRecordsDao.getKeysetPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType?.name,
      status: status?.name,
      from: from,
      to: to,
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
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) =>
      _database.qazaRecordsDao.countCompletedBetween(
        userId: userId,
        from: from,
        to: to,
      );

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    final counts =
        await _database.qazaRecordsDao.getProgressCounts(userId: userId);
    final pending = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0
    };
    final completed = <PrayerType, int>{
      for (final prayer in PrayerType.values) prayer: 0
    };

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
  Future<LocalQazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    final page = await _database.qazaRecordsDao.getOperationPage(
      userId: userId,
      operationId: operationId,
      matchLastAction: matchLastAction,
      operationAt: operationAt,
      status: status,
      limit: limit,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    return LocalQazaPage(
      records: page.records,
      hasMore: page.hasMore,
    );
  }

  @override
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) =>
      _database.qazaRecordsDao.getOperationSummary(
        userId: userId,
        operationId: operationId,
      );

  @override
  Future<bool> hasRecordCombination({
    required String userId,
    required PrayerType prayerType,
    required DateTime originalDate,
    String? excludingRecordId,
  }) =>
      _database.qazaRecordsDao.hasRecordCombination(
        userId: userId,
        prayerType: prayerType.name,
        originalDate: originalDate,
        excludingRecordId: excludingRecordId,
      );

  @override
  Future<List<QazaRecord>> softDeletePendingIfUnchanged({
    required String userId,
    required List<String> recordIds,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
    required String operationId,
  }) async {
    if (recordIds.isEmpty) return const <QazaRecord>[];

    return _database.transaction(() async {
      final changed =
          await _database.qazaRecordsDao.softDeletePendingIfUnchangedByIds(
        userId: userId,
        ids: recordIds,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: deletedAt,
      );
      if (changed.isEmpty) return const <QazaRecord>[];

      final ops = <PendingSyncOp>[
        for (final record in changed)
          PendingSyncOp(
            id: 'soft_delete_${record.id}_$operationId',
            type: SyncOpType.update,
            userId: userId,
            queuedAt: deletedAt,
            targetRecordId: record.id,
            record: record,
          ),
      ];

      await _database.syncOutboxDao.putAll(
        ops.map(_toOpCompanion).toList(growable: false),
      );
      return changed;
    });
  }

  @override
  Future<bool> updateRecord(QazaRecord record) => _database.transaction(
        () => _database.qazaRecordsDao.updateRecord(record),
      );

  @override
  Future<bool> deleteRecord({
    required String userId,
    required String recordId,
  }) =>
      _database
          .transaction(
            () => _database.qazaRecordsDao.deleteById(
              userId: userId,
              id: recordId,
            ),
          )
          .then((count) => count > 0);

  @override
  Future<bool> updateRecordAndOutbox({
    required String userId,
    required QazaRecord record,
    required PendingSyncOp operation,
  }) async {
    if (record.userId != userId || operation.userId != userId) {
      throw StateError('Cannot persist data for a different user.');
    }
    return _database.transaction(() async {
      final changed = await _database.qazaRecordsDao.updateRecord(record);
      if (!changed) return false;
      await _database.syncOutboxDao.putAll([_toOpCompanion(operation)]);
      return true;
    });
  }

  @override
  Future<bool> deleteRecordAndOutbox({
    required String userId,
    required String recordId,
    required PendingSyncOp operation,
  }) async {
    if (operation.userId != userId) {
      throw StateError('Cannot queue sync data for a different user.');
    }
    return _database.transaction(() async {
      final deleted = await _database.qazaRecordsDao.deleteById(
        userId: userId,
        id: recordId,
      );
      if (deleted == 0) return false;
      await _database.syncOutboxDao.putAll([_toOpCompanion(operation)]);
      return true;
    });
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
  Future<int> countPendingOutbox(String userId) =>
      _database.syncOutboxDao.countPending(userId: userId);

  @override
  Future<List<PendingSyncOp>> loadOutboxBatch(String userId,
      {int limit = 400}) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    final rows = await _database.syncOutboxDao.getPendingBatch(
      userId: userId,
      limit: limit,
    );
    return rows.map(_toDomainOp).toList(growable: false);
  }

  @override
  Future<void> removeOutboxBatch(String userId, List<String> ids) =>
      _database.syncOutboxDao.removeBatch(userId: userId, ids: ids);

  @override
  Future<void> markOutboxBatchRetry({
    required String userId,
    required List<String> ids,
    required String error,
  }) async {
    await _database.syncOutboxDao.markBatchRetry(
      userId: userId,
      ids: ids,
      error: error,
    );
  }

  @override
  Future<void> upsertRecordsAndOutbox({
    required String userId,
    required List<QazaRecord> records,
    required List<PendingSyncOp> ops,
  }) async {
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    for (final op in ops) {
      if (op.userId != userId) {
        throw StateError('Cannot queue a sync operation for a different user.');
      }
    }
    await _database.transaction(() async {
      if (records.isNotEmpty) {
        await _database.qazaRecordsDao.upsertRecords(
          records.map(_toCompanion).toList(growable: false),
        );
      }
      if (ops.isNotEmpty) {
        await _database.syncOutboxDao.putAll(
          ops.map(_toOpCompanion).toList(growable: false),
        );
      }
    });
  }

  @override
  Future<void> appendRecordsAndOutbox(
      String userId, List<QazaRecord> records, List<PendingSyncOp> ops) async {
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    for (final op in ops) {
      if (op.userId != userId) {
        throw StateError('Cannot queue a sync operation for a different user.');
      }
    }
    await _database.transaction(() async {
      if (records.isNotEmpty) {
        await _database.qazaRecordsDao.insertRecords(
          records.map(_toCompanion).toList(growable: false),
        );
      }
      if (ops.isNotEmpty) {
        await _database.syncOutboxDao.putAll(
          ops.map(_toOpCompanion).toList(growable: false),
        );
      }
    });
  }

  @override
  Future<List<String>> appendRecordsAndOutboxReturningInsertedIds({
    required String userId,
    required List<QazaRecord> records,
    required List<PendingSyncOp> ops,
  }) async {
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    for (final op in ops) {
      if (op.userId != userId) {
        throw StateError('Cannot queue a sync operation for a different user.');
      }
    }

    return _database.transaction(() async {
      final insertedIds = records.isEmpty
          ? const <String>[]
          : await _database.qazaRecordsDao.insertRecordsReturningInsertedIds(
              records.map(_toCompanion).toList(growable: false),
            );
      final inserted = insertedIds.toSet();
      final insertedOps = [
        for (final op in ops)
          if (op.record == null || inserted.contains(op.record!.id)) op,
      ];
      if (insertedOps.isNotEmpty) {
        await _database.syncOutboxDao.putAll(
          insertedOps.map(_toOpCompanion).toList(growable: false),
        );
      }
      return insertedIds;
    });
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const <QazaRecord>[];
    // The DAO already decodes its rows into domain records. This used to
    // rebuild them a second time, re-parsing the enums off a QazaRecord as if
    // it were a table row; `value.name == record.prayerType` compares a String
    // to a PrayerType, which is never equal, so every non-empty lookup threw
    // "Unknown prayer type". That is the exception Home was reporting as
    // "Qaza cannot be completed" after the record had in fact been saved.
    return _database.qazaRecordsDao.getByIds(userId: userId, ids: ids);
  }

  @override
  Future<List<PendingSyncOp>> loadOutbox(String userId) async {
    final rows = await _database.syncOutboxDao.getPending(userId: userId);
    return rows.map(_toDomainOp).toList(growable: false);
  }

  /// One indexed UPDATE per id in a single transaction: no snapshot read and
  /// no rewrite of the user's rows.
  @override
  Future<List<String>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) =>
      _database.qazaRecordsDao.completeByIds(
        userId: userId,
        ids: recordIds,
        completedAt: completedAt,
      );

  @override
  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) =>
      _database.qazaRecordsDao.undoCompletions(
        userId: userId,
        expectedCompletionIds: expectedCompletionIds,
        undoneAt: undoneAt,
      );

  @override
  Future<List<QazaRecord>> undoCompletionsAndQueue({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletionIds.isEmpty) {
      return const <QazaRecord>[];
    }

    return _database.transaction(() async {
      final changed = await _database.qazaRecordsDao.undoCompletions(
        userId: userId,
        expectedCompletionIds: expectedCompletionIds,
        undoneAt: undoneAt,
      );
      if (changed.isEmpty) return const <QazaRecord>[];

      final operations = <PendingSyncOp>[
        for (final record in changed)
          PendingSyncOp(
            id: 'undo_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
            type: SyncOpType.update,
            userId: userId,
            queuedAt: record.updatedAt,
            targetRecordId: record.id,
            completionId: expectedCompletionIds[record.id],
            record: record,
          ),
      ];
      await _database.syncOutboxDao.putAll(
        operations.map(_toOpCompanion).toList(growable: false),
      );
      return changed;
    });
  }

  @override
  Future<void> upsertRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    await _database.transaction(() async {
      await _database.qazaRecordsDao.upsertRecords(
        records.map(_toCompanion).toList(growable: false),
      );
    });
  }

  /// Inserts only the new rows; existing ones are left untouched.
  @override
  Future<void> appendRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    await _database.qazaRecordsDao.insertRecords(
      records.map(_toCompanion).toList(growable: false),
    );
  }

  @override
  Future<bool> hasPendingReset(String userId) => _database.syncOutboxDao
      .hasPending(userId: userId, type: SyncOpType.reset.name);

  @override
  Future<void> retireUserData({required String userId}) async {
    await _database.transaction(() async {
      await _database.qazaRecordsDao.deleteAllForUser(userId: userId);
      await _database.syncOutboxDao.removeAll(userId: userId);
    });
  }

  @override
  Future<LocalQazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) async {
    final page = await _database.qazaRecordsDao.getRecentlyDeletedPage(
      userId: userId,
      limit: limit,
      beforeDeletedAt: beforeDeletedAt,
      beforeId: beforeId,
    );
    return LocalQazaHistoryPage(
      records: page.records,
      hasMore: page.hasMore,
    );
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    _lastSyncByUser[userId] = lastSync;
  }

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
        completionId: row.completionId,
        attempts: row.attempts,
        lastError: row.lastError,
      );

  QazaRecordsCompanion _toCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
        id: record.id,
        userId: record.userId,
        operationId: Value(record.operationId),
        prayerType: record.prayerType.name,
        originalDate: record.originalDate,
        status: record.status.name,
        completedAt: record.completedAt == null
            ? const Value.absent()
            : Value(record.completedAt),
        completionId: record.completionId == null
            ? const Value.absent()
            : Value(record.completionId),
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
        completionId: op.completionId == null
            ? const Value.absent()
            : Value(op.completionId),
        attempts: Value(op.attempts),
        lastError:
            op.lastError == null ? const Value.absent() : Value(op.lastError),
      );
}
