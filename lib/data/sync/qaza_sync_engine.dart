import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/qaza_local_store.dart';
import 'qaza_sync_remote_data_source.dart';
import 'sync_state.dart';

class QazaSyncEngine {
  QazaSyncEngine({
    required QazaLocalStore localStore,
    required QazaSyncRemoteDataSource remote,
    required void Function(SyncState state) onState,
    Future<void> Function()? onLocalDataChanged,
  })  : _localStore = localStore,
        _remote = remote,
        _onState = onState,
        _onLocalDataChanged = onLocalDataChanged;

  static const int batchSize = 400;
  static const int changePageSize = 25;
  static const int maxRetryAttempts = 6;

  final QazaLocalStore _localStore;
  final QazaSyncRemoteDataSource _remote;
  final void Function(SyncState state) _onState;
  final Future<void> Function()? _onLocalDataChanged;

  Future<void>? _running;
  Timer? _retryTimer;
  String? _retryUserId;
  bool _disposed = false;

  Future<void> synchronize(String userId) {
    final existing = _running;
    if (existing != null) return existing;

    final future = _run(userId);
    _running = future;
    return future.whenComplete(() {
      if (!_disposed) _running = null;
    });
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
        await _remote.resetUserRecords(
          userId: userId,
          operationId: 'recovery_${userId}',
        );
        await _localStore.retireUserData(userId: userId);
        cursor = null;
        await primeCursor(userId: userId, cursor: null);
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
          await _remote.resetUserRecords(
            userId: userId,
            operationId: first.id,
          );
          await _localStore.retireUserData(userId: userId);
          await _localStore.removeOutboxBatch(userId, [first.id]);
          cursor = null;
          await primeCursor(userId: userId, cursor: null);
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
          final remoteReset = await _remote.getResetState(userId: userId);
          if (remoteReset.inProgress) {
            await _remote.resetUserRecords(
              userId: userId,
              operationId: 'recovery_${userId}',
            );
            await _localStore.retireUserData(userId: userId);
            cursor = null;
            await primeCursor(userId: userId, cursor: null);
            await _notifyLocalDataChanged();
            continue;
          }

          final committed = await _remote.applyOperationsBatch(
            userId: userId,
            operations: operations,
          );
          locallyCommittedChanges.add(committed.id);
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
            error: error.toString(),
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
      final page = await _remote.getChanges(
        userId: userId,
        after: current,
        limit: changePageSize,
      );

      if (page.changes.isEmpty) return current;

      for (final change in page.changes) {
        if (change.type == QazaRemoteChangeType.reset) {
          await _localStore.retireUserData(userId: userId);
          locallyCommittedChanges.clear();
          await _notifyLocalDataChanged();
        } else if (!locallyCommittedChanges.contains(change.cursor.id)) {
          await _localStore.upsertRecords(userId, change.records);
          await _notifyLocalDataChanged();
        }

        current = change.cursor;
        await primeCursor(userId: userId, cursor: current);
      }

      if (!page.hasMore) return current;
    }
  }

  Future<int> _maxAttemptForUser(String userId) async {
    final operations = await _localStore.loadOutboxBatch(
      userId,
      limit: batchSize,
    );
    if (operations.isEmpty) return 0;
    return operations
        .map((operation) => operation.attempts)
        .fold(0, (max, attempts) => attempts > max ? attempts : max);
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
        message.contains('temporarily unavailable');
  }

  String _keyPrefix(String userId) => 'qaza_sync_cursor_${userId}';

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
