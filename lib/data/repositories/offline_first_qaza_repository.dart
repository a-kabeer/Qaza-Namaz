import 'dart:async';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/qaza_sync_engine.dart';
import '../sync/qaza_sync_remote_data_source.dart';
import '../sync/sync_state.dart';

class _LegacyQazaSyncRemoteDataSource implements QazaSyncRemoteDataSource {
  const _LegacyQazaSyncRemoteDataSource(this._remote);

  final QazaRepository _remote;

  @override
  Future<QazaRemoteResetState> getResetState({
    required String userId,
  }) async =>
      const QazaRemoteResetState(generation: 0, inProgress: false);

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  }) async =>
      null;

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) async =>
      const QazaRemoteChangePage(changes: [], hasMore: false);

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    if (operations.isEmpty) {
      throw ArgumentError('operations must not be empty');
    }

    final type = operations.first.type;
    if (type == SyncOpType.add) {
      await _remote.addRecords([
        for (final operation in operations)
          if (operation.record != null) operation.record!,
      ]);
    } else if (type == SyncOpType.complete) {
      await _remote.completeRecords(
        userId: userId,
        recordIds: [
          for (final operation in operations)
            if (operation.targetRecordId != null) operation.targetRecordId!,
        ],
        completedAt: operations.first.completedAt ?? DateTime.now(),
      );
    } else {
      throw ArgumentError('Reset must use resetUserRecordsForSync.');
    }

    return QazaRemoteChangeCursor(
      at: DateTime.now().toUtc(),
      id: 'legacy_' + operations.first.id,
      generation: 0,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) async {
    await _remote.resetUserRecords(userId: userId);
    return QazaRemoteChangeCursor(
      at: DateTime.now().toUtc(),
      id: 'legacy_reset_' + operationId,
      generation: 0,
    );
  }
}

class OfflineFirstQazaRepository implements QazaRepository {
  static QazaSyncRemoteDataSource _resolveSyncRemote(
    QazaRepository remote,
    QazaSyncRemoteDataSource? syncRemote,
  ) {
    if (syncRemote != null) return syncRemote;
    if (remote is QazaSyncRemoteDataSource) {
      return remote as QazaSyncRemoteDataSource;
    }
    return _LegacyQazaSyncRemoteDataSource(remote);
  }

  OfflineFirstQazaRepository({
    required QazaRepository remote,
    QazaSyncRemoteDataSource? syncRemote,
    required QazaLocalStore localStore,
    Stream<bool>? connectivityChanges,
    DateTime Function()? now,
  })  : _remote = remote,
        _syncRemote = _resolveSyncRemote(remote, syncRemote),
        _localStore = localStore,
        _now = now ?? DateTime.now {
    _connectivitySubscription =
        connectivityChanges?.listen(_onConnectivityChanged);
  }

  final QazaRepository _remote;
  final QazaSyncRemoteDataSource _syncRemote;
  final QazaLocalStore _localStore;
  final DateTime Function() _now;

  StreamSubscription<bool>? _connectivitySubscription;
  final Map<String, QazaRecord> _records = {};
  List<PendingSyncOp> _outbox = [];
  String? _activeUserId;
  bool _isOnline = true;
  bool _loaded = false;
  bool _outboxLoaded = false;
  bool _hydrated = false;
  Future<void>? _hydrationFuture;
  int _sessionGeneration = 0;

  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  QazaSyncEngine? _syncEngine;

  Stream<SyncState> get syncState => _stateController.stream;
  SyncState get currentState => _state;
  String? get activeUserId => _activeUserId;

  Future<void> setActiveUser(String? userId) async {
    final generation = ++_sessionGeneration;

    _activeUserId = null;
    _syncEngine?.dispose();
    _syncEngine = null;
    _loaded = false;
    _records.clear();
    _outbox = [];
    _outboxLoaded = false;
    _hydrated = false;
    _hydrationFuture = null;

    if (generation != _sessionGeneration) return;
    _activeUserId = userId;

    if (userId == null) {
      _emit(const SyncState());
      return;
    }

    final engine = QazaSyncEngine(
      localStore: _localStore,
      remote: _syncRemote,
      onState: _emit,
      onLocalDataChanged: () async {
        if (userId != _activeUserId) return;
        _loaded = false;
        _outboxLoaded = false;
        _records.clear();
      },
    );
    _syncEngine = engine;
    _hydrationFuture = _bootstrap(userId, generation, engine);
  }

