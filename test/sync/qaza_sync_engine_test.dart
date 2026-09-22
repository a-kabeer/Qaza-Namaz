import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_engine.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_remote_data_source.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('13,000 pending records sync in bounded batches without queue rewrites',
      () async {
    final local = _FakeSyncStore();
    final remote = _FakeSyncRemote();
    final states = <SyncState>[];
    final engine = QazaSyncEngine(
      localStore: local,
      remote: remote,
      onState: states.add,
    );
    addTearDown(engine.dispose);

    final now = DateTime.utc(2026, 1, 1);
    for (var index = 0; index < 13000; index++) {
      final record = QazaRecord(
        id: 'u1_fajr_' + index.toString(),
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: now.add(Duration(days: index)),
        status: QazaStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      local.records[record.id] = record;
      local.outbox.add(
        PendingSyncOp(
          id: 'add_' + record.id,
          type: SyncOpType.add,
          userId: 'u1',
          queuedAt: now,
          record: record,
        ),
      );
    }

    await engine.synchronize('u1');

    expect(remote.applyCalls, 33);
    expect(remote.maximumBatchSize, 400);
    expect(local.outbox, isEmpty);
    expect(local.wholeQueueSaveCalls, 0);
    expect(states.last.status, SyncStatus.synced);
    expect(states.last.pendingCount, 0);
  });

  test('incremental sync advances a durable cursor and applies only changes',
      () async {
    final local = _FakeSyncStore();
    final remote = _FakeSyncRemote();
    final engine = QazaSyncEngine(
      localStore: local,
      remote: remote,
      onState: (_) {},
    );
    addTearDown(engine.dispose);

    final record = QazaRecord(
      id: 'u1_fajr_1',
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 1, 1),
      status: QazaStatus.completed,
      completedAt: DateTime(2026, 2, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 2, 1),
    );
    remote.changes = [
      QazaRemoteChange(
        type: QazaRemoteChangeType.complete,
        cursor: QazaRemoteChangeCursor(
          at: DateTime.utc(2026, 2, 1, 10),
          id: 'change-1',
          generation: 0,
        ),
        records: [record],
      ),
    ];

    await engine.synchronize('u1');
    await engine.synchronize('u1');

    expect(local.records[record.id]?.status, QazaStatus.completed);
    expect(remote.observedCursors.length, greaterThanOrEqualTo(2));
    expect(remote.observedCursors.last?.id, 'change-1');
  });

  test('reset clears local ledger, consumes reset queue, and lands on reset cursor',
      () async {
    final local = _FakeSyncStore();
    final remote = _FakeSyncRemote();
    final states = <SyncState>[];
    final engine = QazaSyncEngine(
      localStore: local,
      remote: remote,
      onState: states.add,
    );
    addTearDown(engine.dispose);

    final record = QazaRecord(
      id: 'u1_fajr_1',
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 1, 1),
      status: QazaStatus.pending,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    local.records[record.id] = record;
    local.outbox.add(
      PendingSyncOp(
        id: 'reset_u1',
        type: SyncOpType.reset,
        userId: 'u1',
        queuedAt: DateTime(2026, 1, 2),
      ),
    );

    await engine.synchronize('u1');

    expect(remote.resetCalls, 1);
    expect(local.records, isEmpty);
    expect(local.outbox, isEmpty);
    expect(states.last.status, SyncStatus.synced);
  });

  test('transient failure is persisted for retry and can recover independently',
      () async {
    final local = _FakeSyncStore();
    final remote = _FakeSyncRemote()..failNextApply = true;
    final states = <SyncState>[];
    final engine = QazaSyncEngine(
      localStore: local,
      remote: remote,
      onState: states.add,
    );
    addTearDown(engine.dispose);

    final record = QazaRecord(
      id: 'u1_fajr_1',
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 1, 1),
      status: QazaStatus.pending,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    local.records[record.id] = record;
    local.outbox.add(
      PendingSyncOp(
        id: 'add_' + record.id,
        type: SyncOpType.add,
        userId: 'u1',
        queuedAt: DateTime(2026, 1, 1),
        record: record,
      ),
    );

    await engine.synchronize('u1');

    expect(states.any((state) => state.status == SyncStatus.retrying), isTrue);
    expect(local.outbox.single.attempts, 1);

    await engine.synchronize('u1');

    expect(local.outbox, isEmpty);
    expect(states.last.status, SyncStatus.synced);
    expect(remote.applyCalls, 2);
  });
