import 'dart:async';

import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/repositories/qaza_undo_repository.dart';
import '../../domain/repositories/qaza_recovery_repository.dart';
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
    } else if (type == SyncOpType.update) {
      for (final operation in operations) {
        if (operation.record != null) {
          await _remote.updateRecord(record: operation.record!);
        }
      }
    } else if (type == SyncOpType.delete) {
      for (final operation in operations) {
        if (operation.targetRecordId != null) {
          await _remote.deleteRecord(
            userId: userId,
            recordId: operation.targetRecordId!,
          );
        }
      }
    } else {
      throw ArgumentError('Reset must use resetUserRecordsForSync.');
    }

    return QazaRemoteChangeCursor(
      at: DateTime.now().toUtc(),
      id: 'legacy_${operations.first.id}',
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
      id: 'legacy_reset_$operationId',
      generation: 0,
    );
  }

  @override
  Future<void> deleteCloudData({required String userId}) async {
    // The legacy adapter cannot issue the newer change-log deletion API.
    // Use its existing scoped reset operation for interface compatibility.
    await _remote.resetUserRecords(userId: userId);
  }
}

class OfflineFirstQazaRepository implements QazaRepository, QazaUndoRepository, QazaRecoveryRepository {
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

  final DiagnosticsService _diagnostics;

  OfflineFirstQazaRepository({
    required QazaRepository remote,
    QazaSyncRemoteDataSource? syncRemote,
    required QazaLocalStore localStore,
    Stream<bool>? connectivityChanges,
    DateTime Function()? now,
    String? syncCursorNamespace,
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  })  : _diagnostics = diagnostics,
        _remote = remote,
        _syncRemote = _resolveSyncRemote(remote, syncRemote),
        _localStore = localStore,
        _now = now ?? DateTime.now,
        _syncCursorNamespace = syncCursorNamespace {
    _connectivityKnown = connectivityChanges == null;
    _isOnline = connectivityChanges == null;
    _connectivitySubscription =
        connectivityChanges?.listen(_onConnectivityChanged);
  }

  final QazaRepository _remote;
  final QazaSyncRemoteDataSource _syncRemote;
  final QazaLocalStore _localStore;
  final DateTime Function() _now;
  final String? _syncCursorNamespace;

  StreamSubscription<bool>? _connectivitySubscription;
  final Map<String, QazaRecord> _records = {};
  List<PendingSyncOp> _outbox = [];
  String? _activeUserId;
  bool _isOnline = true;
  bool _connectivityKnown = true;
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
      cursorNamespace: _syncCursorNamespace,
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

      if (probe.records.isEmpty &&
          _isOnline &&
          _connectivityKnown &&
          !resetQueued) {
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
      if (_isOnline && _connectivityKnown) {
        await engine.synchronize(userId);
      } else if (!_isOnline) {
        _emit(const SyncState(status: SyncStatus.offline));
      }
    } catch (error, stack) {
      if (generation != _sessionGeneration || userId != _activeUserId) return;
      _hydrated = true;
      // Sync failure monitoring: this is the one the user never sees, because
      // the app keeps working offline.
      _diagnostics.recordFailure(
        DiagnosticArea.sync,
        'hydrate_failed',
        error,
        stack: stack,
      );
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
        .where(
            (record) => prayerType == null || record.prayerType == prayerType)
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
    if (generation != _sessionGeneration || userId != _activeUserId)
      return null;
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
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (userId != _activeUserId) return 0;
    await ensureHydrated();
    final generation = _sessionGeneration;
    final count = await _localStore.countCompletedBetween(
      userId: userId,
      from: from,
      to: to,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return 0;
    }
    return count;
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
        '${record.prayerType.name}|${record.originalDate.year}-${record.originalDate.month}-${record.originalDate.day}',
    };

    final fresh = <QazaRecord>[];
    for (final record in records) {
      final key =
          '${record.prayerType.name}|${record.originalDate.year}-${record.originalDate.month}-${record.originalDate.day}';

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
          id: 'add_${record.id}',
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

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
  }

