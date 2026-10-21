import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/onboarding/cloud_setup_choice_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        final primaryColor = ref.watch(primaryColorProvider);
        return MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(locale: locale, primaryColor: primaryColor),
          darkTheme: AppTheme.dark(locale: locale, primaryColor: primaryColor),
          themeMode: ref.watch(themeModeProvider).materialMode,
          home: const CloudSetupChoiceScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('theme selector precedes language and offers only theme modes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        // Keep this UI contract test independent of platform cloud restore.
        cloudAccountStartupRestoreProvider.overrideWith(
          (ref) async => const CloudAccountSnapshot.unavailable(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final themeSelector = find.byKey(const Key('cloud_setup_theme_selector'));
    final languageSelector =
        find.byKey(const Key('cloud_setup_language_selector'));
    expect(themeSelector, findsOneWidget);
    expect(languageSelector, findsOneWidget);
    expect(
      tester.getCenter(themeSelector).dx,
      lessThan(tester.getCenter(languageSelector).dx),
    );
    expect(find.text('Teal'), findsNothing);
    expect(find.text('Blue'), findsNothing);

    await tester.tap(themeSelector);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('cloud_setup_theme_option_system')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cloud_setup_theme_option_light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cloud_setup_theme_option_dark')),
      findsOneWidget,
    );
    expect(find.text('Teal'), findsNothing);

    await tester.tap(find.byKey(const Key('cloud_setup_theme_option_dark')));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);
    await tester.pump(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeNotifier.storageKey), 'dark');
  });

  // Scenario 8(a) — a brand-new Google account (no Drive backup) that has a
  // saved Guest workspace offers adoption; choosing the Guest moves its data
  // into the Google workspace, runs the first backup, and records the
  // adoption backup verification (Scenario 4 marking path, end to end).
  testWidgets(
      'new Google sign-in adopts the chosen saved Guest, backs it up, '
      'and marks the adoption verified', (tester) async {
    final run = await _startAdoptionFlow(tester);

    await tester.tap(find.byKey(Key('guest_workspace_choice_${run.guestId}')));
    await tester.pumpAndSettle();

    // The session landed in the Google workspace.
    expect(
      run.container.read(accountSessionManagerProvider).activeLocalAccountId,
      run.workspaceId,
    );
    // The Guest source is preserved as an adopted recovery workspace.
    expect(
      (await run.store.getAccount(run.guestId))?.lifecycleState,
      AccountLifecycleState.adoptedRecovery,
    );
    // The Guest's records moved to the Google workspace; none stay behind.
    expect(
      (await run.database.qazaRecordsDao.getAll(userId: run.workspaceId))
          .map((record) => record.id),
      ['choice_guest_fajr_1'],
    );
    expect(
      await run.database.qazaRecordsDao.getAll(userId: run.guestId),
      isEmpty,
    );
    // The Google display name was applied to the adopted workspace.
    expect(
      (await run.store.getAccount(run.workspaceId))?.displayName,
      'Amina Google',
    );
    // The first cloud backup ran exactly once, and its success marked the
    // adoption backup as verified (Scenario 4 leftover).
    expect(run.syncProvider.backupNowCalls, 1);
    expect(
      await _adoptionBackupVerifiedAt(run.database, run.workspaceId),
      isNotNull,
    );
    expect(run.container.read(startupWorkspaceRestoreSatisfiedProvider), true);
    expect(tester.takeException(), isNull);
  });

  // Scenario 8(a) follow-up — after that successful first backup, the
  // durable initial-backup pending marker for the Google workspace must be
  // cleared; otherwise every later startup keeps treating the workspace as
  // still owing its first backup.
  testWidgets(
      'successful adoption backup clears the initial-backup pending marker',
      (tester) async {
    final run = await _startAdoptionFlow(tester);

    await tester.tap(find.byKey(Key('guest_workspace_choice_${run.guestId}')));
    await tester.pumpAndSettle();

    expect(run.syncProvider.backupNowCalls, 1);
    expect(
      await run.database.hasPendingInitialCloudBackup(
        localAccountId: run.workspaceId,
      ),
      isFalse,
    );
  });

  // Scenario 8(b) — choosing Start Fresh instead of adoption leaves the
  // saved Guest completely untouched and opens a fresh Google workspace.
  testWidgets(
      'Start Fresh leaves the saved Guest untouched and opens a fresh '
      'Google workspace', (tester) async {
    final run = await _startAdoptionFlow(tester);

    await tester.tap(find.byKey(const Key('guest_workspace_start_fresh')));
    await tester.pumpAndSettle();

    expect(
      run.container.read(accountSessionManagerProvider).activeLocalAccountId,
      run.workspaceId,
    );
    // Guest is still a normal active workspace with its record intact.
    expect(
      (await run.store.getAccount(run.guestId))?.lifecycleState,
      AccountLifecycleState.active,
    );
    expect(
      (await run.database.qazaRecordsDao.getAll(userId: run.guestId))
          .map((record) => record.id),
      ['choice_guest_fajr_1'],
    );
    // The fresh Google workspace starts empty; nothing was adopted.
    expect(
      await run.database.qazaRecordsDao.getAll(userId: run.workspaceId),
      isEmpty,
    );
    expect(
      await _adoptionJournalCount(run.database, run.workspaceId),
      0,
    );
    // No adoption means no adoption backup is attempted on this path.
    expect(run.syncProvider.backupNowCalls, 0);
    expect(run.container.read(startupWorkspaceRestoreSatisfiedProvider), true);
    expect(tester.takeException(), isNull);
  });

  // Scenarios 18 + 23 — an abandoned empty Guest draft (left behind by an
  // earlier cancelled onboarding) is NOT listed in the chooser, because a
  // draft is listed only when it holds data; the Guest flow therefore goes
  // straight to Start Fresh, which resumes that same hidden draft instead
  // of creating a second empty workspace.
  //
  // Updated in the final coverage sweep: this test previously expected the
  // chooser dialog to list the empty draft and offer Start Fresh from it,
  // which was the pre-plan listing behaviour. The plan (Section 11,
  // scenario 18) lists a draft only when it holds data, so no dialog opens
  // when the only saved Guest is an empty draft.
  testWidgets(
      'an abandoned empty draft is hidden from the chooser and reused by '
      'Start Fresh', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final seedStore = AccountLocalStore(database: database);
    final abandonedDraftId = await seedStore.createGuestWorkspace(draft: true);
    final container = await _cloudContainer(
      database: database,
      accountProvider: _FakeCloudAccountProvider(
        signInResult: const CloudAccountSnapshot.disconnected(),
      ),
      syncProvider: _FakeCloudSyncProvider(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('cloud_setup_continue_local')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cloud_setup_continue_local')));

    // No chooser dialog ever opens: the only saved Guest is an empty
    // draft, which the listing hides, so the flow proceeds directly to
    // Start Fresh. The screen's working state keeps frames scheduled
    // forever, so pump in bounded steps until the flow completes instead
    // of using pumpAndSettle.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (container.read(startupWorkspaceRestoreSatisfiedProvider)) break;
    }
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    expect(
      container.read(accountSessionManagerProvider).activeLocalAccountId,
      abandonedDraftId,
    );
    final draftRows = await database
        .customSelect(
          "SELECT local_account_id FROM local_accounts "
          "WHERE lifecycle_state = 'draft'",
        )
        .get();
    expect(draftRows, hasLength(1));
    expect(
      draftRows.single.read<String>('local_account_id'),
      abandonedDraftId,
    );
    expect(container.read(startupWorkspaceRestoreSatisfiedProvider), true);
    expect(tester.takeException(), isNull);
  });

  // Scenario 8(c) — with no saved Guest workspace, a new Google sign-in
  // skips the chooser entirely and goes straight to Google setup.
  testWidgets(
      'new Google sign-in without a saved Guest goes straight to Google '
      'setup', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final syncProvider = _FakeCloudSyncProvider();
    final container = await _cloudContainer(
      database: database,
      accountProvider: _FakeCloudAccountProvider(
        signInResult: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Amina Google',
          email: 'amina@example.com',
        ),
      ),
      syncProvider: syncProvider,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    // No Guest chooser dialog ever appears.
    expect(find.byType(AlertDialog), findsNothing);
    const workspaceId = 'google_test-google-account-A';
    expect(
      container.read(accountSessionManagerProvider).activeLocalAccountId,
      workspaceId,
    );
    expect(syncProvider.discoverBackupCalls, 1);
    expect(syncProvider.backupNowCalls, 0);
    // The fresh Google workspace still owes its first backup.
    expect(
      await database.hasPendingInitialCloudBackup(
        localAccountId: workspaceId,
      ),
      isTrue,
    );
    expect(container.read(startupWorkspaceRestoreSatisfiedProvider), true);
    expect(tester.takeException(), isNull);
  });

  // Scenario 14 — tapping Connect Google repeatedly while a sign-in is
  // already in flight must not start a second sign-in flow: the screen's
  // working guard plus the disabled button keep it to exactly one, and the
  // final state is a single, consistent Google workspace.
  testWidgets(
      'repeated Connect Google taps during an in-flight sign-in run one '
      'sign-in flow', (tester) async {
    // A tall surface keeps every choice-screen control built while the
    // working card is visible (the body is a lazily built ListView).
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final accountProvider = _GatedCloudAccountProvider(
      signInResult: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: 'test-google-account-A',
        displayName: 'Amina Google',
        email: 'amina@example.com',
      ),
    );
    final syncProvider = _FakeCloudSyncProvider();
    final container = await _cloudContainer(
      database: database,
      accountProvider: accountProvider,
      syncProvider: syncProvider,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('cloud_setup_connect_google'));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    // The first sign-in is now parked inside the gated provider.
    expect(accountProvider.signInCalls, 1);

    // Further taps while the first attempt is still in flight.
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(accountProvider.signInCalls, 1);
    expect(tester.takeException(), isNull);

    accountProvider.gate.complete();
    await tester.pumpAndSettle();

    expect(accountProvider.signInCalls, 1);
    expect(syncProvider.discoverBackupCalls, 1);
    const workspaceId = 'google_test-google-account-A';
    expect(
      container.read(accountSessionManagerProvider).activeLocalAccountId,
      workspaceId,
    );
    // Exactly one Google workspace row was created.
    expect(
      (await _localAccountIds(database))
          .where((id) => id.startsWith('google_')),
      [workspaceId],
    );
    expect(tester.takeException(), isNull);
  });

  // Scenario 21 — Google identity is the stable account ID, never the
  // email or display name. Signing in again with the same stable ID but a
  // changed email and display name must reactivate the very same workspace
  // (with its data and the updated display name), not create a new one.
  testWidgets(
      'changed Google email and display name still activate the same '
      'workspace', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);
    final workspaceId = googleLocalWorkspaceId('stable-google-21');

    // First launch: sign in as "Original Name" <original@example.com>.
    final firstContainer = await _cloudContainer(
      database: database,
      accountProvider: _FakeCloudAccountProvider(
        signInResult: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'stable-google-21',
          displayName: 'Original Name',
          email: 'original@example.com',
        ),
      ),
      syncProvider: _FakeCloudSyncProvider(),
    );
    await tester.pumpWidget(_app(firstContainer));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );
    expect(
      firstContainer.read(accountSessionManagerProvider).activeLocalAccountId,
      workspaceId,
    );
    expect(
      (await store.getAccount(workspaceId))?.displayName,
      'Original Name',
    );
    // The user accumulates data in this workspace.
    await database.qazaRecordsDao.insertRecord(
      _recordFor(workspaceId, 'scenario21_record', DateTime(2025, 2, 2)),
    );
    final accountIdsBefore = await _localAccountIds(database);
    await tester.pumpWidget(const SizedBox());
    firstContainer.dispose();

    // Second launch: same stable Google ID, but the Google account now has
    // a different email address and display name.
    final secondContainer = await _cloudContainer(
      database: database,
      accountProvider: _FakeCloudAccountProvider(
        signInResult: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'stable-google-21',
          displayName: 'Renamed Person',
          email: 'renamed@example.org',
        ),
      ),
      syncProvider: _FakeCloudSyncProvider(),
    );
    addTearDown(secondContainer.dispose);
    await tester.pumpWidget(_app(secondContainer));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    // The same workspace activates — no new local account row of any kind.
    expect(
      secondContainer.read(accountSessionManagerProvider).activeLocalAccountId,
      workspaceId,
    );
    expect(await _localAccountIds(database), accountIdsBefore);
    // Its data is intact and the displayed name follows the Google profile.
    expect(
      (await database.qazaRecordsDao.getAll(userId: workspaceId))
          .map((record) => record.id),
      ['scenario21_record'],
    );
    expect(
      (await store.getAccount(workspaceId))?.displayName,
      'Renamed Person',
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeCloudAccountProvider implements CloudAccountProvider {
  _FakeCloudAccountProvider({required this.signInResult})
      : _snapshot = const CloudAccountSnapshot.disconnected();

  final CloudAccountSnapshot signInResult;
  CloudAccountSnapshot _snapshot;
  int signInCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async => _snapshot;

  @override
  Future<CloudAccountSnapshot> signIn() async {
    signInCalls++;
    _snapshot = signInResult;
    return _snapshot;
  }

  @override
  Future<List<RememberedCloudAccount>> rememberedAccounts() async =>
      const <RememberedCloudAccount>[];

  @override
  Future<CloudAccountSnapshot> signInWithRememberedAccount(
    String accountId,
  ) =>
      signIn();

  @override
  Future<void> disconnect() async {
    _snapshot = const CloudAccountSnapshot.disconnected();
  }
}

/// A sign-in that stays in flight until [gate] completes, so tests can tap
/// Connect Google again while the first attempt is still running.
class _GatedCloudAccountProvider implements CloudAccountProvider {
  _GatedCloudAccountProvider({required this.signInResult})
      : _snapshot = const CloudAccountSnapshot.disconnected();

  final CloudAccountSnapshot signInResult;
  final Completer<void> gate = Completer<void>();
  CloudAccountSnapshot _snapshot;
  int signInCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async => _snapshot;

  @override
  Future<CloudAccountSnapshot> signIn() async {
    signInCalls++;
    await gate.future;
    _snapshot = signInResult;
    return _snapshot;
  }

  @override
  Future<List<RememberedCloudAccount>> rememberedAccounts() async =>
      const <RememberedCloudAccount>[];

  @override
  Future<CloudAccountSnapshot> signInWithRememberedAccount(
    String accountId,
  ) =>
      signIn();

  @override
  Future<void> disconnect() async {
    _snapshot = const CloudAccountSnapshot.disconnected();
  }
}

class _FakeCloudSyncProvider implements CloudSyncProvider {
  int discoverBackupCalls = 0;
  int backupNowCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async {
    discoverBackupCalls++;
    return const CloudBackupDiscoverySnapshot.noBackup();
  }

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) async {
    backupNowCalls++;
    return const CloudSyncSnapshot(status: CloudSyncStatus.synced);
  }

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> setAutomaticBackupFrequency(
    CloudBackupFrequency frequency,
  ) async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
    CloudBackupProgressCallback? onProgress,
  }) async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.disconnected();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

