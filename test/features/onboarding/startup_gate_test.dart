import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/onboarding/account_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeIdentityProvider implements GoogleIdentityProvider {
  _FakeIdentityProvider({this.snapshot =
      const GoogleIdentitySnapshot.signedOut()});

  final GoogleIdentitySnapshot snapshot;

  @override
  bool get isSupported => true;

  @override
  Future<GoogleIdentitySnapshot> restore() async => snapshot;

  @override
  Future<GoogleIdentitySnapshot> signIn() async => snapshot;

  @override
  Future<void> signOut() async {}
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget did not appear: $finder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('offline startup reaches local onboarding without cloud services',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseManagerProvider.overrideWithValue(manager),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(
          const UnsupportedGoogleIdentityProvider(),
        ),
      ],
    );
    await session.initialize();
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StartupGate(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      find.byType(LanguageSelectionScreen),
    );

    expect(find.byType(AccountChoiceScreen), findsNothing);
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('identity-enabled startup uses local account choice only',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final manager = DatabaseManager(controlDatabase: database);
    final store = AccountLocalStore(
      database: database,
      databaseManager: manager,
    );
    final session = AccountSessionManager(accountStore: store);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        databaseManagerProvider.overrideWithValue(manager),
        accountLocalStoreProvider.overrideWithValue(store),
        accountSessionManagerProvider.overrideWith((ref) => session),
        googleIdentityProvider.overrideWithValue(_FakeIdentityProvider()),
      ],
    );
    await session.initialize();
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StartupGate(),
        ),
      ),
    );
    await _pumpUntil(tester, find.byType(AccountChoiceScreen));

    expect(find.byType(AccountChoiceScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
