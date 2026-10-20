import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

void main() {
  test('Google workspace IDs use the stable authenticated account ID', () {
    expect(
      googleLocalWorkspaceId('  stable-google-account-A  '),
      'google_stable-google-account-A',
    );
    expect(
      () => googleLocalWorkspaceId('  '),
      throwsArgumentError,
    );
  });

  test('startup creates and restores one local device session', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);

    await manager.initialize();

    expect(manager.state.phase, AccountSessionPhase.ready);
    final initialWorkspaceId = manager.activeLocalAccountId!;
    expect(initialWorkspaceId, startsWith('guest_'));
    expect(manager.activeAccount, isNotNull);
    expect(manager.activeAccount!.accountMode, AccountMode.local);

    await manager.refresh();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(manager.activeLocalAccountId, initialWorkspaceId);
  });

  test('Google and Guest sessions use separate persistent workspaces',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();
    final originalGuestId = manager.activeLocalAccountId!;
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'guest_only_record',
        userId: originalGuestId,
        prayerType: 'fajr',
        originalDate: DateTime(2025, 1, 1),
        status: 'pending',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    await manager.activateGoogleAccount('stable-google-account-A');
    const googleId = 'google_stable-google-account-A';
    expect(manager.activeLocalAccountId, googleId);
    expect(await database.qazaRecordsDao.getAll(userId: googleId), isEmpty);

    await manager.activateGuest();
    final signedOutGuestId = manager.activeLocalAccountId!;
    expect(signedOutGuestId, startsWith('guest_'));
    expect(signedOutGuestId, isNot(originalGuestId));
    expect(await database.qazaRecordsDao.getAll(userId: signedOutGuestId), isEmpty);
    expect(
      (await database.qazaRecordsDao.getAll(userId: originalGuestId))
          .map((record) => record.id),
      contains('guest_only_record'),
    );
  });

  test('multiple Guest workspaces keep names and survive process restart',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();

    final firstGuestId = await store.createGuestWorkspace(displayName: 'Amina');
    await manager.activateLocalAccount(firstGuestId);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'first_guest_fajr',
        userId: firstGuestId,
        prayerType: 'fajr',
        originalDate: DateTime(2025, 1, 1),
        status: 'pending',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    final secondGuestId =
        await store.createGuestWorkspace(displayName: 'Bilal');
    await manager.activateLocalAccount(secondGuestId);

    final guests = await store.listGuestWorkspaces();
    expect(
      guests.map((account) => account.localAccountId),
      containsAll([firstGuestId, secondGuestId]),
    );
    expect(
      guests
          .singleWhere((account) => account.localAccountId == firstGuestId)
          .displayName,
      'Amina',
    );
    expect(
      guests
          .singleWhere((account) => account.localAccountId == secondGuestId)
          .displayName,
      'Bilal',
    );
    expect(
      await database.qazaRecordsDao.getAll(userId: secondGuestId),
      isEmpty,
    );

    await manager.activateLocalAccount(firstGuestId);
    final restartedManager = AccountSessionManager(accountStore: store);
    await restartedManager.initialize();

    expect(restartedManager.activeLocalAccountId, firstGuestId);
    expect(
      (await database.qazaRecordsDao.getAll(userId: firstGuestId))
          .map((record) => record.id),
      ['first_guest_fajr'],
    );
  });

  test('sign-out fallback never tries to reactivate an archived Guest',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();
    final archivedGuestId = manager.activeLocalAccountId!;

    await database.customUpdate(
      "UPDATE local_accounts SET lifecycle_state = 'archived' "
      "WHERE local_account_id = ?",
      variables: [Variable(archivedGuestId)],
    );

    await manager.activateGuest();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(manager.activeLocalAccountId, startsWith('guest_'));
    expect(manager.activeLocalAccountId, isNot(archivedGuestId));
    expect((await store.getAccount(archivedGuestId))?.lifecycleState,
        AccountLifecycleState.archived);
  });

  test('startup recovers if the persisted Guest workspace is archived',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);
    final initialManager = AccountSessionManager(accountStore: store);
    await initialManager.initialize();
    final archivedGuestId = initialManager.activeLocalAccountId!;

    await database.customUpdate(
      "UPDATE local_accounts SET lifecycle_state = 'archived' "
      "WHERE local_account_id = ?",
      variables: [Variable(archivedGuestId)],
    );

    final restartedManager = AccountSessionManager(accountStore: store);
    await restartedManager.initialize();

    expect(restartedManager.state.phase, AccountSessionPhase.ready);
    expect(restartedManager.activeLocalAccountId, startsWith('guest_'));
    expect(restartedManager.activeLocalAccountId, isNot(archivedGuestId));
    expect((await store.getAccount(archivedGuestId))?.lifecycleState,
        AccountLifecycleState.archived);
  });
}