  @override
  Future<void> updateRecord({required QazaRecord record}) async {
    final userId = _activeUserId;
    if (userId == null || record.userId != userId || record.id.isEmpty) {
      throw StateError('Cannot update a Qaza record for a non-active user.');
    }

    final generation = _sessionGeneration;
    await _ensureLoaded();
    await _ensureOutboxLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) return;

    final current = _records[record.id];
    if (current == null) return;
    if (_records.values.any(
      (candidate) =>
          candidate.id != record.id &&
          candidate.userId == userId &&
          candidate.prayerType == record.prayerType &&
          candidate.originalDate.year == record.originalDate.year &&
          candidate.originalDate.month == record.originalDate.month &&
          candidate.originalDate.day == record.originalDate.day,
    )) {
      throw StateError(
          'A Qaza record already exists for this prayer and date.');
    }

    final operation = PendingSyncOp(
      id: 'update_' +
          record.id +
          '_' +
          record.updatedAt.microsecondsSinceEpoch.toString(),
      type: SyncOpType.update,
      userId: userId,
      queuedAt: record.updatedAt,
      record: record,
      targetRecordId: record.id,
    );
    final changed = await _localStore.updateRecordAndOutbox(
      userId: userId,
      record: record,
      operation: operation,
    );
    if (!changed) return;
    if (generation != _sessionGeneration || userId != _activeUserId) return;

    _records[record.id] = record;
    _outbox.add(operation);
    _outboxLoaded = true;
    _emitPending();

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    if (userId != _activeUserId) {
      throw StateError('Cannot delete a Qaza record for a non-active user.');
    }

    final generation = _sessionGeneration;
    await _ensureLoaded();
    await _ensureOutboxLoaded();
    if (generation != _sessionGeneration || userId != _activeUserId) return;

    final current = _records[recordId];
    if (current == null) return;

    final now = _now();
    final operation = PendingSyncOp(
      id: 'delete_' + recordId + '_' + now.microsecondsSinceEpoch.toString(),
      type: SyncOpType.delete,
      userId: userId,
      queuedAt: now,
      targetRecordId: recordId,
      record: current,
    );
    final changed = await _localStore.deleteRecordAndOutbox(
      userId: userId,
      recordId: recordId,
      operation: operation,
    );
    if (!changed) return;
    if (generation != _sessionGeneration || userId != _activeUserId) return;

