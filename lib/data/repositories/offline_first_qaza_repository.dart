import 'dart:async';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';

class OfflineFirstQazaRepository implements QazaRepository {
  OfflineFirstQazaRepository(
      {required QazaRepository remote,
      required QazaLocalStore localStore,
      Stream<bool>? connectivityChanges,
      DateTime Function()? now})
      : _remote = remote,
        _localStore = localStore,
        _now = now ?? DateTime.now {
    _connectivitySubscription =
        connectivityChanges?.listen(_onConnectivityChanged);
  }
  final QazaRepository _remote;
  final QazaLocalStore _localStore;
  final DateTime Function() _now;
  StreamSubscription<bool>? _connectivitySubscription;
  final Map<String, QazaRecord> _records = {};
  List<PendingSyncOp> _outbox = [];
  DateTime? _lastSyncAt;
  String? _activeUserId;
  bool _isOnline = true;
  bool _loaded = false;
  bool _hydrated = false;
  Future<void>? _hydrationFuture;
  int _sessionGeneration = 0;
  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Future<void>? _syncFuture;
  Stream<SyncState> get syncState => _stateController.stream;
  SyncState get currentState => _state;
  String? get activeUserId => _activeUserId;
  Future<void> setActiveUser(String? userId) async {
    final generation = ++_sessionGeneration;
    _activeUserId = null;
    _loaded = false;
    final inflight = _syncFuture;
    _syncFuture = null;
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {}
    }
    _records.clear();
    _outbox = [];
    _lastSyncAt = null;
    if (generation != _sessionGeneration) return;
    _activeUserId = userId;
    _hydrated = false;
    _hydrationFuture = null;
    if (userId == null) {
      _emit(const SyncState());
      return;
    }
    _hydrationFuture = _bootstrap(userId, generation);
  }

  /// Brings the local database to a state that can be trusted as complete for
  /// this account before any availability or duplicate calculation runs.
  ///
  /// ```text
  /// signed in -> BOOTSTRAPPING -> (local empty?) -> HYDRATING -> READY
  /// ```
  ///
  /// An offline start, an empty cloud account or a failed pull all still end in
  /// a ready state: the account simply starts from whatever is local. Only an
  /// interrupted account switch abandons the run, and the next one supersedes
  /// it through [_sessionGeneration].
  Future<void> _bootstrap(String userId, int generation) async {
    _emit(SyncState(status: SyncStatus.bootstrapping, pendingCount: 0));
    try {
      // Emptiness is probed with a single-record page, never by materializing
      // the local snapshot: startup must stay bounded on a 10,000-record
      // ledger. `_records` and `_outbox` were just cleared for this session, so
      // when the probe comes back empty they already match the local state and
      // `_pullRemote` can merge into them directly.
      final probe = await _localStore.getPage(userId: userId, limit: 1);
      if (generation != _sessionGeneration || userId != _activeUserId) return;

      // An empty ledger with a queued reset is empty by intent, not by
      // absence: hydrating it would restore exactly the records the reset is
      // about to delete remotely.
      final resetQueued = probe.records.isEmpty
          ? await _localStore.hasPendingReset(userId)
          : false;
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      final needsHydration = probe.records.isEmpty && _isOnline && !resetQueued;
      if (needsHydration) {
        _emit(SyncState(
          status: SyncStatus.hydrating,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
        ));
        try {
          await _pullRemote(userId, generation);
          if (generation != _sessionGeneration || userId != _activeUserId) {
            return;
          }
          _lastSyncAt = _now();
          await _localStore.saveLastSync(userId, _lastSyncAt);
        } catch (error) {
          // A failed first pull must not strand the account in HYDRATING; the
          // app continues offline-first and retries on the next sync.
          if (generation != _sessionGeneration || userId != _activeUserId) {
            return;
          }
          _hydrated = true;
          _emit(SyncState(
            status: _isOnline ? SyncStatus.syncError : SyncStatus.offline,
            lastSyncAt: _lastSyncAt,
            pendingCount: _outbox.length,
            detail: error.toString(),
          ));
          return;
        }
      }

      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _hydrated = true;
      _emitPending();
    } catch (_) {
      // Bootstrap must always terminate in a usable state.
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _hydrated = true;
      _emitPending();
    }
  }

  /// Awaits initial hydration. Reads use this so no caller can observe a
  /// partially hydrated ledger.
  Future<void> ensureHydrated() async {
    final pending = _hydrationFuture;
    if (_hydrated || pending == null) return;
    try {
      await pending;
    } catch (_) {
      // _bootstrap already converted failures into a ready state.
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _activeUserId == null) return;
    final generation = _sessionGeneration;
    final userId = _activeUserId!;
    final snapshot = await _localStore.load();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _records
      ..clear()
      ..addAll({
        for (final r in snapshot.recordsByUser[userId] ?? const []) r.id: r
      });
    _outbox = List.of(snapshot.outboxByUser[userId] ?? const []);
    _lastSyncAt = snapshot.lastSyncByUser[userId];
    _loaded = true;
  }

  @override
  Future<List<QazaRecord>> getRecords(
      {required String userId,
      PrayerType? prayerType,
      QazaStatus? status}) async {
    if (userId != _activeUserId) return const [];
    await ensureHydrated();
    await _ensureLoaded();
    if (userId != _activeUserId) return const [];
    final result = _records.values
        .where((r) => prayerType == null || r.prayerType == prayerType)
        .where((r) => status == null || r.status == status)
        .toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    unawaited(_syncInBackground());
    return result;
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
    if (userId != _activeUserId)
      return const QazaPage(records: [], hasMore: false);
    await ensureHydrated();
    final generation = _sessionGeneration;
    final page = await _localStore.getPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        from: from,
        to: to,
        afterOriginalDate: afterOriginalDate,
        afterId: afterId);
    if (generation != _sessionGeneration || userId != _activeUserId)
      return const QazaPage(records: [], hasMore: false);
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending(
      {required String userId, required PrayerType prayerType}) async {
    if (userId != _activeUserId) return null;
    await ensureHydrated();
    final generation = _sessionGeneration;
    final record = await _localStore.getOldestPending(
        userId: userId, prayerType: prayerType);
    if (generation != _sessionGeneration || userId != _activeUserId)
      return null;
    return record;
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
    if (userId != _activeUserId)
      return const QazaHistoryPage(records: [], hasMore: false);
    await ensureHydrated();
    final generation = _sessionGeneration;
    final page = await _localStore.getHistoryPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        from: from,
        to: to,
        beforeOriginalDate: beforeOriginalDate,
        beforeId: beforeId);
    if (generation != _sessionGeneration || userId != _activeUserId)
      return const QazaHistoryPage(records: [], hasMore: false);
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary(
      {required String userId}) async {
    if (userId != _activeUserId) return QazaProgressSummary.empty();
    await ensureHydrated();
    final generation = _sessionGeneration;
    final result = await _localStore.getProgressSummary(userId: userId);
    if (generation != _sessionGeneration || userId != _activeUserId)
      return QazaProgressSummary.empty();
    return result;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (record.userId != _activeUserId)
      throw StateError('Cannot add a Qaza record for a non-active user.');
    await addRecords([record]);
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userId = _activeUserId;
    if (userId == null)
      throw StateError('Cannot add Qaza records while signed out.');
    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId)
      throw StateError(
          'Authentication session changed while loading Qaza data.');
    final keys = {
      for (final r in _records.values)
        '${r.prayerType.name}|${r.originalDate.year}-${r.originalDate.month}-${r.originalDate.day}'
    };
    final fresh = <QazaRecord>[];
    for (final r in records) {
      if (r.userId != userId ||
          _records.containsKey(r.id) ||
          !keys.add(
              '${r.prayerType.name}|${r.originalDate.year}-${r.originalDate.month}-${r.originalDate.day}'))
        continue;
      _records[r.id] = r;
      fresh.add(r);
    }
    if (fresh.isEmpty) return;
    final queuedAt = _now();
    _outbox.addAll([
      for (final r in fresh)
        PendingSyncOp(
            id: 'add_${r.id}',
            type: SyncOpType.add,
            userId: userId,
            queuedAt: queuedAt,
            record: r)
    ]);
    await _persistSnapshot();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _emitPending();
    unawaited(_syncInBackground());
  }

  @override
  Future<void> completeRecord(
          {required String userId,
          required String recordId,
          required DateTime completedAt}) =>
      completeRecords(
          userId: userId, recordIds: [recordId], completedAt: completedAt);
  @override
  Future<void> completeRecords(
      {required String userId,
      required List<String> recordIds,
      required DateTime completedAt}) async {
    if (recordIds.isEmpty || userId != _activeUserId) return;
    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    final now = _now();
    final changed = <String>{};
    for (final id in recordIds.toSet()) {
      final r = _records[id];
      if (r == null || r.userId != userId || r.status == QazaStatus.completed)
        continue;
      _records[id] = r.copyWith(
          status: QazaStatus.completed,
          completedAt:
              r.completedAt == null || completedAt.isBefore(r.completedAt!)
                  ? completedAt
                  : r.completedAt,
          updatedAt: now);
      changed.add(id);
    }
    if (changed.isEmpty) return;
    final queuedAt = _now();
    final queued = {
      for (final op in _outbox)
        if (op.type == SyncOpType.complete) op.targetRecordId
    };
    _outbox.addAll([
      for (final id in changed)
        if (!queued.contains(id))
          PendingSyncOp(
              id: 'complete_$id',
              type: SyncOpType.complete,
              userId: userId,
              queuedAt: queuedAt,
              targetRecordId: id,
              completedAt: completedAt)
    ]);
    await _persistSnapshot();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _emitPending();
    unawaited(_syncInBackground());
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    if (userId != _activeUserId)
      throw StateError('Cannot reset Qaza records for a non-active user.');
    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId)
      throw StateError(
          'Authentication session changed while loading Qaza data.');
    _records.clear();
    // Queued adds and completions name records that no longer exist, so the
    // reset replaces the outbox instead of joining the back of it. Anything
    // queued after this point is a genuinely new record and still flushes in
    // order, behind the reset.
    _outbox = [
      PendingSyncOp(
          id: 'reset_$userId',
          type: SyncOpType.reset,
          userId: userId,
          queuedAt: _now())
    ];
    await _persistSnapshot();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _emitPending();
    unawaited(_syncInBackground());
  }

  Future<void> syncNow() async {
    if (_activeUserId == null) return;
    await _ensureLoaded();
    await _syncInBackground();
  }

  Future<void> _syncInBackground() async {
    final existing = _syncFuture;
    if (existing != null) return existing;
    if (!_loaded || _activeUserId == null) return;
    final generation = _sessionGeneration;
    final future = _runSync(generation);
    _syncFuture = future;
    try {
      await future;
    } finally {
      if (generation == _sessionGeneration) _syncFuture = null;
    }
  }

  Future<void> _runSync(int generation) async {
    final userId = _activeUserId;
    if (userId == null || generation != _sessionGeneration) return;
    if (!_isOnline) {
      _emit(SyncState(
          status: SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length));
      return;
    }
    _emit(SyncState(
        status: SyncStatus.syncing,
        lastSyncAt: _lastSyncAt,
        pendingCount: _outbox.length));
    try {
      await _flushOutbox(userId, generation);
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      await _pullRemote(userId, generation);
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _lastSyncAt = _now();
      await _localStore.saveLastSync(userId, _lastSyncAt);
      _emit(SyncState(
          status: _outbox.isEmpty ? SyncStatus.synced : SyncStatus.pendingSync,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length));
    } catch (error) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      await _persistOutbox();
      _emit(SyncState(
          status: _isOnline ? SyncStatus.syncError : SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length,
          detail: error.toString()));
    }
  }

  Future<void> _flushOutbox(String userId, int generation) async {
    while (_outbox.isNotEmpty) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      final op = _outbox.first;
      if (op.userId != userId)
        throw StateError('Outbox contains an operation for a different user.');
      try {
        switch (op.type) {
          case SyncOpType.add:
            if (op.record == null) {
              _outbox.removeAt(0);
              await _persistOutbox();
              continue;
            }
            if (op.record!.userId != userId)
              throw StateError('Outbox add operation user mismatch.');
            await _remote.addRecord(op.record!);
            break;
          case SyncOpType.complete:
            if (op.targetRecordId == null) {
              _outbox.removeAt(0);
              await _persistOutbox();
              continue;
            }
            await _remote.completeRecord(
                userId: userId,
                recordId: op.targetRecordId!,
                completedAt: op.completedAt ?? _now());
            break;
          case SyncOpType.reset:
            await _remote.resetUserRecords(userId: userId);
            break;
        }
      } catch (error) {
        _outbox[0] =
            op.copyWith(attempts: op.attempts + 1, lastError: error.toString());
        await _persistOutbox();
        rethrow;
      }
      _outbox.removeAt(0);
      await _persistOutbox();
    }
  }

  Future<void> _pullRemote(String userId, int generation) async {
    final remoteRecords = await _remote.getRecords(userId: userId);
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    final queued = {
      for (final op in _outbox)
        if (op.type == SyncOpType.complete) op.targetRecordId
    };
    final now = _now();
    for (final remote in remoteRecords) {
      if (remote.userId != userId)
        throw StateError('Remote returned a Qaza record for a different user.');
      final local = _records[remote.id];
      if (local == null) {
        _records[remote.id] = remote;
        continue;
      }
      if (remote.status == QazaStatus.completed) {
        final at = remote.completedAt;
        if (local.status != QazaStatus.completed) {
          _records[remote.id] = local.copyWith(
              status: QazaStatus.completed,
              completedAt: at,
              updatedAt: remote.updatedAt);
          _outbox.removeWhere((op) =>
              op.type == SyncOpType.complete && op.targetRecordId == remote.id);
        } else if (at != null &&
            local.completedAt != null &&
            at.isBefore(local.completedAt!)) {
          _records[remote.id] =
              local.copyWith(completedAt: at, updatedAt: remote.updatedAt);
        }
      } else if (local.status == QazaStatus.completed &&
          !queued.contains(remote.id)) {
        _outbox.insert(
            0,
            PendingSyncOp(
                id: 'complete_${remote.id}',
                type: SyncOpType.complete,
                userId: userId,
                queuedAt: now,
                targetRecordId: remote.id,
                completedAt: local.completedAt));
      }
    }
    await _persistSnapshot();
  }

  Future<void> _persistSnapshot() async {
    final userId = _activeUserId;
    if (userId != null)
      await _localStore.saveRecordsAndOutbox(
          userId, _records.values.toList(), _outbox);
  }

  Future<void> _persistOutbox() async {
    final userId = _activeUserId;
    if (userId != null) await _localStore.saveOutbox(userId, _outbox);
  }

  void _emit(SyncState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _emitPending() {
    if (_activeUserId != null)
      _emit(SyncState(
          status: _isOnline ? SyncStatus.pendingSync : SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length));
  }

  void _onConnectivityChanged(bool online) {
    _isOnline = online;
    if (!online)
      _emit(SyncState(
          status: SyncStatus.offline,
          lastSyncAt: _lastSyncAt,
          pendingCount: _outbox.length));
    else if (_loaded) unawaited(_syncInBackground());
  }

  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_stateController.close());
  }
}
