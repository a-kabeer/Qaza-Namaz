import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

void main() {
  test('Google workspace IDs use the stable authenticated account ID', () {
    expect(
      googleLocalWorkspaceId('  stable-google-account-A  '),
      'google:stable-google-account-A',
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
    expect(
      manager.activeLocalAccountId,
      UserProfile.localLedgerUserId,
    );
    expect(manager.activeAccount, isNotNull);
    expect(manager.activeAccount!.accountMode, AccountMode.local);

    await manager.refresh();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(
      manager.activeLocalAccountId,
      UserProfile.localLedgerUserId,
    );
  });

  test('Google and Guest sessions use separate persistent workspaces',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'guest_only_record',
        userId: UserProfile.localLedgerUserId,
        prayerType: 'fajr',
        originalDate: DateTime(2025, 1, 1),
        status: 'pending',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    await manager.activateGoogleAccount('stable-google-account-A');
    expect(manager.activeLocalAccountId, 'google:stable-google-account-A');
    expect(
      await database.qazaRecordsDao.getAll(
        userId: 'google:stable-google-account-A',
      ),
      isEmpty,
    );

    await manager.activateGuest();
    expect(manager.activeLocalAccountId, UserProfile.localLedgerUserId);
    expect(
      (await database.qazaRecordsDao.getAll(
        userId: UserProfile.localLedgerUserId,
      ))
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

  test('sign-out fallback never tries to reactivate an archived legacy Guest',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();

    await database.customUpdate(
      "UPDATE local_accounts SET lifecycle_state = 'archived' "
      "WHERE local_account_id = 'guest'",
    );

    await manager.activateGuest();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(manager.activeLocalAccountId, startsWith('guest:'));
    expect(manager.activeLocalAccountId, isNot('guest'));
    expect((await store.getAccount('guest'))?.lifecycleState,
        AccountLifecycleState.archived);
  });

  test('startup recovers if the persisted legacy Guest workspace is archived',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);
    final initialManager = AccountSessionManager(accountStore: store);
    await initialManager.initialize();

    await database.customUpdate(
      "UPDATE local_accounts SET lifecycle_state = 'archived' "
      "WHERE local_account_id = 'guest'",
    );

    final restartedManager = AccountSessionManager(accountStore: store);
    await restartedManager.initialize();

    expect(restartedManager.state.phase, AccountSessionPhase.ready);
    expect(restartedManager.activeLocalAccountId, startsWith('guest:'));
    expect((await store.getAccount('guest'))?.lifecycleState,
        AccountLifecycleState.archived);
  });
}
