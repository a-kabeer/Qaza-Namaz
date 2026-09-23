import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord _record(String userId, PrayerType prayer, DateTime date) {
  final stamp = DateTime(2026, 1, 1);
  return QazaRecord(
    id: '${userId}_${prayer.name}_${date.toIso8601String()}',
    userId: userId,
    prayerType: prayer,
    originalDate: date,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// A remote that never answers until released, so a test can observe the
/// intermediate HYDRATING state.
class _BlockingRemote implements QazaRepository {
  _BlockingRemote(this.delegate);

  final InMemoryQazaRepository delegate;
  final Completer<void> gate = Completer<void>();
  bool failPull = false;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    await gate.future;
    if (failPull) throw StateError('remote unavailable');
    return delegate.getRecords(
      userId: userId,
      prayerType: prayerType,
      status: status,
    );
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
    await gate.future;
    if (failPull) throw StateError('remote unavailable');
    return delegate.getPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) =>
      delegate.getOldestPending(userId: userId, prayerType: prayerType);
  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) =>
      delegate.getPendingRecordsByIds(
        userId: userId,
        recordIds: recordIds,
      );


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
  }) =>
      delegate.getHistoryPage(
        userId: userId,
        limit: limit,
        prayerType: prayerType,
        status: status,
        from: from,
        to: to,
        beforeOriginalDate: beforeOriginalDate,
        beforeId: beforeId,
      );

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      delegate.getProgressSummary(userId: userId);

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) =>
      delegate.countCompletedBetween(
        userId: userId,
        from: from,
        to: to,
      );

  @override
  Future<void> addRecord(QazaRecord record) => delegate.addRecord(record);

  @override
  Future<void> addRecords(List<QazaRecord> records) =>
      delegate.addRecords(records);

  @override
  Future<void> updateRecord({required QazaRecord record}) =>
      delegate.updateRecord(record: record);

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) =>
      delegate.deleteRecord(userId: userId, recordId: recordId);

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) =>
      delegate.completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) =>
      delegate.completeRecords(
        userId: userId,
        recordIds: recordIds,
        completedAt: completedAt,
      );

  @override
  Future<void> resetUserRecords({required String userId}) =>
      delegate.resetUserRecords(userId: userId);
}

