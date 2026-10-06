import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_worker.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _UnavailableFirebaseServices extends FirebaseServices {
  @override
  bool get initialized => false;

  @override
  Future<bool> initialize() async => false;
}

class _FakeBackupWorker extends FirebaseBackupWorker {
  _FakeBackupWorker({
    required FirebaseServices firebase,
    required AccountLocalStore accountStore,
    required FirebaseBackupService backupService,
  }) : super(
          firebase: firebase,
          accountStore: accountStore,
          backupService: backupService,
        );

  int retryCalls = 0;

  @override
  Future<bool> retryNow({
    Future<void> Function(int processed, int total)? onProgress,
  }) async {
    retryCalls++;
    return true;
  }
}

class _EnglishLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');
}

Future<(AppDatabase, AccountSessionManager)> _createSession({
  required bool google,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  final store = AccountLocalStore(database: database);
  await store.ensureInitialized(
    hasLegacyProfile: false,
    hasLegacyQaza: false,
  );

  if (google) {
    final googleId = await store.createGooglePartition(
      firebaseUid: 'account-ui-user',
      email: 'account@example.com',
    );
    await store.activate(googleId);
  } else {
    await store.ensureGuestActive();
  }

  final firebase = _UnavailableFirebaseServices();
  final auth = GoogleFirebaseAuthService(firebase);
  final backup = FirebaseBackupService(
    firebase: firebase,
    database: database,
    accountStore: store,
  );
  final reconciliation = FirebaseReconciliationService(
    firebase: firebase,
    backupService: backup,
    accountStore: store,
    database: database,
  );
  final manager = AccountSessionManager(
    accountStore: store,
    firebase: firebase,
    auth: auth,
    backup: backup,
    reconciliation: reconciliation,
  );

  await manager.initialize();
  return (database, manager);
}

Widget _app(
  ProviderContainer container,
  Widget home, {
  Locale locale = const Locale('en'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

ProviderContainer _container(
  AccountSessionManager manager, {
  AppDatabase? database,
  AccountLocalStore? accountStore,
  FirebaseBackupWorker? backupWorker,
}) {
  return ProviderContainer(
    overrides: [
      accountSessionManagerProvider.overrideWith((ref) => manager),
      if (database != null)
        appDatabaseProvider.overrideWithValue(database),
      if (accountStore != null)
        accountLocalStoreProvider.overrideWithValue(accountStore),
      if (backupWorker != null)
        backupWorkerProvider.overrideWithValue(backupWorker),
      localeProvider.overrideWith(_EnglishLocaleNotifier.new),
      progressSummaryProvider.overrideWith(
        (ref) async => QazaProgressSummary.empty(),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Guest account settings expose only local backup CTA', (
    tester,
  ) async {
    final (database, manager) = await _createSession(google: false);
    final container = _container(manager, database: database);
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Guest account'), findsOneWidget);
    expect(find.text('Your data is stored on this device'), findsOneWidget);
    expect(find.text('Not connected to Google'), findsOneWidget);
    expect(find.text('Keep your progress safe'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Automatic backup'), findsNothing);
    expect(find.text('Backed up'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Disconnect Google'), findsNothing);
    expect(find.text('Delete cloud data'), findsNothing);
  });

  testWidgets('Google account settings separate backup and account actions', (
    tester,
  ) async {
    final (database, manager) = await _createSession(google: true);
    final container = _container(manager, database: database);
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('account@example.com'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Automatic backup'), findsOneWidget);
    expect(find.text('Cloud backup'), findsNothing);
    expect(
      find.text('Automatically back up your Qaza progress'),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Enable backup'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Disconnect Google'), findsNothing);
    expect(find.text('Danger zone'), findsNothing);
    expect(find.text('Delete cloud data'), findsNothing);
    expect(find.text('Keep your progress safe'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('Settings account row reflects the active account state', (
    tester,
  ) async {
    final (guestDatabase, guestManager) =
        await _createSession(google: false);
    final guestContainer = _container(guestManager, database: guestDatabase);

    await tester.pumpWidget(
      _app(guestContainer, const SettingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Guest • This device only'), findsOneWidget);
    expect(find.text('Connect Google'), findsNothing);

    // Unmount the guest tree before disposing its ProviderContainer so
    // Riverpod can finish any scheduled auto-dispose work cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    guestContainer.dispose();
    await guestDatabase.close();

    final (googleDatabase, googleManager) =
        await _createSession(google: true);
    final googleContainer = _container(googleManager, database: googleDatabase);
    addTearDown(googleContainer.dispose);
    addTearDown(googleDatabase.close);

    await tester.pumpWidget(
      _app(googleContainer, const SettingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Connect Google'), findsNothing);
  });

  testWidgets(
    'Google backup running state shows real determinate progress',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      final accountId = manager.activeAccount!.localAccountId;
      await store.setBackupState(accountId, 'running');

      final container = _container(
        manager,
        database: database,
        accountStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await store.setBackupProgress(accountId, 68, 100);
      await tester.pump();

      expect(find.text('Backing up your progress…'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Google backup displays zero and 99 percent without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      final accountId = manager.activeAccount!.localAccountId;
      await store.setBackupState(accountId, 'running');

      final container = _container(
        manager,
        database: database,
        accountStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      for (final processed in [0, 99]) {
        await store.setBackupProgress(accountId, processed, 100);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('$processed%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    '100 percent transitions to the completed backup state',
    (tester) async {
      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      final accountId = manager.activeAccount!.localAccountId;
      await store.setBackupState(accountId, 'running');
      await store.setBackupProgress(accountId, 100, 100);

      final container = _container(
        manager,
        database: database,
        accountStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('100%'), findsOneWidget);

      final acknowledged = await store.acknowledgeBackup(
        localAccountId: accountId,
        revision: 0,
        generation: 1,
        completedAt: DateTime(2026, 10, 6, 21, 42),
      );
      expect(acknowledged, isTrue);

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Backup complete'), findsOneWidget);
      expect(find.text('Today, 9:42 PM'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
    },
  );

  testWidgets(
    'failed backup shows safe message and Try again triggers the existing worker',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      final accountId = manager.activeAccount!.localAccountId;
      await store.setBackupState(accountId, 'failed');

      final firebase = _UnavailableFirebaseServices();
      final backup = FirebaseBackupService(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final worker = _FakeBackupWorker(
        firebase: firebase,
        accountStore: store,
        backupService: backup,
      );
      final container = _container(
        manager,
        database: database,
        accountStore: store,
        backupWorker: worker,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("Backup couldn't complete"), findsOneWidget);
      expect(
        find.text('Your Qaza data is safe on this device.'),
        findsOneWidget,
      );
      expect(
        find.text('Your Qaza data is safe on this device.'),
        findsAtLeastNWidgets(1),
      );
      expect(find.byKey(const Key('account_backup_try_again')), findsOneWidget);

      await tester.tap(find.byKey(const Key('account_backup_try_again')));
      await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

      expect(worker.retryCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'waiting and disabled backup states have no progress indicator',
    (tester) async {
      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      final accountId = manager.activeAccount!.localAccountId;

      final container = _container(
        manager,
        database: database,
        accountStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await store.setBackupState(accountId, 'waitingForConnection');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(find.text('Your Qaza data is safe on this device.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await store.setBackupEnabled(accountId, false);
      await store.setBackupState(accountId, 'disabled');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Automatic backup is off'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'Urdu backup failure wraps cleanly in RTL',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (database, manager) = await _createSession(google: true);
      final store = AccountLocalStore(database: database);
      await store.setBackupState(
        manager.activeAccount!.localAccountId,
        'failed',
      );

      final container = _container(
        manager,
        database: database,
        accountStore: store,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(
        _app(
          container,
          const AccountScreen(),
          locale: const Locale('ur'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('بیک اپ مکمل نہیں ہو سکا'), findsOneWidget);
      expect(find.text('دوبارہ کوشش کریں'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
