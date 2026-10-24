import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

/// Chained end-to-end scenario tests (TP-GEN v4.1 plan, Section 11).
///
/// The individual legs of these journeys are covered elsewhere
/// (account_screen_test.dart, local_session_test.dart, the cloud adapter
/// suites); these tests chain the legs together against one database and
/// one session manager, the way a real user would live them:
///
/// * Scenario 5, Case B — connecting a Google account whose Drive backup is
///   found while a local Google workspace already exists must reconcile the
///   local workspace through an explicit user decision, never restore over
///   it blindly, and must leave a separate Guest workspace untouched.
/// * Scenario 6 — an existing Google workspace with unsynced local changes
///   opens on start; the changes are reconciled by upload, never lost to a
///   destructive restore.
/// * Scenario 9 — Google A makes offline changes, signs out anyway, Google B
///   signs in on the same device, then A returns: A's unsynced data is
///   still there and is reconciled (uploaded) on reactivation.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'scenario 5 Case B: found backup reconciles the existing local Google '
    'workspace via Keep Local and leaves the Guest workspace untouched',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = AccountLocalStore(database: database);
      final manager = await _createSession(database);
      final guestId = manager.activeLocalAccountId!;
      await _insertRecord(database, guestId, 'guest_record_1');

      const accountA = 'test-google-account-A';
      const googleA = 'google_test-google-account-A';
      await manager.activateGoogleAccount(accountA);
      expect(manager.activeLocalAccountId, googleA);
      await _insertRecord(database, googleA, 'google_local_record_1');
      await _saveCompletedProfile(store, googleA);
      // The user is currently working in the Guest workspace.
      await manager.activateLocalAccount(guestId);

      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot.disconnected(),
      )..signInSnapshot = const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: accountA,
          displayName: 'A Test User',
          email: 'a@example.com',
        );
      final cloudSync = _FakeCloudSyncProvider()
        ..discoverySnapshot = CloudBackupDiscoverySnapshot.backupFound(
          CloudConflictInfo(
            localDeviceId: 'device-local',
            localTimestamp: DateTime(2026, 10, 2),
            localRevision: 5,
            localBaseBackupId: null,
            remoteDeviceId: 'device-remote',
            remoteTimestamp: DateTime(2026, 10, 1),
            remoteRevision: 4,
            remoteBackupId: 'backup-remote-1',
            remoteBaseBackupId: null,
            lastSyncedBackupId: null,
            remoteVersion: '7',
          ),
        );
      final container = _container(
        database: database,
        manager: manager,
        cloudAccount: cloudAccount,
        cloudSync: cloudSync,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(
        _app(container, const AccountScreen(autoConnect: true)),
      );
      await _pumpUntilVisible(tester, find.text('Different changes found'));

      // A found backup for a workspace that already has local data must be
      // reconciled through an explicit decision — never restored blindly.
      expect(find.text('Different changes found'), findsOneWidget);
      expect(cloudSync.resolveChoices, isEmpty);
      expect(cloudSync.backupCalls, 0);

      await tester.tap(find.text('Keep this device'));
      await _pumpUntilVisible(
        tester,
        find.text("Keep this device's progress?"),
      );
      await tester.tap(find.text('Continue'));
      await _pumpUntilAbsent(
        tester,
        find.byKey(const Key('account_cloud_operation_progress')),
      );

      // Reconciled as Keep Local: the provider was asked to publish the
      // local workspace, not to import the remote backup over it.
      expect(cloudSync.resolveChoices, [CloudConflictChoice.keepLocal]);
      expect(manager.activeLocalAccountId, googleA);
      expect(
        await _recordStates(database, googleA),
        ['google_local_record_1:pending'],
      );
      // The Guest workspace was not adopted, merged, or modified.
      expect(
          await _recordStates(database, guestId), ['guest_record_1:pending']);
      expect(
        (await store.getAccount(guestId))?.lifecycleState.name,
        'active',
      );
    },
  );

  testWidgets(
    'scenario 6: an existing Google workspace opens on start and its '
    'unsynced changes are uploaded, never restored over',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = AccountLocalStore(database: database);
      final manager = await _createSession(database);

      const accountA = 'test-google-account-A';
      const googleA = 'google_test-google-account-A';
      await manager.activateGoogleAccount(accountA);
      await _insertRecord(database, googleA, 'google_unsynced_1');
      await _insertRecord(
        database,
        googleA,
        'google_unsynced_2',
        prayerType: 'zuhr',
        date: DateTime(2026, 9, 30),
      );
      await _saveCompletedProfile(store, googleA);
      expect(manager.activeLocalAccountId, googleA);

      // A persisted Google session is restored on start.
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: accountA,
          displayName: 'A Test User',
          email: 'a@example.com',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider()
        ..backupResult = const CloudSyncSnapshot(
          status: CloudSyncStatus.synced,
          hasPendingChanges: false,
        );
      final container = _container(
        database: database,
        manager: manager,
        cloudAccount: cloudAccount,
        cloudSync: cloudSync,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(
        _app(container, const AccountScreen(autoConnect: true)),
      );
      await tester.pumpAndSettle();

      // The local workspace opened as-is and its unsynced changes were
      // reconciled by uploading them; no restore decision was forced and
      // nothing was imported over the local data.
      expect(manager.activeLocalAccountId, googleA);
      expect(cloudSync.discoveryCalls, 1);
      expect(cloudSync.backupCalls, 1);
      expect(cloudSync.resolveChoices, isEmpty);
      expect(
        await _recordStates(database, googleA),
        ['google_unsynced_1:pending', 'google_unsynced_2:pending'],
      );
    },
  );

  testWidgets(
    'scenario 9: offline changes survive an A -> B -> A account round trip '
    'and are uploaded when A is reactivated',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = AccountLocalStore(database: database);
      final manager = await _createSession(database);

      const accountA = 'test-google-account-A';
      const accountB = 'test-google-account-B';
      const googleA = 'google_test-google-account-A';
      const googleB = 'google_test-google-account-B';

      // Google A is active and holds a change made while offline.
      await manager.activateGoogleAccount(accountA);
      await _saveCompletedProfile(store, googleA);
      await _insertRecord(database, googleA, 'a_offline_fajr');
      // Google B also has a (separate, empty) workspace on this device.
      await manager.activateGoogleAccount(accountB);
      await _saveCompletedProfile(store, googleB);
      await manager.activateLocalAccount(googleA);

      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: accountA,
          displayName: 'User A',
          email: 'a@example.com',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider();
      addTearDown(database.close);

      // Each leg runs in a fresh provider container wired to the same
      // database, session manager, and cloud fakes — the wiring is per
      // "app run", while the data under test persists across legs, which
      // is exactly what this scenario pins down. The leg containers are
      // deliberately not disposed: ChangeNotifierProvider disposal would
      // dispose the shared session manager that later legs still use.
      ProviderContainer newContainer() {
        return _container(
          database: database,
          manager: manager,
          cloudAccount: cloudAccount,
          cloudSync: cloudSync,
        );
      }

      // Leg 1: A signs out anyway while offline with pending changes.
      cloudSync.snapshot = const CloudSyncSnapshot(
        status: CloudSyncStatus.failed,
        hasPendingChanges: true,
      );
      cloudSync.discoverySnapshot =
          const CloudBackupDiscoverySnapshot.failed('offline');
      await tester.pumpWidget(_app(newContainer(), const AccountScreen()));
      await tester.pumpAndSettle();
      expect(find.text('User A'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await _pumpUntilVisible(tester, find.text('Changes not backed up'));
      await tester.tap(find.text('Sign Out Anyway'));
      await _pumpUntilVisible(tester, find.text('Welcome to Qaza Namaz'));

      expect(cloudAccount.snapshot.isConnected, isFalse);
      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(manager.activeLocalAccountId, startsWith('guest_'));
      expect(
        await _recordStates(database, googleA),
        ['a_offline_fajr:pending'],
      );

      // Leg 2: B signs in. B's workspace is separate and empty; A's data is
      // neither visible under B nor modified.
      await tester.pumpWidget(const SizedBox());
      cloudAccount.signInSnapshot = const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: accountB,
        displayName: 'User B',
        email: 'b@example.com',
      );
      cloudSync.snapshot = const CloudSyncSnapshot(
        status: CloudSyncStatus.idle,
        hasPendingChanges: false,
      );
      cloudSync.discoverySnapshot =
          const CloudBackupDiscoverySnapshot.noBackup();
      cloudSync.backupResult = const CloudSyncSnapshot(
        status: CloudSyncStatus.synced,
        hasPendingChanges: false,
      );
      final backupsBeforeB = cloudSync.backupCalls;
      await tester.pumpWidget(_app(newContainer(), const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in with Google'));
      await _pumpUntilAbsent(
        tester,
        find.byKey(const Key('account_cloud_operation_progress')),
      );

      expect(manager.activeLocalAccountId, googleB);
      expect(cloudSync.backupCalls, backupsBeforeB + 1);
      expect(await _recordStates(database, googleB), isEmpty);
      expect(
        await _recordStates(database, googleA),
        ['a_offline_fajr:pending'],
      );

      // Leg 3: B signs out (nothing pending, so no warning dialog).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(newContainer(), const AccountScreen()));
      await tester.pumpAndSettle();
      expect(find.text('User B'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await _pumpUntilVisible(tester, find.text('Welcome to Qaza Namaz'));

      expect(cloudAccount.snapshot.isConnected, isFalse);
      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(
        await _recordStates(database, googleA),
        ['a_offline_fajr:pending'],
      );

      // Leg 4: A signs back in. The offline change is still present and is
      // reconciled by uploading it on reactivation — no restore is forced
      // and no conflict decision is demanded.
      await tester.pumpWidget(const SizedBox());
      cloudAccount.signInSnapshot = const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: accountA,
        displayName: 'User A',
        email: 'a@example.com',
      );
      final backupsBeforeReturn = cloudSync.backupCalls;
      await tester.pumpWidget(_app(newContainer(), const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in with Google'));
      await _pumpUntilAbsent(
        tester,
        find.byKey(const Key('account_cloud_operation_progress')),
      );

      expect(manager.activeLocalAccountId, googleA);
      expect(cloudSync.backupCalls, backupsBeforeReturn + 1);
      expect(cloudSync.resolveChoices, isEmpty);
      expect(
        await _recordStates(database, googleA),
        ['a_offline_fajr:pending'],
      );
    },
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 30,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget to become visible within $maxFrames frames.');
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 30,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Expected widget to disappear within $maxFrames frames.');
}

Future<AccountSessionManager> _createSession(AppDatabase database) async {
  final store = AccountLocalStore(database: database);
  final manager = AccountSessionManager(accountStore: store);
  await manager.initialize();
  return manager;
}

Widget _app(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

ProviderContainer _container({
  required AppDatabase database,
  required AccountSessionManager manager,
  required _FakeCloudAccountProvider cloudAccount,
  required _FakeCloudSyncProvider cloudSync,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      accountSessionManagerProvider.overrideWith((ref) => manager),
      cloudAccountProvider.overrideWith((ref) => cloudAccount),
      cloudSyncProvider.overrideWith((ref) => cloudSync),
      progressSummaryProvider.overrideWith(
        (ref) async => QazaProgressSummary.empty(),
      ),
    ],
  );
}

Future<void> _insertRecord(
  AppDatabase database,
  String userId,
  String id, {
  String prayerType = 'fajr',
  DateTime? date,
}) async {
  final recordDate = date ?? DateTime(2026, 10, 1);
  await database.qazaRecordsDao.insertRecord(
    QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: prayerType,
      originalDate: recordDate,
      status: 'pending',
      createdAt: recordDate,
      updatedAt: recordDate,
    ),
  );
}

Future<void> _saveCompletedProfile(
  AccountLocalStore store,
  String workspaceId,
) async {
  await store.saveProfile(
    workspaceId,
    UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1990, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    ),
  );
}

/// Record id + status pairs for [userId], ordered by id: the dataset and
/// its pending state in one comparable value.
Future<List<String>> _recordStates(
  AppDatabase database,
  String userId,
) async {
  final records = await database.qazaRecordsDao.getAll(userId: userId);
  final states = records
      .map((record) => '${record.id}:${record.status.name}')
      .toList()
    ..sort();
  return states;
}

class _FakeCloudAccountProvider extends UnsupportedCloudAccountProvider {
  _FakeCloudAccountProvider({required this.snapshot});

  CloudAccountSnapshot snapshot;

  /// When set, [signIn] returns this snapshot instead of [snapshot] (and it
  /// becomes the current snapshot, like a real sign-in would leave behind).
  CloudAccountSnapshot? signInSnapshot;
  int signInCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async => snapshot;

  @override
  Future<CloudAccountSnapshot> signIn() async {
    signInCalls++;
    final result = signInSnapshot ?? snapshot;
    snapshot = result;
    return result;
  }

  @override
  Future<List<RememberedCloudAccount>> rememberedAccounts() async =>
      const <RememberedCloudAccount>[];

  @override
  Future<CloudAccountSnapshot> signInWithRememberedAccount(
    String accountId,
  ) async =>
      snapshot;

  @override
  Future<void> disconnect() async {
    snapshot = const CloudAccountSnapshot.disconnected();
  }
}

class _FakeCloudSyncProvider extends UnsupportedCloudSyncProvider {
  CloudSyncSnapshot snapshot = const CloudSyncSnapshot(
    status: CloudSyncStatus.idle,
  );
  CloudBackupDiscoverySnapshot discoverySnapshot =
      const CloudBackupDiscoverySnapshot.noBackup();
  CloudSyncSnapshot? backupResult;
  CloudSyncSnapshot resolveResult = const CloudSyncSnapshot(
    status: CloudSyncStatus.synced,
    hasPendingChanges: false,
  );
  int discoveryCalls = 0;
  int backupCalls = 0;
  final List<CloudConflictChoice> resolveChoices = <CloudConflictChoice>[];

  @override
  bool get isSupported => true;

  @override
  Future<CloudSyncSnapshot> status() async => snapshot;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async {
    discoveryCalls++;
    return discoverySnapshot;
  }

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) async {
    backupCalls++;
    onProgress?.call(const CloudBackupProgress.preparing());
    return backupResult ?? snapshot;
  }

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
    CloudBackupProgressCallback? onProgress,
  }) async {
    resolveChoices.add(choice);
    return resolveResult;
  }
}
