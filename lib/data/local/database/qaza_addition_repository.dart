import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/constants/prayer_types.dart';

import '../../../core/utils/qaza_completion_id.dart';
import '../../../domain/entities/qaza_addition.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/repositories/qaza_addition_repository.dart';
import 'app_database.dart';

class _NoInsertedRecords implements Exception {
  const _NoInsertedRecords();
}

class _CancelledTransaction implements Exception {
  const _CancelledTransaction();
}

class DriftQazaAdditionRepository implements QazaAdditionRepository {
  const DriftQazaAdditionRepository(this.database);

  final AppDatabase database;

  @override
  Future<QazaAddition?> getAddition({
    required String userId,
    required String additionId,
  }) async {
    final rows = await database.customSelect(
      '''SELECT id, user_id, mode, input_snapshot, revision, created_at, updated_at
         FROM qaza_additions
         WHERE user_id = ? AND id = ?
         LIMIT 1''',
      variables: [Variable(userId), Variable(additionId)],
    ).get();
    return rows.isEmpty ? null : _mapAddition(rows.first);
  }

  @override
  Future<QazaAdditionDetail?> getAdditionDetail({
    required String userId,
    required String additionId,
  }) async {
    final rows = await database.customSelect(
      '''SELECT
           a.id,
           a.user_id,
           a.mode,
           a.input_snapshot,
           a.revision,
           a.created_at,
           a.updated_at,
           COUNT(r.id) AS active_count,
           COALESCE(SUM(CASE WHEN r.status = 'pending' THEN 1 ELSE 0 END), 0)
             AS pending_count,
           COALESCE(SUM(CASE WHEN r.status = 'completed' THEN 1 ELSE 0 END), 0)
             AS completed_count,
           CASE WHEN EXISTS (
             SELECT 1
             FROM qaza_deletion_actions da
             WHERE da.user_id = a.user_id
               AND da.addition_id = a.id
               AND da.resolved_at IS NULL
           ) THEN 1 ELSE 0 END AS is_deleted
         FROM qaza_additions a
         LEFT JOIN qaza_records r
           ON r.user_id = a.user_id AND r.addition_id = a.id
         WHERE a.user_id = ? AND a.id = ?
         GROUP BY a.id''',
      variables: [Variable(userId), Variable(additionId)],
    ).get();

    if (rows.isEmpty) return null;
    final row = rows.first;
    return QazaAdditionDetail(
      addition: _mapAddition(row),
      activeCount: row.read<int>('active_count'),
      pendingCount: row.read<int>('pending_count'),
      completedCount: row.read<int>('completed_count'),
      isDeleted: row.read<int>('is_deleted') != 0,
    );
  }

