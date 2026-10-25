import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/onboarding/account_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
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
  stderr.writeln('[account-choice-test] harness: create temporary directory');
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
  stderr.writeln('[account-choice-test] harness: read database revision');
  await database.readDbRevision().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
            'Harness timed out reading database revision'),
      );
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
  stderr.writeln('[account-choice-test] harness: initialize account session');
  await session.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
            'Harness timed out initializing account session'),
      );
  stderr.writeln('[account-choice-test] harness: ready');
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

Future<_Harness> _createHarnessForWidgetTest(
  WidgetTester tester, {
  GoogleIdentitySnapshot restoreResult =
      const GoogleIdentitySnapshot.signedOut(),
  GoogleIdentitySnapshot signInResult =
      const GoogleIdentitySnapshot.signedOut(),
}) async {
  // File-system IO and Drift's native executor are real asynchronous work.
  // testWidgets otherwise runs in a fake-async zone that can leave this setup
  // pending before the widget is mounted. Execute setup in the test binding's
  // real async zone, with a bounded diagnostic timeout.
  final harness = await tester.runAsync(
    () => _createHarness(
      restoreResult: restoreResult,
      signInResult: signInResult,
    ),
  );
  if (harness == null) {
    throw TimeoutException(
      'Real-async account-choice harness setup returned without a harness',
    );
  }
  return harness;
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
  fail('Widget did not appear within 4 seconds: $finder');
}

Future<void> _pumpUntilEither(
  WidgetTester tester,
  Finder first,
  Finder second,
) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (first.evaluate().isNotEmpty || second.evaluate().isNotEmpty) return;
  }
  fail('Neither expected widget appeared within 4 seconds: $first OR $second');
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
}) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('Condition did not become true within 4 seconds: $description');
}

Future<void> _waitForLoginButton(WidgetTester tester) async {
  const key = Key('account_choice_google_login');
  await _pumpUntilCondition(
    tester,
    () {
      final finder = find.byKey(key);
      return finder.evaluate().isNotEmpty &&
          tester.widget<OutlinedButton>(finder).onPressed != null;
    },
    description: 'Google sign-in button becomes enabled',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Google sign-in creates or resumes a local Google workspace',
      (tester) async {
    final harness = await _createHarnessForWidgetTest(
      tester,
      signInResult: const GoogleIdentitySnapshot.signedIn(
        accountId: 'google-account-42',
        displayName: 'Test User',
        email: 'test@example.com',
      ),
    );
    addTearDown(() async {
      await tester.runAsync(
        harness.dispose,
      );
    });

    await tester.pumpWidget(_app(harness.container));
    await _waitForLoginButton(tester);
    await tester.tap(find.byKey(const Key('account_choice_google_login')));

    // A new Google identity may require an explicit Guest decision. The
    // screen keeps its loading indicator active while that dialog is open,
    // so pumpAndSettle() would wait for an animation that cannot settle until
    // the test makes the decision.
    const startFreshKey = Key('google_workspace_start_fresh');
    await _pumpUntilEither(
      tester,
      find.byType(StartupGate),
      find.byKey(startFreshKey),
    );
    if (find.byKey(startFreshKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(startFreshKey));
    }
    await _pumpUntil(tester, find.byType(StartupGate));

    expect(harness.identity.signInCalls, 1);
    expect(
      harness.session.activeLocalAccountId,
      googleLocalWorkspaceId('google-account-42'),
    );
    expect(
      (await tester.runAsync(
        () => harness.database.isAccountChoiceComplete(),
      ))!,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));

  testWidgets('Continue as Guest offers saved local workspaces and Start Fresh',
      (tester) async {
    final harness = await _createHarnessForWidgetTest(
      tester,
    );
    addTearDown(() async {
      await tester.runAsync(
        harness.dispose,
      );
    });

    await tester.runAsync(
      () => harness.store.createGuestWorkspace(displayName: 'Saved Guest'),
    );
    await tester.pumpWidget(_app(harness.container));
    const guestKey = Key('account_choice_continue_guest');
    await _pumpUntilCondition(
      tester,
      () {
        final finder = find.byKey(guestKey);
        return finder.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(finder).onPressed != null;
      },
      description: 'Continue as Guest button becomes enabled',
    );
    await tester.tap(find.byKey(guestKey));

    // The guest-choice dialog is intentionally shown while _working is true.
    // Wait for the dialog instead of settling the continuously animated spinner.
    const startFreshGuestKey = Key('guest_workspace_start_fresh');
    await _pumpUntil(tester, find.byKey(startFreshGuestKey));
    await tester.tap(find.byKey(startFreshGuestKey));
    await _pumpUntil(tester, find.byType(StartupGate));

    expect(
      isGuestLocalWorkspaceId(harness.session.activeLocalAccountId),
      isTrue,
    );
    expect(
      (await tester.runAsync(
        () => harness.database.isAccountChoiceComplete(),
      ))!,
      isTrue,
    );
    expect(harness.identity.signInCalls, 0);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));

  testWidgets('Google sign-in offers an explicit local Guest adoption',
      (tester) async {
    final harness = await _createHarnessForWidgetTest(
      tester,
      signInResult: const GoogleIdentitySnapshot.signedIn(
        accountId: 'google-adopt-account',
        displayName: 'Adoption Test',
      ),
    );
    addTearDown(() async {
      await tester.runAsync(
        harness.dispose,
      );
    });

    final guestId = (await tester.runAsync(
      () => harness.store.createGuestWorkspace(displayName: 'Saved Guest'),
    ))!;
    await tester.pumpWidget(_app(harness.container));
    await _waitForLoginButton(tester);
    await tester.tap(find.byKey(const Key('account_choice_google_login')));
    await _pumpUntil(
      tester,
      find.byKey(Key('google_adopt_guest_$guestId')),
    );

    expect(
        find.byKey(const Key('google_workspace_start_fresh')), findsOneWidget);
    await tester.tap(find.byKey(Key('google_adopt_guest_$guestId')));
    await _pumpUntil(tester, find.byType(StartupGate));

    expect(
      harness.session.activeLocalAccountId,
      googleLocalWorkspaceId('google-adopt-account'),
    );
    expect(
      (await tester.runAsync(
        () => harness.store.getAccount(guestId),
      ))
          ?.lifecycleState,
      AccountLifecycleState.adoptedRecovery,
    );
    expect(
      (await tester.runAsync(
        () => harness.database.isAccountChoiceComplete(),
      ))!,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));

  testWidgets('Google identity failure leaves local account choice available',
      (tester) async {
    final harness = await _createHarnessForWidgetTest(
      tester,
      signInResult: const GoogleIdentitySnapshot.failed('Sign-in failed'),
    );
    addTearDown(() async {
      await tester.runAsync(
        harness.dispose,
      );
    });

    await tester.pumpWidget(_app(harness.container));
    await _waitForLoginButton(tester);
    await tester.tap(find.byKey(const Key('account_choice_google_login')));
    await _pumpUntil(tester, find.text('Sign-in failed'));
    await _pumpUntilCondition(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      description: 'loading indicator clears after identity failure',
    );

    expect(
        find.byKey(const Key('account_choice_continue_guest')), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => harness.database.isAccountChoiceComplete(),
      ))!,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
