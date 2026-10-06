import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

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
  int lightweightAuthenticationCalls = 0;

  @override
  Future<GoogleFirebaseIdentity?> attemptLightweightAuthentication({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    lightweightAuthenticationCalls++;
    return identity;
  }

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() async {
    if (identity == null) {
      throw StateError('Google authentication returned no user.');
    }
    return identity!;
  }

  @override
  Future<void> signOut() async {}
}

class _FailingInteractiveAuth extends _FakeAuth {
  _FailingInteractiveAuth(super.services, super.identity);

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() async {
    throw StateError('Google authentication canceled.');
  }
}

class _ControlledInteractiveAuth extends _FakeAuth {
  _ControlledInteractiveAuth(
    super.services,
    super.identity,
  );

  final Completer<GoogleFirebaseIdentity> signInCompleter =
      Completer<GoogleFirebaseIdentity>();
  int signInCalls = 0;

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() {
    signInCalls++;
    return signInCompleter.future;
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
  int bootstrapCalls = 0;
  int snapshotCalls = 0;

  @override
  Future<Map<String, dynamic>?> readCloudRoot(String uid) async => root;

  @override
  Future<CloudRootReadResult> readCloudRootResult(String uid) async {
    if (root == null) {
      return const CloudRootReadResult(status: CloudRootStatus.missing);
    }
    return CloudRootReadResult(
      status: CloudRootStatus.exists,
      data: root,
    );
  }

  @override
  Future<void> bootstrapAccount({
    required String localAccountId,
    required String uid,
    required int generation,
  }) async {
    bootstrapCalls++;
  }

  @override
  Future<void> snapshotAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    int? bootstrapCutoffMicros,
  }) async {
    snapshotCalls++;
  }
}

class _UnavailableCloudBackup extends _FakeBackup {
  _UnavailableCloudBackup({
    required super.firebase,
    required super.database,
    required super.accountStore,
  });

  @override
  Future<CloudRootReadResult> readCloudRootResult(String uid) async {
    return const CloudRootReadResult(status: CloudRootStatus.unavailable);
  }
}

class _FailingReconciliation extends FirebaseReconciliationService {
  _FailingReconciliation({
    required super.firebase,
    required super.backupService,
    required super.accountStore,
    required super.database,
  });

