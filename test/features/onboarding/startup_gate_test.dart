import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/onboarding/cloud_setup_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeCloudAccountProvider implements CloudAccountProvider {
  _FakeCloudAccountProvider({
    this.signInResult = const CloudAccountSnapshot(
      status: CloudAccountStatus.connected,
    ),
  });

  final CloudAccountSnapshot signInResult;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async =>
      const CloudAccountSnapshot.disconnected();

  @override
  Future<CloudAccountSnapshot> signIn() async => signInResult;

  @override
  Future<void> disconnect() async {}
}

class _FakeCloudSyncProvider implements CloudSyncProvider {
  _FakeCloudSyncProvider({
    this.discoveryResult = const CloudBackupDiscoverySnapshot.noBackup(),
  });

  final CloudBackupDiscoverySnapshot discoveryResult;
  int resolveConflictCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async =>
      discoveryResult;

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) async =>
      const CloudSyncSnapshot.disconnected();

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
  }) async {
    resolveConflictCalls++;
    return const CloudSyncSnapshot.disconnected();
  }

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.disconnected();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseLanguage(
  WidgetTester tester,
  String languageCode,
) async {
  await tester.tap(find.byKey(const Key('cloud_setup_language_selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('cloud_setup_language_$languageCode')));
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StartupGate(),
      ),
    ),
  );
}

Future<ProviderContainer> _container({
  required AppDatabase database,
  required bool cloudEnabled,
  CloudAccountSnapshot? signInResult,
  CloudBackupDiscoverySnapshot? discoveryResult,
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      if (cloudEnabled) ...[
        cloudAccountProvider.overrideWithValue(
          _FakeCloudAccountProvider(
            signInResult: signInResult ??
                const CloudAccountSnapshot(
                  status: CloudAccountStatus.connected,
                ),
          ),
        ),
        cloudSyncProvider.overrideWithValue(
          _FakeCloudSyncProvider(
            discoveryResult: discoveryResult ??
                const CloudBackupDiscoverySnapshot.noBackup(),
          ),
        ),
      ],
    ],
  );
  await container.read(accountSessionManagerProvider).initialize();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'cloud startup shows unified account choice before profile onboarding',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byType(CloudSetupChoiceScreen), findsOneWidget);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    expect(find.byKey(const Key('cloud_setup_connect_google')), findsOneWidget);
    expect(find.byKey(const Key('cloud_setup_continue_local')), findsOneWidget);

    await _chooseLanguage(tester, 'ur');
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleNotifier.storageKey), 'ur');
    expect(find.text('قضا نماز میں خوش آمدید'), findsOneWidget);

    await _chooseLanguage(tester, 'en');
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance())
          .getString(LocaleNotifier.storageKey),
      'en',
    );

    await _chooseLanguage(tester, 'ur');
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance())
          .getString(LocaleNotifier.storageKey),
      'ur',
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_continue_local')),
    );
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(CloudSetupChoiceScreen), findsNothing);
  });

  testWidgets(
      'Google sign-in with no backup opens onboarding in selected language',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await _chooseLanguage(tester, 'ur');
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    expect(find.byType(CloudSetupChoiceScreen), findsNothing);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('اپنا پروفائل مکمل کریں'), findsOneWidget);
    expect(await database.hasPendingInitialCloudBackup(), isTrue);
  });

  testWidgets('sign-in failure keeps local continuation available',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
      signInResult: const CloudAccountSnapshot(
        status: CloudAccountStatus.failed,
        message: 'simulated sign-in failure',
      ),
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    await _chooseLanguage(tester, 'ur');
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    expect(find.byType(CloudSetupChoiceScreen), findsOneWidget);
    expect(find.text('simulated sign-in failure'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance())
          .getString(LocaleNotifier.storageKey),
      'ur',
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_continue_local')),
    );
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(await database.isOnboardingCompleted(), isFalse);
  });

  testWidgets(
      'backup discovery failure is recoverable without forcing onboarding',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
      discoveryResult: const CloudBackupDiscoverySnapshot.failed(
        'simulated backup discovery failure',
      ),
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    expect(find.byType(CloudSetupChoiceScreen), findsOneWidget);
    expect(find.text('simulated backup discovery failure'), findsOneWidget);
    // Retry is conditionally appended at the end of the lazy ListView,
    // so it may not be built yet for ensureVisible to find it.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_continue_local')),
    );
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(await database.isOnboardingCompleted(), isFalse);
  });

  testWidgets('a discovered backup offers explicit restore before onboarding',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
      discoveryResult: CloudBackupDiscoverySnapshot.backupFound(
        CloudConflictInfo(
          localDeviceId: 'local-device',
          localTimestamp: DateTime.utc(2026, 10, 10),
          localRevision: 1,
          localBaseBackupId: null,
          remoteDeviceId: 'remote-device',
          remoteTimestamp: DateTime.utc(2026, 10, 9),
          remoteRevision: 7,
          remoteBackupId: 'backup-7',
          remoteBaseBackupId: null,
          lastSyncedBackupId: null,
          remoteVersion: '1',
        ),
      ),
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('cloud_setup_connect_google')),
    );

    expect(
      (container.read(cloudSyncProvider) as _FakeCloudSyncProvider)
          .resolveConflictCalls,
      1,
      reason: 'a verified fresh installation should attempt automatic restore',
    );
    expect(find.byType(CloudSetupChoiceScreen), findsOneWidget);
    expect(find.byKey(const Key('cloud_setup_restore_backup')), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
  });

  testWidgets(
      'existing installations with completed onboarding bypass first-run choice',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final accountStore = AccountLocalStore(database: database);
    await accountStore.ensureInitialized();
    await accountStore.saveProfileLocalOnly(
      UserProfile.localLedgerUserId,
      const UserProfile(onboardingCompleted: true),
    );
    final container = await _container(
      database: database,
      cloudEnabled: true,
    );
    expect(await database.isOnboardingCompleted(), isTrue);
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byType(CloudSetupChoiceScreen), findsNothing);
    expect(
      await database.isCloudSetupChoiceComplete(),
      isTrue,
    );
  });

  testWidgets(
      'welcome screen preserves logo proportions and shows Google G CTA',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: true,
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final logo = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/qaza_namaz_logo.png',
      ),
    );
    expect(logo.fit, BoxFit.contain);
    expect(logo.width, 88);
    expect(logo.height, 88);

    expect(find.text('Welcome to Qaza Namaz'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue on this device'), findsOneWidget);
    expect(
        find.byKey(const Key('cloud_setup_language_selector')), findsOneWidget);
    expect(find.byKey(const Key('google_g_mark')), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('offline startup retains standalone language selection',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = await _container(
      database: database,
      cloudEnabled: false,
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(CloudSetupChoiceScreen), findsNothing);
  });
}
