import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  QazaRecord record({required String id, required String userId}) {
    final date = DateTime(2026, 1, 1);
    return QazaRecord(
        id: id,
        userId: userId,
        prayerType: PrayerType.fajr,
        originalDate: date,
        status: QazaStatus.pending,
        createdAt: date,
        updatedAt: date);
  }

  test('setActiveUser does not materialize the full local snapshot', () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    expect(localStore.loadCalls, 0);
    expect(repository.activeUserId, 'user-a');
  });

  test('bounded page read does not materialize the legacy snapshot', () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    final page = await repository.getPage(
        userId: 'user-a', limit: 50, status: QazaStatus.pending);
    expect(page.records, isEmpty);
    expect(localStore.loadCalls, 0);
  });

  test('oldest-pending read does not materialize the legacy snapshot',
      () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    final oldest = await repository.getOldestPending(
        userId: 'user-a', prayerType: PrayerType.fajr);
    expect(oldest, isNull);
    expect(localStore.loadCalls, 0);
  });

  test('explicit sync remains the controlled legacy full-ledger entry point',
      () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    expect(localStore.loadCalls, 0);
    await repository.syncNow();
    expect(localStore.loadCalls, 1);
  });

  test(
      'switching accounts isolates the in-memory session and restores each user data set',
      () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    await repository.addRecord(record(id: 'a1', userId: 'user-a'));
    await repository.setActiveUser('user-b');
    expect(await repository.getRecords(userId: 'user-b'), isEmpty);
    final emptySummary = await repository.getProgressSummary(userId: 'user-b');
    expect(emptySummary.overall.pending, 0);
    expect(emptySummary.overall.completed, 0);
    expect(emptySummary.byPrayer.length, PrayerType.values.length);
    await repository.setActiveUser('user-a');
    expect(
        (await repository.getRecords(userId: 'user-a')).map((item) => item.id),
        ['a1']);
  });

  test(
      'sign-out clears the active session and rejects access to the previous user ledger',
      () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    await repository.addRecord(record(id: 'a1', userId: 'user-a'));
    await repository.setActiveUser(null);
    expect(repository.activeUserId, isNull);
    expect(await repository.getRecords(userId: 'user-a'), isEmpty);
    expect(() => repository.addRecord(record(id: 'a2', userId: 'user-a')),
        throwsStateError);
  });

  test(
      'a record for another account cannot be added through the active session',
      () async {
    final localStore = InMemoryQazaLocalStore();
    final repository = OfflineFirstQazaRepository(
        remote: InMemoryQazaRepository(), localStore: localStore);
    addTearDown(repository.dispose);
    await repository.setActiveUser('user-a');
    expect(() => repository.addRecord(record(id: 'b1', userId: 'user-b')),
        throwsStateError);
    expect(await repository.getRecords(userId: 'user-a'), isEmpty);
  });
}