test('50,000 pending records sync without whole-queue rewrites', () async {
  final local = _FakeSyncStore();
  final remote = _FakeSyncRemote();
  final engine = QazaSyncEngine(
    localStore: local,
    remote: remote,
    onState: (_) {},
  );
  addTearDown(engine.dispose);

  final now = DateTime.utc(2026, 1, 1);
  for (var index = 0; index < 50000; index++) {
    final record = QazaRecord(
      id: 'u1_fajr_' + index.toString(),
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: now.add(Duration(days: index)),
      status: QazaStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    local.records[record.id] = record;
    local.outbox.add(
      PendingSyncOp(
        id: 'add_' + record.id,
        type: SyncOpType.add,
        userId: 'u1',
        queuedAt: now,
        record: record,
      ),
    );
  }

  await engine.synchronize('u1');

  expect(remote.applyCalls, 125);
  expect(remote.maximumBatchSize, 400);
  expect(local.outbox, isEmpty);
  expect(local.wholeQueueSaveCalls, 0);
});

test('delete/complete races preserve completion metadata in tombstones', () async {
  final local = _FakeSyncStore();
  final remote = _FakeSyncRemote();
  final engine = QazaSyncEngine(
    localStore: local,
    remote: remote,
    onState: (_) {},
  );
  addTearDown(engine.dispose);

  final completedAt = DateTime.utc(2026, 2, 1);
  final localDeleted = QazaRecord(
    id: 'race-1',
    userId: 'u1',
    prayerType: PrayerType.fajr,
    originalDate: DateTime(2026, 1, 1),
    status: QazaStatus.deleted,
    completedAt: null,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 2, 2),
  );
  final remoteCompleted = localDeleted.copyWith(
    status: QazaStatus.completed,
    completedAt: completedAt,
    updatedAt: DateTime.utc(2026, 2, 1),
  );
  local.records[localDeleted.id] = localDeleted;
  remote.changes = [
    QazaRemoteChange(
      type: QazaRemoteChangeType.update,
      cursor: QazaRemoteChangeCursor(
        at: DateTime.utc(2026, 2, 3),
        id: 'race-change',
        generation: 0,
      ),
      records: [remoteCompleted],
    ),
  ];

  await engine.synchronize('u1');

  expect(local.records[localDeleted.id]?.status, QazaStatus.deleted);
  expect(local.records[localDeleted.id]?.completedAt, completedAt);
  expect(local.outbox, hasLength(1));
  expect(local.outbox.single.type, SyncOpType.update);
});

test('1,000 completion operations sync in bounded batches', () async {
  final local = _FakeSyncStore();
  final remote = _FakeSyncRemote();
  final engine = QazaSyncEngine(
    localStore: local,
    remote: remote,
    onState: (_) {},
  );
  addTearDown(engine.dispose);

  final now = DateTime.utc(2026, 1, 1);
  for (var index = 0; index < 1000; index++) {
    final record = QazaRecord(
      id: 'u1_fajr_' + index.toString(),
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: now.add(Duration(days: index)),
      status: QazaStatus.completed,
      completedAt: now.add(const Duration(days: 2)),
      createdAt: now,
      updatedAt: now.add(const Duration(days: 2)),
    );
    local.records[record.id] = record;
    local.outbox.add(
      PendingSyncOp(
        id: 'complete_' + record.id,
        type: SyncOpType.complete,
        userId: 'u1',
        queuedAt: now,
        completedAt: record.completedAt,
        record: record,
      ),
    );
  }

  await engine.synchronize('u1');

  expect(remote.applyCalls, 3);
  expect(remote.maximumBatchSize, 400);
  expect(local.outbox, isEmpty);
});

}


