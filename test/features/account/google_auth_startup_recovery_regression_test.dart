import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_reconciliation_service.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

class _CountingFirebaseServices extends FirebaseServices {
  int initializeCalls = 0;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return false;
  }
}

class _PendingAuth extends GoogleFirebaseAuthService {
  _PendingAuth(super.services);

  final Completer<GoogleFirebaseIdentity> completer =
      Completer<GoogleFirebaseIdentity>();
  int signInCalls = 0;

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() {
    signInCalls++;
    return completer.future;
  }
}

class _FailingAuth extends GoogleFirebaseAuthService {
  _FailingAuth(super.services);

  int signInCalls = 0;

  @override
  Future<GoogleFirebaseIdentity> signInIdentity() async {
    signInCalls++;
    throw StateError('Google authentication canceled.');
  }
}

Future<(AppDatabase, AccountLocalStore)> _newLocalSession() async {
  SharedPreferences.setMockInitialValues({});
  final database = AppDatabase(NativeDatabase.memory());
  final store = AccountLocalStore(database: database);
  await store.ensureInitialized(
    hasLegacyProfile: false,
    hasLegacyQaza: false,
  );
  return (database, store);
}

AccountSessionManager _newManager({
  required AccountLocalStore store,
  required FirebaseServices firebase,
  required GoogleFirebaseAuthService auth,
}) {
  final backup = FirebaseBackupService(
    firebase: firebase,
    database: store.database,
    accountStore: store,
  );
  final reconciliation = FirebaseReconciliationService(
    firebase: firebase,
    backupService: backup,
    accountStore: store,
    database: store.database,
  );

  return AccountSessionManager(
    accountStore: store,
    firebase: firebase,
    auth: auth,
    backup: backup,
    reconciliation: reconciliation,
  );
}

void main() {
  test(
    'fresh Google authentication does not persist migration state while picker is pending',
    () async {
      final (database, store) = await _newLocalSession();
      addTearDown(database.close);

      final firebase = _CountingFirebaseServices();
      final auth = _PendingAuth(firebase);
      final manager = _newManager(
        store: store,
        firebase: firebase,
        auth: auth,
      );

      await manager.initialize();
      expect(await store.migrationState(), 'none');
      expect(await store.activeAccount(), isNull);
      expect(await store.initialChoiceRequired(), isTrue);

      final connectFuture = manager.connectGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(auth.signInCalls, 1);
      expect(manager.state.phase, AccountSessionPhase.connecting);

      // The interactive Credential Manager request is still pending. No
      // durable Google migration state may exist yet.
      expect(await store.migrationState(), 'none');
      expect(await store.activeAccount(), isNull);
      expect(await store.initialChoiceRequired(), isTrue);

      // Complete the controlled authentication so the in-flight operation can
      // finish cleanly before test teardown.
      auth.completer.complete(
        const GoogleFirebaseIdentity(
          uid: 'regression-google',
          email: 'regression@example.com',
        ),
      );
      await connectFuture;

      expect(await store.migrationState(), 'completed');
      expect((await store.activeAccount())?.firebaseUid, 'regression-google');
    },
  );

  test(
    'relaunch during a pending fresh Google authentication returns to Account Choice',
    () async {
      final (database, store) = await _newLocalSession();
      addTearDown(database.close);

      final firebase = _CountingFirebaseServices();
      final auth = _PendingAuth(firebase);
      final firstManager = _newManager(
        store: store,
        firebase: firebase,
        auth: auth,
      );

      await firstManager.initialize();
      final connectFuture = firstManager.connectGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(await store.migrationState(), 'none');
      expect(await store.activeAccount(), isNull);
      expect(await store.initialChoiceRequired(), isTrue);

      // Simulate a fresh process/session using the same durable database.
      final relaunchedManager = _newManager(
        store: store,
        firebase: firebase,
        auth: GoogleFirebaseAuthService(firebase),
      );
      await relaunchedManager.initialize();

      expect(relaunchedManager.activeAccount, isNull);
      expect(relaunchedManager.activeLocalAccountId, isNull);
      expect(relaunchedManager.initialChoiceRequired, isTrue);
      expect(relaunchedManager.state.migrationState, 'none');

      auth.completer.complete(
        const GoogleFirebaseIdentity(
          uid: 'relaunch-google',
          email: 'relaunch@example.com',
        ),
      );
      await connectFuture;
    },
  );

  test(
    'Google authentication failure leaves the clean account boundary and Guest stays local',
    () async {
      final (database, store) = await _newLocalSession();
      addTearDown(database.close);

      final firebase = _CountingFirebaseServices();
      final auth = _FailingAuth(firebase);
      final manager = _newManager(
        store: store,
        firebase: firebase,
        auth: auth,
      );

      await manager.initialize();
      await manager.connectGoogle();

      expect(auth.signInCalls, 1);
      expect(manager.activeAccount, isNull);
      expect(manager.activeLocalAccountId, isNull);
      expect(manager.initialChoiceRequired, isTrue);
      expect(await store.migrationState(), 'none');
      expect(firebase.initializeCalls, 0);

      await manager.continueAsGuest();

      expect(manager.activeAccount?.isGuest, isTrue);
      expect(manager.initialChoiceRequired, isFalse);
      expect(firebase.initializeCalls, 0);
    },
  );
}