  @override
  Future<ReconciliationResult> restore({
    required String localAccountId,
    required String uid,
  }) async {
    throw StateError('Cloud restore failed.');
  }
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
    await manager.startupRestoreFuture;
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
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
      final auth = _FakeAuth(firebase, null);
      final backup = _FakeBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: auth,
        backup: backup,
        reconciliation: FirebaseReconciliationService(
          firebase: firebase,
          backupService: backup,
          accountStore: store,
          database: database,
        ),
      );

      await manager.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);
      expect(firebase.initializeCalls, 0);
      expect(auth.lightweightAuthenticationCalls, 0);
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
    'fresh installation with cached Google identity still shows Account Choice',
    (tester) async {
      final firebase = _FakeFirebase();
      final auth = _FakeAuth(
        firebase,
        const GoogleFirebaseIdentity(
          uid: 'new-device-google',
          email: 'user@example.com',
        ),
      );
      final backup = _FakeBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: auth,
        backup: backup,
        reconciliation: FirebaseReconciliationService(
          firebase: firebase,
          backupService: backup,
          accountStore: store,
          database: database,
        ),
      );
      await manager.initialize();

      expect(manager.activeAccount, isNull);
      expect(auth.lightweightAuthenticationCalls, 0);
      expect(manager.initialChoiceRequired, isTrue);

      await pumpStartupGate(tester, manager);

      expect(find.byType(AccountChoiceScreen), findsOneWidget);
      expect(find.byType(LanguageSelectionScreen), findsNothing);
    },
  );

  test('existing Google UID reuses the same local partition', () async {
    final id = await store.createGooglePartition(
      firebaseUid: 'existing-uid',
      email: 'existing@example.com',
    );
    final profile = _completeProfile();
    await store.saveProfile(id, profile);
    await store.activate(id);

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
    'existing Google UID restores the local partition from cloud profile',
    () async {
      final id = await store.createGooglePartition(
        firebaseUid: 'recovered-uid',
        email: 'recovered@example.com',
      );
      await store.activate(id);

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
  test(
    'duplicate connectGoogle calls start only one authentication operation',
    () async {
      final firebase = _FakeFirebase();
      final auth = _ControlledInteractiveAuth(firebase, null);
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: auth,
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
      expect(manager.initialChoiceRequired, isTrue);

      final first = manager.connectGoogle();
      await Future<void>.delayed(Duration.zero);

      final second = manager.connectGoogle();
      expect(auth.signInCalls, 1);
      expect(manager.state.phase, AccountSessionPhase.connecting);

      auth.signInCompleter.complete(
        const GoogleFirebaseIdentity(
          uid: 'single-flight-google',
          email: 'single@example.com',
        ),
      );
      await first;
      await second;

      expect(auth.signInCalls, 1);
      expect(manager.state.phase, AccountSessionPhase.ready);
      expect(manager.activeAccount, isNull);
      expect(manager.initialChoiceRequired, isTrue);
    },
  );


  test(
    'new Google account activates locally before an unavailable cloud sync',
    () async {
      final firebase = _FakeFirebase();
      final backup = _UnavailableCloudBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final auth = _FakeAuth(
        firebase,
        const GoogleFirebaseIdentity(
          uid: 'new-google-offline',
          email: 'offline@example.com',
        ),
      );
      final reconciliation = _FakeReconciliation(
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
      await manager.connectGoogle();

      expect(manager.state.phase, AccountSessionPhase.ready);
      expect(manager.activeAccount?.isGoogle, isTrue);
      expect(manager.activeAccount?.firebaseUid, 'new-google-offline');
      expect(manager.initialChoiceRequired, isFalse);
      expect(manager.state.migrationState, 'completed');

      await Future<void>.delayed(Duration.zero);
      expect(backup.bootstrapCalls, 0);
    },
  );

  test(
    'Guest → Google preserves local data when cloud is unavailable',
    () async {
      final firebase = _FakeFirebase();
      final backup = _UnavailableCloudBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final auth = _FakeAuth(
        firebase,
        const GoogleFirebaseIdentity(
          uid: 'guest-google-offline',
          email: 'guest@example.com',
        ),
      );
      final reconciliation = _FakeReconciliation(
        firebase: firebase,
        backupService: backup,
        accountStore: store,
        database: database,
      );
      await store.saveProfile(
        UserProfile.localLedgerUserId,
        _completeProfile(),
      );
      await store.activate(UserProfile.localLedgerUserId);

      await database.customInsert(
        '''INSERT INTO qaza_records
           (id, user_id, prayer_type, original_date, status, completed_at,
            completion_id, addition_id, record_version, created_at, updated_at)
           VALUES (?, ?, 'fajr', ?, 'pending', NULL, NULL, NULL, 1, ?, ?)''',
        variables: [
          Variable('guest-record-1'),
          Variable(UserProfile.localLedgerUserId),
          Variable(DateTime(2025, 1, 1)),
          Variable(DateTime(2025, 1, 1)),
          Variable(DateTime(2025, 1, 1)),
        ],
      );

      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: auth,
        backup: backup,
        reconciliation: reconciliation,
      );

      await manager.initialize();
      await manager.connectGoogle();

      final active = manager.activeAccount;
      expect(manager.state.phase, AccountSessionPhase.ready);
      expect(active?.isGoogle, isTrue);
      expect(active?.firebaseUid, 'guest-google-offline');
      expect(active?.localAccountId, UserProfile.localLedgerUserId);
      expect(await store.hasAnyQaza(UserProfile.localLedgerUserId), isTrue);
      expect(manager.state.migrationState, 'completed');
    },
  );

  test(
    'existing Google account stays active when cloud restore fails',
    () async {
      final firebase = _FakeFirebase();
      final id = await store.createGooglePartition(
        firebaseUid: 'existing-google-offline',
        email: 'existing@example.com',
      );
      await store.activate(id);
      await store.saveProfile(id, _completeProfile());

      final backup = _FakeBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
        root: {'cloudGeneration': 1, 'datasetState': 'ready'},
      );
      final reconciliation = _FailingReconciliation(
        firebase: firebase,
        backupService: backup,
        accountStore: store,
        database: database,
      );
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: _FakeAuth(
          firebase,
          const GoogleFirebaseIdentity(
            uid: 'existing-google-offline',
            email: 'existing@example.com',
          ),
        ),
        backup: backup,
        reconciliation: reconciliation,
      );

      await manager.initialize();
      await waitForGoogleStartupRestore(manager);

      expect(manager.state.phase, AccountSessionPhase.ready);
      expect(manager.activeLocalAccountId, id);
      expect(manager.activeAccount?.isGoogle, isTrue);
      expect(manager.activeAccount?.firebaseUid, 'existing-google-offline');
    },
  );

  test(
    'cloud root unavailable never triggers bootstrap',
    () async {
      final firebase = _FakeFirebase();
      final backup = _UnavailableCloudBackup(
        firebase: firebase,
        database: database,
        accountStore: store,
      );
      final reconciliation = _FakeReconciliation(
        firebase: firebase,
        backupService: backup,
        accountStore: store,
        database: database,
      );
      final auth = _FakeAuth(
        firebase,
        const GoogleFirebaseIdentity(
          uid: 'cloud-unavailable-google',
          email: 'cloud@example.com',
        ),
      );
      final manager = AccountSessionManager(
        accountStore: store,
        firebase: firebase,
        auth: auth,
        backup: backup,
        reconciliation: reconciliation,
      );

      await manager.initialize();
      await manager.connectGoogle();

      await Future<void>.delayed(Duration.zero);
      expect(manager.activeAccount?.isGoogle, isTrue);
      expect(backup.bootstrapCalls, 0);
      expect(manager.state.migrationState, 'completed');
    },
  );

}
