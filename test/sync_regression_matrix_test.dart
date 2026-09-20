import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

/// The sync rows of the V2 regression matrix that were not already pinned
/// elsewhere: reconnect, logout, and offline-write-then-reconnect.
///
/// Upload, pull, conflict handling, outbox persistence and multi-device
/// convergence live in `task3h_offline_first_repository_test.dart`; bootstrap
/// and account switching live in `cloud_bootstrap_test.dart`.
void main() {
  QazaRecord record({
    required String id,
    String userId = 'user-a',
    PrayerType prayer = PrayerType.fajr,
    DateTime? date,
  }) {
    final originalDate = date ?? DateTime(2026, 3, 1);
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: originalDate,
      createdAt: originalDate,
      updatedAt: originalDate,
    );
  }

  test('going offline is reported without losing the pending count', () async {
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final repository = OfflineFirstQazaRepository(
      remote: InMemoryQazaRepository(),
      localStore: InMemoryQazaLocalStore(),
      connectivityChanges: connectivity.stream,
    );
    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();

    connectivity.add(false);
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentState.status, SyncStatus.offline);
    expect(repository.currentState.isReady, isTrue,
        reason: 'offline is a working state, not a startup state');
  });

  test('an offline write is kept locally and uploaded after reconnect',
      () async {
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: InMemoryQazaLocalStore(),
      connectivityChanges: connectivity.stream,
    );
    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();

    connectivity.add(false);
    await Future<void>.delayed(Duration.zero);

    await repository.addRecord(record(id: 'offline-1'));

    // The write is readable locally straight away.
    final localPage = await repository.getPage(userId: 'user-a', limit: 50);
    expect(localPage.records.map((r) => r.id), contains('offline-1'));

    // ...and has not reached the backend yet.
    expect(await remote.getRecords(userId: 'user-a'), isEmpty);
    expect(repository.currentState.pendingCount, greaterThan(0));

    final synced = repository.syncState.firstWhere(
      (state) =>
          state.status == SyncStatus.synced && state.pendingCount == 0,
    );
    connectivity.add(true);
    await synced;

    expect(
      (await remote.getRecords(userId: 'user-a')).map((r) => r.id),
      contains('offline-1'),
      reason: 'reconnect must flush the outbox',
    );
    expect(repository.currentState.pendingCount, 0);
  });

  test('signing out clears the active user and stops serving their data',
      () async {
    final repository = OfflineFirstQazaRepository(
      remote: InMemoryQazaRepository(),
      localStore: InMemoryQazaLocalStore(),
    );
    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();
    await repository.addRecord(record(id: 'a-1'));
    expect(
      (await repository.getPage(userId: 'user-a', limit: 50)).records,
      isNotEmpty,
    );

    await repository.setActiveUser(null);

    expect(repository.activeUserId, isNull);
    expect(
      (await repository.getPage(userId: 'user-a', limit: 50)).records,
      isEmpty,
      reason: 'a signed-out session must not serve the previous account',
    );
    final summary = await repository.getProgressSummary(userId: 'user-a');
    expect(summary.overall.total, 0);
  });

  test('signing back in restores the persisted ledger', () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
      remote: InMemoryQazaRepository(),
      localStore: localStore,
    );
    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();
    await repository.addRecord(record(id: 'a-1'));

    await repository.setActiveUser(null);
    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();

    final page = await repository.getPage(userId: 'user-a', limit: 50);
    expect(page.records.map((r) => r.id), contains('a-1'),
        reason: 'sign-out is not data deletion');
  });

  test('a second account never sees the first account records', () async {
    final repository = OfflineFirstQazaRepository(
      remote: InMemoryQazaRepository(),
      localStore: InMemoryQazaLocalStore(),
    );
    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.ensureHydrated();
    await repository.addRecord(record(id: 'a-1'));

    await repository.setActiveUser('user-b');
    await repository.ensureHydrated();

    expect((await repository.getPage(userId: 'user-b', limit: 50)).records,
        isEmpty);
    expect((await repository.getPage(userId: 'user-a', limit: 50)).records,
        isEmpty,
        reason: 'reads for a non-active account return nothing');
  });
}
