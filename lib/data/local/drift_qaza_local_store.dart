import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_activity.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_profile_plan_mutation_repository.dart';
import '../../domain/services/qaza_availability_service.dart';
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
      final rawRecords = await _database.qazaRecordsDao.getAll(userId: userId);
      final records = await _withProfilePlanProvenance(userId, rawRecords);
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
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? toExclusive,
    DateTime? afterOriginalDate,
    String? afterId,
    DateTime? beforeOriginalDate,
    String? beforeId,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    final page = await _database.qazaRecordsDao.getKeysetPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType?.name,
      prayerTypes: prayerTypes?.map((value) => value.name),
      status: status?.name,
      additionId: additionId,
      from: from,
      to: to,
      toExclusive: toExclusive,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
      afterCompletedAt: afterCompletedAt,
      beforeCompletedAt: beforeCompletedAt,
      descending: descending,
    );
    final records = await _withProfilePlanProvenance(userId, page.records);
    return LocalQazaPage(records: records, hasMore: page.hasMore);
  }

  @override
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) =>
      _database.qazaRecordsDao.getCompletedActivityRows(
        userId: userId,
        from: from,
        toExclusive: toExclusive,
        prayerTypes: prayerTypes?.map((value) => value.name),
      );

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) =>
      _database.qazaRecordsDao.countCompletedBetween(
        userId: userId,
        from: from,
        to: to,
        prayerTypes: prayerTypes?.map((value) => value.name),
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
  Future<bool> updateRecord(QazaRecord record) => _database.transaction(() async {
        final changed = await _database.qazaRecordsDao.updateRecord(record);
        if (!changed) return false;
        await _syncProfilePlanProvenance(record);
        return true;
      });

  @override
  Future<bool> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    return _database.transaction(() async {
      final deleted = await _database.qazaRecordsDao.deleteById(
        userId: userId,
        id: recordId,
      );
      if (deleted == 0) return false;
      await _deleteProfilePlanProvenance(userId, [recordId]);
      return true;
    });
  }

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
      await _syncProfilePlanProvenance(record);
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
      await _deleteProfilePlanProvenance(userId, [recordId]);
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
      await _replaceProfilePlanProvenance(userId, records);
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
      await _replaceProfilePlanProvenance(userId, records);
      await _database.syncOutboxDao.removeAll(userId: userId);
      await _database.syncOutboxDao.putAll(
        ops.map(_toOpCompanion).toList(growable: false),
      );
    });
  }

  @override
  Future<QazaProfilePlanMutationResult> applyProfilePlanChanges({
    required String userId,
    required List<QazaRecord> additions,
    required List<String> removalIds,
    required Set<String> newPlanKeys,
    required String expectedPreviousPlanFingerprint,
  }) {
    if (!expectedPreviousPlanFingerprint.startsWith('qazaPlanV2Fixed360|') &&
        removalIds.isNotEmpty) {
      throw StateError(
        'Legacy profile-plan revisions cannot authorize automatic removals.',
      );
    }

    return _database.transaction(() async {
      final rawCurrent = await _database.qazaRecordsDao.getByIds(
        userId: userId,
        ids: removalIds,
      );
      final current = await _withProfilePlanProvenance(userId, rawCurrent);
      final byId = {for (final record in current) record.id: record};
      final removed = <QazaRecord>[];

      for (final id in removalIds.toSet()) {
        final record = byId[id];
        if (record == null ||
            record.status != QazaStatus.pending ||
            record.profilePlanRevisionId == null ||
            record.profilePlanFingerprint == null ||
            record.profilePlanFingerprint != expectedPreviousPlanFingerprint) {
          continue;
        }
        if (newPlanKeys.contains(QazaPrayerKey.fromRecord(record).value)) {
          continue;
        }
        removed.add(record);
      }

      final removedIds = removed.map((record) => record.id).toSet();
      if (removedIds.isNotEmpty) {
        for (final id in removedIds) {
          await _database.qazaRecordsDao.deleteById(userId: userId, id: id);
        }
        await _deleteProfilePlanProvenance(
          userId,
          removedIds.toList(growable: false),
        );
      }

      final insertable = <QazaRecord>[];
      final existing = await _database.qazaRecordsDao.getByIds(
        userId: userId,
        ids: additions.map((record) => record.id).toList(growable: false),
      );
      final existingIds = {for (final record in existing) record.id};
      final duplicateKeys = <String>{};
      for (final record in additions) {
        final key = QazaPrayerKey.fromRecord(record).value;
        if (existingIds.contains(record.id) || duplicateKeys.contains(key)) {
          continue;
        }
        if (record.profilePlanRevisionId == null ||
            record.profilePlanFingerprint == null) {
          throw StateError(
            'Profile-generated additions require trustworthy provenance.',
          );
        }
        insertable.add(record);
        duplicateKeys.add(key);
      }

      final insertedIds = await _database.qazaRecordsDao
          .insertRecordsReturningInsertedIds(
        insertable.map(_toCompanion).toList(growable: false),
      );
      final inserted = insertable
          .where((record) => insertedIds.contains(record.id))
          .toList(growable: false);
      await _upsertProfilePlanProvenance(inserted);

      final now = DateTime.now();
      final operations = <PendingSyncOp>[
        for (final record in inserted)
          PendingSyncOp(
            id: 'profile_add_${record.profilePlanRevisionId}_${record.id}',
            type: SyncOpType.add,
            userId: userId,
            queuedAt: now,
            record: record,
            targetRecordId: record.id,
          ),
        for (final record in removed)
          PendingSyncOp(
            id: 'profile_delete_${record.profilePlanRevisionId}_${record.id}',
            type: SyncOpType.delete,
            userId: userId,
            queuedAt: now,
            record: record,
            targetRecordId: record.id,
          ),
      ];
      if (operations.isNotEmpty) {
        await _database.syncOutboxDao.putAll(
          operations.map(_toOpCompanion).toList(growable: false),
        );
      }

      return QazaProfilePlanMutationResult(
        userId: userId,
        added: List.unmodifiable(inserted),
        removed: List.unmodifiable(removed),
        operationIds: List.unmodifiable(
          operations.map((operation) => operation.id),
        ),
      );
    });
  }

  @override
  Future<void> rollbackProfilePlanChanges(
    QazaProfilePlanMutationResult mutation,
  ) {
    return _database.transaction(() async {
      for (final record in mutation.added) {
        final rawCurrent = await _database.qazaRecordsDao.getByIds(
          userId: mutation.userId,
          ids: [record.id],
        );
        final current = await _withProfilePlanProvenance(
          mutation.userId,
          rawCurrent,
        );
        if (current.length != 1) continue;
        final existing = current.single;
        if (existing.profilePlanRevisionId != record.profilePlanRevisionId ||
            existing.profilePlanFingerprint != record.profilePlanFingerprint) {
          continue;
        }
        await _database.qazaRecordsDao.deleteById(
          userId: mutation.userId,
          id: record.id,
        );
        await _deleteProfilePlanProvenance(
          mutation.userId,
          [record.id],
        );
      }

      if (mutation.removed.isNotEmpty) {
        await _database.qazaRecordsDao.insertRecordsReturningInsertedIds(
          mutation.removed.map(_toCompanion).toList(growable: false),
        );
        await _upsertProfilePlanProvenance(mutation.removed);
      }

      await _database.syncOutboxDao.removeBatch(
        userId: mutation.userId,
        ids: mutation.operationIds,
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
        await _upsertProfilePlanProvenance(records);
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
        final insertedIds = await _database.qazaRecordsDao
            .insertRecordsReturningInsertedIds(
          records.map(_toCompanion).toList(growable: false),
        );
        await _upsertProfilePlanProvenance(
          records.where((record) => insertedIds.contains(record.id)).toList(),
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
      await _upsertProfilePlanProvenance(
        records.where((record) => insertedIds.contains(record.id)).toList(),
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
    final records = await _database.qazaRecordsDao.getByIds(
      userId: userId,
      ids: ids,
    );
    return _withProfilePlanProvenance(userId, records);
  }

  @override
  Future<List<PendingSyncOp>> loadOutbox(String userId) async {
    final rows = await _database.syncOutboxDao.getPending(userId: userId);
    return rows.map(_toDomainOp).toList(growable: false);
  }

  /// One indexed UPDATE per id in a single transaction: no snapshot read and
  /// no rewrite of the user's rows.
  @override
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) =>
      _database.qazaRecordsDao.completeByIds(
        userId: userId,
        ids: recordIds,
        completedAt: completedAt,
        completionIds: completionIds,
      );

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) =>
      _database.qazaRecordsDao.markCompletedAsPendingBatch(
        userId: userId,
        expectedCompletionIds: expectedCompletionIds,
        updatedAt: updatedAt,
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
    await _database.transaction(() async {
      final insertedIds = await _database.qazaRecordsDao
          .insertRecordsReturningInsertedIds(
        records.map(_toCompanion).toList(growable: false),
      );
      final inserted = records
          .where((record) => insertedIds.contains(record.id))
          .toList(growable: false);
      await _upsertProfilePlanProvenance(inserted);
    });
  }

  @override
  Future<bool> hasPendingReset(String userId) => _database.syncOutboxDao
      .hasPending(userId: userId, type: SyncOpType.reset.name);

  @override
  Future<void> retireUserData({required String userId}) async {
    await _database.transaction(() async {
      await _database.qazaRecordsDao.deleteAllForUser(userId: userId);
      await _deleteAllProfilePlanProvenance(userId);
      await _database.syncOutboxDao.removeAll(userId: userId);
    });
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    _lastSyncByUser[userId] = lastSync;
  }

  Future<List<QazaRecord>> _withProfilePlanProvenance(
    String userId,
    List<QazaRecord> records,
  ) async {
    if (records.isEmpty) return records;
    final result = <String, QazaRecord>{
      for (final record in records) record.id: record,
    };
    final ids = records.map((record) => record.id).toList(growable: false);

    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.skip(start).take(400).toList(growable: false);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _database.customSelect(
        'SELECT record_id, plan_revision_id, plan_fingerprint '
        'FROM qaza_profile_plan_provenance '
        'WHERE user_id = ? AND record_id IN ($placeholders)',
        variables: [
          Variable.withString(userId),
          ...chunk.map(Variable.withString),
        ],
      ).get();
      for (final row in rows) {
        final id = row.read<String>('record_id');
        final revisionId = row.read<String>('plan_revision_id');
        final fingerprint = row.read<String>('plan_fingerprint');
        final record = result[id];
        if (record != null) {
          result[id] = record.copyWith(
            profilePlanRevisionId: revisionId,
            profilePlanFingerprint: fingerprint,
          );
        }
      }
    }

    return [
      for (final record in records) result[record.id] ?? record,
    ];
  }

  String _sqlStringLiteral(String value) =>
      "'${value.replaceAll("'", "''")}'";

  Future<void> _upsertProfilePlanProvenance(
    Iterable<QazaRecord> records,
  ) async {
    for (final record in records) {
      final revisionId = record.profilePlanRevisionId;
      final fingerprint = record.profilePlanFingerprint;
      if (revisionId == null || fingerprint == null) continue;
      await _database.customStatement(
        'INSERT INTO qaza_profile_plan_provenance '
        '(record_id, user_id, plan_revision_id, plan_fingerprint) '
        'VALUES (${_sqlStringLiteral(record.id)}, '
        '${_sqlStringLiteral(record.userId)}, '
        '${_sqlStringLiteral(revisionId)}, '
        '${_sqlStringLiteral(fingerprint)}) '
        'ON CONFLICT(record_id) DO UPDATE SET '
        'user_id = excluded.user_id, '
        'plan_revision_id = excluded.plan_revision_id, '
        'plan_fingerprint = excluded.plan_fingerprint',
      );
    }
  }

  Future<void> _deleteProfilePlanProvenance(
    String userId,
    Iterable<String> recordIds,
  ) async {
    final ids = recordIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.skip(start).take(400).toList(growable: false);
      final placeholders =
          chunk.map(_sqlStringLiteral).join(', ');
      await _database.customStatement(
        'DELETE FROM qaza_profile_plan_provenance '
        'WHERE user_id = ${_sqlStringLiteral(userId)} '
        'AND record_id IN ($placeholders)',
      );
    }
  }

  Future<void> _deleteAllProfilePlanProvenance(String userId) =>
      _database.customStatement(
        'DELETE FROM qaza_profile_plan_provenance '
        'WHERE user_id = ${_sqlStringLiteral(userId)}',
      );

  Future<void> _replaceProfilePlanProvenance(
    String userId,
    Iterable<QazaRecord> records,
  ) async {
    await _deleteAllProfilePlanProvenance(userId);
    await _upsertProfilePlanProvenance(records);
  }

  Future<void> _syncProfilePlanProvenance(QazaRecord record) async {
    if (record.profilePlanRevisionId == null ||
        record.profilePlanFingerprint == null) {
      await _deleteProfilePlanProvenance(record.userId, [record.id]);
      return;
    }
    await _upsertProfilePlanProvenance([record]);
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