QazaRecordsCompanion _recordFor(String userId, String id, DateTime date) =>
    QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr.name,
      originalDate: date,
      status: QazaStatus.pending.name,
      createdAt: date,
      updatedAt: date,
    );

/// Creates a saved Guest workspace (completed profile + one Qaza record)
/// and returns its workspace ID.
Future<String> _seedSavedGuest(AppDatabase database) async {
  final store = AccountLocalStore(database: database);
  final guestId = await store.createGuestWorkspace(displayName: 'Amina');
  await store.saveProfile(
    guestId,
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
  await database.qazaRecordsDao.insertRecord(
    _recordFor(guestId, 'choice_guest_fajr_1', DateTime(2025, 1, 1)),
  );
  return guestId;
}

Future<ProviderContainer> _cloudContainer({
  required AppDatabase database,
  required CloudAccountProvider accountProvider,
  required _FakeCloudSyncProvider syncProvider,
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      cloudAccountProvider.overrideWithValue(accountProvider),
      cloudSyncProvider.overrideWithValue(syncProvider),
      // Keep these flows independent of any platform account restore.
      cloudAccountStartupRestoreProvider.overrideWith(
        (ref) async => const CloudAccountSnapshot.unavailable(),
      ),
    ],
  );
  await container.read(accountSessionManagerProvider).initialize();
  return container;
}

