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

class _FakeCloudAccountProvider extends UnsupportedCloudAccountProvider {
  _FakeCloudAccountProvider({required this.snapshot});

  CloudAccountSnapshot snapshot;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async => snapshot;

  @override
  Future<CloudAccountSnapshot> signIn() async => snapshot;

  @override
  Future<void> disconnect() async {
    snapshot = const CloudAccountSnapshot.disconnected();
  }
}

class _FakeCloudSyncProvider extends UnsupportedCloudSyncProvider {
  @override
  bool get isSupported => true;

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot(status: CloudSyncStatus.disconnected);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('account omits redundant device and progress intro cards',
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
    expect(find.byKey(const Key('account_google_profile_card')), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Your local progress remains on this device.'),
        findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Automatic backup'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('connected Google profile appears above Cloud Backup', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        displayName: 'A Test User',
        email: 'user@example.com',
        photoUrl: null,
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

    expect(find.text('A Test User'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.byKey(const Key('account_cloud_backup_card')), findsOneWidget);

    final profileY = tester
        .getTopLeft(find.byKey(const Key('account_google_profile_card')))
        .dy;
    final backupY = tester
        .getTopLeft(find.byKey(const Key('account_cloud_backup_card')))
        .dy;
    expect(profileY, lessThan(backupY));
    expect(find.text('Connect Google'), findsNothing);
  });

  testWidgets('connected profile safely falls back when Google fields are absent', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
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
  });

  testWidgets('profile updates to Guest after Google disconnection', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = await _createSession(database);
    final cloudAccount = _FakeCloudAccountProvider(
      snapshot: const CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        displayName: 'Connected User',
        email: 'connected@example.com',
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
    expect(find.text('Connected User'), findsOneWidget);
    expect(manager.activeAccount, isNotNull);

    await tester.tap(find.text('Disconnect account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect account').last);
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Connected User'), findsNothing);
    expect(manager.activeAccount, isNotNull);
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
}
