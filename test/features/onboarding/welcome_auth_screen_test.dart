import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/onboarding/welcome_auth_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestScreen(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          final themeMode = ref.watch(themeModeProvider);
          return MaterialApp(
            locale: locale,
            themeMode: themeMode.materialMode,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WelcomeAuthScreen(),
          );
        },
      ),
    );
  }

  testWidgets('WelcomeAuthScreen renders all actions, language and theme buttons',
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
      ],
    );
    await session.initialize();
    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(buildTestScreen(container));
    await tester.pumpAndSettle();

    // Verify main components are present
    expect(find.byKey(const Key('welcome_continue_google')), findsOneWidget);
    expect(find.byKey(const Key('welcome_continue_email')), findsOneWidget);
    expect(find.byKey(const Key('welcome_continue_guest')), findsOneWidget);
    expect(find.byKey(const Key('welcome_theme_toggle_button')), findsOneWidget);
    expect(find.byKey(const Key('welcome_language_selector')), findsOneWidget);

    // Verify Theme toggle updates global themeModeProvider
    final initialTheme = container.read(themeModeProvider);
    await tester.tap(find.byKey(const Key('welcome_theme_toggle_button')));
    await tester.pumpAndSettle();

    final toggledTheme = container.read(themeModeProvider);
    expect(toggledTheme, isNot(equals(initialTheme)));

    // Verify Continue as Guest marks account choice complete
    expect(await database.isAccountChoiceComplete(), isFalse);
    await tester.tap(find.byKey(const Key('welcome_continue_guest')));
    await tester.pumpAndSettle();

    expect(await database.isAccountChoiceComplete(), isTrue);
  });

  testWidgets(
      'WelcomeAuthScreen with existing guest profiles presents selection sheet',
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
      ],
    );
    await session.initialize();
    final guest1 = await store.createGuestWorkspace(displayName: 'Ahmed Guest');
    await store.createGuestWorkspace(displayName: 'Bilal Guest');

    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(buildTestScreen(container));
    await tester.pumpAndSettle();

    // Tap Continue as Guest
    await tester.tap(find.byKey(const Key('welcome_continue_guest')));
    await tester.pumpAndSettle();

    // Sheet should be visible with both guests
    expect(find.text('Ahmed Guest'), findsOneWidget);
    expect(find.text('Bilal Guest'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Tap on Ahmed Guest
    await tester.tap(find.text('Ahmed Guest'));
    await tester.pumpAndSettle();

    expect(await database.isAccountChoiceComplete(), isTrue);
    expect(session.activeLocalAccountId, guest1);
  });

  testWidgets(
      'WelcomeAuthScreen with existing guest profiles can choose to create fresh profile',
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
      ],
    );
    await session.initialize();
    final guest1 =
        await store.createGuestWorkspace(displayName: 'Existing Guest');

    addTearDown(container.dispose);
    addTearDown(manager.close);
    addTearDown(database.close);

    await tester.pumpWidget(buildTestScreen(container));
    await tester.pumpAndSettle();

    // Tap Continue as Guest
    await tester.tap(find.byKey(const Key('welcome_continue_guest')));
    await tester.pumpAndSettle();

    expect(find.text('Existing Guest'), findsOneWidget);

    // Tap Create New Profile button
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(await database.isAccountChoiceComplete(), isTrue);
    expect(session.activeLocalAccountId, isNot(equals(guest1)));
  });
}
