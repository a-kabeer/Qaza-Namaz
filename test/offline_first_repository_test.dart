import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_remote_data_source.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  final baseDate = DateTime(2026, 9, 15);

  QazaRecord record(
      {String userId = 'u1',
      PrayerType prayer = PrayerType.fajr,
      DateTime? date,
      QazaStatus status = QazaStatus.pending,
      DateTime? completedAt}) {
    final originalDate = date ?? baseDate;
    return QazaRecord(
        id: '${userId}_${prayer.name}_${originalDate.toIso8601String()}',
        userId: userId,
        prayerType: prayer,
        originalDate: originalDate,
        status: status,
        completedAt: completedAt,
        createdAt: originalDate,
        updatedAt: completedAt ?? originalDate);
  }

  OfflineFirstQazaRepository createRepository(
          {required QazaRepository remote,
          required InMemoryQazaLocalStore local,
          Stream<bool>? connectivity}) =>
      OfflineFirstQazaRepository(
          remote: remote,
          localStore: local,
          connectivityChanges: connectivity,
          now: () => baseDate);

  group('Task 3H offline-first repository', () {
    test('writes locally before remote sync and persists the outbox', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final connectivity = StreamController<bool>();
      final repo = createRepository(
          remote: remote, local: local, connectivity: connectivity.stream);
      await repo.setActiveUser('u1');
      await repo.ensureHydrated();
      connectivity.add(false);
      await Future<void>.delayed(Duration.zero);
      final item = record();
      await repo.addRecord(item);
      expect((await repo.getRecords(userId: 'u1')).single.id, item.id);
      expect(await remote.getRecords(userId: 'u1'), isEmpty);
      expect((await local.load()).outboxByUser['u1'], hasLength(1));
      expect(repo.currentState.status, SyncStatus.offline);
      connectivity.add(true);
      await repo.syncNow();
      expect(await remote.getRecords(userId: 'u1'), hasLength(1));
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      expect(repo.currentState.status, SyncStatus.synced);
      await connectivity.close();
      repo.dispose();
    });
    test('keeps failed operations queued and retries without data loss',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository();
      final connectivity = StreamController<bool>();
      final repo = createRepository(
          remote: remote,
          local: local,
          connectivity: connectivity.stream);
      addTearDown(connectivity.close);
      await repo.setActiveUser('u1');
      await repo.ensureHydrated();
      connectivity.add(false);
      await Future<void>.delayed(Duration.zero);
      remote.failWrites = true;
      await repo.addRecord(record());
      expect((await local.load()).outboxByUser['u1'], hasLength(1));
      final failedSync = repo.syncState.firstWhere(
        (state) => state.status == SyncStatus.syncError,
      );
      connectivity.add(true);
      await failedSync;
      final failed = (await local.load()).outboxByUser['u1']!;
      expect(failed, hasLength(1));
      expect(failed.single.attempts, 1);
      expect(repo.currentState.status, SyncStatus.syncError);
      remote.failWrites = false;
      await repo.syncNow();
      expect(await remote.getRecords(userId: 'u1'), hasLength(1));
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      repo.dispose();
    });
    test('isolates cached records and outboxes between users', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final repo = createRepository(remote: remote, local: local);
      await repo.setActiveUser('u1');
      await repo.addRecord(record(userId: 'u1'));
      await repo.syncNow();
      await repo.setActiveUser('u2');
      expect(await repo.getRecords(userId: 'u2'), isEmpty);
      expect(await repo.getRecords(userId: 'u1'), isEmpty);
      await repo.addRecord(record(userId: 'u2'));
      await repo.syncNow();
      await repo.setActiveUser('u1');
      expect((await repo.getRecords(userId: 'u1')).single.userId, 'u1');
      await repo.setActiveUser('u2');
      expect((await repo.getRecords(userId: 'u2')).single.userId, 'u2');
      final snapshot = await local.load();
      expect(snapshot.recordsByUser['u1'], hasLength(1));
      expect(snapshot.recordsByUser['u2'], hasLength(1));
      expect(snapshot.outboxByUser['u1'], isEmpty);
      expect(snapshot.outboxByUser['u2'], isEmpty);
      repo.dispose();
    });
    test(
        'history reads from bounded local page API without a second full snapshot load',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository();
      final repo = createRepository(remote: remote, local: local);
      await local.saveRecords('u1', [
        for (var i = 0; i < 120; i++)
          record(
              userId: 'u1',
              date: baseDate.subtract(Duration(days: i)),
              status: i.isEven ? QazaStatus.completed : QazaStatus.pending),
      ]);
      await repo.setActiveUser('u1');
      final loadsAfterActivation = local.loadCalls;
      final page =
          await repo.getHistoryPage(userId: 'u1', limit: 50, status: null);
      expect(page.records, hasLength(50));
      expect(page.hasMore, isTrue);
      expect(page.records.first.originalDate, baseDate);
      expect(local.historyPageCalls, 1);
      expect(local.loadCalls, loadsAfterActivation);
      expect(remote.historyPageCalls, 0);
      repo.dispose();
    });
    test('merges remote completion forward without regressing local state',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final repo = createRepository(remote: remote, local: local);
      final original = record();
      await remote.addRecord(original);
      await repo.setActiveUser('u1');
      await repo.syncNow();
      expect((await repo.getRecords(userId: 'u1')).single.status,
          QazaStatus.pending);
      final completedAt = baseDate.add(const Duration(hours: 4));
      await remote.completeRecord(
          userId: 'u1', recordId: original.id, completedAt: completedAt);
      await repo.syncNow();
      final merged = (await repo.getRecords(userId: 'u1')).single;
      expect(merged.status, QazaStatus.completed);
      expect(merged.completedAt, completedAt);
      repo.dispose();
    });
    test('requeues a local completion when its persisted outbox is missing',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository();
      final connectivity = StreamController<bool>();
      final original = record();
      await remote.addRecord(original);
      final completedAt = baseDate.add(const Duration(hours: 2));
      await local.saveRecords('u1',
          [record(status: QazaStatus.completed, completedAt: completedAt)]);
      await local.saveOutbox('u1', []);
      final repo = createRepository(
          remote: remote, local: local, connectivity: connectivity.stream);
      connectivity.add(false);
      await Future<void>.delayed(Duration.zero);
      await repo.setActiveUser('u1');
      await repo.ensureHydrated();
      await repo.syncNow();
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      remote.failWrites = true;
      connectivity.add(true);
      await repo.syncNow();
      final queued = (await local.load()).outboxByUser['u1']!;
      expect(queued, hasLength(1));
      expect(queued.single.type, SyncOpType.complete);
      expect(queued.single.targetRecordId, original.id);
      remote.failWrites = false;
      await repo.syncNow();
      expect((await remote.getRecords(userId: 'u1')).single.status,
          QazaStatus.completed);
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      await connectivity.close();
      repo.dispose();
    });
    test('restores persisted records and outbox after repository recreation',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository()..failWrites = true;
      final first = createRepository(remote: remote, local: local);
      await first.setActiveUser('u1');
      await first.addRecord(record());
      await first.syncNow();
      first.dispose();
      final restored = createRepository(remote: remote, local: local);
      await restored.setActiveUser('u1');
      expect(await restored.getRecords(userId: 'u1'), hasLength(1));
      await restored.syncNow();
      expect((await local.load()).outboxByUser['u1'], hasLength(1));
      remote.failWrites = false;
      await restored.syncNow();
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      expect(await remote.getRecords(userId: 'u1'), hasLength(1));
      restored.dispose();
    });
    test(
        'syncs remote-only changes to both devices and converges on earliest completion',
        () async {
      final remote = InMemoryQazaRepository();
      final localA = InMemoryQazaLocalStore();
      final localB = InMemoryQazaLocalStore();
      final deviceA = OfflineFirstQazaRepository(
          remote: remote,
          localStore: localA,
          now: () => baseDate,
          syncCursorNamespace: 'device-a');
      final deviceB = OfflineFirstQazaRepository(
          remote: remote,
          localStore: localB,
          now: () => baseDate,
          syncCursorNamespace: 'device-b');
      final original = record();
      await remote.addRecord(original);
      await deviceA.setActiveUser('u1');
      await deviceB.setActiveUser('u1');
      await deviceA.syncNow();
      await deviceB.syncNow();
      expect((await deviceA.getRecords(userId: 'u1')).single.id, original.id);
      expect((await deviceB.getRecords(userId: 'u1')).single.id, original.id);
      final later = baseDate.add(const Duration(hours: 10));
      final earlier = baseDate.add(const Duration(hours: 6));
      await deviceA.completeRecord(
          userId: 'u1', recordId: original.id, completedAt: later);
      await deviceA.syncNow();
      expect((await remote.getRecords(userId: 'u1')).single.completedAt, later);
      await deviceB.completeRecord(
          userId: 'u1', recordId: original.id, completedAt: earlier);
      await deviceB.syncNow();
      expect(
          (await remote.getRecords(userId: 'u1')).single.completedAt, earlier);
      expect(
          (await deviceB.getRecords(userId: 'u1')).single.completedAt, earlier);
      await deviceA.syncNow();
      expect(
          (await deviceA.getRecords(userId: 'u1')).single.completedAt, earlier);
      expect((await localA.load()).outboxByUser['u1'], isEmpty);
      expect((await localB.load()).outboxByUser['u1'], isEmpty);
      deviceA.dispose();
      deviceB.dispose();
    });
  });
}

