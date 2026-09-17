import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
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
      updatedAt: date,
    );
  }

  test('setActiveUser does not materialize the full local snapshot', () async {
    final localStore = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: localStore,
    );

    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');

    expect(localStore.loadCalls, 0);
    expect(repository.activeUserId, 'user-a');
  });

  test('explicit sync is the controlled entry point that loads the legacy full ledger', () async {
    final localStore = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: localStore,
    );

    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    expect(localStore.loadCalls, 0);

    await repository.syncNow();

    expect(localStore.loadCalls, 1);
  });

  test('switching accounts isolates the in-memory session and restores each user data set', () async {
    final localStore = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: localStore,
    );

    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.addRecord(record(id: 'a1', userId: 'user-a'));

    await repository.setActiveUser('user-b');
    expect(await repository.getRecords(userId: 'user-b'), isEmpty);
    expect(await repository.getProgressSummary(userId: 'user-b'), QazaProgressSummary.empty());

    await repository.setActiveUser('user-a');
    final restored = await repository.getRecords(userId: 'user-a');
    expect(restored.map((item) => item.id), ['a1']);
    expect(restored.every((item) => item.userId == 'user-a'), isTrue);
  });

  test('sign-out clears the active session and rejects access to the previous user ledger', () async {
    final localStore = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: localStore,
    );

    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    await repository.addRecord(record(id: 'a1', userId: 'user-a'));
    await repository.setActiveUser(null);

    expect(repository.activeUserId, isNull);
    expect(await repository.getRecords(userId: 'user-a'), isEmpty);
    expect(() => repository.addRecord(record(id: 'a2', userId: 'user-a')), throwsStateError);
  });

  test('a record for another account cannot be added through the active session', () async {
    final localStore = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: localStore,
    );

    addTearDown(repository.dispose);

    await repository.setActiveUser('user-a');
    expect(() => repository.addRecord(record(id: 'b1', userId: 'user-b')), throwsStateError);
    expect(await repository.getRecords(userId: 'user-a'), isEmpty);
  });
}
