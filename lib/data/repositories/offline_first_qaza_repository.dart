import 'dart:async';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';

/// Offline-first decorator around the real [QazaRepository].
///
/// Architecture: UI -> QazaService -> this repository -> local cache ->
/// Firestore synchronization.
///
/// Behaviour:
/// - Reads are always served from the local cache: instant, and fully
///   functional with no network.
/// - Writes hit the local cache first, update the UI immediately, and enqueue
///   an outbox operation that is replayed against Firestore in the background.
///   Users are never blocked on network availability.
/// - The outbox is removed only after the remote repository confirms the
///   operation, so an app kill or network failure mid-sync simply replays the
///   remaining operations. Remote operations are idempotent (stable record
///   IDs, skip-if-exists adds, skip-if-completed completions), which makes
///   replays duplicate-safe.
///
/// Conflict policy (deterministic, no data loss):
/// - The stable record ID (`{userId}_{prayerType}_{date}`) is authoritative.
/// - Adds are idempotent: an incoming record for an existing ID never
///   overwrites or duplicates local data.
/// - Completion is forward-only: pending -> completed, never back. When both
///   sides are completed, the earliest `completedAt` wins.
/// - During pull-merge, a locally completed record whose remote copy is still
///   pending gets its completion re-queued, covering lost-op edge cases.
///
/// Cache data is namespaced by Firebase UID; [setActiveUser] swaps the active
/// namespace so different accounts never see each other's records.
class OfflineFirstQazaRepository implements QazaRepository {
  OfflineFirstQazaRepository({
    required QazaRepository remote,
    required QazaLocalStore localStore,
    Stream<bool>? connectivityChanges,
    DateTime Function()? now,
  })  : _remote = remote,
        _localStore = localStore,
        _now = now ?? DateTime.now {
    _connectivitySubscription =
        connectivityChanges?.listen(_onConnectivityChanged);
  }

  final QazaRepository _remote;
  final QazaLocalStore _localStore;
  final DateTime Function() _now;

  /// Held so [dispose] can release it: an un-cancelled connectivity listener
  /// outlives the repository and keeps it (and its cache) alive.
  StreamSubscription<bool>? _connectivitySubscription;

  /// Active user's cache. Empty whenever no user is signed in.
  final Map<String, QazaRecord> _records = {};
  List<PendingSyncOp> _outbox = [];
  DateTime? _lastSyncAt;
  String? _activeUserId;
  bool _isOnline = true;
  bool _loaded = false;

  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Future<void>? _syncFuture;

  /// Broadcast stream of sync-layer snapshots for the UI.
  Stream<SyncState> get syncState => _stateController.stream;

  /// Latest sync snapshot (a plain getter so UI can render without waiting
  /// for the first stream event).
  SyncState get currentState => _state;

  String? get activeUserId => _activeUserId;

