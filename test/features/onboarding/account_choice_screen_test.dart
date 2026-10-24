import 'dart:io';

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
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  _FakeGoogleIdentityProvider({
    this.restoreResult = const GoogleIdentitySnapshot.signedOut(),
    this.signInResult = const GoogleIdentitySnapshot.signedOut(),
  });

  final GoogleIdentitySnapshot restoreResult;
  final GoogleIdentitySnapshot signInResult;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<GoogleIdentitySnapshot> restore() async => restoreResult;

  @override
  Future<GoogleIdentitySnapshot> signIn() async {
    signInCalls++;
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _Harness {
  _Harness({
    required this.database,
    required this.manager,
    required this.store,
    required this.session,
    required this.container,
    required this.identity,
    required this.tempDirectory,
  });

  final AppDatabase database;
  final DatabaseManager manager;
  final AccountLocalStore store;
  final AccountSessionManager session;
  final ProviderContainer container;
  final _FakeGoogleIdentityProvider identity;
  final Directory tempDirectory;

  Future<void> dispose() async {
    container.dispose();
    await manager.close();
    await database.close();
    await tempDirectory.delete(recursive: true);
  }
}

Future<_Harness> _createHarness({
  GoogleIdentitySnapshot restoreResult =
      const GoogleIdentitySnapshot.signedOut(),
  GoogleIdentitySnapshot signInResult =
      const GoogleIdentitySnapshot.signedOut(),
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp('qaza-id-test-');
  final database = AppDatabase(
    NativeDatabase(File('${tempDirectory.path}/control.sqlite')),
  );
  final manager = DatabaseManager(
    controlDatabase: database,
    documentsDirectoryProvider: () async => tempDirectory,
    googleDatabaseFactory: ({
      required String fileName,
      required String workspaceId,
    }) =>
        GoogleWorkspaceDatabase.forTesting(
      executor: NativeDatabase(File('${tempDirectory.path}/$fileName')),
      workspaceId: workspaceId,
    ),
    freeSpaceBytesProvider: (_) async => 1024 * 1024 * 1024,
  );
  await database.readDbRevision();
  final store = AccountLocalStore(
    database: database,
    databaseManager: manager,
  );
  final session = AccountSessionManager(accountStore: store);
  final identity = _FakeGoogleIdentityProvider(
    restoreResult: restoreResult,
    signInResult: signInResult,
  );
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      databaseManagerProvider.overrideWithValue(manager),
      accountLocalStoreProvider.overrideWithValue(store),
      accountSessionManagerProvider.overrideWith((ref) => session),
      googleIdentityProvider.overrideWithValue(identity),
    ],
  );
  await session.initialize();
  return _Harness(
    database: database,
    manager: manager,
    store: store,
    session: session,
    container: container,
    identity: identity,
    tempDirectory: tempDirectory,
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        return MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountChoiceScreen(),
        );
      },
    ),
  );
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget did not appear: $finder');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Google sign-in creates or resumes a local Google workspace',
      (tester) async {
    final harness = await _createHarness(
      signInResult: const GoogleIdentitySnapshot.signedIn(
        accountId: 'google-account-42',
        displayName: 'Test User',
        email: 'test@example.com',
      ),
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(_app(harness.container));
    await _pumpUntil(tester,
        find.byKey(const Key('account_choice_google_login')));
    await tester.tap(find.byKey(const Key('account_choice_google_login')));
    await tester.pumpAndSettle();

    expect(harness.identity.signInCalls, 1);
    expect(
      harness.session.activeLocalAccountId,
      googleLocalWorkspaceId('google-account-42'),
    );
    expect(await harness.database.isCloudSetupChoiceComplete(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue as Guest offers saved local workspaces and Start Fresh',
      (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await harness.store.createGuestWorkspace(displayName: 'Saved Guest');
    await tester.pumpWidget(_app(harness.container));
    await _pumpUntil(
      tester,
      find.byKey(const Key('account_choice_continue_guest')),
    );
    await tester.tap(find.byKey(const Key('account_choice_continue_guest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guest_workspace_start_fresh')), findsOneWidget);
    await tester.tap(find.byKey(const Key('guest_workspace_start_fresh')));
    await tester.pumpAndSettle();

    expect(
      isGuestLocalWorkspaceId(harness.session.activeLocalAccountId),
      isTrue,
    );
    expect(await harness.database.isCloudSetupChoiceComplete(), isTrue);
    expect(harness.identity.signInCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google identity failure leaves local account choice available',
      (tester) async {
    final harness = await _createHarness(
      signInResult: const GoogleIdentitySnapshot.failed('Sign-in failed'),
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(_app(harness.container));
    await _pumpUntil(tester,
        find.byKey(const Key('account_choice_google_login')));
    await tester.tap(find.byKey(const Key('account_choice_google_login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_choice_continue_guest')), findsOneWidget);
    expect(await harness.database.isCloudSetupChoiceComplete(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
