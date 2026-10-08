import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_activity.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_bulk_delete_repository.dart';
import '../../domain/repositories/qaza_profile_plan_mutation_repository.dart';
import '../../domain/services/qaza_availability_service.dart';
import 'database/app_database.dart';
import 'qaza_local_store.dart';

/// Production local store backed exclusively by Drift/SQLite.
///
/// SharedPreferences is intentionally not part of the runtime persistence
/// path. It is retained only by the one-time migration bootstrap so existing
/// installations can be upgraded safely.
class DriftQazaLocalStore extends QazaLocalStore
    implements QazaBulkDeleteRepository {
  DriftQazaLocalStore({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  @override
  Future<OfflineCacheSnapshot> load() async {
    final users = await _database.qazaRecordsDao.userIds();
    final recordsByUser = <String, List<QazaRecord>>{};

    for (final userId in users) {
      final rawRecords = await _database.qazaRecordsDao.getAll(userId: userId);
      recordsByUser[userId] = List<QazaRecord>.unmodifiable(
        await _withProfilePlanProvenance(userId, rawRecords),
      );
    }

    return OfflineCacheSnapshot(recordsByUser: recordsByUser);
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
    PrayerType? afterPrayerType,
    DateTime? beforeOriginalDate,
    String? beforeId,
    PrayerType? beforePrayerType,
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
      afterPrayerType: afterPrayerType?.name,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
      beforePrayerType: beforePrayerType?.name,
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
  Future<int> deleteRecords({
    required String userId,
    required List<String> recordIds,
  }) async {
    if (recordIds.isEmpty) return 0;
    return _database.transactionWithRevision(() async {
      final unique = recordIds.toSet().toList(growable: false);
      var deleted = 0;
      for (var start = 0; start < unique.length; start += 400) {
        final end = start + 400 < unique.length ? start + 400 : unique.length;
        final ids = unique.sublist(start, end);
        deleted += await _database.qazaRecordsDao.deleteByIds(
          userId: userId,
          ids: ids,
        );
        await _deleteProfilePlanProvenance(userId, ids);
      }
      return deleted;
    });
  }

  @override
  Future<bool> updateRecord(QazaRecord record) =>
      _database.transactionWithRevision(() async {
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
    return _database.transactionWithRevision(() async {
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
  }) {
    if (record.userId != userId || operation.userId != userId) {
      throw StateError('Cannot persist data for a different user.');
    }
    return updateRecord(record);
  }

  @override
  Future<bool> deleteRecordAndOutbox({
    required String userId,
    required String recordId,
    required PendingSyncOp operation,
  }) {
    if (operation.userId != userId) {
      throw StateError('Cannot persist data for a different user.');
    }
    return deleteRecord(userId: userId, recordId: recordId);
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    await _database.transactionWithRevision(() async {
      await _database.qazaRecordsDao.replaceUserRecords(
        userId: userId,
        records: records.map(_toCompanion).toList(growable: false),
      );
      await _replaceProfilePlanProvenance(userId, records);
    });
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {}

  @override
  Future<void> saveRecordsAndOutbox(
    String userId,
    List<QazaRecord> records,
    List<PendingSyncOp> ops,
  ) =>
      saveRecords(userId, records);

  @override
  Future<QazaProfilePlanMutationResult> applyProfilePlanChanges({
    required String userId,
    required List<QazaRecord> additions,
    required List<String> removalIds,
    required Set<String> newPlanKeys,
    required String expectedPreviousPlanFingerprint,
    void Function(int processed, int total)? onProgress,
  }) {
    if (!expectedPreviousPlanFingerprint.startsWith('qazaPlanV2Fixed360|') &&
        removalIds.isNotEmpty) {
      throw StateError(
        'Legacy profile-plan revisions cannot authorize automatic removals.',
      );
    }

    return _database.transactionWithRevision(() async {
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

      final totalWork = removalIds.toSet().length + additions.length;
      var processedWork = 0;
      onProgress?.call(0, totalWork);

      final removedIds =
          removed.map((record) => record.id).toList(growable: false);
      for (var start = 0; start < removedIds.length; start += 400) {
        final end =
            start + 400 < removedIds.length ? start + 400 : removedIds.length;
        final chunkIds = removedIds.sublist(start, end);
        await _database.qazaRecordsDao.deleteByIds(
          userId: userId,
          ids: chunkIds,
        );
        await _deleteProfilePlanProvenance(userId, chunkIds);
        processedWork += chunkIds.length;
        onProgress?.call(processedWork, totalWork);
      }
      final requestedRemovalCount = removalIds.toSet().length;
      if (processedWork < requestedRemovalCount) {
        processedWork = requestedRemovalCount;
        onProgress?.call(processedWork, totalWork);
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

      final inserted = <QazaRecord>[];
      for (var start = 0; start < insertable.length; start += 500) {
        final end =
            start + 500 < insertable.length ? start + 500 : insertable.length;
        final chunk = insertable.sublist(start, end);
        final insertedIds =
            await _database.qazaRecordsDao.insertRecordsReturningInsertedIds(
          chunk.map(_toCompanion).toList(growable: false),
        );
        final insertedChunk = chunk
            .where((record) => insertedIds.contains(record.id))
            .toList(growable: false);
        inserted.addAll(insertedChunk);
        await _upsertProfilePlanProvenance(insertedChunk);
        processedWork += chunk.length;
        onProgress?.call(processedWork, totalWork);
      }

      return QazaProfilePlanMutationResult(
        userId: userId,
        added: List.unmodifiable(inserted),
        removed: List.unmodifiable(removed),
        operationIds: const <String>[],
      );
    });
  }

  @override
  Future<void> rollbackProfilePlanChanges(
    QazaProfilePlanMutationResult mutation,
  ) {
    return _database.transactionWithRevision(() async {
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
    });
  }

  @override
  Future<int> countPendingOutbox(String userId) async => 0;

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
  Future<List<PendingSyncOp>> loadOutbox(String userId) async =>
      const <PendingSyncOp>[];

  /// One indexed UPDATE per id in a single transaction: no snapshot read and
  /// no rewrite of the user's rows.
  @override
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) =>
      _database.transactionWithRevision(
        () => _database.qazaRecordsDao.completeByIds(
          userId: userId,
          ids: recordIds,
          completedAt: completedAt,
          completionIds: completionIds,
        ),
      );

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) =>
      _database.transactionWithRevision(
        () => _database.qazaRecordsDao.markCompletedAsPendingBatch(
          userId: userId,
          expectedCompletionIds: expectedCompletionIds,
          updatedAt: updatedAt,
        ),
      );

  @override
  Future<List<QazaRecord>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) =>
      _database.transactionWithRevision(
        () => _database.qazaRecordsDao.undoCompletions(
          userId: userId,
          expectedCompletionIds: expectedCompletionIds,
          undoneAt: undoneAt,
        ),
      );

  @override
  Future<List<QazaRecord>> undoCompletionsAndQueue({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) =>
      undoCompletions(
        userId: userId,
        expectedCompletionIds: expectedCompletionIds,
        undoneAt: undoneAt,
      );

  @override
  Future<void> upsertRecords(String userId, List<QazaRecord> records) async {
    if (records.isEmpty) return;
    for (final record in records) {
      if (record.userId != userId) {
        throw StateError('Cannot persist a Qaza record for a different user.');
      }
    }
    await _database.transactionWithRevision(() async {
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
    await _database.transactionWithRevision(() async {
      final insertedIds =
          await _database.qazaRecordsDao.insertRecordsReturningInsertedIds(
        records.map(_toCompanion).toList(growable: false),
      );
      final inserted = records
          .where((record) => insertedIds.contains(record.id))
          .toList(growable: false);
      await _upsertProfilePlanProvenance(inserted);
    });
  }

  @override
  Future<bool> hasPendingReset(String userId) async => false;

  @override
  Future<void> retireUserData({required String userId}) async {
    await _database.transactionWithRevision(() async {
      await _database.qazaRecordsDao.deleteAllForUser(userId: userId);
      await _deleteAllProfilePlanProvenance(userId);
    });
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {}

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

  String _sqlStringLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  Future<void> _upsertProfilePlanProvenance(
    Iterable<QazaRecord> records,
  ) async {
    final eligible = records
        .where(
          (record) =>
              record.profilePlanRevisionId != null &&
              record.profilePlanFingerprint != null,
        )
        .toList(growable: false);
    for (var start = 0; start < eligible.length; start += 400) {
      final end = start + 400 < eligible.length ? start + 400 : eligible.length;
      final chunk = eligible.sublist(start, end);
      final values = chunk
          .map(
            (record) => '(${_sqlStringLiteral(record.id)}, '
                '${_sqlStringLiteral(record.userId)}, '
                '${_sqlStringLiteral(record.profilePlanRevisionId!)}, '
                '${_sqlStringLiteral(record.profilePlanFingerprint!)})',
          )
          .join(', ');
      await _database.customStatement(
        'INSERT INTO qaza_profile_plan_provenance '
        '(record_id, user_id, plan_revision_id, plan_fingerprint) '
        'VALUES $values '
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
      final placeholders = chunk.map(_sqlStringLiteral).join(', ');
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
}