  Future<void> _bootstrap(
      String userId, int generation, QazaSyncEngine engine) async {
    _emit(const SyncState(status: SyncStatus.bootstrapping));

    try {
      final probe = await _localStore.getPage(userId: userId, limit: 1);
      if (generation != _sessionGeneration || userId != _activeUserId) return;

      final resetQueued = probe.records.isEmpty
          ? await _localStore.hasPendingReset(userId)
          : false;
      if (generation != _sessionGeneration || userId != _activeUserId) return;

      if (probe.records.isEmpty && _isOnline && !resetQueued) {
        _emit(const SyncState(status: SyncStatus.hydrating));

        final baseline = await _syncRemote.getLatestChange(userId: userId);

        DateTime? afterDate;
        String? afterId;
        while (true) {
          final page = await _remote.getPage(
            userId: userId,
            limit: 500,
            afterOriginalDate: afterDate,
            afterId: afterId,
          );

          if (generation != _sessionGeneration || userId != _activeUserId) {
            return;
          }

          if (page.records.isNotEmpty) {
            await _localStore.appendRecords(userId, page.records);
          }

          if (!page.hasMore) break;
          afterDate = page.nextOriginalDate;
          afterId = page.nextId;
        }

        // Changes that happened during the full restore are reconciled by
        // starting incremental sync from the baseline captured beforehand.
        await engine.primeCursor(userId: userId, cursor: baseline);
      }

      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _hydrated = true;
      await engine.synchronize(userId);
    } catch (error) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _hydrated = true;
      _emit(
        SyncState(
          status: _isOnline ? SyncStatus.syncError : SyncStatus.offline,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<void> ensureHydrated() async {
    final pending = _hydrationFuture;
    if (_hydrated || pending == null) return;
    try {
      await pending;
    } catch (_) {}
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
        for (final record in snapshot.recordsByUser[userId] ?? const [])
          record.id: record,
      });
    _outbox = List.of(snapshot.outboxByUser[userId] ?? const []);
    _loaded = true;
    _outboxLoaded = true;
  }

  Future<void> _ensureOutboxLoaded() async {
    if (_outboxLoaded || _activeUserId == null) return;
    final userId = _activeUserId!;
    final stored = await _localStore.loadOutbox(userId);
    if (userId != _activeUserId) return;
    _outbox = [...stored, ..._outbox];
    _outboxLoaded = true;
  }

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    if (userId != _activeUserId) return const [];
    await ensureHydrated();
    await _ensureLoaded();
    if (userId != _activeUserId) return const [];

    final result = _records.values
        .where((record) =>
            prayerType == null || record.prayerType == prayerType)
        .where((record) => status == null || record.status == status)
        .toList()
      ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
    return result;
  }

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) async {
    if (userId != _activeUserId) {
      return const QazaPage(records: [], hasMore: false);
    }
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
      afterId: afterId,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return const QazaPage(records: [], hasMore: false);
    }
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    if (userId != _activeUserId) return null;
    await ensureHydrated();
    final generation = _sessionGeneration;
    final record = await _localStore.getOldestPending(
      userId: userId,
      prayerType: prayerType,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) return null;
    return record;
  }

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    if (userId != _activeUserId) {
      return const QazaHistoryPage(records: [], hasMore: false);
    }
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
      beforeId: beforeId,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return const QazaHistoryPage(records: [], hasMore: false);
    }
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) async {
    if (userId != _activeUserId) return QazaProgressSummary.empty();
    await ensureHydrated();
    final generation = _sessionGeneration;
    final result = await _localStore.getProgressSummary(userId: userId);
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return QazaProgressSummary.empty();
    }
    return result;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (record.userId != _activeUserId) {
      throw StateError('Cannot add a Qaza record for a non-active user.');
    }
    await addRecords([record]);
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    if (records.isEmpty) return;
    final userId = _activeUserId;
    if (userId == null) {
      throw StateError('Cannot add Qaza records while signed out.');
    }

    final generation = _sessionGeneration;
    await _ensureLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) {
      throw StateError(
          'Authentication session changed while loading Qaza data.');
    }

    final keys = {
      for (final record in _records.values)
        record.prayerType.name +
            '|' +
            record.originalDate.year.toString() +
            '-' +
            record.originalDate.month.toString() +
            '-' +
            record.originalDate.day.toString(),
    };

    final fresh = <QazaRecord>[];
    for (final record in records) {
      final key = record.prayerType.name +
          '|' +
          record.originalDate.year.toString() +
          '-' +
          record.originalDate.month.toString() +
          '-' +
          record.originalDate.day.toString();

      if (record.userId != userId ||
          _records.containsKey(record.id) ||
          !keys.add(key)) {
        continue;
      }

      _records[record.id] = record;
      fresh.add(record);
    }

    if (fresh.isEmpty) return;

    final queuedAt = _now();
    final operations = <PendingSyncOp>[
      for (final record in fresh)
        PendingSyncOp(
          id: 'add_' + record.id,
          type: SyncOpType.add,
          userId: userId,
          queuedAt: queuedAt,
          record: record,
        ),
    ];

    await _localStore.appendRecordsAndOutbox(userId, fresh, operations);
    _outbox.addAll(operations);
    _outboxLoaded = true;
    _emitPending();

    unawaited(_syncEngine?.synchronize(userId) ?? Future<void>.value());
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) =>
      completeRecords(
        userId: userId,
        recordIds: [recordId],
        completedAt: completedAt,
      );

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (recordIds.isEmpty || userId != _activeUserId) return;

    final generation = _sessionGeneration;
    await _ensureOutboxLoaded();

    final changed = await _localStore.completeRecords(
      userId: userId,
      recordIds: recordIds.toSet().toList(growable: false),
      completedAt: completedAt,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) return;
    if (changed.isEmpty) return;

    final changedRecords = await _localStore.getRecordsByIds(
      userId: userId,
      ids: changed,
    );
    final queuedAt = _now();
    final operations = <PendingSyncOp>[
      for (final record in changedRecords)
        PendingSyncOp(
          id: 'complete_' + record.id,
          type: SyncOpType.complete,
          userId: userId,
          queuedAt: queuedAt,
          targetRecordId: record.id,
          completedAt: record.completedAt ?? completedAt,
          record: record,
        ),
    ];

    await _localStore.appendRecordsAndOutbox(
      userId,
      const <QazaRecord>[],
      operations,
    );

    for (final record in changedRecords) {
      _records[record.id] = record;
    }
    _outbox.addAll(operations);
    _outboxLoaded = true;
    _emitPending();

    unawaited(_syncEngine?.synchronize(userId) ?? Future<void>.value());
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    if (userId != _activeUserId) {
      throw StateError('Cannot reset Qaza records for a non-active user.');
    }

    final operation = PendingSyncOp(
      id: 'reset_' + userId + '_' + DateTime.now().microsecondsSinceEpoch.toString(),
      type: SyncOpType.reset,
      userId: userId,
      queuedAt: _now(),
    );

    await _localStore.retireUserData(userId: userId);
    await _localStore.appendRecordsAndOutbox(
      userId,
      const <QazaRecord>[],
      [operation],
    );

    _records.clear();
    _outbox
      ..clear()
      ..add(operation);
    _loaded = true;
    _outboxLoaded = true;
    _emitPending();

    unawaited(_syncEngine?.synchronize(userId) ?? Future<void>.value());
  }

  Future<void> syncNow() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await _ensureLoaded();
    await _syncEngine?.synchronize(userId);
  }

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
        pendingCount: _outbox.length,
      ),
    );
  }

  void _onConnectivityChanged(bool online) {
    _isOnline = online;
    if (!online) {
      _emit(
        SyncState(
          status: SyncStatus.offline,
          pendingCount: _outbox.length,
        ),
      );
      return;
    }

    final userId = _activeUserId;
    if (userId != null) {
      unawaited(_syncEngine?.synchronize(userId) ?? Future<void>.value());
    }
  }

  void dispose() {
    _syncEngine?.dispose();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_stateController.close());
  }
}
