import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_service.dart';
import 'package:qaza_namaz/data/remote/firebase_backup_worker.dart';
import 'package:qaza_namaz/data/remote/firebase_services.dart';

class _FakeBackupService extends FirebaseBackupService {
  _FakeBackupService(
    FirebaseServices firebase,
    AppDatabase database,
    AccountLocalStore accountStore,
  ) : super(
          firebase: firebase,
          database: database,
          accountStore: accountStore,
        );

  bool failNext = true;
  int calls = 0;

  @override
  Future<void> snapshotAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    int? bootstrapCutoffMicros,
    BackupProgressCallback? onProgress,
  }) async {
    calls++;
    if (failNext) {
      failNext = false;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'synthetic Firebase outage',
      );
    }
    if (onProgress != null) {
      await onProgress(0, 4);
      await onProgress(2, 4);
      await onProgress(4, 4);
    }
  }
}

class _BlockingBackupService extends FirebaseBackupService {
  _BlockingBackupService(
    FirebaseServices firebase,
    AppDatabase database,
    AccountLocalStore accountStore,
  ) : super(
          firebase: firebase,
          database: database,
          accountStore: accountStore,
        );

  final Completer<void> started = Completer<void>();
  final Completer<void> continueCompleter = Completer<void>();
  int calls = 0;

  @override
  Future<void> snapshotAccount({
    required String localAccountId,
    required String uid,
    required int generation,
    int? bootstrapCutoffMicros,
    BackupProgressCallback? onProgress,
  }) async {
    calls++;
    if (!started.isCompleted) {
      started.complete();
    }
    await continueCompleter.future;
    if (onProgress != null) {
      await onProgress(1, 1);
    }
  }
}