  /// Switches the active account namespace. Called on sign-in, account
  /// switch, and with `null` on sign-out. Per-user data stays persisted on
  /// disk, but only the active user's records are ever loaded into memory.
  ///
  /// Race safety: an in-flight background sync for the previous account is
  /// fully drained BEFORE the next account's data is loaded. During the
  /// drain the active user is `null`, so the sync's persistence helpers are
  /// no-ops and it can never merge the previous account's data into the
  /// next account's namespace.
  Future<void> setActiveUser(String? userId) async {
    // 1. Detach immediately: durable writes for the old session become
    //    no-ops (persist helpers read `_activeUserId` at resume time).
    _activeUserId = null;
    _loaded = false;
    // 2. Drain any in-flight sync so it cannot touch the next namespace.
    final inflight = _syncFuture;
    _syncFuture = null;
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {
        // Its failure is already reflected in the persisted outbox.
      }
    }
    // 3. The draining sync may have mutated the shared buffers; reset them.
    _records.clear();
    _outbox = [];
    _lastSyncAt = null;
    // 4. Swap in the new account.
    _activeUserId = userId;
    if (userId == null) {
      _emit(_state = const SyncState());
      return;
    }
    await _ensureLoaded();
    _emitPending();
    // Fresh account session: flush queued writes and pull remote changes.
    unawaited(_syncInBackground());
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _activeUserId == null) return;
    final snapshot = await _localStore.load();
    final userId = _activeUserId!;
    _records
      ..clear()
      ..addAll({
        for (final record in snapshot.recordsByUser[userId] ?? const [])
          record.id: record,
      });
    _outbox = List<PendingSyncOp>.of(
      snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[],
    );
    _lastSyncAt = snapshot.lastSyncByUser[userId];
    _loaded = true;
  }

  // ---- QazaRepository: reads are always local, never network-bound ----

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    // Never serve another account's cache.
    if (userId != _activeUserId) return const [];
    await _ensureLoaded();
    final records = _records.values
        .where(
          (record) => prayerType == null || record.prayerType == prayerType,
        )
        .where((record) => status == null || record.status == status)
        .toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
  }

  // ---- QazaRepository: writes are local-first, remote sync is backgrounded

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (record.userId != _activeUserId) {
      throw StateError(
        'Cannot add a Qaza record for a non-active user while offline-first.',
      );
    }
    await _ensureLoaded();
    final existing = _records[record.id];
    final key = _combinationKey(record);
    final duplicate = existing != null ||
        _records.values.any((candidate) => _combinationKey(candidate) == key);
    // Idempotent under the stable-ID convention: never duplicate or mutate
    // an existing record through add.
    if (duplicate) return;

    _records[record.id] = record;
    await _persistRecords();
    _enqueueAdds([record]);
    await _persistOutbox();
    _emitPending();
    unawaited(_syncInBackground());
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userId = _activeUserId;
    if (userId == null) {
      throw StateError('Cannot add Qaza records while signed out.');
    }
    await _ensureLoaded();
    // One set lookup per incoming record instead of a full scan, so bulk adds
    // stay linear in the ledger size rather than quadratic.
    final knownKeys = {
      for (final record in _records.values) _combinationKey(record),
    };
    final fresh = <QazaRecord>[];
    for (final record in records) {
      if (record.userId != userId) continue;
      if (_records.containsKey(record.id)) continue;
      if (!knownKeys.add(_combinationKey(record))) continue;
      _records[record.id] = record;
      fresh.add(record);
    }
    if (fresh.isEmpty) return;

    await _persistRecords();
    _enqueueAdds(fresh);
    await _persistOutbox();
    _emitPending();
    unawaited(_syncInBackground());
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) {
    return completeRecords(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty) return;
    // Never mutate another account's cache.
    if (userId != _activeUserId) return;
    await _ensureLoaded();
    final now = _now();
    final changedIds = <String>{};

    for (final recordId in recordIds.toSet()) {
      final record = _records[recordId];
      if (record == null || record.status == QazaStatus.completed) continue;
      // Forward-only: pending -> completed. Earliest completion timestamp
      // wins when several devices completed the same record.
      _records[recordId] = record.copyWith(
        status: QazaStatus.completed,
        completedAt: record.completedAt == null
            ? completedAt
            : record.completedAt!.isBefore(completedAt)
                ? record.completedAt
                : completedAt,
        updatedAt: now,
      );
      changedIds.add(recordId);
    }
    if (changedIds.isEmpty) return;

    await _persistRecords();
    _enqueueCompletions(changedIds, completedAt);
    await _persistOutbox();
    _emitPending();
    unawaited(_syncInBackground());
  }

  // ---- Synchronization engine ----

  /// Manual retry entry point for the UI (sync banner, Data & Cloud screen).
  Future<void> syncNow() async {
    if (_activeUserId == null) return;
    await _ensureLoaded();
    await _syncInBackground();
  }

  /// Single-flight background sync: flushes the outbox, then pulls remote
  /// changes. Failures leave the outbox intact for the next attempt.
  Future<void> _syncInBackground() async {
    final existing = _syncFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _runSync();
    _syncFuture = future;
    try {
      await future;
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _runSync() async {
    final userId = _activeUserId;
    if (userId == null) return;
    if (!_isOnline) {
      _emit(
        _state = SyncState(
          status: SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
        ),
      );
      return;
    }
    _emit(
      _state = SyncState(
        status: SyncStatus.syncing,
        lastSyncAt: _lastSyncAt,
        pendingCount: _outbox.length,
      ),
    );

    try {
      await _flushOutbox(userId);
      await _pullRemote(userId);
      _lastSyncAt = _now();
      await _localStore.saveLastSync(userId, _lastSyncAt);
      _emit(
        _state = SyncState(
          status: _outbox.isEmpty ? SyncStatus.synced : SyncStatus.pendingSync,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
        ),
      );
    } catch (error) {
      // Keep every unconfirmed op queued; surface the failure deterministically.
      await _persistOutbox();
      _emit(
        _state = SyncState(
          status: _isOnline ? SyncStatus.syncError : SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<void> _flushOutbox(String userId) async {
    while (_outbox.isNotEmpty) {
      // The head is mutated in place rather than re-allocating the whole list
      // with `sublist`, so a long queue does not churn memory per operation.
      final op = _outbox.first;
      try {
        switch (op.type) {
          case SyncOpType.add:
            final record = op.record;
            if (record == null) {
              // Corrupt entry: drop instead of blocking the queue forever.
              _outbox.removeAt(0);
              await _persistOutbox();
              continue;
            }
            // Idempotent remote add: skip-if-exists keeps replays safe.
            await _remote.addRecord(record);
            break;
          case SyncOpType.complete:
            final targetId = op.targetRecordId;
            if (targetId == null) {
              _outbox.removeAt(0);
              await _persistOutbox();
              continue;
            }
            // Idempotent remote completion: skip-if-completed keeps replays
            // safe.
            await _remote.completeRecord(
              userId: userId,
              recordId: targetId,
              completedAt: op.completedAt ?? _now(),
            );
            break;
        }
      } catch (error) {
        // The op stays queued with its failure recorded for the next attempt.
        _outbox[0] = op.copyWith(
          attempts: op.attempts + 1,
          lastError: error.toString(),
        );
        rethrow;
      }
      // Confirmed remotely: only now remove the op from the outbox.
      _outbox.removeAt(0);
      await _persistOutbox();
    }
  }

  /// Pull-merge of remote records into the local cache.
  ///
  /// Deterministic, additive, and loss-free:
  /// - Remote records missing locally are inserted (deduped by stable ID).
  /// - Remote completion of a locally pending record is merged forward-only;
  ///   any queued completion op for it is dropped (backend already confirmed).
  /// - Locally completed record whose remote copy is still pending re-queues
  ///   its completion so a kill mid-sync can never lose user data.
  /// - Both completed: the earliest `completedAt` wins.
  /// - Local-only records are never deleted by a pull.
  Future<void> _pullRemote(String userId) async {
    final remoteRecords = await _remote.getRecords(userId: userId);
    var outboxDirty = false;
    final now = _now();
    // Completions already queued, so the merge below never scans the outbox
    // once per remote record.
    final queuedCompletionIds = {
      for (final op in _outbox)
        if (op.type == SyncOpType.complete) op.targetRecordId,
    };

    for (final remote in remoteRecords) {
      final local = _records[remote.id];
      if (local == null) {
        _records[remote.id] = remote;
        continue;
      }

      if (remote.status == QazaStatus.completed) {
        final remoteAt = remote.completedAt;
        if (local.status != QazaStatus.completed) {
          _records[remote.id] = local.copyWith(
            status: QazaStatus.completed,
            completedAt: remoteAt,
            updatedAt: remote.updatedAt,
          );
          final before = _outbox.length;
          _outbox = _outbox
              .where(
                (op) => !(op.type == SyncOpType.complete &&
                    op.targetRecordId == remote.id),
              )
              .toList();
          if (_outbox.length != before) {
            outboxDirty = true;
            queuedCompletionIds.remove(remote.id);
          }
        } else if (remoteAt != null &&
            local.completedAt != null &&
            remoteAt.isBefore(local.completedAt!)) {
          _records[remote.id] = local.copyWith(
            completedAt: remoteAt,
            updatedAt: remote.updatedAt,
          );
        }
      } else if (local.status == QazaStatus.completed &&
          !queuedCompletionIds.contains(remote.id)) {
        _outbox = [
          PendingSyncOp(
            id: 'complete_${remote.id}',
            type: SyncOpType.complete,
            userId: userId,
            queuedAt: now,
            targetRecordId: remote.id,
            completedAt: local.completedAt,
          ),
          ..._outbox,
        ];
        queuedCompletionIds.add(remote.id);
        outboxDirty = true;
      }
    }

    await _persistRecords();
    if (outboxDirty) await _persistOutbox();
  }

  // ---- Outbox helpers ----

  /// Queues add operations with stable op IDs (`add_{recordId}`), so a record
  /// can never be queued for remote creation twice.
  void _enqueueAdds(List<QazaRecord> records) {
    final queuedAt = _now();
    _outbox = [
      ..._outbox,
      for (final record in records)
        PendingSyncOp(
          id: 'add_${record.id}',
          type: SyncOpType.add,
          userId: record.userId,
          queuedAt: queuedAt,
          record: record,
        ),
    ];
  }

  /// Queues completion operations with stable op IDs (`complete_{recordId}`),
  /// skipping ones already queued, so completions cannot duplicate.
  void _enqueueCompletions(Set<String> recordIds, DateTime completedAt) {
    final queuedAt = _now();
    // One pass over the outbox builds the "already queued" set, so enqueueing
    // stays linear rather than scanning the queue once per record.
    final alreadyQueued = {
      for (final op in _outbox)
        if (op.type == SyncOpType.complete) op.targetRecordId,
    };
    final fresh = <PendingSyncOp>[
      for (final recordId in recordIds)
        if (!alreadyQueued.contains(recordId))
          PendingSyncOp(
            id: 'complete_$recordId',
            type: SyncOpType.complete,
            userId: _activeUserId!,
            queuedAt: queuedAt,
            targetRecordId: recordId,
            completedAt: completedAt,
          ),
    ];
    if (fresh.isEmpty) return;
    _outbox = [..._outbox, ...fresh];
  }

  Future<void> _persistRecords() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await _localStore.saveRecords(userId, _records.values.toList());
  }

  Future<void> _persistOutbox() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await _localStore.saveOutbox(userId, _outbox);
  }

  // ---- State emission ----

  void _emit(SyncState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitPending() {
    if (_activeUserId == null) return;
    _emit(
      SyncState(
        status: _isOnline ? SyncStatus.pendingSync : SyncStatus.offline,
        lastSyncAt: _lastSyncAt,
        pendingCount: _outbox.length,
      ),
    );
  }

  // ---- Connectivity ----

  void _onConnectivityChanged(bool isOnline) {
    _isOnline = isOnline;
    if (!isOnline) {
      _emit(
        _state = SyncState(
          status: SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
        ),
      );
      return;
    }
    // Connection restored: flush the queue as soon as possible.
    unawaited(_syncInBackground());
  }

  /// Duplicate key for the stable-ID convention: one record per prayer per
  /// calendar day.
  String _combinationKey(QazaRecord record) =>
      '${record.prayerType.name}|${_dateKey(record.originalDate)}';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Releases the connectivity subscription and the sync-state stream. The
  /// repository is a long-lived application-scoped object; call only on app
  /// teardown/tests.
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_stateController.close());
  }
}


