import 'dart:async';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';

class OfflineFirstQazaRepository implements QazaRepository {
  OfflineFirstQazaRepository({required QazaRepository remote, required QazaLocalStore localStore, Stream<bool>? connectivityChanges, DateTime Function()? now}) : _remote = remote, _localStore = localStore, _now = now ?? DateTime.now { _connectivitySubscription = connectivityChanges?.listen(_onConnectivityChanged); }
  final QazaRepository _remote; final QazaLocalStore _localStore; final DateTime Function() _now;
  StreamSubscription<bool>? _connectivitySubscription; String? _activeUserId; bool _isOnline = true; bool _loaded = false; DateTime? _lastSyncAt;
  final StreamController<SyncState> _stateController = StreamController<SyncState>.broadcast(); SyncState _state = const SyncState(); Future<void>? _syncFuture;
  Stream<SyncState> get syncState => _stateController.stream; SyncState get currentState => _state; String? get activeUserId => _activeUserId;

  Future<void> setActiveUser(String? userId) async { _activeUserId = null; _loaded = false; final inflight = _syncFuture; _syncFuture = null; if (inflight != null) { try { await inflight; } catch (_) {} } _lastSyncAt = null; _activeUserId = userId; if (userId == null) { _emit(_state = const SyncState()); return; } await _ensureLoaded(); await _emitPending(); unawaited(_syncInBackground()); }
  Future<void> _ensureLoaded() async { if (_loaded || _activeUserId == null) return; _lastSyncAt = await _localStore.getLastSync(_activeUserId!); _loaded = true; }
  Future<int> _pendingCount(String userId) => _localStore.getPendingSyncCount(userId);

  @override Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async { if (userId != _activeUserId) return const []; return _localStore.getRecordsForDates(userId: userId, dates: const [], prayerType: prayerType, status: status); }
  @override Future<List<QazaRecord>> getRecordsForDates({required String userId, required Iterable<DateTime> dates, PrayerType? prayerType, QazaStatus? status}) async { if (userId != _activeUserId) return const []; return _localStore.getRecordsForDates(userId: userId, dates: dates, prayerType: prayerType, status: status); }
  @override Future<void> addRecord(QazaRecord record) => addRecords([record]);