void main() {
  test('worker retries the same durable operation and removes it only after success',
      () async {
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = AccountLocalStore(database: database);

    await store.ensureInitialized(
      hasLegacyProfile: false,
      hasLegacyQaza: false,
    );
    final accountId = await store.createGooglePartition(
      firebaseUid: 'worker-user',
      email: 'worker@example.com',
    );
    await store.activate(accountId);
    await store.enqueueSnapshot(accountId);

    final first = await store.loadModernOutboxBatch(
      localAccountId: accountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch,
      limit: 10,
    );
    expect(first, hasLength(1));
    final operationId = first.single['id']! as String;

    final backup = _FakeBackupService(
      FirebaseServices(),
      database,
      store,
    );
    final worker = FirebaseBackupWorker(
      firebase: FirebaseServices(),
      accountStore: store,
      backupService: backup,
      currentFirebaseUidProvider: () async => 'worker-user',
    );

    await worker.runOnce();

    final afterFailure = await store.loadModernOutboxBatch(
      localAccountId: accountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch +
          const Duration(minutes: 5).inMicroseconds +
          1,
      limit: 10,
    );
    expect(afterFailure, hasLength(1));
    expect(afterFailure.single['id'], operationId);
    expect(afterFailure.single['attempts'], 1);
    expect(afterFailure.single['last_error'], contains('synthetic Firebase outage'));
    expect(afterFailure.single['failure_category'], 'networkUnavailable');
    expect(afterFailure.single['last_attempt_at'], isNotNull);

    await database.customUpdate(
      '''UPDATE sync_outbox
         SET next_attempt_at = ?, worker_id = NULL, lease_until = NULL
         WHERE user_id = ? AND id = ?''',
      variables: [
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(accountId),
        Variable(operationId),
      ],
    );

    await worker.runOnce();

    final afterSuccess = await store.loadModernOutboxBatch(
      localAccountId: accountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch,
      limit: 10,
    );
    expect(afterSuccess, isEmpty);
    expect(backup.calls, 2);
  });

  test(
    'worker persists real determinate progress and clears it after success',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);

      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );
      final accountId = await store.createGooglePartition(
        firebaseUid: 'progress-user',
        email: 'progress@example.com',
      );
      await store.activate(accountId);
      await store.enqueueSnapshot(accountId);

      final backup = _FakeBackupService(
        FirebaseServices(),
        database,
        store,
      )..failNext = false;

      final worker = FirebaseBackupWorker(
        firebase: FirebaseServices(),
        accountStore: store,
        backupService: backup,
        currentFirebaseUidProvider: () async => 'progress-user',
      );

      await worker.runOnce();

      expect(backup.calls, 1);
      final status = await store.readBackupStatus(accountId);
      expect(status.state, 'idle');
      expect(status.progressCompleted, isNull);
      expect(status.progressTotal, isNull);
    },
  );

  test(
    'manual retry bypasses delayed backoff without creating a duplicate operation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);

      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );
      final accountId = await store.createGooglePartition(
        firebaseUid: 'retry-user',
        email: 'retry@example.com',
      );
      await store.activate(accountId);
      await store.enqueueSnapshot(accountId);

      final backup = _FakeBackupService(
        FirebaseServices(),
        database,
        store,
      );

      final worker = FirebaseBackupWorker(
        firebase: FirebaseServices(),
        accountStore: store,
        backupService: backup,
        currentFirebaseUidProvider: () async => 'retry-user',
        connectivityProvider: () async => const [ConnectivityResult.wifi],
      );

      await worker.runOnce();

      final failed = await store.readBackupStatus(accountId);
      expect(failed.state, 'failed');
      expect(failed.failureCategory, 'networkUnavailable');
      expect(failed.attemptCount, 1);
      expect(failed.lastAttemptAt, isNotNull);
      expect(failed.nextRetryAt, isNotNull);

      final retryStarted = await worker.retryNow();
      expect(retryStarted, isTrue);
      expect(backup.calls, 2);

      final operations = await store.loadModernOutboxBatch(
        localAccountId: accountId,
        nowMicros: DateTime.now().microsecondsSinceEpoch,
        limit: 10,
      );
      expect(operations, isEmpty);

      final success = await store.readBackupStatus(accountId);
      expect(success.state, 'idle');
    },
  );

  test(
    'worker refuses a Firebase UID mismatch without writing cloud data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);

      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );
      final accountId = await store.createGooglePartition(
        firebaseUid: 'owner-user',
        email: 'owner@example.com',
      );
      await store.activate(accountId);
      await store.enqueueSnapshot(accountId);

      final backup = _FakeBackupService(
        FirebaseServices(),
        database,
        store,
      )..failNext = false;

      final worker = FirebaseBackupWorker(
        firebase: FirebaseServices(),
        accountStore: store,
        backupService: backup,
        currentFirebaseUidProvider: () async => 'different-user',
      );

      await worker.runOnce();

      final status = await store.readBackupStatus(accountId);
      expect(status.state, 'failed');
      expect(status.failureCategory, 'authenticationUidMismatch');
      expect(backup.calls, 0);
    },
  );

  test(
    'worker records authentication unavailable and keeps the durable operation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);

      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );
      final accountId = await store.createGooglePartition(
        firebaseUid: 'offline-auth-user',
        email: 'offline-auth@example.com',
      );
      await store.activate(accountId);
      await store.enqueueSnapshot(accountId);

      final backup = _FakeBackupService(
        FirebaseServices(),
        database,
        store,
      )..failNext = false;

      final worker = FirebaseBackupWorker(
        firebase: FirebaseServices(),
        accountStore: store,
        backupService: backup,
        currentFirebaseUidProvider: () async => null,
      );

      await worker.runOnce();

      final status = await store.readBackupStatus(accountId);
      expect(status.state, 'failed');
      expect(status.failureCategory, 'authenticationUnavailable');
      expect(backup.calls, 0);

      final outbox = await store.loadModernOutboxBatch(
        localAccountId: accountId,
        nowMicros: DateTime.now().microsecondsSinceEpoch + 3600000,
        limit: 10,
      );
      expect(outbox, hasLength(1));
    },
  );

  test(
    'retryNow cannot start a second backup while the worker is running',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = AccountLocalStore(database: database);

      await store.ensureInitialized(
        hasLegacyProfile: false,
        hasLegacyQaza: false,
      );
      final accountId = await store.createGooglePartition(
        firebaseUid: 'concurrent-user',
        email: 'concurrent@example.com',
      );
      await store.activate(accountId);
      await store.enqueueSnapshot(accountId);

      final backup = _BlockingBackupService(
        FirebaseServices(),
        database,
        store,
      );

      final worker = FirebaseBackupWorker(
        firebase: FirebaseServices(),
        accountStore: store,
        backupService: backup,
        currentFirebaseUidProvider: () async => 'concurrent-user',
      );

      final first = worker.runOnce();
      await backup.started.future;

      expect(await worker.retryNow(), isFalse);
      expect(backup.calls, 1);

      backup.continueCompleter.complete();
      await first;
      expect(backup.calls, 1);
    },
  );
}