  @override
  Future<QazaAdditionListPage> getRecentAdditions({
    required String userId,
    int limit = 30,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    _validateLimit(limit);
    if ((afterCreatedAt == null) != (afterId == null)) {
      throw ArgumentError('A complete addition cursor is required.');
    }

    final where = StringBuffer(
      '''a.user_id = ?
         AND NOT EXISTS (
           SELECT 1
           FROM qaza_deletion_actions da
           WHERE da.user_id = a.user_id
             AND da.addition_id = a.id
             AND da.resolved_at IS NULL
         )''',
    );
    final variables = <Variable<Object>>[Variable(userId)];

    if (afterCreatedAt != null) {
      where.write(
        ' AND (a.created_at < ? OR (a.created_at = ? AND a.id < ?))',
      );
      final created = afterCreatedAt.toIso8601String();
      variables
        ..add(Variable(created))
        ..add(Variable(created))
        ..add(Variable(afterId!));
    }

    variables.add(Variable(limit));
    final rows = await database.customSelect(
      '''SELECT
           a.id,
           a.user_id,
           a.mode,
           a.input_snapshot,
           a.revision,
           a.created_at,
           a.updated_at,
           COUNT(r.id) AS active_count,
           COALESCE(SUM(CASE WHEN r.status = 'pending' THEN 1 ELSE 0 END), 0)
             AS pending_count,
           COALESCE(SUM(CASE WHEN r.status = 'completed' THEN 1 ELSE 0 END), 0)
             AS completed_count
         FROM qaza_additions a
         LEFT JOIN qaza_records r
           ON r.user_id = a.user_id AND r.addition_id = a.id
         WHERE ${where.toString()}
         GROUP BY a.id
         HAVING COUNT(r.id) > 0
         ORDER BY a.created_at DESC, a.id DESC
         LIMIT ?''',
      variables: variables,
    ).get();

    return QazaAdditionListPage(
      items: rows
          .map(
            (row) => QazaAdditionListItem(
              addition: _mapAddition(row),
              activeCount: row.read<int>('active_count'),
              pendingCount: row.read<int>('pending_count'),
              completedCount: row.read<int>('completed_count'),
            ),
          )
          .toList(growable: false),
      hasMore: rows.length == limit,
    );
  }

  @override
  Future<QazaDeletionActionPage> getRecentDeletionActions({
    required String userId,
    int limit = 30,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    _validateLimit(limit);
    if ((afterCreatedAt == null) != (afterId == null)) {
      throw ArgumentError('A complete deletion cursor is required.');
    }

    final where = StringBuffer(
      'a.user_id = ? AND a.resolved_at IS NULL',
    );
    final variables = <Variable<Object>>[Variable(userId)];

    if (afterCreatedAt != null) {
      where.write(
        ' AND (a.created_at < ? OR (a.created_at = ? AND a.id < ?))',
      );
      final created = afterCreatedAt.toIso8601String();
      variables
        ..add(Variable(created))
        ..add(Variable(created))
        ..add(Variable(afterId!));
    }

    variables.add(Variable(limit));
    final rows = await database.customSelect(
      '''SELECT
           a.id,
           a.user_id,
           a.addition_id,
           a.created_at,
           COUNT(s.record_id) AS deleted_count,
           MIN(s.original_date) AS first_original_date,
           MAX(s.original_date) AS last_original_date
         FROM qaza_deletion_actions a
         LEFT JOIN qaza_deletion_action_record_snapshots s
           ON s.deletion_action_id = a.id
         WHERE ${where.toString()}
         GROUP BY a.id
         HAVING COUNT(s.record_id) > 0
         ORDER BY a.created_at DESC, a.id DESC
         LIMIT ?''',
      variables: variables,
    ).get();

    return QazaDeletionActionPage(
      items: rows.map(_mapDeletionListItem).toList(growable: false),
      hasMore: rows.length == limit,
    );
  }

  @override
  Future<List<QazaRecord>> getRecordsForAddition({
    required String userId,
    required String additionId,
  }) =>
      database.qazaRecordsDao.getByAdditionId(
        userId: userId,
        additionId: additionId,
      );

  @override
  Future<QazaAdditionMutationResult> createAddition({
    required QazaAddition addition,
    required List<QazaRecord> records,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  }) async {
    try {
      return await database.transaction(() async {
        if (isCancellationRequested?.call() ?? false) {
          throw const _CancelledTransaction();
        }

        await _insertAddition(addition);
        final insertedIds = <String>[];
        const batchSize = 500;
        onProgress?.call(0, records.length, 0);

        for (var start = 0; start < records.length; start += batchSize) {
          if (isCancellationRequested?.call() ?? false) {
            throw const _CancelledTransaction();
          }
          final end = start + batchSize < records.length
              ? start + batchSize
              : records.length;
          final ids = await database.qazaRecordsDao
              .insertRecordsReturningInsertedIds(
                records
                    .sublist(start, end)
                    .map(_recordCompanion)
                    .toList(growable: false),
              );
          insertedIds.addAll(ids);
          onProgress?.call(end, records.length, insertedIds.length);
        }

        if (isCancellationRequested?.call() ?? false) {
          throw const _CancelledTransaction();
        }
        if (insertedIds.isEmpty) {
          throw const _NoInsertedRecords();
        }

        return QazaAdditionMutationResult(
          additionId: addition.id,
          revision: addition.revision,
          addedCount: insertedIds.length,
          skippedCount: records.length - insertedIds.length,
          insertedRecordIds: List.unmodifiable(insertedIds),
        );
      });
    } on _CancelledTransaction {
      return const QazaAdditionMutationResult(cancelled: true);
    } on _NoInsertedRecords {
      return const QazaAdditionMutationResult();
    }
  }

  @override
  Future<QazaAdditionMutationResult> editAddition({
    required String userId,
    required String additionId,
    required int expectedRevision,
    required QazaAdditionInputSnapshot snapshot,
    required Set<QazaRecordKey> requestedKeys,
    required List<QazaRecord> recordsToAdd,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  }) async {
    try {
      return await database.transaction(() async {
        if (isCancellationRequested?.call() ?? false) {
          throw const _CancelledTransaction();
        }

        final addition = await _getAdditionInsideTransaction(
          userId,
          additionId,
        );
        if (addition == null) {
          throw StateError('Qaza addition was not found.');
        }
        if (await _hasUnresolvedDeletionAction(
          userId,
          additionId,
        )) {
          throw StateError(
            'This Qaza addition is deleted. Restore it from Recently Deleted before editing.',
          );
        }
        if (addition.revision != expectedRevision) {
          throw StateError(
            'This Qaza addition was changed elsewhere. Reopen it and try again.',
          );
        }

        final current = await database.qazaRecordsDao.getByAdditionId(
          userId: userId,
          additionId: additionId,
        );
        if (current.isEmpty) {
          throw StateError(
            'This Qaza addition has no active records and cannot be edited. Restore it first.',
          );
        }

        final removable = <QazaRecord>[];
        var protectedCount = 0;
        for (final record in current) {
          final requested = requestedKeys.contains(
            QazaRecordKey(
              date: record.originalDate,
              prayerType: record.prayerType,
            ),
          );
          if (!requested &&
              record.status == QazaStatus.pending &&
              record.recordVersion == 1) {
            removable.add(record);
          } else if (!requested) {
            protectedCount++;
          }
        }

        final removedIds = <String>[];
        for (var start = 0; start < removable.length; start += 400) {
          if (isCancellationRequested?.call() ?? false) {
            throw const _CancelledTransaction();
          }
          final end = start + 400 < removable.length
              ? start + 400
              : removable.length;
          final ids = removable
              .sublist(start, end)
              .map((record) => record.id)
              .toList(growable: false);
          final deleted = await (database.delete(database.qazaRecords)
                ..where(
                  (row) =>
                      row.userId.equals(userId) &
                      row.additionId.equals(additionId) &
                      row.status.equals(QazaStatus.pending.name) &
                      row.recordVersion.equals(1) &
                      row.id.isIn(ids),
                ))
              .go();
          if (deleted > 0) {
            removedIds.addAll(ids.take(deleted));
          }
        }

        onProgress?.call(0, recordsToAdd.length, 0);
        final insertedIds = <String>[];
        for (var start = 0; start < recordsToAdd.length; start += 500) {
          if (isCancellationRequested?.call() ?? false) {
            throw const _CancelledTransaction();
          }
          final end = start + 500 < recordsToAdd.length
              ? start + 500
              : recordsToAdd.length;
          final ids = await database.qazaRecordsDao
              .insertRecordsReturningInsertedIds(
                recordsToAdd
                    .sublist(start, end)
                    .map(_recordCompanion)
                    .toList(growable: false),
              );
          insertedIds.addAll(ids);
          onProgress?.call(end, recordsToAdd.length, insertedIds.length);
        }

        if (isCancellationRequested?.call() ?? false) {
          throw const _CancelledTransaction();
        }

        final nextRevision = addition.revision + 1;
        final now = DateTime.now().toIso8601String();
        await database.customUpdate(
          '''UPDATE qaza_additions
             SET mode = ?, input_snapshot = ?, revision = ?, updated_at = ?
             WHERE user_id = ? AND id = ? AND revision = ?''',
          variables: [
            Variable(snapshot.mode.name),
            Variable(jsonEncode(snapshot.toJson())),
            Variable(nextRevision),
            Variable(now),
            Variable(userId),
            Variable(additionId),
            Variable(addition.revision),
          ],
        );

        return QazaAdditionMutationResult(
          additionId: additionId,
          revision: nextRevision,
          addedCount: insertedIds.length,
          removedCount: removedIds.length,
          protectedCount: protectedCount,
          skippedCount: recordsToAdd.length - insertedIds.length,
          insertedRecordIds: List.unmodifiable(insertedIds),
          removedRecordIds: List.unmodifiable(removedIds),
        );
      });
    } on _CancelledTransaction {
      return const QazaAdditionMutationResult(cancelled: true);
    }
  }

  @override
  Future<QazaDeletionResult> deleteAddition({
    required String userId,
    required String additionId,
  }) =>
      database.transaction(() async {
        final addition =
            await _getAdditionInsideTransaction(userId, additionId);
        if (addition == null) {
          throw StateError('Qaza addition was not found.');
        }
        if (await _hasUnresolvedDeletionAction(
          userId,
          additionId,
        )) {
          throw StateError(
            'This Qaza addition is deleted. Restore it from Recently Deleted before deleting again.',
          );
        }

        final current = await database.qazaRecordsDao.getByAdditionId(
          userId: userId,
          additionId: additionId,
        );
        final eligible = current
            .where((record) => record.status == QazaStatus.pending)
            .toList(growable: false);
        final protectedCount = current.length - eligible.length;

        if (eligible.isEmpty) {
          return QazaDeletionResult(
            additionId: additionId,
            protectedCount: protectedCount,
          );
        }

        final actionId = newQazaCompletionId();
        final createdAt = DateTime.now();
        await database.customInsert(
          '''INSERT INTO qaza_deletion_actions
             (id, user_id, addition_id, created_at, resolved_at)
             VALUES (?, ?, ?, ?, NULL)''',
          variables: [
            Variable(actionId),
            Variable(userId),
            Variable(additionId),
            Variable(createdAt.toIso8601String()),
          ],
        );

        for (final record in eligible) {
          await database.customInsert(
            '''INSERT INTO qaza_deletion_action_record_snapshots
               (deletion_action_id, record_id, user_id, addition_id,
                prayer_type, original_date, status, completed_at,
                completion_id, created_at, updated_at, record_version)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            variables: [
              Variable(actionId),
              Variable(record.id),
              Variable(record.userId),
              Variable(record.additionId),
              Variable(record.prayerType.name),
              Variable(record.originalDate.toIso8601String()),
              Variable(record.status.name),
              Variable(record.completedAt?.toIso8601String()),
              Variable(record.completionId),
              Variable(record.createdAt.toIso8601String()),
              Variable(record.updatedAt.toIso8601String()),
              Variable(record.recordVersion),
            ],
          );
        }

        final deletedIds = <String>[];
        for (var start = 0; start < eligible.length; start += 400) {
          final end = start + 400 < eligible.length
              ? start + 400
              : eligible.length;
          final ids = eligible
              .sublist(start, end)
              .map((record) => record.id)
              .toList(growable: false);
          final deleted = await (database.delete(database.qazaRecords)
                ..where(
                  (row) =>
                      row.userId.equals(userId) &
                      row.additionId.equals(additionId) &
                      row.status.equals(QazaStatus.pending.name) &
                      row.id.isIn(ids),
                ))
              .go();
          if (deleted > 0) {
            deletedIds.addAll(ids.take(deleted));
          }
        }

        if (deletedIds.isEmpty) {
          throw StateError('No eligible Qaza records could be deleted.');
        }

        return QazaDeletionResult(
          additionId: additionId,
          deletionActionId: actionId,
          deletedCount: deletedIds.length,
          protectedCount: protectedCount,
        );
      });

  @override
  Future<QazaRestoreResult> restoreDeletionAction({
    required String userId,
    required String deletionActionId,
  }) =>
      database.transaction(() async {
        final actions = await database.customSelect(
          '''SELECT id, resolved_at
             FROM qaza_deletion_actions
             WHERE user_id = ? AND id = ?
             LIMIT 1''',
          variables: [Variable(userId), Variable(deletionActionId)],
        ).get();
        if (actions.isEmpty) {
          throw StateError('Deleted Qaza action was not found.');
        }
        if (actions.first.read<String?>('resolved_at') != null) {
          return QazaRestoreResult(
            deletionActionId: deletionActionId,
            alreadyResolved: true,
          );
        }

        final rows = await database.customSelect(
          '''SELECT deletion_action_id, record_id, user_id, addition_id,
                    prayer_type, original_date, status, completed_at,
                    completion_id, created_at, updated_at, record_version
             FROM qaza_deletion_action_record_snapshots
             WHERE deletion_action_id = ?
             ORDER BY original_date ASC, record_id ASC''',
          variables: [Variable(deletionActionId)],
        ).get();

        var restored = 0;
        var conflicts = 0;
        for (final row in rows) {
          final record = _mapSnapshot(row);
          final conflict = await database.customSelect(
            '''SELECT id
               FROM qaza_records
               WHERE user_id = ?
                 AND (
                   id = ?
                   OR (prayer_type = ? AND original_date = ?)
                 )
               LIMIT 1''',
            variables: [
              Variable(userId),
              Variable(record.recordId),
              Variable(record.prayerType.name),
              Variable(record.originalDate),
            ],
          ).get();
          if (conflict.isNotEmpty) {
            conflicts++;
            continue;
          }

          final inserted = await database.qazaRecordsDao.insertRecord(
            _recordCompanion(record.toRecord()),
          );
          if (inserted > 0) {
            restored++;
          } else {
            conflicts++;
          }
        }

        if (rows.isNotEmpty) {
          // Every snapshot is now either restored or already represented by a
          // conflicting live record, so this deletion event is no longer
          // actionable. Keep the action row for permanent history.
          await database.customUpdate(
            '''UPDATE qaza_deletion_actions
               SET resolved_at = ?
               WHERE user_id = ? AND id = ? AND resolved_at IS NULL''',
            variables: [
              Variable(DateTime.now().toIso8601String()),
              Variable(userId),
              Variable(deletionActionId),
            ],
          );
        }

        return QazaRestoreResult(
          deletionActionId: deletionActionId,
          restoredCount: restored,
          conflictCount: conflicts,
        );
      });

  Future<void> _insertAddition(QazaAddition addition) =>
      database.customInsert(
        '''INSERT INTO qaza_additions
           (id, user_id, mode, input_snapshot, revision, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable(addition.id),
          Variable(addition.userId),
          Variable(addition.mode.name),
          Variable(jsonEncode(addition.currentInputSnapshot.toJson())),
          Variable(addition.revision),
          Variable(addition.createdAt.toIso8601String()),
          Variable(addition.updatedAt.toIso8601String()),
        ],
      );

  Future<bool> _hasUnresolvedDeletionAction(
    String userId,
    String additionId,
  ) async {
    final rows = await database.customSelect(
      '''SELECT 1
         FROM qaza_deletion_actions
         WHERE user_id = ? AND addition_id = ? AND resolved_at IS NULL
         LIMIT 1''',
      variables: [Variable(userId), Variable(additionId)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<QazaAddition?> _getAdditionInsideTransaction(
    String userId,
    String additionId,
  ) async {
    final rows = await database.customSelect(
      '''SELECT id, user_id, mode, input_snapshot, revision, created_at, updated_at
         FROM qaza_additions
         WHERE user_id = ? AND id = ?
         LIMIT 1''',
      variables: [Variable(userId), Variable(additionId)],
    ).get();
    return rows.isEmpty ? null : _mapAddition(rows.first);
  }

  QazaRecordsCompanion _recordCompanion(QazaRecord record) =>
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
        additionId: Value(record.additionId),
        recordVersion: Value(record.recordVersion),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );

  QazaAddition _mapAddition(QueryRow row) => QazaAddition(
        id: row.read<String>('id'),
        userId: row.read<String>('user_id'),
        mode: QazaAdditionModeX.fromName(row.read<String>('mode')),
        currentInputSnapshot: QazaAdditionInputSnapshot.fromJson(
          jsonDecode(row.read<String>('input_snapshot')) as Map<String, dynamic>,
        ),
        revision: row.read<int>('revision'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );

  QazaDeletionActionListItem _mapDeletionListItem(QueryRow row) =>
      QazaDeletionActionListItem(
        id: row.read<String>('id'),
        userId: row.read<String>('user_id'),
        additionId: row.read<String>('addition_id'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        deletedCount: row.read<int>('deleted_count'),
        firstOriginalDate:
            _parseOptionalDate(row.read<String?>('first_original_date')),
        lastOriginalDate:
            _parseOptionalDate(row.read<String?>('last_original_date')),
      );

  QazaDeletionActionRecordSnapshot _mapSnapshot(QueryRow row) =>
      QazaDeletionActionRecordSnapshot(
        deletionActionId: row.read<String>('deletion_action_id'),
        recordId: row.read<String>('record_id'),
        userId: row.read<String>('user_id'),
        additionId: row.read<String>('addition_id'),
        prayerType: PrayerType.values.firstWhere(
          (value) => value.name == row.read<String>('prayer_type'),
        ),
        originalDate: DateTime.parse(row.read<String>('original_date')),
        status: QazaStatus.values.firstWhere(
          (value) => value.name == row.read<String>('status'),
        ),
        completedAt: _parseOptionalDate(row.read<String?>('completed_at')),
        completionId: row.read<String?>('completion_id'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
        recordVersion: row.read<int>('record_version'),
      );

  DateTime? _parseOptionalDate(String? value) =>
      value == null ? null : DateTime.parse(value);

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }
  }
}
