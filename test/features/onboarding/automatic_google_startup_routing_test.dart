import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_choice_screen.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeFirebase extends FirebaseServices {
  int initializeCalls = 0;

  @override
  bool get initialized => true;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return true;
  }
}

class _UnavailableFirebase extends FirebaseServices {
  @override
  bool get initialized => false;

  @override
  Future<bool> initialize() async => false;
}

class _FakeAuth extends GoogleFirebaseAuthService {
  _FakeAuth(super.services, this.identity);

  final GoogleFirebaseIdentity? identity;

  @override
  Future<GoogleFirebaseIdentity?> attemptLightweightAuthentication({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      identity;

  @override
  Future<void> signOut() async {}
}

class _FailingInteractiveAuth extends _FakeAuth {
  _FailingInteractiveAuth(super.services, super.identity);

  @override
  Future<User?> signIn() async {
    throw StateError('Google authentication canceled.');
  }
}

class _FakeBackup extends FirebaseBackupService {
  _FakeBackup({
    required FirebaseServices firebase,
    required AppDatabase database,
    required AccountLocalStore accountStore,
    this.root,
  }) : super(
          firebase: firebase,
          database: database,
          accountStore: accountStore,
        );

  final Map<String, dynamic>? root;

  @override
  Future<Map<String, dynamic>?> readCloudRoot(String uid) async => root;
}

class _FakeReconciliation extends FirebaseReconciliationService {
  _FakeReconciliation({
    required FirebaseServices firebase,
    required FirebaseBackupService backupService,
    required AccountLocalStore accountStore,
    required AppDatabase database,
    this.profile,
  }) : store = accountStore,
       super(
         firebase: firebase,
         backupService: backupService,
         accountStore: accountStore,
         database: database,
       );

  final UserProfile? profile;
  final AccountLocalStore store;

  @override
  Future<ReconciliationResult> restore({
    required String localAccountId,
    required String uid,
  }) async {
    if (profile != null) {
      await store.saveProfile(localAccountId, profile!);
    }
    return const ReconciliationResult(cloudAvailable: true);
  }
}

UserProfile _completeProfile() => UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1990, 1, 1),
      pubertyAge: 15,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );

Future<AccountSessionManager> _manager({
  required AppDatabase database,
  required AccountLocalStore store,
  required GoogleFirebaseIdentity? identity,
  FirebaseServices? firebase,
  Map<String, dynamic>? root,
  UserProfile? cloudProfile,
}) async {
  final services = firebase ?? _FakeFirebase();
  final backup = _FakeBackup(
    firebase: services,
    database: database,
    accountStore: store,
    root: root,
  );
  final reconciliation = _FakeReconciliation(
    firebase: services,
    backupService: backup,
    accountStore: store,
    database: database,
    profile: cloudProfile,
  );
  return AccountSessionManager(
    accountStore: store,
    firebase: services,
    auth: _FakeAuth(services, identity),
    backup: backup,
    reconciliation: reconciliation,
  );
}