class _FailingRepository
    implements QazaRepository, QazaSyncRemoteDataSource {
  final InMemoryQazaRepository _delegate = InMemoryQazaRepository();
  bool failWrites = false;

  @override
  Future<List<QazaRecord>> getRecords(
          {required String userId,
          PrayerType? prayerType,
          QazaStatus? status}) =>
      _delegate.getRecords(
          userId: userId, prayerType: prayerType, status: status);
  @override
  Future<QazaPage> getPage(
          {required String userId,
          int limit = 50,
          PrayerType? prayerType,
          QazaStatus? status,
          DateTime? from,
          DateTime? to,
          DateTime? afterOriginalDate,
          String? afterId}) =>
      _delegate.getPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: status,
          from: from,
          to: to,
          afterOriginalDate: afterOriginalDate,
          afterId: afterId);
  @override
  Future<QazaRecord?> getOldestPending(
          {required String userId, required PrayerType prayerType}) =>
      _delegate.getOldestPending(userId: userId, prayerType: prayerType);
  @override
  Future<QazaHistoryPage> getHistoryPage(
          {required String userId,
          int limit = 50,
          PrayerType? prayerType,
          QazaStatus? status = QazaStatus.completed,
          DateTime? from,
          DateTime? to,
          DateTime? beforeOriginalDate,
          String? beforeId}) =>
      _delegate.getHistoryPage(
          userId: userId,
          limit: limit,
          prayerType: prayerType,
          status: status,
          from: from,
          to: to,
          beforeOriginalDate: beforeOriginalDate,
          beforeId: beforeId);
  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      _delegate.getProgressSummary(userId: userId);
  @override
  Future<void> addRecord(QazaRecord record) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.addRecord(record);
  }

  @override
  Future<void> addRecords(List<QazaRecord> records) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.addRecords(records);
  }

  @override
  Future<void> completeRecord(
      {required String userId,
      required String recordId,
      required DateTime completedAt}) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.completeRecord(
        userId: userId, recordId: recordId, completedAt: completedAt);
  }

  @override
  Future<void> completeRecords(
      {required String userId,
      required List<String> recordIds,
      required DateTime completedAt}) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.completeRecords(
        userId: userId, recordIds: recordIds, completedAt: completedAt);
  }

  @override
  Future<void> resetUserRecords({required String userId}) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.resetUserRecords(userId: userId);
  }

  @override
  Future<QazaRemoteResetState> getResetState({required String userId}) =>
      _delegate.getResetState(userId: userId);

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({
    required String userId,
  }) =>
      _delegate.getLatestChange(userId: userId);

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) =>
      _delegate.getChanges(
        userId: userId,
        after: after,
        limit: limit,
      );

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) {
    if (failWrites) {
      return Future.error(StateError('simulated remote outage'));
    }
    return _delegate.applyOperationsBatch(
      userId: userId,
      operations: operations,
    );
  }

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) {
    if (failWrites) {
      return Future.error(StateError('simulated remote outage'));
    }
    return _delegate.resetUserRecordsForSync(
      userId: userId,
      operationId: operationId,
    );
  }

  int get historyPageCalls => _delegate.historyPageCalls;
}