class _AdoptionRun {
  const _AdoptionRun({
    required this.database,
    required this.store,
    required this.container,
    required this.syncProvider,
    required this.guestId,
    required this.workspaceId,
  });

  final AppDatabase database;
  final AccountLocalStore store;
  final ProviderContainer container;
  final _FakeCloudSyncProvider syncProvider;
  final String guestId;
  final String workspaceId;
}

/// Seeds a saved Guest, signs in with a brand-new Google account, and
/// stops with the Guest chooser dialog open for the test to drive.
Future<_AdoptionRun> _startAdoptionFlow(WidgetTester tester) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final store = AccountLocalStore(database: database);
  final guestId = await _seedSavedGuest(database);
  final syncProvider = _FakeCloudSyncProvider();
  final container = await _cloudContainer(
    database: database,
    accountProvider: _FakeCloudAccountProvider(
      signInResult: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: 'test-google-account-A',
        displayName: 'Amina Google',
        email: 'amina@example.com',
      ),
    ),
    syncProvider: syncProvider,
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(_app(container));
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const Key('cloud_setup_connect_google')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('cloud_setup_connect_google')));

  // The chooser opens while the screen is still in its working state,
  // whose indeterminate progress indicator keeps frames scheduled forever,
  // so pumpAndSettle can never return here. Pump in bounded steps until
  // the dialog appears instead.
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find
        .byKey(Key('guest_workspace_choice_$guestId'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
  }
  expect(
    find.byKey(Key('guest_workspace_choice_$guestId')),
    findsOneWidget,
  );
  return _AdoptionRun(
    database: database,
    store: store,
    container: container,
    syncProvider: syncProvider,
    guestId: guestId,
    workspaceId: googleLocalWorkspaceId('test-google-account-A'),
  );
}

Future<List<String>> _localAccountIds(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT local_account_id FROM local_accounts '
        'ORDER BY local_account_id',
      )
      .get();
  return rows.map((row) => row.read<String>('local_account_id')).toList();
}

Future<int> _adoptionJournalCount(
  AppDatabase database,
  String targetWorkspaceId,
) async {
  final rows = await database.customSelect(
    'SELECT COUNT(*) AS row_count FROM workspace_operation_journal '
    "WHERE operation_type = 'guest_adoption' "
    'AND target_local_account_id = ?',
    variables: [Variable.withString(targetWorkspaceId)],
  ).get();
  return rows.single.read<int>('row_count');
}

Future<int?> _adoptionBackupVerifiedAt(
  AppDatabase database,
  String targetWorkspaceId,
) async {
  final rows = await database.customSelect(
    'SELECT backup_verified_at FROM workspace_operation_journal '
    "WHERE operation_type = 'guest_adoption' "
    'AND target_local_account_id = ?',
    variables: [Variable.withString(targetWorkspaceId)],
  ).get();
  expect(rows, hasLength(1));
  return rows.single.readNullable<int>('backup_verified_at');
}
