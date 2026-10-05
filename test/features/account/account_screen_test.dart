import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
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

Widget _app(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

ProviderContainer _container(AccountSessionManager manager) {
  return ProviderContainer(
    overrides: [
      accountSessionManagerProvider.overrideWith((ref) => manager),
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
    final container = _container(manager);
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Guest account'), findsOneWidget);
    expect(find.text('Your data is stored on this device'), findsOneWidget);
    expect(find.text('Not connected to Google'), findsOneWidget);
    expect(find.text('Keep your progress safe'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Cloud backup'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Disconnect Google'), findsNothing);
    expect(find.text('Delete cloud data'), findsNothing);
  });

  testWidgets('Google account settings separate backup and account actions', (
    tester,
  ) async {
    final (database, manager) = await _createSession(google: true);
    final container = _container(manager);
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(_app(container, const AccountScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('account@example.com'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Cloud backup'), findsOneWidget);
    expect(
      find.text('Automatically back up your Qaza progress'),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Enable backup'), findsNothing);
    expect(find.text('Account actions'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Disconnect Google'), findsOneWidget);
    expect(find.text('Danger zone'), findsOneWidget);
    expect(find.text('Delete cloud data'), findsOneWidget);
    expect(find.text('Keep your progress safe'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('Settings account row reflects the active account state', (
    tester,
  ) async {
    final (guestDatabase, guestManager) =
        await _createSession(google: false);
    final guestContainer = _container(guestManager);

    await tester.pumpWidget(
      _app(guestContainer, const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest • This device only'), findsOneWidget);
    expect(find.text('Connect Google'), findsNothing);

    guestContainer.dispose();
    await guestDatabase.close();

    final (googleDatabase, googleManager) =
        await _createSession(google: true);
    final googleContainer = _container(googleManager);
    addTearDown(googleContainer.dispose);
    addTearDown(googleDatabase.close);

    await tester.pumpWidget(
      _app(googleContainer, const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Connect Google'), findsNothing);
  });
}
