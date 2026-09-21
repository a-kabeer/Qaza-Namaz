import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/qaza_record.dart';
import '../local/qaza_local_store.dart';
import 'sync_error_classifier.dart';
import 'qaza_sync_remote_data_source.dart';
import 'sync_state.dart';

class QazaSyncEngine {
  QazaSyncEngine({
    required QazaLocalStore localStore,
    required QazaSyncRemoteDataSource remote,
    String? cursorNamespace,
    required void Function(SyncState state) onState,
    Future<void> Function()? onLocalDataChanged,
  })  : _localStore = localStore,
        _remote = remote,
        _cursorNamespace = cursorNamespace,
        _onState = onState,
        _onLocalDataChanged = onLocalDataChanged;

  static const int batchSize = 400;
  static const int changePageSize = 25;
  static const int maxRetryAttempts = 6;

  final QazaLocalStore _localStore;
  final QazaSyncRemoteDataSource _remote;
  final String? _cursorNamespace;
  final void Function(SyncState state) _onState;
  final Future<void> Function()? _onLocalDataChanged;

  Future<void>? _running;
  Completer<void>? _idleCompleter;
  bool _rerunRequested = false;
  Timer? _retryTimer;
  String? _retryUserId;
  bool _disposed = false;

  Future<void> synchronize(
    String userId, {
    bool requestRerun = false,
  }) {
    _retryTimer?.cancel();
    _retryTimer = null;

    final existing = _idleCompleter;
    if (existing != null) {
      if (requestRerun) _rerunRequested = true;
      return existing.future;
    }

    final idle = Completer<void>();
    _idleCompleter = idle;
    unawaited(_drain(userId, idle));
    return idle.future;
  }

  Future<void> _drain(String userId, Completer<void> idle) async {
    try {
      while (!_disposed) {
        _rerunRequested = false;
        final run = _run(userId);
        _running = run;
        try {
          await run;
        } finally {
          if (identical(_running, run)) {
            _running = null;
          }
        }
        if (!_rerunRequested) break;
      }

      if (!idle.isCompleted) idle.complete();
    } catch (error, stackTrace) {
      if (!idle.isCompleted) idle.completeError(error, stackTrace);
    } finally {
      if (identical(_idleCompleter, idle)) {
        _idleCompleter = null;
      }
    }
  }

  Future<void> primeCursor(
      {required String userId, QazaRemoteChangeCursor? cursor}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _keyPrefix(userId);
    if (cursor == null) {
      await prefs.remove('${prefix}_at');
      await prefs.remove('${prefix}_id');
      await prefs.remove('${prefix}_generation');
      return;
    }
    await prefs.setString('${prefix}_at', cursor.at.toUtc().toIso8601String());
    await prefs.setString('${prefix}_id', cursor.id);
    await prefs.setInt('${prefix}_generation', cursor.generation);
  }

