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
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';
import 'package:qaza_namaz/features/account/account_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/language_selection_screen.dart';
import 'package:qaza_namaz/features/onboarding/startup_gate.dart';

class _FakeFirebase extends FirebaseServices {
  @override
  bool get initialized => true;

  @override
  Future<bool> initialize() async => true;
}

class _FakeAuth extends GoogleFirebaseAuthService {
  _FakeAuth(super.services, this.identity);

  final GoogleFirebaseIdentity? identity;

  @override
  Future<GoogleFirebaseIdentity?> attemptLightweightAuthentication({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      identity;
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
  })  : store = accountStore,
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
  Map<String, dynamic>? root,
  UserProfile? cloudProfile,
}) async {
  final firebase = _FakeFirebase();
  final backup = _FakeBackup(
    firebase: firebase,
    database: database,
    accountStore: store,
    root: root,
  );
  final reconciliation = FirebaseReconciliationService(
    firebase: firebase,
    backupService: backup,
    accountStore: store,
    database: database,
  );
  final auth = _FakeAuth(firebase, identity);
  return AccountSessionManager(
    accountStore: store,
    firebase: firebase,
    auth: auth,
    backup: backup,
    reconciliation: reconciliation,
  );
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

    expect(manager.activeLocalAccountId, id);
    expect(manager.activeAccount?.isGoogle, isTrue);
    expect(await store.loadProfile(id), profile);

    final rows = await database.customSelect(
      "SELECT COUNT(*) AS count FROM local_accounts WHERE firebase_uid = 'existing-uid'",
    ).get();
    expect(rows.single.read<int>('count'), 1);
  });

  test('new Google UID creates one partition and restores cloud profile', () async {
    final firebase = _FakeFirebase();
    final backup = _FakeBackup(
      firebase: firebase,
      database: database,
      accountStore: store,
      root: {'cloudGeneration': 1, 'datasetState': 'ready'},
    );
    final reconciliation = _FakeReconciliation(
      firebase: firebase,
      backupService: backup,
      accountStore: store,
      database: database,
      profile: _completeProfile(),
    );
    final manager = AccountSessionManager(
      accountStore: store,
      firebase: firebase,
      auth: _FakeAuth(
        firebase,
        const GoogleFirebaseIdentity(
          uid: 'recovered-uid',
          email: 'recovered@example.com',
        ),
      ),
      backup: backup,
      reconciliation: reconciliation,
    );

    await manager.initialize();

    final account = manager.activeAccount;
    expect(account?.isGoogle, isTrue);
    expect(account?.firebaseUid, 'recovered-uid');
    expect(await store.loadProfile(account!.localAccountId), _completeProfile());

    final rows = await database.customSelect(
      "SELECT COUNT(*) AS count FROM local_accounts WHERE firebase_uid = 'recovered-uid'",
    ).get();
    expect(rows.single.read<int>('count'), 1);
  });

  test('no Google session preserves a completed Guest account', () async {
    final profile = _completeProfile();
    await store.saveProfile(UserProfile.localLedgerUserId, profile);
    await store.activate(UserProfile.localLedgerUserId);

    final manager = await _manager(
      database: database,
      store: store,
      identity: null,
    );
    await manager.initialize();

    expect(manager.activeAccount?.isGuest, isTrue);
    expect(manager.activeLocalAccountId, UserProfile.localLedgerUserId);
    expect(await store.loadProfile(UserProfile.localLedgerUserId), profile);
  });

  test('Firebase failure preserves the completed local Guest account', () async {
    final profile = _completeProfile();
    await store.saveProfile(UserProfile.localLedgerUserId, profile);
    await store.activate(UserProfile.localLedgerUserId);

    final firebase = _FakeFirebase();
    final manager = AccountSessionManager(
      accountStore: store,
      firebase: firebase,
      auth: _FakeAuth(firebase, null),
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

    expect(manager.activeAccount?.isGuest, isTrue);
    expect(await store.loadProfile(UserProfile.localLedgerUserId), profile);
  });

  testWidgets('normal startup never shows AccountChoiceScreen', (tester) async {
    final firebase = _FakeFirebase();
    final manager = AccountSessionManager(
      accountStore: store,
      firebase: firebase,
      auth: _FakeAuth(firebase, null),
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSessionManagerProvider.overrideWith((ref) => manager),
          userProfileProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const MaterialApp(home: StartupGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountChoiceScreen), findsNothing);
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
  });
}
