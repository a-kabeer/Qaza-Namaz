import 'dart:async';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';

class OfflineFirstQazaRepository implements QazaRepository {
  OfflineFirstQazaRepository({required QazaRepository remote, required QazaLocalStore localStore, Stream<bool>? connectivityChanges, DateTime Function()? now}) : _remote = remote, _localStore = localStore, _now = now ?? DateTime.now { _connectivitySubscription = connectivityChanges?.listen(_onConnectivityChanged); }
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
  int _sessionGeneration = 0;
  final StreamController<SyncState> _stateController = StreamController<SyncState>.broadcast();
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
    if (inflight != null) { try { await inflight; } catch (_) {} }
    _records.clear();
    _outbox = [];
    _lastSyncAt = null;
    if (generation != _sessionGeneration) return;
    _activeUserId = userId;
    if (userId == null) { _emit(const SyncState()); return; }
    _emitPending();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _activeUserId == null) return;
    final generation = _sessionGeneration;
    final userId = _activeUserId!;
    final snapshot = await _localStore.load();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _records..clear()..addAll({for (final record in snapshot.recordsByUser[userId] ?? const []) record.id: record});
    _outbox = List<PendingSyncOp>.of(snapshot.outboxByUser[userId] ?? const <PendingSyncOp>[]);
    _lastSyncAt = snapshot.lastSyncByUser[userId];
    _loaded = true;
  }

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    if (userId != _activeUserId) return const [];
    await _ensureLoaded();
    if (userId != _activeUserId) return const [];
    final records = _records.values.where((r) => prayerType == null || r.prayerType == prayerType).where((r) => status == null || r.status == status).toList()..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    unawaited(_syncInBackground());
    return records;
  }

  @override
  Future<QazaPage> getPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status, DateTime? afterOriginalDate, String? afterId}) async {
    if (userId != _activeUserId) return const QazaPage(records: [], hasMore: false);
    final generation = _sessionGeneration;
    final page = await _localStore.getPage(userId: userId, limit: limit, prayerType: prayerType, status: status, afterOriginalDate: afterOriginalDate, afterId: afterId);
    if (generation != _sessionGeneration || userId != _activeUserId) return const QazaPage(records: [], hasMore: false);
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending({required String userId, required PrayerType prayerType}) async {
    if (userId != _activeUserId) return null;
    final generation = _sessionGeneration;
    final record = await _localStore.getOldestPending(userId: userId, prayerType: prayerType);
    if (generation != _sessionGeneration || userId != _activeUserId) return null;
    return record;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status = QazaStatus.completed, DateTime? from, DateTime? to, DateTime? beforeOriginalDate, String? beforeId}) async {
    if (userId != _activeUserId) return const QazaHistoryPage(records: [], hasMore: false);
    final generation = _sessionGeneration;
    final page = await _localStore.getHistoryPage(userId: userId, limit: limit, prayerType: prayerType, status: status, from: from, to: to, beforeOriginalDate: beforeOriginalDate, beforeId: beforeId);
    if (generation != _sessionGeneration || userId != _activeUserId) return const QazaHistoryPage(records: [], hasMore: false);
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    if (userId != _activeUserId) return QazaProgressSummary.empty();
    final generation = _sessionGeneration;
    final summary = await _localStore.getProgressSummary(userId: userId);
    if (generation != _sessionGeneration || userId != _activeUserId) return QazaProgressSummary.empty();
    return summary;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (record.userId != _activeUserId) throw StateError('Cannot add a Qaza record for a non-active user.');
    await addRecords([record]);
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userId = _activeUserId;
    if (userId == null) throw StateError('Cannot add Qaza records while signed out.');
    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) throw StateError('Authentication session changed while loading Qaza data.');
    final knownKeys = {for (final r in _records.values) _combinationKey(r)};
    final fresh = <QazaRecord>[];
    for (final record in records) {
      if (record.userId != userId || _records.containsKey(record.id) || !knownKeys.add(_combinationKey(record))) continue;
      _records[record.id] = record;
      fresh.add(record);
    }
    if (fresh.isEmpty) return;
    _enqueueAdds(fresh);
    await _persistSnapshot();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _emitPending();
    unawaited(_syncInBackground());
  }

  @override
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => completeRecords(userId: userId, recordIds: [recordId], completedAt: completedAt);

  @override
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) async {
    if (recordIds.isEmpty || userId != _activeUserId) return;
    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    final now = _now();
    final changedIds = <String>{};
    for (final id in recordIds.toSet()) {
      final record = _records[id];
      if (record == null || record.userId != userId || record.status == QazaStatus.completed) continue;
      _records[id] = record.copyWith(status: QazaStatus.completed, completedAt: record.completedAt == null || completedAt.isBefore(record.completedAt!) ? completedAt : record.completedAt, updatedAt: now);
      changedIds.add(id);
    }
    if (changedIds.isEmpty) return;
    _enqueueCompletions(changedIds, completedAt);
    await _persistSnapshot();
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    _emitPending();
    unawaited(_syncInBackground());
  }

  Future<void> syncNow() async { if (_activeUserId == null) return; final generation = _sessionGeneration; await _ensureLoaded(); if (generation != _sessionGeneration || _activeUserId == null) return; await _syncInBackground(); }
  Future<void> _syncInBackground() async { final existing = _syncFuture; if (existing != null) return existing; if (!_loaded || _activeUserId == null) return; final generation = _sessionGeneration; final future = _runSync(generation); _syncFuture = future; try { await future; } finally { if (generation == _sessionGeneration) _syncFuture = null; } }
  Future<void> _runSync(int generation) async {
    final userId = _activeUserId;
    if (userId == null || generation != _sessionGeneration) return;
    if (!_isOnline) { _emit(SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length)); return; }
    _emit(SyncState(status: SyncStatus.syncing, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
    try {
      await _flushOutbox(userId, generation);
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      await _pullRemote(userId, generation);
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _lastSyncAt = _now();
      await _localStore.saveLastSync(userId, _lastSyncAt);
      _emit(SyncState(status: _outbox.isEmpty ? SyncStatus.synced : SyncStatus.pendingSync, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length));
    } catch (error) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      await _persistOutbox();
      _emit(SyncState(status: _isOnline ? SyncStatus.syncError : SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length, detail: error.toString()));
    }
  }
  Future<void> _flushOutbox(String userId, int generation) async {
    while (_outbox.isNotEmpty) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      final op = _outbox.first;
      if (op.userId != userId) throw StateError('Outbox contains an operation for a different user.');
      try {
        switch (op.type) {
          case SyncOpType.add:
            if (op.record == null) { _outbox.removeAt(0); await _persistOutbox(); continue; }
            if (op.record!.userId != userId) throw StateError('Outbox add operation user mismatch.');
            await _remote.addRecord(op.record!); break;
          case SyncOpType.complete:
            if (op.targetRecordId == null) { _outbox.removeAt(0); await _persistOutbox(); continue; }
            await _remote.completeRecord(userId: userId, recordId: op.targetRecordId!, completedAt: op.completedAt ?? _now()); break;
        }
      } catch (error) {
        if (generation != _sessionGeneration || userId != _activeUserId) return;
        _outbox[0] = op.copyWith(attempts: op.attempts + 1, lastError: error.toString()); await _persistOutbox(); rethrow;
      }
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _outbox.removeAt(0); await _persistOutbox();
    }
  }
  Future<void> _pullRemote(String userId, int generation) async {
    final remoteRecords = await _remote.getRecords(userId: userId);
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    final queuedCompletionIds = {for (final op in _outbox) if (op.type == SyncOpType.complete) op.targetRecordId};
    final now = _now();
    for (final remote in remoteRecords) {
      if (remote.userId != userId) throw StateError('Remote returned a Qaza record for a different user.');
      final local = _records[remote.id];
      if (local == null) { _records[remote.id] = remote; continue; }
      if (remote.status == QazaStatus.completed) {
        final remoteAt = remote.completedAt;
        if (local.status != QazaStatus.completed) { _records[remote.id] = local.copyWith(status: QazaStatus.completed, completedAt: remoteAt, updatedAt: remote.updatedAt); _outbox.removeWhere((op) => op.type == SyncOpType.complete && op.targetRecordId == remote.id); }
        else if (remoteAt != null && local.completedAt != null && remoteAt.isBefore(local.completedAt!)) { _records[remote.id] = local.copyWith(completedAt: remoteAt, updatedAt: remote.updatedAt); }
      } else if (local.status == QazaStatus.completed && !queuedCompletionIds.contains(remote.id)) {
        _outbox.insert(0, PendingSyncOp(id: 'complete_${remote.id}', type: SyncOpType.complete, userId: userId, queuedAt: now, targetRecordId: remote.id, completedAt: local.completedAt));
      }
    }
    await _persistSnapshot();
  }
  void _enqueueAdds(List<QazaRecord> records) { final queuedAt = _now(); _outbox.addAll([for (final record in records) PendingSyncOp(id: 'add_${record.id}', type: SyncOpType.add, userId: record.userId, queuedAt: queuedAt, record: record)]); }
  void _enqueueCompletions(Set<String> ids, DateTime completedAt) { final queuedAt = _now(); final queued = {for (final op in _outbox) if (op.type == SyncOpType.complete) op.targetRecordId}; _outbox.addAll([for (final id in ids) if (!queued.contains(id)) PendingSyncOp(id: 'complete_$id', type: SyncOpType.complete, userId: _activeUserId!, queuedAt: queuedAt, targetRecordId: id, completedAt: completedAt)]); }
  Future<void> _persistSnapshot() async { final userId = _activeUserId; if (userId != null) await _localStore.saveRecordsAndOutbox(userId, _records.values.toList(), _outbox); }
  Future<void> _persistOutbox() async { final userId = _activeUserId; if (userId != null) await _localStore.saveOutbox(userId, _outbox); }
  void _emit(SyncState state) { _state = state; if (!_stateController.isClosed) _stateController.add(state); }
  void _emitPending() { if (_activeUserId != null) _emit(SyncState(status: _isOnline ? SyncStatus.pendingSync : SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length)); }
  void _onConnectivityChanged(bool isOnline) { _isOnline = isOnline; if (!isOnline) _emit(SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: _outbox.length)); else if (_loaded) unawaited(_syncInBackground()); }
  String _combinationKey(QazaRecord record) => '${record.prayerType.name}|${record.originalDate.year}-${record.originalDate.month}-${record.originalDate.day}';
  void dispose() { unawaited(_connectivitySubscription?.cancel()); unawaited(_stateController.close()); }
}