void main() {
  group('startup lifecycle', () {
    test('an empty cloud account still reaches a ready state', () async {
      final local = InMemoryQazaLocalStore();
      final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(),
        localStore: local,
      );
      addTearDown(repository.dispose);

      final seen = <SyncStatus>[];
      final sub = repository.syncState.listen((s) => seen.add(s.status));
      addTearDown(sub.cancel);

      await repository.setActiveUser('fresh-user');
      await repository.ensureHydrated();

      expect(seen.first, SyncStatus.bootstrapping);
      expect(repository.currentState.isReady, isTrue);
      expect(
        await repository.getProgressSummary(userId: 'fresh-user'),
        isA<QazaProgressSummary>().having((s) => s.overall.total, 'total', 0),
      );
    });

    test('a fresh device hydrates existing cloud data before reads resolve',
        () async {
      final remoteBacking = InMemoryQazaRepository();
      await remoteBacking.addRecords([
        for (var day = 1; day <= 4; day++)
          _record('cloud-user', PrayerType.fajr, DateTime(2025, 1, day)),
      ]);

      final repository = OfflineFirstQazaRepository(
        remote: remoteBacking,
        localStore: InMemoryQazaLocalStore(),
      );
      addTearDown(repository.dispose);

      final seen = <SyncStatus>[];
      final sub = repository.syncState.listen((s) => seen.add(s.status));
      addTearDown(sub.cancel);

      await repository.setActiveUser('cloud-user');
      await repository.ensureHydrated();

      expect(seen, contains(SyncStatus.bootstrapping));
      expect(seen, contains(SyncStatus.hydrating));
      expect(repository.currentState.isReady, isTrue);

      final summary = await repository.getProgressSummary(userId: 'cloud-user');
      expect(summary.overall.pending, 4,
          reason: 'reads must see the hydrated ledger, not an empty one');
    });

    test('reads do not observe a partially hydrated ledger', () async {
      final backing = InMemoryQazaRepository();
      await backing.addRecords([
        for (var day = 1; day <= 3; day++)
          _record('cloud-user', PrayerType.zuhr, DateTime(2025, 2, day)),
      ]);
      final remote = _BlockingRemote(backing);

      final repository = OfflineFirstQazaRepository(
        remote: remote,
        localStore: InMemoryQazaLocalStore(),
      );
      addTearDown(repository.dispose);

      final hydrating = repository.syncState.firstWhere(
        (state) => state.status == SyncStatus.hydrating,
      );
      await repository.setActiveUser('cloud-user');
      await hydrating;

      expect(repository.currentState.status, SyncStatus.hydrating);
      expect(repository.currentState.isReady, isFalse);

      // A read issued mid-hydration must wait rather than report an empty
      // ledger, which is what would corrupt availability and duplicate checks.
      final pageFuture = repository.getPage(userId: 'cloud-user', limit: 50);
      remote.gate.complete();
      final page = await pageFuture;

      expect(page.records.length, 3);
      expect(repository.currentState.isReady, isTrue);
    });

    test('an offline start is ready immediately with local data', () async {
      final local = InMemoryQazaLocalStore();
      final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(),
        localStore: local,
        connectivityChanges: Stream<bool>.value(false),
      );
      addTearDown(repository.dispose);

      await repository.setActiveUser('offline-user');
      await Future<void>.delayed(Duration.zero);
      await repository.ensureHydrated();

      expect(repository.currentState.isReady, isTrue);
    });

    test('an interrupted pull still ends ready rather than stuck', () async {
      final remote = _BlockingRemote(InMemoryQazaRepository())..failPull = true;
      final repository = OfflineFirstQazaRepository(
        remote: remote,
        localStore: InMemoryQazaLocalStore(),
      );
      addTearDown(repository.dispose);

      await repository.setActiveUser('cloud-user');
      await Future<void>.delayed(Duration.zero);
      remote.gate.complete();
      await repository.ensureHydrated();

      expect(repository.currentState.isReady, isTrue,
          reason: 'a failed first pull must not strand the account');
    });

    test('switching accounts re-runs bootstrap for the new account', () async {
      final backing = InMemoryQazaRepository();
      await backing.addRecords([
        _record('user-b', PrayerType.asr, DateTime(2025, 3, 1)),
      ]);

      final repository = OfflineFirstQazaRepository(
        remote: backing,
        localStore: InMemoryQazaLocalStore(),
      );
      addTearDown(repository.dispose);

      await repository.setActiveUser('user-a');
      await repository.ensureHydrated();
      expect(
        (await repository.getProgressSummary(userId: 'user-a')).overall.total,
        0,
      );

      await repository.setActiveUser('user-b');
      await repository.ensureHydrated();
      final summary = await repository.getProgressSummary(userId: 'user-b');
      expect(summary.overall.pending, 1);

      // The previous account's data must not leak through the new session.
      expect(
        (await repository.getPage(userId: 'user-a', limit: 50)).records,
        isEmpty,
      );
    });

    test('signing out returns to a neutral ready state', () async {
      final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(),
        localStore: InMemoryQazaLocalStore(),
      );
      addTearDown(repository.dispose);

      await repository.setActiveUser('user-a');
      await repository.ensureHydrated();
      await repository.setActiveUser(null);

      expect(repository.currentState.isReady, isTrue);
      expect(repository.currentState.status, SyncStatus.synced);
    });
  });

  group('readiness contract', () {
    test('only the startup states report not-ready', () {
      for (final status in SyncStatus.values) {
        final ready = const SyncState().isReady;
        expect(ready, isTrue);
        final state = SyncState(status: status);
        expect(
          state.isReady,
          status != SyncStatus.bootstrapping && status != SyncStatus.hydrating,
          reason: '$status readiness',
        );
      }
    });
  });
}
