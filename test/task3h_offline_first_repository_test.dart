import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/in_memory_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';

void main() {
  final baseDate = DateTime(2026, 9, 15);

  QazaRecord record({
    String userId = 'u1',
    PrayerType prayer = PrayerType.fajr,
    DateTime? date,
    QazaStatus status = QazaStatus.pending,
    DateTime? completedAt,
  }) {
    final originalDate = date ?? baseDate;
    return QazaRecord(
      id: '${userId}_${prayer.name}_${originalDate.toIso8601String()}',
      userId: userId,
      prayerType: prayer,
      originalDate: originalDate,
      status: status,
      completedAt: completedAt,
      createdAt: originalDate,
      updatedAt: completedAt ?? originalDate,
    );
  }

  OfflineFirstQazaRepository createRepository({
    required QazaRepository remote,
    required InMemoryQazaLocalStore local,
    Stream<bool>? connectivity,
  }) {
    return OfflineFirstQazaRepository(
      remote: remote,
      localStore: local,
      connectivityChanges: connectivity,
      now: () => baseDate,
    );
  }

  group('Task 3H offline-first repository', () {
    test('writes locally before remote sync and persists the outbox', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final connectivity = StreamController<bool>();
      final repo = createRepository(
        remote: remote,
        local: local,
        connectivity: connectivity.stream,
      );

      await repo.setActiveUser('u1');
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

    test('keeps failed operations queued and retries without data loss', () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository();
      final repo = createRepository(remote: remote, local: local);

      await repo.setActiveUser('u1');
      remote.failWrites = true;
      await repo.addRecord(record());
      await repo.syncNow();

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

    test('merges remote completion forward without regressing local state', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final repo = createRepository(remote: remote, local: local);

      final original = record();
      await remote.addRecord(original);
      await repo.setActiveUser('u1');
      await repo.syncNow();
      expect((await repo.getRecords(userId: 'u1')).single.status, QazaStatus.pending);

      final completedAt = baseDate.add(const Duration(hours: 4));
      await remote.completeRecord(
        userId: 'u1',
        recordId: original.id,
        completedAt: completedAt,
      );
      await repo.syncNow();

      final merged = (await repo.getRecords(userId: 'u1')).single;
      expect(merged.status, QazaStatus.completed);
      expect(merged.completedAt, completedAt);

      repo.dispose();
    });

    test('requeues a local completion when its persisted outbox is missing', () async {
      final local = InMemoryQazaLocalStore();
      final remote = _FailingRepository()..failWrites = true;
      final original = record();
      await remote.addRecord(original);

      final completedAt = baseDate.add(const Duration(hours: 2));
      await local.saveRecords('u1', [
        record(status: QazaStatus.completed, completedAt: completedAt),
      ]);
      await local.saveOutbox('u1', []);

      final repo = createRepository(remote: remote, local: local);
      await repo.setActiveUser('u1');
      await repo.syncNow();

      final queued = (await local.load()).outboxByUser['u1']!;
      expect(queued, hasLength(1));
      expect(queued.single.type, SyncOpType.complete);
      expect(queued.single.targetRecordId, original.id);

      remote.failWrites = false;
      await repo.syncNow();
      expect((await remote.getRecords(userId: 'u1')).single.status, QazaStatus.completed);
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      repo.dispose();
    });

    test('restores persisted records and outbox after repository recreation', () async {
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
      expect((await local.load()).outboxByUser['u1'], hasLength(1));

      remote.failWrites = false;
      await restored.syncNow();
      expect((await local.load()).outboxByUser['u1'], isEmpty);
      expect(await remote.getRecords(userId: 'u1'), hasLength(1));
      restored.dispose();
    });
  });
}

class _FailingRepository implements QazaRepository {
  final InMemoryQazaRepository _delegate = InMemoryQazaRepository();
  bool failWrites = false;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) => _delegate.getRecords(
        userId: userId,
        prayerType: prayerType,
        status: status,
      );

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
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    if (failWrites) return Future.error(StateError('simulated remote outage'));
    return _delegate.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }
}
