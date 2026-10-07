import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_choice_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/onboarding/splash_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _NoopFirebaseServices extends FirebaseServices {
  int initializeCalls = 0;

  @override
  bool get initialized => false;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return false;
  }
}

class _ControlledFirebaseServices extends FirebaseServices {
  _ControlledFirebaseServices(this.initializeCompleter);

  final Completer<bool> initializeCompleter;
  int initializeCalls = 0;

  @override
  bool get initialized => false;

  @override
  Future<bool> initialize() {
    initializeCalls++;
    return initializeCompleter.future;
  }
}

class _CachedGoogleAuthService extends GoogleFirebaseAuthService {
  _CachedGoogleAuthService(super.services);

  @override
  Future<GoogleFirebaseIdentity?> attemptLightweightAuthentication({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return const GoogleFirebaseIdentity(
      uid: 'stale-background-google',
      email: 'stale@example.com',
    );
  }
}

class _HangingInteractiveAuth extends GoogleFirebaseAuthService {
  _HangingInteractiveAuth(super.services);

  final Completer<GoogleFirebaseIdentity> signInCompleter =
      Completer<GoogleFirebaseIdentity>();

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() => signInCompleter.future;

  @override
  Future<void> signOut() async {}
}

Future<(AppDatabase, AccountSessionManager)> _newManager({
  bool google = false,
  FirebaseServices? firebase,
  GoogleFirebaseAuthService? auth,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  final store = AccountLocalStore(database: database);
  await store.ensureInitialized(
    hasLegacyProfile: false,
    hasLegacyQaza: false,
  );

  if (google) {
    final googleId = await store.createGooglePartition(
      firebaseUid: 'existing-google',
      email: 'existing@example.com',
    );
    await store.activate(googleId);
  }

  final services = firebase ?? _NoopFirebaseServices();
  final googleAuth = auth ?? GoogleFirebaseAuthService(services);
  final backup = FirebaseBackupService(
    firebase: services,
    database: database,
    accountStore: store,
  );
  final reconciliation = FirebaseReconciliationService(
    firebase: services,
    backupService: backup,
    accountStore: store,
    database: database,
  );

  final manager = AccountSessionManager(
    accountStore: store,
    firebase: services,
    auth: googleAuth,
    backup: backup,
    reconciliation: reconciliation,
  );
  return (database, manager);
}

Widget _startupApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const StartupGate(),
    ),
  );
}

ProviderContainer _container({
  required AccountSessionManager manager,
  required AppDatabase database,
  UserProfile? profile,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      accountSessionManagerProvider.overrideWith((ref) => manager),
      activeUserIdProvider.overrideWith((ref) => manager.activeLocalAccountId),
      userProfileProvider.overrideWith((ref) async => profile),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'StartupGate does not initialize the session from build',
    (tester) async {
      final (database, manager) = await _newManager();
      final container = _container(manager: manager, database: database);
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(AccountChoiceScreen), findsNothing);
    },
  );

  testWidgets(
    'fresh install shows Account Choice before slow cached Google restoration',
    (tester) async {
      final firebaseGate = Completer<bool>();
      final firebase = _ControlledFirebaseServices(firebaseGate);
      final (database, manager) = await _newManager(firebase: firebase);
      final container = _container(
        manager: manager,
        database: database,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await manager.initialize();
      await tester.pump();

      expect(find.byType(AccountChoiceScreen), findsOneWidget);
      expect(firebase.initializeCalls, 0);

      firebaseGate.complete(false);
      await tester.pump();
    },
  );

  testWidgets(
    'Guest remains tappable while Google sign-in is still connecting',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = AccountLocalStore(database: database);
      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );

      final firebase = _NoopFirebaseServices();
      final auth = _HangingInteractiveAuth(firebase);
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
      final container = _container(manager: manager, database: database);
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await manager.initialize();
      await tester.pump();

      expect(find.byType(AccountChoiceScreen), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(manager.state.phase, AccountSessionPhase.connecting);

      final guestButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(guestButton.onPressed, isNotNull);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();

      expect(manager.activeAccount?.isGuest, isTrue);
      expect(manager.initialChoiceRequired, isFalse);

      auth.signInCompleter.complete(
        const GoogleFirebaseIdentity(
          uid: 'late-google-result',
          email: 'late@example.com',
        ),
      );
      await tester.pump();
    },
  );

  testWidgets(
    'fresh local state reaches Account Choice after session initialization',
    (tester) async {
      final (database, manager) = await _newManager();
      final container = _container(manager: manager, database: database);
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await manager.initialize();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountChoiceScreen), findsOneWidget);
    },
  );

  testWidgets(
    'incomplete Google onboarding remains in Language Selection',
    (tester) async {
      final (database, manager) = await _newManager(google: true);
      await manager.initialize();

      final container = _container(
        manager: manager,
        database: database,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
      expect(find.byType(WorkspaceShell), findsNothing);
    },
  );

  testWidgets(
    'invalid Google profile routes to Profile Setup instead of Home',
    (tester) async {
      final (database, manager) = await _newManager(google: true);
      await manager.initialize();

      final profile = UserProfile(
        languageCode: 'en',
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(1990, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 12,
        witrIncluded: true,
        onboardingCompleted: false,
      );
      final container = _container(
        manager: manager,
        database: database,
        profile: profile,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      expect(find.byType(WorkspaceShell), findsNothing);
    },
  );

  testWidgets(
    'completed Google profile routes to Workspace Shell',
    (tester) async {
      final (database, manager) = await _newManager(google: true);
      await manager.initialize();

      final profile = UserProfile(
        languageCode: 'en',
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(1990, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 12,
        witrIncluded: true,
        onboardingCompleted: true,
      );
      final container = _container(
        manager: manager,
        database: database,
        profile: profile,
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await tester.pumpWidget(_startupApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WorkspaceShell), findsOneWidget);
      expect(find.byType(LanguageSelectionScreen), findsNothing);
      expect(find.byType(ProfileSetupScreen), findsNothing);
    },
  );

  test(
    'existing Guest startup never initializes Firebase or Google restoration',
    () async {
      final firebase = _NoopFirebaseServices();
      final (database, manager) = await _newManager(firebase: firebase);
      final store = AccountLocalStore(database: database);
      await store.ensureGuestActive();

      await manager.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeAccount?.isGuest, isTrue);
      expect(firebase.initializeCalls, 0);
    },
  );

  test(
    'explicit Guest selection invalidates a stale cached Google restore',
    () async {
      final firebaseGate = Completer<bool>();
      final firebase = _ControlledFirebaseServices(firebaseGate);
      final auth = _CachedGoogleAuthService(firebase);
      final (database, manager) =
          await _newManager(firebase: firebase, auth: auth);
      final store = AccountLocalStore(database: database);

      await manager.initialize();
      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);

      await manager.continueAsGuest();
      expect(manager.activeAccount?.isGuest, isTrue);

      firebaseGate.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(manager.activeAccount?.isGuest, isTrue);
      expect(
        await store.findGoogleByUid('stale-background-google'),
        isNull,
      );
    },
  );
}