  Future<QazaRemoteChangeCursor?> _loadCursor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _keyPrefix(userId);
    final rawAt = prefs.getString('${prefix}_at');
    final id = prefs.getString('${prefix}_id');
    if (rawAt == null || id == null) return null;
    final at = DateTime.tryParse(rawAt);
    if (at == null) return null;
    return QazaRemoteChangeCursor(
      at: at.toUtc(),
      id: id,
      generation: prefs.getInt('${prefix}_generation') ?? 0,
    );
  }

  Future<void> _run(String userId) async {
    if (userId.isEmpty || _disposed) return;

    final pending = await _localStore.countPendingOutbox(userId);
    _emit(
      SyncState(
        status: SyncStatus.syncing,
        pendingCount: pending,
        processedCount: 0,
        totalCount: pending,
      ),
    );

    var processed = 0;
    var cursor = await _loadCursor(userId);
    final locallyCommittedChanges = <String>{};

    try {
      final remoteReset = await _remote.getResetState(userId: userId);
      if (remoteReset.inProgress) {
        final resetCursor = await _remote.resetUserRecordsForSync(
          userId: userId,
          operationId: 'recovery_$userId',
        );
        await _localStore.retireUserData(userId: userId);
        cursor = resetCursor;
        await primeCursor(userId: userId, cursor: cursor);
        await _notifyLocalDataChanged();
      }

      cursor = await _pullRemoteChanges(
        userId: userId,
        cursor: cursor,
        locallyCommittedChanges: locallyCommittedChanges,
      );

      while (true) {
        final batch = await _localStore.loadOutboxBatch(
          userId,
          limit: batchSize,
        );
        if (batch.isEmpty) break;

        final first = batch.first;
        if (first.type == SyncOpType.reset) {
          final resetCursor = await _remote.resetUserRecordsForSync(
            userId: userId,
            operationId: first.id,
          );
          await _localStore.retireUserData(userId: userId);
          await _localStore.removeOutboxBatch(userId, [first.id]);
          cursor = resetCursor;
          await primeCursor(userId: userId, cursor: cursor);
          processed += 1;
          await _notifyLocalDataChanged();
          continue;
        }

        final type = first.type;
        final operations = <PendingSyncOp>[];
        for (final operation in batch) {
          if (operation.type != type) break;
          operations.add(operation);
          if (operations.length == batchSize) break;
        }

        try {
          if (_disposed) return;
          final remoteReset = await _remote.getResetState(userId: userId);
          if (remoteReset.inProgress) {
            final resetCursor = await _remote.resetUserRecordsForSync(
              userId: userId,
              operationId: 'recovery_$userId',
            );
            await _localStore.retireUserData(userId: userId);
            cursor = resetCursor;
            await primeCursor(userId: userId, cursor: cursor);
            await _notifyLocalDataChanged();
            continue;
          }

          final committed = await _remote.applyOperationsBatch(
            userId: userId,
            operations: operations,
          );
          // Keep the cursor at the last pulled change until the post-write
          // pull. This prevents concurrent remote changes that land while the
          // write is in flight from being skipped.
          if (operations.first.type != SyncOpType.update &&
              operations.first.type != SyncOpType.delete) {
            locallyCommittedChanges.add(committed.id);
          }
          await _localStore.removeOutboxBatch(
            userId,
            operations.map((op) => op.id).toList(growable: false),
          );
          processed += operations.length;

          final remaining = await _localStore.countPendingOutbox(userId);
          _emit(
            SyncState(
              status: remaining == 0
                  ? SyncStatus.syncing
                  : SyncStatus.partiallySynced,
              pendingCount: remaining,
              processedCount: processed,
              totalCount: pending,
              currentBatch: ((processed - 1) ~/ batchSize) + 1,
              totalBatches: pending == 0
                  ? 0
                  : ((pending + batchSize - 1) ~/ batchSize),
            ),
          );
        } catch (error) {
          final ids = operations.map((op) => op.id).toList(growable: false);
          await _localStore.markOutboxBatchRetry(
            userId: userId,
            ids: ids,
            error: classifyPersistedSyncError(error),
          );
          rethrow;
        }
      }

      cursor = await _pullRemoteChanges(
        userId: userId,
        cursor: cursor,
        locallyCommittedChanges: locallyCommittedChanges,
      );

      final remaining = await _localStore.countPendingOutbox(userId);
      _emit(
        SyncState(
          status: remaining == 0
              ? SyncStatus.synced
              : SyncStatus.pendingSync,
          pendingCount: remaining,
          processedCount: processed,
          totalCount: pending,
          lastSyncAt: DateTime.now(),
          currentBatch:
              pending == 0 ? 0 : ((processed + batchSize - 1) ~/ batchSize),
          totalBatches:
              pending == 0 ? 0 : ((pending + batchSize - 1) ~/ batchSize),
        ),
      );
    } catch (error) {
      final transient = _isTransient(error);
      final retryCount = await _maxAttemptForUser(userId);
      _emit(
        SyncState(
          status: transient && retryCount < maxRetryAttempts
              ? SyncStatus.retrying
              : SyncStatus.syncError,
          pendingCount: await _localStore.countPendingOutbox(userId),
          processedCount: processed,
          totalCount: pending,
          retryCount: retryCount,
          detail: error.toString(),
        ),
      );

      if (transient && retryCount < maxRetryAttempts && !_disposed) {
        _scheduleRetry(userId, retryCount);
      }
    }
  }

  Future<QazaRemoteChangeCursor?> _pullRemoteChanges({
    required String userId,
    required QazaRemoteChangeCursor? cursor,
    required Set<String> locallyCommittedChanges,
  }) async {
    var current = cursor;

    while (true) {
      if (_disposed) return current;
      final page = await _remote.getChanges(
        userId: userId,
        after: current,
        limit: changePageSize,
      );

      if (page.changes.isEmpty) return current;

      for (final change in page.changes) {
        if (_disposed) return current;
        if (change.type == QazaRemoteChangeType.reset) {
          await _localStore.retireUserData(userId: userId);
          locallyCommittedChanges.clear();
          await _notifyLocalDataChanged();
        } else if (!locallyCommittedChanges.contains(change.cursor.id)) {
          if (change.type == QazaRemoteChangeType.delete &&
              change.recordIds.isNotEmpty) {
            for (final recordId in change.recordIds) {
              await _localStore.deleteRecord(
                userId: userId,
                recordId: recordId,
              );
            }
            await _notifyLocalDataChanged();
          }
          await _mergeRemoteRecords(
            userId: userId,
            records: change.records,
          );
        }

        current = change.cursor;
        await primeCursor(userId: userId, cursor: current);
      }

      if (!page.hasMore) return current;
    }
  }

  Future<void> _mergeRemoteRecords({
    required String userId,
    required List<QazaRecord> records,
  }) async {
    if (records.isEmpty) return;

    final existing = await _localStore.getRecordsByIds(
      userId: userId,
      ids: records.map((record) => record.id).toList(growable: false),
    );
    final byId = <String, QazaRecord>{
      for (final record in existing) record.id: record,
    };
    final merged = <QazaRecord>[];
    final recovery = <PendingSyncOp>[];

    for (final remoteRecord in records) {
      final localRecord = byId[remoteRecord.id];
      var winner = remoteRecord;
      PendingSyncOp? recoveryOp;

      if (localRecord != null) {
        final localCompletedAt = localRecord.completedAt;
        final remoteCompletedAt = remoteRecord.completedAt;

        if (localCompletedAt != null && remoteCompletedAt != null) {
          // Completion is a monotonic business event: the earliest recorded
          // completion wins across devices.
          if (localCompletedAt.isBefore(remoteCompletedAt)) {
            winner = localRecord;
          } else if (remoteCompletedAt.isBefore(localCompletedAt)) {
            winner = remoteRecord;
            recoveryOp = PendingSyncOp(
              id: 'update_${remoteRecord.id}_${remoteRecord.updatedAt.microsecondsSinceEpoch}',
              type: SyncOpType.update,
              userId: userId,
              queuedAt: remoteRecord.updatedAt,
              targetRecordId: remoteRecord.id,
              record: remoteRecord,
            );
          } else if (localRecord.updatedAt.isAfter(remoteRecord.updatedAt)) {
            winner = localRecord;
          }
        } else if (localCompletedAt != null && remoteCompletedAt == null) {
          winner = localRecord;
        } else if (localCompletedAt == null && remoteCompletedAt != null) {
          winner = remoteRecord;
          recoveryOp = PendingSyncOp(
            id: 'update_${remoteRecord.id}_${remoteRecord.updatedAt.microsecondsSinceEpoch}',
            type: SyncOpType.update,
            userId: userId,
            queuedAt: remoteRecord.updatedAt,
            targetRecordId: remoteRecord.id,
            record: remoteRecord,
          );
        } else if (localRecord.updatedAt.isAfter(remoteRecord.updatedAt)) {
          winner = localRecord;
          recoveryOp = PendingSyncOp(
            id: 'update_${localRecord.id}_${localRecord.updatedAt.microsecondsSinceEpoch}',
            type: SyncOpType.update,
            userId: userId,
            queuedAt: localRecord.updatedAt,
            targetRecordId: localRecord.id,
            record: localRecord,
          );
        }
      }

      merged.add(winner);
      if (recoveryOp != null) recovery.add(recoveryOp);
    }

    await _localStore.upsertRecordsAndOutbox(
      userId: userId,
      records: merged,
      ops: recovery,
    );
    await _notifyLocalDataChanged();
  }

  Future<int> _maxAttemptForUser(String userId) async {
    final operations = await _localStore.loadOutboxBatch(
      userId,
      limit: batchSize,
    );
    if (operations.isEmpty) return 0;
    var maximum = 0;
    for (final operation in operations) {
      if (operation.attempts > maximum) maximum = operation.attempts;
    }
    return maximum;
  }

  void _scheduleRetry(String userId, int retryCount) {
    _retryTimer?.cancel();
    final exponent = retryCount.clamp(0, 8).toInt();
    final delaySeconds = (1 << exponent).clamp(1, 300);
    _retryUserId = userId;
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      final target = _retryUserId;
      if (!_disposed && target != null) {
        unawaited(synchronize(target));
      }
    });
  }

  bool _isTransient(Object error) {
    if (error is FirebaseException) {
      return <String>{
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'unavailable',
      }.contains(error.code);
    }

    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('timeout') ||
        message.contains('temporarily unavailable') ||
        message.contains('reset is currently in progress');
  }

  String _keyPrefix(String userId) {
    final namespace = _cursorNamespace;
    if (namespace == null || namespace.isEmpty) {
      return 'qaza_sync_cursor_$userId';
    }
    return 'qaza_sync_cursor_${namespace}_$userId';
  }

  Future<void> _notifyLocalDataChanged() async {
    final callback = _onLocalDataChanged;
    if (callback != null) await callback();
  }

  void _emit(SyncState state) {
    if (!_disposed) _onState(state);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _running = null;
  }
}
