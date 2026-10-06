
import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'firebase_backup_service.dart';
import 'firebase_services.dart';
import '../local/account_local_store.dart';

class FirebaseBackupWorker {
  FirebaseBackupWorker({
    required FirebaseServices firebase,
    required AccountLocalStore accountStore,
    required FirebaseBackupService backupService,
    Future<String?> Function()? currentFirebaseUidProvider,
  })  : _firebase = firebase,
        _accountStore = accountStore,
        _backup = backupService,
        _currentFirebaseUidProvider = currentFirebaseUidProvider;

  final FirebaseServices _firebase;
  final AccountLocalStore _accountStore;
  final FirebaseBackupService _backup;
  final Future<String?> Function()? _currentFirebaseUidProvider;
  final String _workerId = 'worker_${Random.secure().nextInt(1 << 30)}';
  bool _running = false;

  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    try {
      final account = await _accountStore.activeAccount();
      if (account == null || !account.isGoogle || !account.cloudBackupEnabled) {
        return;
      }
      final uid = account.firebaseUid;
      if (uid == null || uid.isEmpty) return;

      final currentUser = await (_currentFirebaseUidProvider?.call() ??
          _currentFirebaseUserId());
      if (currentUser != uid) return;

      final now = DateTime.now().microsecondsSinceEpoch;
      final status = await _accountStore.readBackupStatus(account.localAccountId);
      if (status.currentRevision > status.acknowledgedRevision) {
        await _accountStore.enqueueSnapshot(account.localAccountId);
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
          .map((op) =>
              (op['cloud_generation'] as int?) ?? account.cloudGeneration)
          .toSet();

      for (final generation in generations) {
        final matching = claimed.where(
          (item) =>
              ((item['cloud_generation'] as int?) ?? generation) == generation,
        );

        if (generation != account.cloudGeneration) {
          for (final op in matching) {
            await _accountStore.removeOutboxOperation(
              localAccountId: account.localAccountId,
              operationId: op['id']! as String,
              workerId: _workerId,
            );
          }
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
          );
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
              final attempts = (op['attempts'] as int?) ?? 0;
              await _accountStore.markOutboxRetry(
                localAccountId: account.localAccountId,
                operationId: op['id']! as String,
                workerId: _workerId,
                attempts: attempts,
                error: '',
                nextAttemptMicros: DateTime.now().microsecondsSinceEpoch,
              );
            }
            continue;
          }
          for (final op in matching) {
            await _accountStore.removeOutboxOperation(
              localAccountId: account.localAccountId,
              operationId: op['id']! as String,
              workerId: _workerId,
            );
          }
        } catch (error) {
          try {
            final connectivity = await Connectivity().checkConnectivity();
            await _accountStore.setBackupState(
              account.localAccountId,
              connectivity.contains(ConnectivityResult.none)
                  ? 'waitingForConnection'
                  : 'failed',
            );
          } catch (_) {
            await _accountStore.setBackupState(
              account.localAccountId,
              'failed',
            );
          }
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
              error: error.toString().replaceFirst('Exception: ', ''),
              nextAttemptMicros: next.microsecondsSinceEpoch,
            );
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<String?> _currentFirebaseUserId() async {
    if (!await _firebase.initialize()) return null;
    return _firebase.auth.currentUser?.uid;
  }
}
