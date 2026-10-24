import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/data_management/qaza_data_management_screen.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

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

Future<AccountSessionManager> _createSession(AppDatabase database) async {
  final store = AccountLocalStore(database: database);
  final manager = AccountSessionManager(accountStore: store);
  await manager.initialize();
  return manager;
}

Widget _app(
  ProviderContainer container,
  Widget home, {
  Locale? locale,
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

class _FakeCloudAccountProvider extends UnsupportedCloudAccountProvider {
  _FakeCloudAccountProvider({required this.snapshot});

  CloudAccountSnapshot snapshot;
  int signInCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async => snapshot;

  @override
  Future<CloudAccountSnapshot> signIn() async {
    signInCalls++;
    return snapshot;
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
  _FakeCloudSyncProvider({
    this.snapshot = const CloudSyncSnapshot(
      status: CloudSyncStatus.disconnected,
    ),
    this.discoverySnapshot = const CloudBackupDiscoverySnapshot.unavailable(),
    this.backupResult,
  });

  CloudSyncSnapshot snapshot;
  CloudBackupDiscoverySnapshot discoverySnapshot;
  int discoveryCalls = 0;
  Completer<CloudSyncSnapshot>? statusCompleter;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async {
    discoveryCalls++;
    return discoverySnapshot;
  }

  Completer<CloudSyncSnapshot>? backupCompleter;
  Completer<CloudSyncSnapshot>? settingsCompleter;
  Completer<CloudSyncSnapshot>? frequencyCompleter;
  CloudSyncSnapshot? backupResult;
  Object? backupError;
  bool emitBackupProgress = true;
  int backupCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudSyncSnapshot> status() {
    return statusCompleter?.future ??
        Future<CloudSyncSnapshot>.value(snapshot);
  }

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) {
    backupCalls++;
    if (emitBackupProgress) {
      onProgress?.call(const CloudBackupProgress.preparing());
      onProgress?.call(
        const CloudBackupProgress.uploading(sentBytes: 1, totalBytes: 2),
      );
    }
    final error = backupError;
    if (error != null) return Future<CloudSyncSnapshot>.error(error);
    return backupCompleter?.future ??
        Future<CloudSyncSnapshot>.value(backupResult ?? snapshot);
  }

  CloudSyncSnapshot _withSettings({
    bool? automaticSyncEnabled,
    CloudBackupFrequency? backupFrequency,
  }) =>
      CloudSyncSnapshot(
        status: snapshot.status,
        automaticSyncEnabled:
            automaticSyncEnabled ?? snapshot.automaticSyncEnabled,
        backupFrequency: backupFrequency ?? snapshot.backupFrequency,
        lastSuccessAt: snapshot.lastSuccessAt,
        message: snapshot.message,
        conflict: snapshot.conflict,
        hasLocalRecoverySnapshot: snapshot.hasLocalRecoverySnapshot,
        restoredRemoteBackup: snapshot.restoredRemoteBackup,
        backupAlreadyUpToDate: snapshot.backupAlreadyUpToDate,
        hasPendingChanges: snapshot.hasPendingChanges,
      );

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async {
    snapshot = _withSettings(automaticSyncEnabled: enabled);
    final pending = settingsCompleter;
    if (pending != null) snapshot = await pending.future;
    return snapshot;
  }

  @override
  Future<CloudSyncSnapshot> setAutomaticBackupFrequency(
    CloudBackupFrequency frequency,
  ) async {
    snapshot = _withSettings(backupFrequency: frequency);
    final pending = frequencyCompleter;
    if (pending != null) snapshot = await pending.future;
    return snapshot;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'account omits redundant device and progress intro cards',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pump();

      expect(find.text('This device'), findsNothing);
      expect(find.text('Your data is stored on this device'), findsNothing);
      expect(find.text('Keep your progress safe'), findsNothing);
      expect(
        find.byKey(const Key('account_google_profile_card')),
        findsOneWidget,
      );
      expect(find.text('Guest'), findsOneWidget);
      expect(
        find.text('Your local progress remains on this device.'),
        findsOneWidget,
      );
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Automatic backup'), findsNothing);
      expect(
        find.byKey(const Key('account_guest_sign_out')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'connected Google profile appears above Cloud Backup',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
          email: 'user@example.com',
          photoUrl: 'https://example.invalid/profile.png',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith(
            (ref) => _FakeCloudSyncProvider(
              snapshot: const CloudSyncSnapshot(
                status: CloudSyncStatus.idle,
                automaticSyncEnabled: true,
              ),
            ),
          ),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text('A Test User'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('Signed in with Google'), findsOneWidget);
      final avatarImage = tester.widget<Image>(find.byType(Image));
      expect(avatarImage.image, isA<NetworkImage>());
      expect(
        (avatarImage.image as NetworkImage).url,
        'https://example.invalid/profile.png',
      );
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(
        find.byKey(const Key('account_cloud_backup_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account_cloud_backup_frequency')),
        findsOneWidget,
      );
      expect(find.text('Automatic backup'), findsOneWidget);
      expect(find.text('Daily'), findsWidgets);

      final profileY = tester
          .getTopLeft(find.byKey(const Key('account_google_profile_card')))
          .dy;
      final backupY = tester
          .getTopLeft(find.byKey(const Key('account_cloud_backup_card')))
          .dy;
      expect(profileY, lessThan(backupY));
      expect(find.text('Sign in with Google'), findsNothing);
    },
  );

  testWidgets(
    'auto-connect waits for account restore before invoking native sign-in',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot.disconnected(),
      );
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith(
            (ref) => _FakeCloudSyncProvider(),
          ),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(
        _app(container, const AccountScreen(autoConnect: true)),
      );
      await tester.pumpAndSettle();

      expect(cloudAccount.signInCalls, 1);
      expect(
        find.byKey(const Key('continue_with_new_google_account')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'automatic backup hides the frequency selector and preserves its choice',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          automaticSyncEnabled: false,
          backupFrequency: CloudBackupFrequency.weekly,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_cloud_backup_frequency')),
          findsNothing);

      await tester.tap(find.byKey(const Key('account_daily_cloud_backup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_cloud_backup_frequency')),
          findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account_daily_cloud_backup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_cloud_backup_frequency')),
          findsNothing);
      expect(cloudSync.snapshot.backupFrequency, CloudBackupFrequency.weekly);

      await tester.tap(find.byKey(const Key('account_daily_cloud_backup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_cloud_backup_frequency')),
          findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
    },
  );

  testWidgets(
      'monthly frequency label is localized in English, Urdu and Arabic',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: 'test-google-account-A',
        displayName: 'A Test User',
      ),
    );
    final cloudSync = _FakeCloudSyncProvider(
      snapshot: const CloudSyncSnapshot(
        status: CloudSyncStatus.idle,
        automaticSyncEnabled: true,
        backupFrequency: CloudBackupFrequency.monthly,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        cloudAccountProvider.overrideWith((ref) => cloudAccount),
        cloudSyncProvider.overrideWith((ref) => cloudSync),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Monthly (every 30 days)'), findsNothing);
    expect(cloudSync.snapshot.backupFrequency, CloudBackupFrequency.monthly);

    await tester.pumpWidget(
      _app(container, const AccountScreen(), locale: const Locale('ur')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ماہانہ'), findsOneWidget);
    expect(find.text('ماہانہ (ہر 30 دن)'), findsNothing);

    await tester.pumpWidget(
      _app(container, const AccountScreen(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('شهريًا'), findsOneWidget);
    expect(find.text('وتيرة النسخ الاحتياطي'), findsOneWidget);
    expect(find.text('Monthly'), findsNothing);
  });

  testWidgets('backup progress clears after success and failure',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: 'test-google-account-A',
        displayName: 'A Test User',
      ),
    );
    final cloudSync = _FakeCloudSyncProvider(
      snapshot: const CloudSyncSnapshot(status: CloudSyncStatus.idle),
    )..backupCompleter = Completer<CloudSyncSnapshot>();
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        cloudAccountProvider.overrideWith((ref) => cloudAccount),
        cloudSyncProvider.overrideWith((ref) => cloudSync),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back up now'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    cloudSync.backupCompleter!.complete(
      const CloudSyncSnapshot(status: CloudSyncStatus.synced),
    );
    cloudSync.backupCompleter = null;
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Cloud backup/sync completed.'), findsOneWidget);

    cloudSync.backupCompleter = Completer<CloudSyncSnapshot>();
    await tester.tap(find.text('Back up now'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    cloudSync.backupCompleter!.complete(
      const CloudSyncSnapshot(
        status: CloudSyncStatus.failed,
        message: 'Backup failed.',
      ),
    );
    cloudSync.backupCompleter = null;
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Backup failed.'), findsOneWidget);
    expect(find.text('Cloud backup/sync completed.'), findsNothing);
  });

  testWidgets(
    'backup progress clears when the provider throws',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(status: CloudSyncStatus.idle),
      )..backupError = StateError('Synthetic backup exception');
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Synthetic backup exception'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
    },
  );

  testWidgets(
    'Backup Now shows checking feedback immediately while remote check is pending',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(status: CloudSyncStatus.idle),
      )
        ..emitBackupProgress = false
        ..backupCompleter = Completer<CloudSyncSnapshot>();
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back up now'));
      await tester.pump();

      expect(find.text('Checking backup…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      cloudSync.backupCompleter!.complete(
        const CloudSyncSnapshot(status: CloudSyncStatus.synced),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checking backup…'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'automatic-backup setting updates do not show Backup Now loading visuals',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          automaticSyncEnabled: true,
        ),
      )..settingsCompleter = Completer<CloudSyncSnapshot>();
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account_daily_cloud_backup')));
      await tester.pump();

      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Working…'), findsNothing);
      expect(find.byIcon(Icons.backup_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      cloudSync.settingsCompleter!.complete(
        const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          automaticSyncEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.byIcon(Icons.backup_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'frequency update does not show Backup Now loading visuals',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'A Test User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          automaticSyncEnabled: true,
          backupFrequency: CloudBackupFrequency.daily,
        ),
      )..frequencyCompleter = Completer<CloudSyncSnapshot>();
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      final frequency = find.byKey(const Key('account_cloud_backup_frequency'));
      expect(frequency, findsOneWidget);
      await tester.tap(frequency);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pump();

      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Working…'), findsNothing);
      expect(find.byIcon(Icons.backup_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      cloudSync.frequencyCompleter!.complete(
        const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          automaticSyncEnabled: true,
          backupFrequency: CloudBackupFrequency.weekly,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.byIcon(Icons.backup_rounded), findsOneWidget);
    },
  );

  testWidgets('safe no-op backup shows the already-up-to-date message',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        accountId: 'test-google-account-A',
        displayName: 'A Test User',
      ),
    );
    final cloudSync = _FakeCloudSyncProvider(
      snapshot: const CloudSyncSnapshot(status: CloudSyncStatus.idle),
    )
      ..emitBackupProgress = false
      ..backupResult = const CloudSyncSnapshot(
        status: CloudSyncStatus.synced,
        backupAlreadyUpToDate: true,
      );
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        cloudAccountProvider.overrideWith((ref) => cloudAccount),
        cloudSyncProvider.overrideWith((ref) => cloudSync),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back up now'));
    await tester.pumpAndSettle();

    expect(cloudSync.backupCalls, 1);
    expect(find.text('Backup is already up to date.'), findsOneWidget);
    expect(find.text('Cloud backup/sync completed.'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'connected profile safely falls back when Google fields are absent',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: ' ',
          email: ' ',
          photoUrl: 'not-a-valid-url',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => _FakeCloudSyncProvider()),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Signed in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'sign out preserves local session and returns to account choice',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Connected User',
          email: 'connected@example.com',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => database),
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => _FakeCloudSyncProvider()),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Connected User'), findsOneWidget);
      expect(manager.activeAccount, isNotNull);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Connected User'), findsNothing);
      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(manager.activeAccount, isNotNull);
      expect(await database.hasReturningAccountChoicePending(), isTrue);
    },
  );

  testWidgets(
    'sign out shows a visible progress state while checking backup status',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Connected User',
          email: 'connected@example.com',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          hasPendingChanges: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => database),
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();

      final statusGate = Completer<CloudSyncSnapshot>();
      cloudSync.statusCompleter = statusGate;
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('account_cloud_operation_progress')),
        findsOneWidget,
      );
      expect(find.text('Checking backup…'), findsOneWidget);
      expect(find.text('Welcome to Qaza Namaz'), findsNothing);

      statusGate.complete(
        const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          hasPendingChanges: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(cloudAccount.snapshot.isConnected, isFalse);
      expect(await database.hasReturningAccountChoicePending(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline sign-out cancellation preserves the connected session and local Qaza',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final workspaceId = manager.activeLocalAccountId!;
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: '${workspaceId}_offline_signout_fajr',
          userId: workspaceId,
          prayerType: 'fajr',
          originalDate: DateTime(2026, 10, 1),
          status: 'pending',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Connected User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.failed,
          hasPendingChanges: true,
        ),
        discoverySnapshot: const CloudBackupDiscoverySnapshot.failed(
          'offline',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => database),
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      // The in-flight progress indicator is indeterminate; wait for the
      // expected safety dialog instead of waiting for all animations to stop.
      await _pumpUntilVisible(tester, find.text('Changes not backed up'));

      expect(find.text('Changes not backed up'), findsOneWidget);
      expect(find.text('Sign Out Anyway'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cloudAccount.snapshot.isConnected, isTrue);
      expect(manager.activeLocalAccountId, workspaceId);
      expect(
        (await database.qazaRecordsDao.getAll(userId: workspaceId))
            .map((record) => record.id),
        ['${workspaceId}_offline_signout_fajr'],
      );
      expect(cloudSync.backupCalls, 0);
    },
  );

  testWidgets(
    'offline sign-out anyway disconnects but keeps local Qaza records',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final workspaceId = manager.activeLocalAccountId!;
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: '${workspaceId}_offline_signout_fajr',
          userId: workspaceId,
          prayerType: 'fajr',
          originalDate: DateTime(2026, 10, 1),
          status: 'pending',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Connected User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.failed,
          hasPendingChanges: true,
        ),
        discoverySnapshot: const CloudBackupDiscoverySnapshot.failed(
          'offline',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => database),
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      // The in-flight progress indicator is indeterminate; wait for the
      // expected safety dialog instead of waiting for all animations to stop.
      await _pumpUntilVisible(tester, find.text('Changes not backed up'));
      await tester.tap(find.text('Sign Out Anyway'));
      await tester.pumpAndSettle();

      expect(cloudAccount.snapshot.isConnected, isFalse);
      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(
        (await database.qazaRecordsDao.getAll(userId: workspaceId))
            .map((record) => record.id),
        ['${workspaceId}_offline_signout_fajr'],
      );
      expect(await database.hasReturningAccountChoicePending(), isTrue);
    },
  );

  testWidgets(
    'reachable Drive backs up pending changes before sign-out',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final workspaceId = manager.activeLocalAccountId!;
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: '${workspaceId}_online_signout_fajr',
          userId: workspaceId,
          prayerType: 'fajr',
          originalDate: DateTime(2026, 10, 1),
          status: 'pending',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-A',
          displayName: 'Connected User',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
          hasPendingChanges: true,
        ),
        discoverySnapshot: const CloudBackupDiscoverySnapshot.noBackup(),
        backupResult: const CloudSyncSnapshot(
          status: CloudSyncStatus.synced,
          hasPendingChanges: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => database),
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith((ref) => cloudSync),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(cloudSync.discoveryCalls, 1);
      expect(cloudSync.backupCalls, 1);
      expect(cloudAccount.snapshot.isConnected, isFalse);
      expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
      expect(
        (await database.qazaRecordsDao.getAll(userId: workspaceId))
            .map((record) => record.id),
        ['${workspaceId}_online_signout_fajr'],
      );
    },
  );

  testWidgets('guest profile supports Urdu RTL layout', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(
      _app(container, const AccountScreen(), locale: const Locale('ur')),
    );
    await tester.pumpAndSettle();

    expect(find.text('مہمان'), findsOneWidget);
    expect(
      find.text('آپ کی مقامی پیش رفت اسی ڈیوائس پر محفوظ رہتی ہے۔'),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('account_google_profile_card'))),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('Account owns data management and reset actions', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_data_management')), findsOneWidget);
    expect(find.byKey(const Key('account_reset_qaza_counter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account_data_management')));
    await tester.pumpAndSettle();

    expect(find.byType(QazaDataManagementScreen), findsOneWidget);
  });

  testWidgets('settings account entry remains local-only', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final container = ProviderContainer(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        progressSummaryProvider.overrideWith(
          (ref) async => QazaProgressSummary.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const SettingsScreen()));
    await tester.pump();

    expect(find.text('Local • This device only'), findsOneWidget);
    expect(find.text('Signed in with Google'), findsNothing);
    expect(find.text('Connect Google'), findsNothing);
    expect(find.byKey(const Key('account_data_management')), findsNothing);
    expect(find.byKey(const Key('account_reset_qaza_counter')), findsNothing);
  });
  testWidgets(
    'cached Google identity is shown as reconnect required without signing in',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot.reconnectRequired(
          displayName: 'Saved User',
          email: 'saved@example.com',
          photoUrl: 'https://example.invalid/saved.png',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          cloudAccountProvider.overrideWith((ref) => cloudAccount),
          cloudSyncProvider.overrideWith(
            (ref) => _FakeCloudSyncProvider(
              snapshot: const CloudSyncSnapshot(
                status: CloudSyncStatus.reconnectRequired,
                automaticSyncEnabled: true,
              ),
            ),
          ),
          progressSummaryProvider.overrideWith(
            (ref) async => QazaProgressSummary.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Saved User'), findsOneWidget);
      expect(find.text('saved@example.com'), findsOneWidget);
      expect(find.text('Signed in with Google'), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byKey(const Key('account_daily_cloud_backup')), findsNothing);
    },
  );
  testWidgets(
    'connection discovery failure restores the prior Guest workspace',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final manager = await _createSession(database);
      final priorGuestId = manager.activeLocalAccountId!;
      expect(priorGuestId, startsWith('guest_'));
      final cloudAccount = _FakeCloudAccountProvider(
        snapshot: const CloudAccountSnapshot(
          status: CloudAccountStatus.connected,
          accountId: 'test-google-account-recovery',
          displayName: 'Recovery Test',
          email: 'recovery@example.com',
        ),
      );
      final cloudSync = _FakeCloudSyncProvider(
        snapshot: const CloudSyncSnapshot(
          status: CloudSyncStatus.idle,
        ),
      );
      final container = ProviderContainer(
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
      addTearDown(container.dispose);
      addTearDown(database.close);

      expect(manager.activeLocalAccountId, priorGuestId);

      await tester.pumpWidget(
        _app(container, const AccountScreen(autoConnect: true)),
      );
      await tester.pumpAndSettle();

      expect(manager.activeLocalAccountId, priorGuestId);
      expect(await database.hasPendingInitialCloudBackup(), isFalse);
      expect(find.text('Account'), findsOneWidget);
    },
  );
}