  @override Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return; final userId = _activeUserId; if (userId == null) throw StateError('Cannot add Qaza records while signed out.'); await _ensureLoaded();
    final existing = await _localStore.getRecordsForDates(userId: userId, dates: records.map((r) => r.originalDate)); final ids = {for (final r in existing) r.id}; final keys = {for (final r in existing) _key(r)}; final batch = <String>{}; final fresh = <QazaRecord>[];
    for (final r in records) { final key = _key(r); if (r.userId == userId && !ids.contains(r.id) && !keys.contains(key) && batch.add(key)) fresh.add(r); }
    if (fresh.isEmpty) return; await _localStore.saveRecords(userId, fresh); for (final r in fresh) await _localStore.saveOutbox(userId, [PendingSyncOp(id: 'add_${r.id}', type: SyncOpType.add, userId: userId, queuedAt: _now(), record: r)]); await _emitPending(); unawaited(_syncInBackground());
  }

  @override Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => completeRecords(userId: userId, recordIds: [recordId], completedAt: completedAt);
  @override Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) async {
    if (recordIds.isEmpty || userId != _activeUserId) return; await _ensureLoaded(); final requested = recordIds.toSet(); final existing = await _localStore.getRecordsByIds(userId: userId, recordIds: requested); final now = _now(); final changed = <QazaRecord>[];
    for (final r in existing) { if (r.status == QazaStatus.completed) continue; changed.add(r.copyWith(status: QazaStatus.completed, completedAt: r.completedAt == null ? completedAt : (r.completedAt!.isBefore(completedAt) ? r.completedAt : completedAt), updatedAt: now)); }
    if (changed.isEmpty) return; await _localStore.saveRecords(userId, changed); for (final r in changed) await _localStore.saveOutbox(userId, [PendingSyncOp(id: 'complete_${r.id}_$userId', type: SyncOpType.complete, userId: userId, queuedAt: now, targetRecordId: r.id, completedAt: completedAt)]); await _emitPending(); unawaited(_syncInBackground());
  }

  Future<void> syncNow() async { if (_activeUserId == null) return; await _ensureLoaded(); await _syncInBackground(); }
  Future<void> _syncInBackground() async { final existing = _syncFuture; if (existing != null) { await existing; return; } final future = _runSync(); _syncFuture = future; try { await future; } finally { _syncFuture = null; } }
  Future<void> _runSync() async {
    final userId = _activeUserId; if (userId == null) return; final pending = await _pendingCount(userId); if (!_isOnline) { _emit(_state = SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: pending)); return; }
    _emit(_state = SyncState(status: SyncStatus.syncing, lastSyncAt: _lastSyncAt, pendingCount: pending));
    try { await _flushOutbox(userId); await _pullRemote(userId); _lastSyncAt = _now(); await _localStore.saveLastSync(userId, _lastSyncAt); _emit(_state = SyncState(status: SyncStatus.synced, lastSyncAt: _lastSyncAt, pendingCount: await _pendingCount(userId))); }
    catch (error) { _emit(_state = SyncState(status: _isOnline ? SyncStatus.syncError : SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: await _pendingCount(userId), detail: error.toString())); }
  }
  Future<void> _flushOutbox(String userId) async {
    while (true) { final op = await _localStore.getNextPendingSyncOp(userId); if (op == null) return; try { switch (op.type) { case SyncOpType.add: if (op.record != null) await _remote.addRecord(op.record!); break; case SyncOpType.complete: if (op.targetRecordId != null) await _remote.completeRecord(userId: userId, recordId: op.targetRecordId!, completedAt: op.completedAt ?? _now()); break; } } catch (error) { await _localStore.updatePendingSyncOp(userId, op.copyWith(attempts: op.attempts + 1, lastError: error.toString())); rethrow; } await _localStore.deletePendingSyncOp(userId, op.id); }
  }
  Future<void> _pullRemote(String userId) async { const pageSize = 100; String? cursor; do { final page = await _remote.getHistoryPage(userId: userId, cursor: cursor, limit: pageSize, ascending: true); if (page.records.isEmpty) return; await _mergeRemotePage(userId, page.records); cursor = page.hasMore ? page.nextCursor : null; } while (cursor != null); }
  Future<void> _mergeRemotePage(String userId, List<QazaRecord> remoteRecords) async {
    final local = await _localStore.getRecordsForDates(userId: userId, dates: remoteRecords.map((r) => r.originalDate)); final localById = {for (final r in local) r.id: r}; final updates = <QazaRecord>[]; final now = _now();
    for (final remote in remoteRecords) { final current = localById[remote.id]; if (current == null) { updates.add(remote); continue; } if (remote.status == QazaStatus.completed) { if (current.status != QazaStatus.completed) updates.add(current.copyWith(status: QazaStatus.completed, completedAt: remote.completedAt, updatedAt: remote.updatedAt)); else if (remote.completedAt != null && current.completedAt != null && remote.completedAt!.isBefore(current.completedAt!)) updates.add(current.copyWith(completedAt: remote.completedAt, updatedAt: remote.updatedAt)); } else if (current.status == QazaStatus.completed && !await _localStore.hasPendingCompletion(userId, remote.id)) { await _localStore.saveOutbox(userId, [PendingSyncOp(id: 'complete_${remote.id}_$userId', type: SyncOpType.complete, userId: userId, queuedAt: now, targetRecordId: remote.id, completedAt: current.completedAt ?? now)]); } }
    if (updates.isNotEmpty) await _localStore.saveRecords(userId, updates);
  }
  Future<void> _emitPending() async { final userId = _activeUserId; if (userId == null) return; final count = await _pendingCount(userId); _emit(_state = SyncState(status: count == 0 ? SyncStatus.synced : SyncStatus.pendingSync, lastSyncAt: _lastSyncAt, pendingCount: count)); }
  void _emit(SyncState state) { if (!_stateController.isClosed) _stateController.add(state); }
  void _onConnectivityChanged(bool online) { _isOnline = online; if (online) unawaited(_syncInBackground()); else unawaited(_emitPendingOffline()); }
  Future<void> _emitPendingOffline() async { final userId = _activeUserId; if (userId != null) { final count = await _pendingCount(userId); _emit(_state = SyncState(status: SyncStatus.offline, lastSyncAt: _lastSyncAt, pendingCount: count)); } }
  String _key(QazaRecord r) => '${r.userId}|${r.prayerType.name}|${r.originalDate.year}-${r.originalDate.month}-${r.originalDate.day}';
  void dispose() { _connectivitySubscription?.cancel(); _stateController.close(); }
}
