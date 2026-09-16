import 'dart:async';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';

/// Offline-first decorator around the real [QazaRepository].
class OfflineFirstQazaRepository implements QazaRepository {
  OfflineFirstQazaRepository({required QazaRepository remote, required QazaLocalStore localStore, Stream<bool>? connectivityChanges, DateTime Function()? now})
      : _remote = remote,
        _localStore = localStore,
        _now = now ?? DateTime.now {
    _connectivitySubscription = connectivityChanges?.listen(_onConnectivityChanged);
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
  final StreamController<SyncState> _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Future<void>? _syncFuture;

  Stream<SyncState> get syncState => _stateController.stream;
  SyncState get currentState => _state;
  String? get activeUserId => _activeUserId;

  Future<void> setActiveUser(String? userId) async {
    _activeUserId = null;
    _loaded = false;
    final inflight = _syncFuture;
    _syncFuture = null;
    if (inflight != null) {
      try { await inflight; } catch (_) {}
    }
    _records.clear();
    _outbox = [];
    _lastSyncAt = null;
    _activeUserId = userId;
    if (userId == null) {
      _emit(_state = const SyncState());
      return;
    }
    await _ensureLoaded();
    _emitPending();
    unawaited(_syncInBackground());
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _activeUserId == null) return;
    final snapshot = await _localStore.load();
    final userId = _activeUserId!;
    _records
      ..clear()
      ..addAll({for (final record in snapshot.recordsByUser[userId] ?? const []) record.id: record});
    _outbox = List<PendingSyncOp>.of(snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[]);
    _lastSyncAt = snapshot.lastSyncByUser[userId];
    _loaded = true;
  }

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    if (userId != _activeUserId) return const [];
    await _ensureLoaded();
    final records = _records.values.where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return records;
  }

  /// Targeted lookup used by date/prayer duplicate checks. It deliberately
  /// bypasses the full repository cache when the local store supports it.
  Future<List<QazaRecord>> getRecordsForDates({required String userId, required Iterable<DateTime> dates, PrayerType? prayerType, QazaStatus? status}) async {
    if (userId != _activeUserId) return const [];
    return _localStore.getRecordsForDates(userId: userId, dates: dates, prayerType: prayerType, status: status);
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (record.userId != _activeUserId) throw StateError('Cannot add a Qaza record for a non-active user while offline-first.');
    await _ensureLoaded();
    final existing = _records[record.id];
    final key = _combinationKey(record);
    if (existing != null || _records.values.any((candidate) => _combinationKey(candidate) == key)) return;
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
    if (userId == null) throw StateError('Cannot add Qaza records while signed out.');
    await _ensureLoaded();
    final knownKeys = {for (final record in _records.values) _combinationKey(record)};
    final fresh = <QazaRecord>[];
    for (final record in records) {
      if (record.userId != userId || _records.containsKey(record.id) || !knownKeys.add(_combinationKey(record))) continue;
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
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => completeRecords(userId: userId, recordIds: [recordId], completedAt: completedAt);

  @override
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) async {
    if (recordIds.isEmpty || userId != _activeUserId) return;
    await _ensureLoaded();
    final now = _now();
    final changedIds = <String>{};
    for (final recordId in recordIds.toSet()) {
      final record = _records[recordId];
      if (record == null || record.status == QazaStatus.completed) continue;
      _records[recordId] = record.copyWith(status: QazaStatus.completed, completedAt: record.completedAt == null ? completedAt : (record.completedAt!.isBefore(completedAt) ? record.completedAt : completedAt), updatedAt: now);
      changedIds.add(recordId);
    }
    if (changedIds.isEmpty) return;
    await _persistRecords();
    _enqueueCompletions(changedIds, completedAt);
    await _persistOutbox();
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
    if (existing != null) { await existing; return; }
    final future = _runSync();
    _syncFuture = future;
    try { await future; } finally { _syncFuture = null; }
  }

  Future<void> _runSync() async {
    final userId = _activeUserId;
    if (userId == null) return;
    if (!_isOnline) {
      _emit(_state = SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
      return;
    }
    _emit(_state = SyncState(status: SyncStatus.syncing, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
    try {
      await _flushOutbox(userId);
      await _pullRemote(userId);
      _lastSyncAt = _now();
      await _localStore.saveLastSync(userId, _lastSyncAt);
      _emit(_state = SyncState(status: _outbox.isEmpty ? SyncStatus.synced : SyncStatus.pendingSync, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
    } catch (error) {
      await _persistOutbox();
      _emit(_state = SyncState(status: _isOnline ? SyncStatus.syncError : SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length, detail: error.toString()));
    }
  }

  Future<void> _flushOutbox(String userId) async {
    while (_outbox.isNotEmpty) {
      final op = _outbox.first;
      try {
        switch (op.type) {
          case SyncOpType.add:
            final record = op.record;
            if (record == null) { _outbox.removeAt(0); await _persistOutbox(); continue; }
            await _remote.addRecord(record);
            break;
          case SyncOpType.complete:
            final targetId = op.targetRecordId;
            if (targetId == null) { _outbox.removeAt(0); await _persistOutbox(); continue; }
            await _remote.completeRecord(userId: userId, recordId: targetId, completedAt: op.completedAt ?? _now());
            break;
        }
      } catch (error) {
        _outbox[0] = op.copyWith(attempts: op.attempts + 1, lastError: error.toString());
        rethrow;
      }
      _outbox.removeAt(0);
      await _persistOutbox();
    }
  }

  Future<void> _pullRemote(String userId) async {
    final remoteRecords = await _remote.getRecords(userId: userId);
    var outboxDirty = false;
    final now = _now();
    final queuedCompletionIds = {for (final op in _outbox) if (op.type == SyncOpType.complete) op.targetRecordId};
    for (final remote in remoteRecords) {
      final local = _records[remote.id];
      if (local == null) { _records[remote.id] = remote; continue; }
      if (remote.status == QazaStatus.completed) {
        final remoteAt = remote.completedAt;
        if (local.status != QazaStatus.completed) {
          _records[remote.id] = local.copyWith(status: QazaStatus.completed, completedAt: remoteAt, updatedAt: remote.updatedAt);
          final before = _outbox.length;
          _outbox = _outbox.where((op) => !(op.type == SyncOpType.complete && op.targetRecordId == remote.id)).toList();
          if (_outbox.length != before) { outboxDirty = true; queuedCompletionIds.remove(remote.id); }
        } else if (remoteAt != null && local.completedAt != null && remoteAt.isBefore(local.completedAt!)) {
          _records[remote.id] = local.copyWith(completedAt: remoteAt, updatedAt: remote.updatedAt);
        }
      } else if (local.status == QazaStatus.completed && !queuedCompletionIds.contains(remote.id)) {
        _enqueueCompletions({remote.id}, local.completedAt ?? now);
        outboxDirty = true;
      }
    }
    if (outboxDirty) await _persistOutbox();
    await _persistRecords();
  }

  void _enqueueAdds(List<QazaRecord> records) {
    final now = _now();
    _outbox.addAll(records.map((record) => PendingSyncOp(id: 'add_${record.id}', type: SyncOpType.add, userId: record.userId, queuedAt: now, record: record)));
  }

  void _enqueueCompletions(Set<String> recordIds, DateTime completedAt) {
    final userId = _activeUserId;
    if (userId == null) return;
    final existing = {for (final op in _outbox) if (op.type == SyncOpType.complete) op.targetRecordId};
    for (final recordId in recordIds) {
      if (existing.contains(recordId)) continue;
      _outbox.add(PendingSyncOp(id: 'complete_${recordId}_$userId', type: SyncOpType.complete, userId: userId, queuedAt: _now(), targetRecordId: recordId, completedAt: completedAt));
    }
  }

  Future<void> _persistRecords() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await _localStore.saveRecords(userId, _records.values.toList(growable: false));
  }

  Future<void> _persistOutbox() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await _localStore.saveOutbox(userId, List<PendingSyncOp>.unmodifiable(_outbox));
  }

  void _emitPending() => _emit(_state = SyncState(status: _outbox.isEmpty ? SyncStatus.synced : SyncStatus.pendingSync, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
  void _emit(SyncState state) { if (!_stateController.isClosed) _stateController.add(state); }
  void _onConnectivityChanged(bool online) { _isOnline = online; if (online) unawaited(_syncInBackground()); else _emit(_state = SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length)); }
  String _combinationKey(QazaRecord record) => '${record.userId}|${record.prayerType.name}|${record.originalDate.year}-${record.originalDate.month}-${record.originalDate.day}';

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _stateController.close();
  }
}