class _FakeSyncRemote implements QazaSyncRemoteDataSource {
  List<QazaRemoteChange> changes = [];
  final List<QazaRemoteChangeCursor?> observedCursors = [];
  int applyCalls = 0;
  int maximumBatchSize = 0;
  int resetCalls = 0;
  bool failNextApply = false;

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
  }) async {
    observedCursors.add(after);
    final available = [
      for (final change in changes)
        if (after == null || _isAfter(change.cursor, after)) change,
    ];
    return QazaRemoteChangePage(
      changes: available,
      hasMore: false,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async {
    applyCalls++;
    maximumBatchSize = operations.length > maximumBatchSize
        ? operations.length
        : maximumBatchSize;
    if (failNextApply) {
      failNextApply = false;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'simulated transient failure',
      );
    }
    return QazaRemoteChangeCursor(
      at: DateTime.utc(2026, 3, 1).add(Duration(seconds: applyCalls)),
      id: 'local-change-' + applyCalls.toString(),
      generation: 0,
    );
  }

  @override
  Future<void> deleteCloudData({required String userId}) async {}

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) async {
    resetCalls++;
    return QazaRemoteChangeCursor(
      at: DateTime.utc(2026, 4, 1),
      id: 'reset-' + operationId,
      generation: 1,
    );
  }

  bool _isAfter(QazaRemoteChangeCursor left, QazaRemoteChangeCursor right) {
    final time = left.at.compareTo(right.at);
    return time > 0 || (time == 0 && left.id.compareTo(right.id) > 0);
  }
}

class _FakeSyncStore extends QazaLocalStore {
  final Map<String, QazaRecord> records = {};
  List<PendingSyncOp> outbox = [];
  int wholeQueueSaveCalls = 0;
  final List<List<String>> removedBatches = [];

  @override
  Future<OfflineCacheSnapshot> load() async => OfflineCacheSnapshot(
        recordsByUser: {'u1': records.values.toList(growable: false)},
        outboxByUser: {'u1': List.unmodifiable(outbox)},
      );

  @override
  Future<void> saveRecords(
      String userId, List<QazaRecord> recordsList) async {
    records
      ..clear()
      ..addEntries(
        recordsList.map((record) => MapEntry(record.id, record)),
      );
  }

  @override
  Future<void> saveOutbox(
      String userId, List<PendingSyncOp> ops) async {
    wholeQueueSaveCalls++;
    outbox = List.of(ops);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {}

  @override
  Future<void> retireUserData({required String userId}) async {
    records.clear();
    outbox.clear();
  }

  @override
  Future<int> countPendingOutbox(String userId) async => outbox.length;

  @override
  Future<List<PendingSyncOp>> loadOutboxBatch(
    String userId, {
    int limit = 400,
  }) async =>
      outbox.take(limit).toList(growable: false);

  @override
  Future<void> removeOutboxBatch(String userId, List<String> ids) async {
    final wanted = ids.toSet();
    removedBatches.add(List.of(ids));
    outbox.removeWhere((operation) => wanted.contains(operation.id));
  }

  @override
  Future<void> markOutboxBatchRetry({
    required String userId,
    required List<String> ids,
    required String error,
  }) async {
    final wanted = ids.toSet();
    outbox = [
      for (final operation in outbox)
        wanted.contains(operation.id)
            ? operation.copyWith(
                attempts: operation.attempts + 1,
                lastError: error,
              )
            : operation,
    ];
  }

  @override
  Future<void> appendRecordsAndOutbox(
    String userId,
    List<QazaRecord> newRecords,
    List<PendingSyncOp> ops,
  ) async {
    for (final record in newRecords) {
      records[record.id] = record;
    }
    outbox.addAll(ops);
  }

  @override
  Future<void> upsertRecords(
      String userId, List<QazaRecord> remoteRecords) async {
    for (final record in remoteRecords) {
      records[record.id] = record;
    }
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) async {
    return [
      for (final id in ids)
        if (records[id] case final record?) record,
    ];
  }
}
