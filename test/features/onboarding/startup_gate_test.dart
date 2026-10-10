import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/features/onboarding/cloud_setup_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeCloudAccountProvider implements CloudAccountProvider {
  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async =>
      const CloudAccountSnapshot.disconnected();

  @override
  Future<CloudAccountSnapshot> signIn() async =>
      const CloudAccountSnapshot(status: CloudAccountStatus.connected);

  @override
  Future<void> disconnect() async {}
}

class _FakeCloudSyncProvider implements CloudSyncProvider {
  @override
  bool get isSupported => true;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup() async =>
      const CloudBackupDiscoverySnapshot.noBackup();

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> backupNow() async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.disconnected();

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.disconnected();
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
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      if (cloudEnabled) ...[
        cloudAccountProvider.overrideWithValue(_FakeCloudAccountProvider()),
        cloudSyncProvider.overrideWithValue(_FakeCloudSyncProvider()),
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

    await tester.tap(find.byKey(const Key('cloud_setup_language_ur')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleNotifier.storageKey), 'ur');
    expect(find.text('اپنی پیش رفت محفوظ رکھیں'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cloud_setup_continue_local')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(CloudSetupChoiceScreen), findsNothing);
  });

  testWidgets(
      'existing installations with completed onboarding bypass first-run choice',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    await database.setOnboardingCompletedInTransaction(true);
    final container = await _container(
      database: database,
      cloudEnabled: true,
    );
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
