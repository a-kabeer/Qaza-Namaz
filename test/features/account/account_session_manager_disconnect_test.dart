import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

class _UnavailableFirebaseServices extends FirebaseServices {
  @override
  bool get initialized => false;

  @override
  Future<bool> initialize() async => false;
}

class _TrackingGoogleAuthService extends GoogleFirebaseAuthService {
  _TrackingGoogleAuthService(super.services);

  bool disconnectCalled = false;
  bool signOutCalled = false;

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  late AppDatabase database;
  late AccountLocalStore store;
  late FirebaseServices firebase;
  late _TrackingGoogleAuthService auth;
  late AccountSessionManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    await store.ensureInitialized(
      hasLegacyProfile: false,
      hasLegacyQaza: false,
    );

    final googleId = await store.createGooglePartition(
      firebaseUid: 'disconnect-user',
      email: 'disconnect@example.com',
    );
    await store.activate(googleId);

    firebase = _UnavailableFirebaseServices();
    auth = _TrackingGoogleAuthService(firebase);

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

    manager = AccountSessionManager(
      accountStore: store,
      firebase: firebase,
      auth: auth,
      backup: backup,
      reconciliation: reconciliation,
    );

    await manager.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'disconnect uses Google disconnect, disables backup, and returns to Guest',
    () async {
      final google = manager.activeAccount;
      expect(google?.isGoogle, isTrue);
      expect(google?.cloudBackupEnabled, isTrue);

      await manager.disconnect();

      expect(auth.disconnectCalled, isTrue);
      expect(
        auth.signOutCalled,
        isFalse,
        reason: 'Disconnect must not degrade into a normal Google sign-out.',
      );

      final active = await store.activeAccount();
      expect(active?.isGuest, isTrue);
      expect(active?.localAccountId, 'guest_local_ledger');

      final googleAfter = await store.getAccount(google!.localAccountId);
      expect(googleAfter?.isGoogle, isTrue);
      expect(googleAfter?.cloudBackupEnabled, isFalse);
    },
  );
}