    _records.remove(recordId);
    _outbox.add(operation);
    _outboxLoaded = true;
    _emitPending();

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
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
          id: 'complete_${record.id}',
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

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
  }

  @override
  Future<int> undoCompletions({
    required String userId,
    required Map<String, DateTime> expectedCompletedAt,
    required DateTime undoneAt,
  }) async {
    if (expectedCompletedAt.isEmpty || userId != _activeUserId) return 0;

    final generation = _sessionGeneration;
    await _ensureOutboxLoaded();
    final changedRecords = await _localStore.undoCompletions(
      userId: userId,
      expectedCompletedAt: expectedCompletedAt,
      undoneAt: undoneAt,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) return 0;
    if (changedRecords.isEmpty) return 0;

    final operations = <PendingSyncOp>[
      for (final record in changedRecords)
        PendingSyncOp(
          id: 'undo_${record.id}_${record.updatedAt.microsecondsSinceEpoch}',
          type: SyncOpType.update,
          userId: userId,
          queuedAt: record.updatedAt,
          targetRecordId: record.id,
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

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
    return changedRecords.length;
  }

  @override
  Future<int> softDeleteRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime deletedAt,
    required String operationId,
  }) async {
    if (recordIds.isEmpty || userId != _activeUserId) return 0;
    await ensureHydrated();
    await _ensureLoaded();
    await _ensureOutboxLoaded();
    if (userId != _activeUserId) return 0;
    final records = await _localStore.getRecordsByIds(
      userId: userId,
      ids: recordIds,
    );
    var changed = 0;
    for (final record in records) {
      if (record.isDeleted) continue;
      final deleted = record.copyWith(
        status: QazaStatus.deleted,
        updatedAt: deletedAt,
      );
      final syncOp = PendingSyncOp(
        id: 'soft_delete_${record.id}_${operationId}',
        type: SyncOpType.update,
        userId: userId,
        queuedAt: deletedAt,
        targetRecordId: record.id,
        record: deleted,
      );
      final ok = await _localStore.updateRecordAndOutbox(
        userId: userId,
        record: deleted,
        operation: syncOp,
      );
      if (ok) {
        _records[record.id] = deleted;
        _outbox.add(syncOp);
        changed++;
      }
    }
    _outboxLoaded = true;
    if (changed > 0) {
      _emitPending();
      if (_isOnline && _connectivityKnown) {
        unawaited(
          _syncEngine?.synchronize(userId, requestRerun: true) ??
              Future<void>.value(),
        );
      }
    }
    return changed;
  }

  @override
  Future<int> restoreDeletedRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime restoredAt,
    required String operationId,
  }) async {
    if (recordIds.isEmpty || userId != _activeUserId) return 0;
    await ensureHydrated();
    await _ensureLoaded();
    await _ensureOutboxLoaded();
    if (userId != _activeUserId) return 0;
    final records = await _localStore.getRecordsByIds(
      userId: userId,
      ids: recordIds,
    );
    var changed = 0;
    for (final record in records) {
      if (!record.isDeleted) continue;
      final duplicate = await _localStore.hasRecordCombination(
        userId: userId,
        prayerType: record.prayerType,
        originalDate: record.originalDate,
        excludingRecordId: record.id,
      );
      if (duplicate) continue;

      final restored = record.copyWith(
        status: record.completedAt == null
            ? QazaStatus.pending
            : QazaStatus.completed,
        updatedAt: restoredAt,
      );
      final syncOp = PendingSyncOp(
        id: 'restore_${record.id}_${operationId}',
        type: SyncOpType.update,
        userId: userId,
        queuedAt: restoredAt,
        targetRecordId: record.id,
        record: restored,
      );
      final ok = await _localStore.updateRecordAndOutbox(
        userId: userId,
        record: restored,
        operation: syncOp,
      );
      if (ok) {
        _records[record.id] = restored;
        _outbox.add(syncOp);
        changed++;
      }
    }
    _outboxLoaded = true;
    if (changed > 0) {
      _emitPending();
      if (_isOnline && _connectivityKnown) {
        unawaited(
          _syncEngine?.synchronize(userId, requestRerun: true) ??
              Future<void>.value(),
        );
      }
    }
    return changed;
  }

  @override
  Future<int> undoAddedOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
  }) =>
      _removeUnchangedPendingFromOperation(
        userId: userId,
        operationId: operationId,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: _now(),
      );

  @override
  Future<int> removeAddition({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) =>
      _removeUnchangedPendingFromOperation(
        userId: userId,
        operationId: operationId,
        expectedCreatedAt: expectedCreatedAt,
        deletedAt: deletedAt,
      );

  Future<int> _removeUnchangedPendingFromOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  }) async {
    if (userId != _activeUserId) return 0;
    await ensureHydrated();
    await _ensureLoaded();
    await _ensureOutboxLoaded();
    if (userId != _activeUserId) return 0;

    DateTime? cursorDate;
    String? cursorId;
    var removed = 0;

    while (true) {
      final page = await _localStore.getOperationPage(
        userId: userId,
        operationId: operationId,
        matchLastAction: false,
        operationAt: expectedCreatedAt,
        status: QazaStatus.pending,
        limit: 200,
        beforeOriginalDate: cursorDate,
        beforeId: cursorId,
      );
      if (page.records.isEmpty) break;

      final ids = <String>[
        for (final record in page.records)
          if (record.createdAt.isAtSameMomentAs(expectedCreatedAt) &&
              record.updatedAt.isAtSameMomentAs(expectedCreatedAt))
            record.id,
      ];

      if (ids.isNotEmpty) {
        final changed = await _localStore.softDeletePendingIfUnchanged(
          userId: userId,
          recordIds: ids,
          expectedCreatedAt: expectedCreatedAt,
          deletedAt: deletedAt,
          operationId: operationId,
        );
        for (final record in changed) {
          _records[record.id] = record;
          _outbox.add(
            PendingSyncOp(
              id: 'soft_delete_' + record.id + '_' + operationId,
              type: SyncOpType.update,
              userId: userId,
              queuedAt: deletedAt,
              targetRecordId: record.id,
              record: record,
            ),
          );
        }
        removed += changed.length;
        _outboxLoaded = true;
      }

      if (!page.hasMore) break;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
    }

    if (removed > 0) {
      _emitPending();
      if (_isOnline && _connectivityKnown) {
        unawaited(
          _syncEngine?.synchronize(userId, requestRerun: true) ??
              Future<void>.value(),
        );
      }
    }
    return removed;
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
    if (userId != _activeUserId) {
      return const QazaPage(records: [], hasMore: false);
    }
    await ensureHydrated();
    final generation = _sessionGeneration;
    final page = await _localStore.getOperationPage(
      userId: userId,
      operationId: operationId,
      matchLastAction: matchLastAction,
      operationAt: operationAt,
      status: status,
      limit: limit,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return const QazaPage(records: [], hasMore: false);
    }
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
  }) async {
    if (userId != _activeUserId) return const QazaOperationSummary();
    await ensureHydrated();
    final generation = _sessionGeneration;
    final summary = await _localStore.getOperationSummary(
      userId: userId,
      operationId: operationId,
    );
    if (generation != _sessionGeneration || userId != _activeUserId) {
      return const QazaOperationSummary();
    }
    return summary;
  }

  @override
  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  }) async {
    if (userId != _activeUserId) return const QazaHistoryPage(records: [], hasMore: false);
    final page = await _localStore.getRecentlyDeletedPage(
      userId: userId,
      limit: limit,
      beforeDeletedAt: beforeDeletedAt,
      beforeId: beforeId,
    );
    return QazaHistoryPage(records: page.records, hasMore: page.hasMore);
  }

  @override
  Future<int> purgeDeletedBefore({
    required String userId,
    required DateTime cutoff,
  }) async {
    if (userId != _activeUserId) return 0;
    DateTime? cursorDeletedAt;
    String? cursorId;
    var removed = 0;
    while (true) {
      final page = await _localStore.getRecentlyDeletedPage(
        userId: userId,
        limit: 200,
        beforeDeletedAt: cursorDeletedAt,
        beforeId: cursorId,
      );
      if (page.records.isEmpty) break;
      for (final record in page.records) {
        if (!record.updatedAt.isBefore(cutoff)) continue;
        final op = PendingSyncOp(
          id: 'purge_deleted_${record.id}_${cutoff.microsecondsSinceEpoch}',
          type: SyncOpType.delete,
          userId: userId,
          queuedAt: _now(),
          targetRecordId: record.id,
        );
        if (await _localStore.deleteRecordAndOutbox(userId: userId, recordId: record.id, operation: op)) {
          _records.remove(record.id);
          _outbox.add(op);
          removed++;
        }
      }
      if (!page.hasMore) break;
      cursorDeletedAt = page.records.last.updatedAt;
      cursorId = page.records.last.id;
    }
    _outboxLoaded = true;
    if (removed > 0) {
      _emitPending();
      if (_isOnline && _connectivityKnown) {
        unawaited(_syncEngine?.synchronize(userId, requestRerun: true) ?? Future<void>.value());
      }
    }
    return removed;
  }
  @override
  Future<void> resetUserRecords({required String userId}) async {
    if (userId != _activeUserId) {
      throw StateError('Cannot reset Qaza records for a non-active user.');
    }

    final operation = PendingSyncOp(
      id: 'reset_${userId}_${DateTime.now().microsecondsSinceEpoch}',
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

    if (_isOnline && _connectivityKnown) {
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
  }

  Future<void> syncNow() async {
    final userId = _activeUserId;
    if (userId == null) return;

    // Stream<bool> events are delivered asynchronously. Allow a pending
    // connectivity notification to settle before deciding whether we are
    // currently offline.
    await Future<void>.delayed(Duration.zero);

    if (!_isOnline) {
      _emit(
        SyncState(
          status: SyncStatus.offline,
          pendingCount: _outbox.length,
        ),
      );
      return;
    }
    await _syncEngine?.synchronize(userId, requestRerun: true);
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
    _connectivityKnown = true;
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
      unawaited(
        _syncEngine?.synchronize(userId, requestRerun: true) ??
            Future<void>.value(),
      );
    }
  }

  void dispose() {
    _syncEngine?.dispose();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_stateController.close());
  }
}