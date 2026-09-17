import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';

import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
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
}
