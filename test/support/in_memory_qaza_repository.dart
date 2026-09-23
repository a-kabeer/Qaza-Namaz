import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_remote_data_source.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/repositories/qaza_undo_repository.dart';
import 'package:qaza_namaz/domain/repositories/qaza_recovery_repository.dart';

class InMemoryQazaRepository
    implements QazaRepository, QazaUndoRepository, QazaSyncRemoteDataSource, QazaRecoveryRepository {
  final Map<String, QazaRecord> _records = {};
  int historyPageCalls = 0;
  int progressSummaryCalls = 0;
  final Map<String, List<QazaRemoteChange>> _changesByUser = {};
  final Map<String, int> _generations = {};
  int _changeSequence = 0;
  Object? completionFailure;
  StackTrace? completionFailureStack;

  @override
  Future<List<QazaRecord>> getRecords(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    final page = await _collectPages(
        userId: userId, prayerType: prayerType, status: status);
    return page;
  }

  @override
  Future<QazaPage> getPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status,
      DateTime? from,
      DateTime? to,
      DateTime? afterOriginalDate,
      String? afterId}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    if ((afterOriginalDate == null) != (afterId == null)) {
      throw ArgumentError(
          'afterOriginalDate and afterId must be provided together');
    }
    final records = _records.values
        .where((r) => r.userId == userId)
        .where((r) => prayerType == null || r.prayerType == prayerType)
        .where((r) => status == QazaStatus.deleted ? r.status == QazaStatus.deleted : r.status != QazaStatus.deleted && (status == null || r.status == status))
        .where((r) => from == null || !r.originalDate.isBefore(from))
        .where((r) => to == null || !r.originalDate.isAfter(to))
        .where((r) =>
            afterOriginalDate == null ||
            r.originalDate.isAfter(afterOriginalDate) ||
            (r.originalDate.isAtSameMomentAs(afterOriginalDate) &&
                r.id.compareTo(afterId!) > 0))
        .toList()
      ..sort((a, b) {
        final d = a.originalDate.compareTo(b.originalDate);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final hasMore = records.length > limit;
    return QazaPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  Future<List<QazaRecord>> _collectPages(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    final result = <QazaRecord>[];
    DateTime? date;
    String? id;
    while (true) {
      final page = await getPage(
          userId: userId,
          limit: 500,
          prayerType: prayerType,
          status: status,
          afterOriginalDate: date,
          afterId: id);
      result.addAll(page.records);
      if (!page.hasMore) return result;
      date = page.nextOriginalDate;
      id = page.nextId;
    }
  }

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    final wanted = recordIds.toSet();
    if (wanted.isEmpty) return const <QazaRecord>[];
    return [
      for (final record in _records.values)
        if (record.userId == userId &&
            wanted.contains(record.id) &&
            record.status == QazaStatus.pending)
          record,
    ];
  }

  @override
  Future<QazaRecord?> getOldestPending(
      {required String userId, required PrayerType prayerType}) async {
    final page = await getPage(
        userId: userId,
        limit: 1,
        prayerType: prayerType,
        status: QazaStatus.pending);
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage(
      {required String userId,
      int limit = 50,
      PrayerType? prayerType,
      QazaStatus? status = QazaStatus.completed,
      DateTime? from,
      DateTime? to,
      DateTime? beforeOriginalDate,
      String? beforeId}) async {
    historyPageCalls++;
    final records = _records.values
        .where((r) => r.userId == userId)
        .where((r) => prayerType == null || r.prayerType == prayerType)
        .where((r) => status == null || r.status == status)
        .where((r) => from == null || !r.originalDate.isBefore(from))
        .where((r) => to == null || !r.originalDate.isAfter(to))
        .where((r) =>
            beforeOriginalDate == null ||
            r.originalDate.isBefore(beforeOriginalDate) ||
            (r.originalDate.isAtSameMomentAs(beforeOriginalDate) &&
                r.id.compareTo(beforeId!) < 0))
        .toList()
      ..sort((a, b) {
        final d = b.originalDate.compareTo(a.originalDate);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
    final hasMore = records.length > limit;
    return QazaHistoryPage(
        records: records.take(limit).toList(growable: false), hasMore: hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    progressSummaryCalls++;
    return QazaProgressSummary.fromRecords(
        _records.values.where((r) => r.userId == userId));
  }

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!from.isBefore(to)) {
      throw ArgumentError('from must be before to');
    }
    return _records.values
        .where((record) =>
            record.userId == userId && record.status == QazaStatus.completed)
        .where((record) {
      final completedAt = record.completedAt;
      return completedAt != null &&
          !completedAt.isBefore(from) &&
          completedAt.isBefore(to);
    }).length;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (!_storeAddRecord(record)) return;
    _recordChange(
      userId: record.userId,
      type: QazaRemoteChangeType.upsert,
      records: [record],
    );
  }

  bool _storeAddRecord(QazaRecord record) {
    if (_records.values.any((r) =>
        r.userId == record.userId &&
        r.prayerType == record.prayerType &&
        _sameDate(r.originalDate, record.originalDate))) {
      return false;
    }
    _records[record.id] = record;
    return true;
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    for (final record in records) {
      await addRecord(record);
    }
  }

  @override
  Future<void> updateRecord({required QazaRecord record}) async {
    final current = _records[record.id];
    if (current == null || current.userId != record.userId) return;
    final duplicate = _records.values.any(
      (candidate) =>
          candidate.id != record.id &&
          candidate.userId == record.userId &&
          candidate.prayerType == record.prayerType &&
          _sameDate(candidate.originalDate, record.originalDate),
    );
    if (duplicate) {
      throw StateError('A Qaza record already exists for this prayer and date.');
    }
    _records[record.id] = record;
    _recordChange(
      userId: record.userId,
      type: QazaRemoteChangeType.update,
      records: [record],
    );
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    final current = _records[recordId];
    if (current == null || current.userId != userId) return;
    _records.remove(recordId);
    _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.delete,
      records: const <QazaRecord>[],
      recordIds: [recordId],
    );
  }

  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final failure = completionFailure;
    if (failure != null) {
      Error.throwWithStackTrace(
        failure,
        completionFailureStack ?? StackTrace.current,
      );
    }

    final current = _records[recordId];
    if (current == null || current.userId != userId) {
      return QazaCompletionResult.notFound;
    }
    if (current.status == QazaStatus.completed) {
      return QazaCompletionResult.alreadyCompleted;
    }
    if (current.status != QazaStatus.pending) {
      return QazaCompletionResult.notFound;
    }

    final updated = current.copyWith(
      status: QazaStatus.completed,
      completedAt: completedAt,
      updatedAt: completedAt,
    );
    _records[recordId] = updated;
    _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.complete,
      records: [updated],
    );
    return QazaCompletionResult.completed;
  }
  @override
  Future<void> completeRecords(
      {required String userId,
      required List<String> recordIds,
      required DateTime completedAt}) async {
    final changed = <QazaRecord>[];
    for (final id in recordIds) {
      final r = _records[id];
      if (r == null || r.userId != userId) continue;
      if (r.status != QazaStatus.pending) continue;
      final updated = r.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        updatedAt: completedAt,
      );
      _records[id] = updated;
      changed.add(updated);
    }
    if (changed.isNotEmpty) {
      _recordChange(
        userId: userId,
        type: QazaRemoteChangeType.complete,
        records: changed,
      );
    }
  }

  @override
  Future<int> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  }) async {
    var changedCount = 0;
    final changed = <QazaRecord>[];
    for (final entry in expectedCompletedAt.entries) {
      final current = _records[entry.key];
      if (current == null ||
          current.userId != userId ||
          current.status != QazaStatus.completed ||
          current.completedAt == null ||
          !current.completedAt!.isAtSameMomentAs(entry.value) ||
          !current.updatedAt.isAtSameMomentAs(entry.value)) {
        continue;
      }
      final pending = current.copyWith(
        status: QazaStatus.pending,
        completedAt: null,
        updatedAt: undoneAt,
      );
      _records[entry.key] = pending;
      changed.add(pending);
      changedCount++;
    }
    if (changed.isNotEmpty) {
      _recordChange(
        userId: userId,
        type: QazaRemoteChangeType.update,
        records: changed,
      );
    }
    return changedCount;
  }

  @override
  Future<int> softDeleteRecords({
    required String userId, required List<String> recordIds, required DateTime deletedAt, required String operationId,
  }) async {
    var changed = 0;
    for (final id in recordIds.toSet()) {
      final current = _records[id];
      if (current == null || current.userId != userId || current.status == QazaStatus.deleted) continue;
      _records[id] = current.copyWith(status: QazaStatus.deleted, updatedAt: deletedAt);
      changed++;
    }
    return changed;
  }

  @override
  Future<int> restoreDeletedRecords({
    required String userId, required List<String> recordIds, required DateTime restoredAt, required String operationId,
  }) async {
    var changed = 0;
    for (final id in recordIds.toSet()) {
      final current = _records[id];
      if (current == null || current.userId != userId || current.status != QazaStatus.deleted) continue;
      _records[id] = current.copyWith(status: current.completedAt == null ? QazaStatus.pending : QazaStatus.completed, updatedAt: restoredAt);
      changed++;
    }
    return changed;
  }

  @override
  Future<int> undoAddedOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
  }) =>
      removeAddition(
        userId: userId,
        operationId: operationId,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: DateTime.now(),
      );

  @override
  Future<int> removeAddition({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) async {
    var changed = 0;
    for (final entry in _records.entries.toList()) {
      final current = entry.value;
      if (current.userId != userId ||
          current.status != QazaStatus.pending ||
          current.operationId != operationId ||
          !current.createdAt.isAtSameMomentAs(expectedCreatedAt) ||
          !current.updatedAt.isAtSameMomentAs(expectedCreatedAt)) {
        continue;
      }
      _records[entry.key] = current.copyWith(
        status: QazaStatus.deleted,
        updatedAt: deletedAt,
      );
      changed++;
    }
    return changed;
  }

  @override
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) async {
    var pending = 0;
    var completed = 0;
    var deleted = 0;
    var unchangedPending = 0;

    for (final record in _records.values) {
      if (record.userId != userId || record.operationId != operationId) {
        continue;
      }
      switch (record.status) {
        case QazaStatus.pending:
          pending++;
          if (record.createdAt.isAtSameMomentAs(record.updatedAt)) {
            unchangedPending++;
          }
        case QazaStatus.completed:
          completed++;
        case QazaStatus.deleted:
          deleted++;
      }
    }

    return QazaOperationSummary(
      pending: pending,
      completed: completed,
      deleted: deleted,
      unchangedPending: unchangedPending,
    );
  }

  @override
  Future<QazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    var rows = _records.values.where((r) => r.userId == userId);
    if (status != null) rows = rows.where((r) => r.status == status);
    rows = rows.where((r) => matchLastAction
        ? r.updatedAt.isAtSameMomentAs(operationAt)
        : r.operationId == operationId);
    final result = rows.toList()..sort((a, b) {
      final d = b.originalDate.compareTo(a.originalDate);
      return d != 0 ? d : b.id.compareTo(a.id);
    });
    return QazaPage(records: result.take(limit).toList(growable: false), hasMore: result.length > limit);
  }

  @override
  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId, int limit = 50, DateTime? beforeDeletedAt, String? beforeId,
  }) async {
    var rows = _records.values.where((r) => r.userId == userId && r.status == QazaStatus.deleted).toList()
      ..sort((a, b) {
        final d = b.updatedAt.compareTo(a.updatedAt);
        return d != 0 ? d : b.id.compareTo(a.id);
      });
    if (beforeDeletedAt != null) {
      rows = rows.where((r) => r.updatedAt.isBefore(beforeDeletedAt) ||
          (r.updatedAt.isAtSameMomentAs(beforeDeletedAt) && r.id.compareTo(beforeId!) < 0)).toList();
    }
    return QazaHistoryPage(records: rows.take(limit).toList(growable: false), hasMore: rows.length > limit);
  }

  @override
  Future<int> purgeDeletedBefore({required String userId, required DateTime cutoff}) async {
    final ids = _records.values.where((r) => r.userId == userId && r.status == QazaStatus.deleted && r.updatedAt.isBefore(cutoff)).map((r) => r.id).toList();
    for (final id in ids) _records.remove(id);
    return ids.length;
  }
  @override
  Future<void> resetUserRecords({required String userId}) async {
    _resetWithoutChange(userId);
    final generation = _generations[userId] ?? 0;
    _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.reset,
      records: const <QazaRecord>[],
      generation: generation,
      idPrefix: 'reset',
    );
  }

  void _resetWithoutChange(String userId) {
    _records.removeWhere((_, record) => record.userId == userId);
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  @override
  Future<QazaRemoteResetState> getResetState({
    required String userId,
  }) async =>
      QazaRemoteResetState(
        generation: _generations[userId] ?? 0,
        inProgress: false,
      );

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  }) async {
    final changes = _changesByUser[userId];
    return changes == null || changes.isEmpty ? null : changes.last.cursor;
  }

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final changes = _changesByUser[userId] ?? const <QazaRemoteChange>[];
    final filtered = [
      for (final change in changes)
        if (after == null || _cursorAfter(change.cursor, after)) change,
    ];
    return QazaRemoteChangePage(
      changes: filtered.take(limit).toList(growable: false),
      hasMore: filtered.length > limit,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    if (operations.isEmpty) {
      throw ArgumentError('operations must not be empty');
    }
    for (final operation in operations) {
      if (operation.userId != userId) {
        throw StateError('operation belongs to another user');
      }
    }

    switch (operations.first.type) {
      case SyncOpType.add:
        final records = <QazaRecord>[];
        for (final operation in operations) {
          final record = operation.record;
          if (record == null) continue;
          _storeAddRecord(record);
          final stored = _records[record.id];
          if (stored != null) records.add(stored);
        }
        return _recordChange(
          userId: userId,
          type: QazaRemoteChangeType.upsert,
          records: records,
        );
      case SyncOpType.update:
        for (final operation in operations) {
          if (operation.record != null) {
            await updateRecord(record: operation.record!);
          }
        }
        final updateLatest = await getLatestChange(userId: userId);
        if (updateLatest == null) {
          throw StateError('update produced no remote change');
        }
        return updateLatest;
      case SyncOpType.delete:
        for (final operation in operations) {
          if (operation.targetRecordId != null) {
            await deleteRecord(
              userId: userId,
              recordId: operation.targetRecordId!,
            );
          }
        }
        final deleteLatest = await getLatestChange(userId: userId);
        if (deleteLatest == null) {
          throw StateError('delete produced no remote change');
        }
        return deleteLatest;
      case SyncOpType.complete:
        await completeRecords(
          userId: userId,
          recordIds: [
            for (final operation in operations)
              if (operation.targetRecordId != null) operation.targetRecordId!,
          ],
          completedAt: operations.first.completedAt ?? DateTime.now(),
        );
        final latest = await getLatestChange(userId: userId);
        if (latest == null) {
          throw StateError('completion produced no remote change');
        }
        return latest;
      case SyncOpType.reset:
        throw ArgumentError('reset must use resetUserRecordsForSync');
    }
  }

  @override
  Future<void> deleteCloudData({required String userId}) async {
    _records.removeWhere((_, record) => record.userId == userId);
    _changesByUser.remove(userId);
  }

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) async {
    _resetWithoutChange(userId);
    final generation = (_generations[userId] ?? 0) + 1;
    _generations[userId] = generation;
    return _recordChange(
      userId: userId,
      type: QazaRemoteChangeType.reset,
      records: const <QazaRecord>[],
      generation: generation,
      idPrefix: 'reset',
    );
  }

  bool _cursorAfter(
    QazaRemoteChangeCursor left,
    QazaRemoteChangeCursor right,
  ) {
    final at = left.at.compareTo(right.at);
    return at > 0 || (at == 0 && left.id.compareTo(right.id) > 0);
  }

  QazaRemoteChangeCursor _recordChange({
    required String userId,
    required QazaRemoteChangeType type,
    required List<QazaRecord> records,
    int? generation,
    String idPrefix = 'change',
    List<String> recordIds = const <String>[],
  }) {
    _changeSequence++;
    final cursor = QazaRemoteChangeCursor(
      at: DateTime.utc(2026, 1, 1).add(
        Duration(microseconds: _changeSequence),
      ),
      id: '${idPrefix}-${_changeSequence.toString().padLeft(8, '0')}',
      generation: generation ?? (_generations[userId] ?? 0),
    );
    final change = QazaRemoteChange(
      type: type,
      cursor: cursor,
      records: List<QazaRecord>.unmodifiable(records),
      recordIds: List<String>.unmodifiable(recordIds),
    );
    (_changesByUser[userId] ??= <QazaRemoteChange>[]).add(change);
    return cursor;
  }

}