Future<void> waitForGoogleStartupRestore(
    AccountSessionManager manager,
  ) async {
    for (var i = 0; i < 50; i++) {
      if (manager.activeAccount?.isGoogle == true) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Let the already-started background reconciliation finish before the
    // in-memory database is torn down by the test.
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }

Future<void> pumpStartupGate(
  WidgetTester tester,
  AccountSessionManager manager,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountSessionManagerProvider.overrideWith((ref) => manager),
        userProfileProvider.overrideWith((ref) => Future.value(null)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StartupGate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase database;
  late AccountLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    await store.ensureInitialized(
      hasLegacyProfile: false,
      hasLegacyQaza: false,
    );
  });

  tearDown(() => database.close());

  test(
    'fresh installation with no Google identity keeps Account Choice required',
    () async {
      final firebase = _FakeFirebase();
      final manager = await _manager(
        database: database,
        store: store,
        identity: null,
        firebase: firebase,
      );

      await manager.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);
      expect(firebase.initializeCalls, 1);
    },
  );

  testWidgets(
    'fresh installation with no Google identity shows Account Choice',
    (tester) async {
      final manager = await _manager(
        database: database,
        store: store,
        identity: null,
      );
      await manager.initialize();

      await pumpStartupGate(tester, manager);

      expect(find.byType(AccountChoiceScreen), findsOneWidget);
      expect(find.byType(LanguageSelectionScreen), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    },
  );

  testWidgets(
    'fresh installation with cached Google identity skips Account Choice',
    (tester) async {
      final manager = await _manager(
        database: database,
        store: store,
        identity: const GoogleFirebaseIdentity(
          uid: 'new-device-google',
          email: 'user@example.com',
        ),
      );
      await manager.initialize();
      await waitForGoogleStartupRestore(manager);

      expect(manager.activeAccount?.isGoogle, isTrue);
      expect(manager.initialChoiceRequired, isFalse);

      await pumpStartupGate(tester, manager);

      expect(find.byType(AccountChoiceScreen), findsNothing);
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    },
  );

  test('existing Google UID reuses the same local partition', () async {
    final id = await store.createGooglePartition(
      firebaseUid: 'existing-uid',
      email: 'existing@example.com',
    );
    final profile = _completeProfile();
    await store.saveProfile(id, profile);

    final manager = await _manager(
      database: database,
      store: store,
      identity: const GoogleFirebaseIdentity(
        uid: 'existing-uid',
        email: 'existing@example.com',
      ),
    );
    await manager.initialize();
    await waitForGoogleStartupRestore(manager);

    expect(manager.activeLocalAccountId, id);
    expect(manager.activeAccount?.isGoogle, isTrue);
    final restored = await store.loadProfile(id);
    expect(restored?.isComplete, isTrue);
    expect(restored?.languageCode, profile.languageCode);

    final rows = await database
        .customSelect(
          "SELECT COUNT(*) AS count FROM local_accounts WHERE firebase_uid = 'existing-uid'",
        )
        .get();
    expect(rows.single.read<int>('count'), 1);
  });

  test('existing Guest account is authoritative and skips Google startup',
      () async {
    final profile = _completeProfile();
    await store.saveProfile(UserProfile.localLedgerUserId, profile);
    await store.activate(UserProfile.localLedgerUserId);
    final firebase = _FakeFirebase();

    final manager = await _manager(
      database: database,
      store: store,
      identity: const GoogleFirebaseIdentity(
        uid: 'cached-but-not-selected',
        email: 'google@example.com',
      ),
      firebase: firebase,
    );
    await manager.initialize();

    expect(manager.activeAccount?.isGuest, isTrue);
    expect(manager.activeLocalAccountId, UserProfile.localLedgerUserId);
    expect(firebase.initializeCalls, 0);
  });

  test(
    'first-launch Google failure keeps Account Choice required',
    () async {
      final firebase = _FakeFirebase();
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: _FailingInteractiveAuth(firebase, null),
        backup: _FakeBackup(
          firebase: firebase,
          database: database,
          accountStore: store,
        ),
        reconciliation: FirebaseReconciliationService(
          firebase: firebase,
          backupService: _FakeBackup(
            firebase: firebase,
            database: database,
            accountStore: store,
          ),
          accountStore: store,
          database: database,
        ),
      );

      await manager.initialize();
      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);

      await manager.connectGoogle();

      expect(manager.state.phase, AccountSessionPhase.ready);
      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);
    },
  );

  test('Firebase failure preserves the completed local Guest account',
      () async {
    final profile = _completeProfile();
    await store.saveProfile(UserProfile.localLedgerUserId, profile);
    await store.activate(UserProfile.localLedgerUserId);

    final firebase = _UnavailableFirebase();
    final manager = await _manager(
      database: database,
      store: store,
      identity: null,
      firebase: firebase,
    );
    await manager.initialize();

    expect(manager.activeAccount?.isGuest, isTrue);
    final restored = await store.loadProfile(UserProfile.localLedgerUserId);
    expect(restored?.isComplete, isTrue);
    expect(restored?.languageCode, profile.languageCode);
  });

  test(
    'new Google UID creates one partition and restores cloud profile',
    () async {
      final manager = await _manager(
        database: database,
        store: store,
        identity: const GoogleFirebaseIdentity(
          uid: 'recovered-uid',
          email: 'recovered@example.com',
        ),
        root: {'cloudGeneration': 1, 'datasetState': 'ready'},
        cloudProfile: _completeProfile(),
      );

      await manager.initialize();
      await waitForGoogleStartupRestore(manager);

      final account = manager.activeAccount;
      expect(account?.isGoogle, isTrue);
      expect(account?.firebaseUid, 'recovered-uid');
      final restored = await store.loadProfile(account!.localAccountId);
      expect(restored?.isComplete, isTrue);
      expect(restored?.languageCode, 'en');

      final rows = await database
          .customSelect(
            "SELECT COUNT(*) AS count FROM local_accounts WHERE firebase_uid = 'recovered-uid'",
          )
          .get();
      expect(rows.single.read<int>('count'), 1);
    },
  );
}
