import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz/features/account/account_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeGoogleProvider implements GoogleIdentityProvider {
  @override
  bool get isSupported => false;
  @override
  Future<GoogleIdentitySnapshot> restore() async =>
      const GoogleIdentitySnapshot.unavailable();
  @override
  Future<GoogleIdentitySnapshot> signIn() async =>
      const GoogleIdentitySnapshot.unavailable();
  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account screen displays Supabase Cloud Sync card',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    final identity = _FakeGoogleProvider();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(identity),
      ],
    );
    addTearDown(() {
      container.dispose();
      database.close();
    });

    await store.ensureInitialized();
    await session.initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cloudCard = find.byKey(const Key('account_supabase_cloud_card'));
    expect(cloudCard, findsOneWidget);

    final connectButton = find.byKey(const Key('account_supabase_connect'));
    expect(connectButton, findsOneWidget);

    // Tap connect button to open SupabaseAuthDialog
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('supabase_auth_email_input')), findsOneWidget);
    expect(
        find.byKey(const Key('supabase_auth_password_input')), findsOneWidget);
    expect(
        find.byKey(const Key('supabase_auth_submit_button')), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('supabase_auth_email_input')), findsNothing);
  });
}
