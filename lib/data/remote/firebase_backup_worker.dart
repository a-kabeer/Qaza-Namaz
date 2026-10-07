import 'dart:async';
import 'dart:math';

import '../local/account_local_store.dart';
import 'backup_failure.dart';
import 'firebase_backup_service.dart';
import 'firebase_services.dart';

class FirebaseBackupWorker {
  FirebaseBackupWorker({
    required FirebaseServices firebase,
    required AccountLocalStore accountStore,
    required FirebaseBackupService backupService,
    GoogleFirebaseAuthService? authService,
    Future<String?> Function()? currentFirebaseUidProvider,
  })  : _firebase = firebase,
        _accountStore = accountStore,
        _backup = backupService,
        _authService = authService,
        _currentFirebaseUidProvider = currentFirebaseUidProvider;

  final FirebaseServices _firebase;
  final AccountLocalStore _accountStore;
  final FirebaseBackupService _backup;
  final GoogleFirebaseAuthService? _authService;
  final Future<String?> Function()? _currentFirebaseUidProvider;
  final String _workerId = 'worker_${Random.secure().nextInt(1 << 30)}';
  bool _running = false;

  Future<void> runOnce({
    Future<void> Function(int processed, int total)? onProgress,
  }) async {
    if (_running) return;
    _running = true;
    try {
      final account = await _accountStore.activeAccount();
      if (account == null || !account.isGoogle || !account.cloudBackupEnabled) {
        return;
      }

      final uid = account.firebaseUid;
      if (uid == null || uid.isEmpty) {
        return;
      }

      final profile = await _accountStore.loadProfile(account.localAccountId);
      if (profile != null && !profile.onboardingCompleted) return;

      String? currentFirebaseUid;
      try {
        currentFirebaseUid = await _resolveFirebaseUid();
      } catch (error, stack) {
        final failure = classifyBackupFailure(error, stackTrace: stack);
        await _accountStore.recordBackupFailure(
          localAccountId: account.localAccountId,
          failureCategory: failure.category.name,
          message: failure.message,
          nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        return;
      }

      if (currentFirebaseUid == null) {
        await _accountStore.recordBackupFailure(
          localAccountId: account.localAccountId,
          failureCategory:
              BackupFailureCategory.authenticationUnavailable.name,
          message: 'Firebase authentication session is unavailable.',
          nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        return;
      }

      if (currentFirebaseUid != uid) {
        await _accountStore.recordBackupFailure(
          localAccountId: account.localAccountId,
          failureCategory:
              BackupFailureCategory.authenticationUidMismatch.name,
          message: 'Firebase authentication UID does not match the active account.',
          nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        return;
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      final status =
          await _accountStore.readBackupStatus(account.localAccountId);
      if (status.currentRevision > status.acknowledgedRevision) {
        await _accountStore.enqueueSnapshot(account.localAccountId);
      }

      if (_isAppCheckFailureCategory(status.failureCategory)) {
        try {
          await _firebase.ensureAppCheckTokenAvailable(forceRefresh: false);
        } catch (error, stack) {
          final failure = classifyBackupFailure(
            error,
            stackTrace: stack,
          );
          await _accountStore.recordBackupFailure(
            localAccountId: account.localAccountId,
            failureCategory: failure.category.name,
            message: failure.message,
            nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
          );
          return;
        }
      }

      final operations = await _accountStore.loadModernOutboxBatch(
        localAccountId: account.localAccountId,
        nowMicros: now,
        limit: 25,
      );
      if (operations.isEmpty) return;

      final claimed = <Map<String, Object?>>[];
      for (final op in operations) {
        final id = op['id']! as String;
        final ok = await _accountStore.claimOutbox(
          localAccountId: account.localAccountId,
          operationId: id,
          workerId: _workerId,
          leaseUntilMicros: DateTime.now()
              .add(const Duration(minutes: 2))
              .microsecondsSinceEpoch,
        );
        if (ok) claimed.add(op);
      }
      if (claimed.isEmpty) return;

      final generations = claimed
          .map(
            (op) =>
                (op['cloud_generation'] as int?) ?? account.cloudGeneration,
          )
          .toSet();

      for (final generation in generations) {
        final matching = claimed.where(
          (item) =>
              ((item['cloud_generation'] as int?) ?? generation) == generation,
        );

        if (generation != account.cloudGeneration) {
          // The durable operation is stale, not the user's data. Remove only
          // this claimed obsolete operation and enqueue a fresh snapshot using
          // the active generation.
          for (final op in matching) {
            await _accountStore.removeOutboxOperation(
              localAccountId: account.localAccountId,
              operationId: op['id']! as String,
              workerId: _workerId,
            );
          }
          await _accountStore.enqueueSnapshot(account.localAccountId);
          continue;
        }

        try {
          await _accountStore.setBackupState(
            account.localAccountId,
            'running',
          );
          final targetRevision =
              await _accountStore.currentBackupRevision(account.localAccountId);
          await _backup.snapshotAccount(
            localAccountId: account.localAccountId,
            uid: uid,
            generation: generation,
            onProgress: (processed, total) async {
              await _accountStore.setBackupProgress(
                account.localAccountId,
                processed,
                total,
              );
              if (onProgress != null) {
                await onProgress(processed, total);
              }
            },
          );

          // A backup can take long enough for the active account to change.
          // Never acknowledge or remove an operation after that change.
          if (!await _activeAccountStillMatches(
            localAccountId: account.localAccountId,
            firebaseUid: account.firebaseUid,
            cloudGeneration: account.cloudGeneration,
            cloudBackupEnabled: account.cloudBackupEnabled,
          )) {
            await _accountStore.setBackupState(
              account.localAccountId,
              'pending',
            );
            return;
          }

          final acknowledged = await _accountStore.acknowledgeBackup(
            localAccountId: account.localAccountId,
            revision: targetRevision,
            generation: generation,
            completedAt: DateTime.now(),
          );
          if (!acknowledged) {
            await _accountStore.setBackupState(
              account.localAccountId,
              'pending',
            );
            for (final op in matching) {
              await _accountStore.removeOutboxOperation(
                localAccountId: account.localAccountId,
                operationId: op['id']! as String,
                workerId: _workerId,
              );
            }
            await _accountStore.enqueueSnapshot(account.localAccountId);
            continue;
          }

          for (final op in matching) {
            await _accountStore.removeOutboxOperation(
              localAccountId: account.localAccountId,
              operationId: op['id']! as String,
              workerId: _workerId,
            );
          }
        } catch (error, stack) {
          final failure = classifyBackupFailure(
            error,
            stackTrace: stack,
          );
          final nowMicros = DateTime.now().microsecondsSinceEpoch;
          // Connectivity is only advisory. A connection being absent must not
          // mask a more specific App Check, auth, rules, or cloud-state error.
          final state = failure.category ==
                  BackupFailureCategory.networkUnavailable
              ? 'waitingForConnection'
              : 'failed';

          await _accountStore.setBackupState(
            account.localAccountId,
            state,
          );

          for (final op in matching) {
            final attempts = ((op['attempts'] as int?) ?? 0) + 1;
            final backoffSeconds = min(3600, 1 << min(attempts, 10));
            final next = DateTime.now().add(
              Duration(seconds: backoffSeconds),
            );
            await _accountStore.markOutboxRetry(
              localAccountId: account.localAccountId,
              operationId: op['id']! as String,
              workerId: _workerId,
              attempts: attempts,
              error: failure.message,
              failureCategory: failure.category.name,
              lastAttemptMicros: nowMicros,
              nextAttemptMicros: next.microsecondsSinceEpoch,
            );
          }

        }
      }
    } finally {
      _running = false;
    }
  }

  Future<bool> retryNow({
    Future<void> Function(int processed, int total)? onProgress,
  }) async {
    if (_running) return false;

    final account = await _accountStore.activeAccount();
    if (account == null ||
        !account.isGoogle ||
        !account.cloudBackupEnabled ||
        account.firebaseUid == null ||
        account.firebaseUid!.isEmpty) {
      return false;
    }

    await _accountStore.prepareBackupRetry(account.localAccountId);
    await runOnce(onProgress: onProgress);
    return true;
  }

  bool _isAppCheckFailureCategory(String? category) {
    return category == BackupFailureCategory.appCheckInitializationFailed.name ||
        category == BackupFailureCategory.appCheckTokenUnavailable.name ||
        category == BackupFailureCategory.appCheckRejected.name;
  }

  Future<bool> _activeAccountStillMatches({
    required String localAccountId,
    required String? firebaseUid,
    required int cloudGeneration,
    required bool cloudBackupEnabled,
  }) async {
    final active = await _accountStore.activeAccount();
    return active != null &&
        active.localAccountId == localAccountId &&
        active.firebaseUid == firebaseUid &&
        active.cloudGeneration == cloudGeneration &&
        active.cloudBackupEnabled &&
        cloudBackupEnabled;
  }

  Future<String?> _resolveFirebaseUid() async {
    final provider = _currentFirebaseUidProvider;
    if (provider != null) {
      return provider();
    }

    final initialization = await _firebase.initializeDetailed();
    if (!initialization.firebaseCoreInitialized) {
      throw const BackupFailure(
        category: BackupFailureCategory.firebaseInitializationFailed,
        message: 'Firebase Core is not initialized.',
      );
    }

    if (!initialization.appCheckInitialized) {
      throw const BackupFailure(
        category: BackupFailureCategory.appCheckInitializationFailed,
        message: 'Firebase App Check is not initialized.',
      );
    }

    final current = _firebase.auth.currentUser;
    if (current != null) return current.uid;

    final authService = _authService;
    if (authService == null) return null;

    final identity = await authService.attemptLightweightAuthentication();
    return identity?.uid;
  }
}
