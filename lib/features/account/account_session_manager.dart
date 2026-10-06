import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics/diagnostics.dart';

import '../../data/local/account_local_store.dart';
import '../../data/remote/firebase_backup_service.dart';
import '../../data/remote/firebase_reconciliation_service.dart';
import '../../data/remote/firebase_services.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/entities/user_profile.dart';

class AccountSessionManager extends ChangeNotifier {
  AccountSessionManager({
    required AccountLocalStore accountStore,
    required FirebaseServices firebase,
    required GoogleFirebaseAuthService auth,
    required FirebaseBackupService backup,
    required FirebaseReconciliationService reconciliation,
    this.onActiveLocalAccountChanged,
  })  : _accountStore = accountStore,
        _firebase = firebase,
        _auth = auth,
        _backup = backup,
        _reconciliation = reconciliation;

  final AccountLocalStore _accountStore;
  final FirebaseServices _firebase;
  final GoogleFirebaseAuthService _auth;
  final FirebaseBackupService _backup;
  final FirebaseReconciliationService _reconciliation;
  final void Function(String?)? onActiveLocalAccountChanged;

  AccountSessionState _state = const AccountSessionState.loading();
  bool _initialized = false;
  Future<void>? _initializationFuture;
  Future<void>? _startupRestoreFuture;
  int _operationEpoch = 0;

  AccountSessionState get state => _state;
  String? get activeLocalAccountId => _state.activeLocalAccountId;
  LocalAccount? get activeAccount => _state.activeAccount;
  bool get initialChoiceRequired => _state.initialChoiceRequired;

  /// Completes when the optional startup Google restoration has finished.
  /// This remains non-blocking for production startup routing.
  Future<void> get startupRestoreFuture =>
      _startupRestoreFuture ?? Future<void>.value();

  static const Duration _startupAuthTimeout = Duration(seconds: 5);
  static const Duration _startupCloudTimeout = Duration(seconds: 8);

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final running = _initializationFuture;
    if (running != null) return running;

    final future = _initializeLocalState();
    _initializationFuture = future;
    return future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLegacyProfile = prefs.getString(UserProfile.storageKey);
      UserProfile? legacyProfile;
      if (rawLegacyProfile != null) {
        try {
          final decoded = jsonDecode(rawLegacyProfile);
          if (decoded is Map) {
            legacyProfile =
                UserProfile.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }

      // Local account/session restoration is the first source of truth.
      await _accountStore.ensureInitialized(
        hasLegacyProfile: rawLegacyProfile != null,
        hasLegacyQaza:
            await _accountStore.hasAnyQaza(UserProfile.localLedgerUserId),
        legacyProfile: legacyProfile,
      );

      var account = await _accountStore.activeAccount();
      var initialChoice = await _accountStore.initialChoiceRequired();
      final migrationState = await _accountStore.migrationState();
      final terminalMigrationState = migrationState == 'none' ||
          migrationState == 'completed' ||
          migrationState == 'failed';

      // Interrupted account migrations must be recovered before exposing
      // account-scoped data. This is a safety boundary, not a performance
      // optimization.
      if (!terminalMigrationState) {
        await _recoverInterruptedMigrationAtStartup(
          migrationState: migrationState,
        );
        account = await _accountStore.activeAccount();
        initialChoice = await _accountStore.initialChoiceRequired();
      }

      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: account?.localAccountId,
          activeAccount: account,
          initialChoiceRequired: initialChoice,
          migrationState: await _accountStore.migrationState(),
          restoreState: 'local_restored',
        ),
      );
      _initialized = true;

      final startupEpoch = _operationEpoch;
      if (account?.isGoogle == true) {
        _startupRestoreFuture = _restoreExistingGoogleInBackground(
          account: account!,
          startupEpoch: startupEpoch,
        );
        unawaited(_startupRestoreFuture!);
      }
    } catch (error, stack) {
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.error,
          activeLocalAccountId: null,
          activeAccount: null,
          initialChoiceRequired: false,
          migrationState: 'failed',
          restoreState: 'failed',
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _recoverInterruptedMigrationAtStartup({
    required String migrationState,
  }) async {
    try {
      final firebaseAvailable = await _firebase
          .initialize()
          .timeout(_startupAuthTimeout, onTimeout: () => false);
      if (firebaseAvailable) {
        final identity = await _auth
            .attemptLightweightAuthentication(timeout: _startupAuthTimeout)
            .timeout(_startupAuthTimeout, onTimeout: () => null);
        if (identity != null) {
          final local = await _accountStore.findGoogleByUid(identity.uid);
          if (local != null) {
            await _resumeInterruptedMigration(identity.uid, identity.email);
            return;
          }
        }
      }

      // No recoverable Firebase identity is available. Use the existing local
      // migration rollback path rather than exposing a migrating partition.
      final migratingId = await _accountStore.migratingGoogleAccount();
      if (migratingId != null) {
        await _accountStore.rollbackGoogleMigration(migratingId);
      } else if (migrationState != 'none') {
        await _accountStore.setMigrationState('failed');
      }
    } catch (error, stack) {
      // Preserve fail-safe behavior: attempt the existing durable rollback
      // path before surfacing the local session.
      try {
        final migratingId = await _accountStore.migratingGoogleAccount();
        if (migratingId != null) {
          await _accountStore.rollbackGoogleMigration(migratingId);
        }
        await _accountStore.setMigrationState('failed');
      } catch (_) {
        _setState(
          AccountSessionState(
            phase: AccountSessionPhase.error,
            activeLocalAccountId: null,
            activeAccount: null,
            initialChoiceRequired: false,
            migrationState: 'failed',
            restoreState: 'failed',
            message: 'Interrupted account migration recovery failed.',
          ),
        );
        return;
      }
      DebugDiagnostics().recordFailure(
        DiagnosticArea.startup,
        'interrupted_migration_recovered_after_failure',
        error,
        stack: stack,
      );
    }
  }

  Future<void> _restoreExistingGoogleInBackground({
    required LocalAccount account,
    required int startupEpoch,
  }) async {
    final uid = account.firebaseUid;
    if (uid == null) return;

    try {
      final initialized = await _firebase
          .initialize()
          .timeout(_startupAuthTimeout, onTimeout: () => false);
      if (!initialized) return;

      final identity = await _auth
          .attemptLightweightAuthentication(timeout: _startupAuthTimeout)
          .timeout(_startupAuthTimeout, onTimeout: () => null);
      if (identity == null || identity.uid != uid) return;
      if (!await _startupRestoreStillActive(
        startupEpoch,
        account.localAccountId,
      )) {
        return;
      }

      await _reconciliation
          .restore(localAccountId: account.localAccountId, uid: uid)
          .timeout(_startupCloudTimeout);

      if (!await _startupRestoreStillActive(
        startupEpoch,
        account.localAccountId,
      )) {
        return;
      }
      await _refresh();
    } catch (error, stack) {
      // The local Google partition remains authoritative when background
      // Firebase/cloud reconciliation is unavailable.
      DebugDiagnostics().recordFailure(
        DiagnosticArea.startup,
        'background_google_reconciliation_failed',
        error,
        stack: stack,
      );
    }
  }

  Future<bool> _startupRestoreStillUnselected(int startupEpoch) async {
    if (startupEpoch != _operationEpoch) return false;
    if (_state.activeLocalAccountId != null) return false;

    final activeId = await _accountStore.activeLocalAccountId();
    if (startupEpoch != _operationEpoch) return false;
    final choiceRequired = await _accountStore.initialChoiceRequired();
    return activeId == null && choiceRequired;
  }

  Future<bool> _startupRestoreStillActive(
    int startupEpoch,
    String accountId,
  ) async {
    if (startupEpoch != _operationEpoch) return false;
    if (_state.activeLocalAccountId != accountId) return false;
    return await _accountStore.activeLocalAccountId() == accountId;
  }

  Future<void> continueAsGuest() async {
    final operationEpoch = ++_operationEpoch;
    await _accountStore.ensureGuestActive();
    _ensureOperationEpochCurrent(operationEpoch);
    await _accountStore.setInitialChoiceRequired(false);
    await _refresh();
  }

  Future<void> connectGoogle() async {
    if (_state.phase == AccountSessionPhase.connecting) return;
    final operationEpoch = ++_operationEpoch;
    _setBusy(AccountSessionPhase.connecting);
    final previous = await _accountStore.activeAccount();
    final operationAccountId = previous?.localAccountId;
    final guestWasActive = previous?.isGuest == true;
    var createdTarget = false;
    String? createdTargetId;

    try {
      await _accountStore.setMigrationState('prepared');

      // Authentication returns a Firebase identity; no Firestore/App Check
      // work is part of this foreground critical path.
      final identity = await _auth.signInIdentity();
      await _accountStore.setMigrationState('authenticated');
      _ensureOperationCurrent(operationEpoch, operationAccountId);
      _ensureActiveAccount(
        operationAccountId,
        identity.uid,
        allowGuestUid: true,
      );

      var target = await _accountStore.findGoogleByUid(identity.uid);

      if (guestWasActive) {
        await _accountStore.setMigrationState('localStateSnapshotSecured');
        final targetId = await _accountStore.cloneGuestToGoogle(
          firebaseUid: identity.uid,
          email: identity.email,
        );
        target = await _accountStore.getAccount(targetId);
        await _accountStore.setMigrationState('targetPartitionPrepared');
      } else if (target == null) {
        final targetId = await _accountStore.createGooglePartition(
          firebaseUid: identity.uid,
          email: identity.email,
        );
        createdTarget = true;
        createdTargetId = targetId;
        target = await _accountStore.getAccount(targetId);
      }

      if (target == null) {
        throw StateError('Unable to create Google partition.');
      }
      _ensureOperationCurrent(operationEpoch, operationAccountId);

      // Commit local account state before any optional cloud operation.
      if (guestWasActive && previous != null) {
        if (target.localAccountId == previous.localAccountId) {
          await _accountStore.activate(target.localAccountId);
        } else {
          await _accountStore.finalizeGuestMigration(
            guestLocalAccountId: previous.localAccountId,
            googleLocalAccountId: target.localAccountId,
          );
        }
      } else {
        await _accountStore.activate(target.localAccountId);
      }
      await _accountStore.setInitialChoiceRequired(false);
      await _accountStore.completeMigration();

      _ensureOperationCurrent(operationEpoch, operationAccountId);
      target =
          await _accountStore.getAccount(target.localAccountId) ?? target;
      await _refresh();

      // Cloud bootstrap/reconciliation is explicitly post-activation.
      unawaited(
        _syncGoogleCloudAfterActivation(
          localAccountId: target.localAccountId,
          uid: identity.uid,
          operationEpoch: operationEpoch,
        ),
      );
    } catch (error, stack) {
      if (operationEpoch != _operationEpoch) return;

      LocalAccount? restoredActive;
      var choiceRequired = previous == null;
      try {
        await _accountStore.setMigrationState('rollbackRequired');
        if (createdTarget && createdTargetId != null) {
          await _accountStore.deleteLocalAccount(createdTargetId);
        }
        if (guestWasActive && previous != null) {
          await _accountStore.rollbackGoogleMigration(previous.localAccountId);
        } else if (previous == null) {
          await _accountStore.setInitialChoiceRequired(true);
        } else {
          choiceRequired = await _accountStore.initialChoiceRequired();
        }
      } catch (cleanupError, cleanupStack) {
        DebugDiagnostics().recordFailure(
          DiagnosticArea.startup,
          'google_connection_cleanup_failed',
          cleanupError,
          stack: cleanupStack,
        );
        if (previous == null) {
          choiceRequired = true;
          try {
            await _accountStore.setInitialChoiceRequired(true);
          } catch (_) {}
        }
      } finally {
        // Only genuine authentication/local failures reach this foreground
        // rollback. Post-activation cloud failures are handled separately.
        try {
          await _auth.signOut().timeout(const Duration(seconds: 5));
        } catch (_) {}

        try {
          await _accountStore.setMigrationState('failed');
        } catch (_) {}

        try {
          restoredActive = await _accountStore.activeAccount();
        } catch (_) {}

        if (previous == null) {
          choiceRequired = true;
        }

        _setState(
          AccountSessionState(
            phase: AccountSessionPhase.ready,
            activeLocalAccountId: restoredActive?.localAccountId,
            activeAccount: restoredActive,
            initialChoiceRequired: choiceRequired,
            migrationState: 'failed',
            restoreState: 'none',
            message: 'Google connection could not be completed.',
          ),
        );
      }

      DebugDiagnostics().recordFailure(
        DiagnosticArea.startup,
        'google_connection_failed',
        error,
        stack: stack,
      );
    }
  }

  Future<bool> _googleCloudOperationStillCurrent(
    int operationEpoch,
    String localAccountId,
    String uid,
  ) async {
    if (operationEpoch != _operationEpoch) return false;
    final active = await _accountStore.activeAccount();
    return active?.localAccountId == localAccountId &&
        active?.firebaseUid == uid &&
        active?.isGoogle == true;
  }

  Future<void> _syncGoogleCloudAfterActivation({
    required String localAccountId,
    required String uid,
    required int operationEpoch,
  }) async {
    try {
      if (!await _googleCloudOperationStillCurrent(
        operationEpoch,
        localAccountId,
        uid,
      )) {
        return;
      }

      final root = await _backup
          .readCloudRootResult(uid)
          .timeout(_startupCloudTimeout);

      if (!root.isAvailable) {
        DebugDiagnostics().recordFailure(
          DiagnosticArea.startup,
          'google_cloud_sync_deferred_unavailable',
          StateError('Cloud is temporarily unavailable.'),
        );
        return;
      }

      if (root.status == CloudRootStatus.missing) {
        await _accountStore.setRestoreState('none');
        final account = await _accountStore.getAccount(localAccountId);
        if (account == null) return;
        await _accountStore.setMigrationState('cloudBackupInProgress');
        await _backup
            .bootstrapAccount(
              localAccountId: localAccountId,
              uid: uid,
              generation: account.cloudGeneration,
            )
            .timeout(_startupCloudTimeout);
      } else {
        final result = await _reconciliation
            .restore(
              localAccountId: localAccountId,
              uid: uid,
            )
            .timeout(_startupCloudTimeout);

        if (result.skipped || result.partial) {
          return;
        }

        if (!await _googleCloudOperationStillCurrent(
          operationEpoch,
          localAccountId,
          uid,
        )) {
          return;
        }

        final account = await _accountStore.getAccount(localAccountId);
        if (account == null) return;
        await _backup
            .snapshotAccount(
              localAccountId: localAccountId,
              uid: uid,
              generation: account.cloudGeneration,
            )
            .timeout(_startupCloudTimeout);
      }

      if (await _googleCloudOperationStillCurrent(
        operationEpoch,
        localAccountId,
        uid,
      )) {
        await _refresh();
      }
    } catch (error, stack) {
      // Cloud failure after local activation never invalidates the local
      // Google session. Existing outbox/retry infrastructure remains
      // authoritative for later synchronization.
      DebugDiagnostics().recordFailure(
        DiagnosticArea.startup,
        'google_cloud_sync_failed_after_activation',
        error,
        stack: stack,
      );
    }
  }

  Future<void> _resumeInterruptedMigration(
    String uid,
    String? email,
  ) async {
    final active = await _accountStore.activeAccount();
    final target = await _accountStore.findGoogleByUid(uid);
    if (target == null) {
      if (active?.isGuest == true) {
        await _accountStore.setMigrationState('failed');
      }
      return;
    }

    final guestMigration = active?.isGuest == true &&
        active?.localAccountId != target.localAccountId;
    if (!guestMigration && active?.localAccountId != target.localAccountId) {
      throw StateError('Interrupted Google migration has ambiguous ownership.');
    }

    if (guestMigration) {
      await _accountStore.setMigrationState('localStateSnapshotSecured');
      await _accountStore.mergeGuestIntoGooglePartition(
        guestLocalAccountId: active!.localAccountId,
        googleLocalAccountId: target.localAccountId,
      );
      await _accountStore.setMigrationState('targetPartitionPrepared');
    }

    final root = await _backup.readCloudRoot(uid);
    await _accountStore.setMigrationState('cloudStateRead');

    if (root == null) {
      await _accountStore.setMigrationState('canonicalStateCalculated');
      await _accountStore.setMigrationState('localCanonicalCommit');
      await _accountStore.setMigrationState('cloudBackupInProgress');
      await _backup.bootstrapAccount(
        localAccountId: target.localAccountId,
        uid: uid,
        generation: target.cloudGeneration,
      );
    } else {
      await _accountStore.setMigrationState('canonicalStateCalculated');
      await _reconciliation.restore(
        localAccountId: target.localAccountId,
        uid: uid,
      );
      final refreshed =
          await _accountStore.getAccount(target.localAccountId) ?? target;
      await _accountStore.setMigrationState('localCanonicalCommit');
      await _accountStore.setMigrationState('cloudBackupInProgress');
      await _backup.snapshotAccount(
        localAccountId: refreshed.localAccountId,
        uid: uid,
        generation: refreshed.cloudGeneration,
      );
    }

    if (guestMigration && active != null) {
      await _accountStore.finalizeGuestMigration(
        guestLocalAccountId: active.localAccountId,
        googleLocalAccountId: target.localAccountId,
      );
    } else {
      await _accountStore.activate(target.localAccountId);
    }
    await _accountStore.completeMigration();
  }

  Future<void> _resumeInterruptedGoogle(
    String uid,
    String? email,
  ) async {
    final targetId = await _accountStore.createGooglePartition(
      firebaseUid: uid,
      email: email,
    );
    final target = await _accountStore.getAccount(targetId);
    if (target == null) {
      throw StateError('Google recovery partition unavailable.');
    }

    try {
      final root = await _backup.readCloudRoot(uid);
      if (root == null) {
        await _backup.bootstrapAccount(
          localAccountId: target.localAccountId,
          uid: uid,
          generation: target.cloudGeneration,
        );
      } else {
        await _reconciliation.restore(
          localAccountId: target.localAccountId,
          uid: uid,
        );
      }
      await _accountStore.activate(target.localAccountId);
    } catch (_) {
      await _accountStore.deleteLocalAccount(target.localAccountId);
      await _auth.signOut();
    }
  }

  Future<void> _restoreExisting(LocalAccount account) async {
    if (account.firebaseUid == null) return;
    try {
      if (!account.cloudBackupEnabled) return;
      await _reconciliation.restore(
        localAccountId: account.localAccountId,
        uid: account.firebaseUid!,
      );
    } catch (_) {
      // Local Google data remains authoritative when cloud recovery fails.
    }
  }

  Future<void> signOut() async {
    final operationEpoch = ++_operationEpoch;
    final operationAccountId = activeLocalAccountId;
    await _auth.signOut();
    _ensureOperationCurrent(operationEpoch, operationAccountId);
    await _accountStore.ensureGuestActive();
    _ensureOperationCurrent(operationEpoch, operationAccountId);
    await _refresh();
  }

  Future<void> pauseBackup() async {
    final operationEpoch = ++_operationEpoch;
    final account = activeAccount;
    if (account == null || !account.isGoogle) return;
    await _accountStore.setBackupEnabled(account.localAccountId, false);
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _refresh();
  }

  Future<void> disconnect() async {
    final operationEpoch = ++_operationEpoch;
    final account = activeAccount;
    if (account == null || !account.isGoogle) return;
    await _accountStore.setBackupEnabled(account.localAccountId, false);
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _auth.disconnect();
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _accountStore.ensureGuestActive();
    await _refresh();
  }

  Future<void> enableBackup() async {
    final operationEpoch = ++_operationEpoch;
    final account = activeAccount;
    if (account == null || !account.isGoogle || account.firebaseUid == null) {
      return;
    }
    final root = await _backup.readCloudRoot(account.firebaseUid!);
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    var generation = account.cloudGeneration;
    if (root != null) {
      final remoteGeneration =
          (root['cloudGeneration'] as num?)?.toInt() ?? generation;
      if (remoteGeneration < account.cloudGeneration) {
        throw StateError(
          'Cloud generation is stale: local=' +
              account.cloudGeneration.toString() +
              ' remote=' +
              remoteGeneration.toString() +
              '.',
        );
      }
      generation = remoteGeneration;
      final state = root['datasetState'] as String? ?? 'empty';
      if (state == 'deleted') {
        final nextGeneration = generation + 1;
        await _backup.startNewCloudGeneration(
          uid: account.firebaseUid!,
          previousGeneration: generation,
          newGeneration: nextGeneration,
        );
        generation = nextGeneration;
      }
    }
    await _accountStore.setCloudGeneration(account.localAccountId, generation);
    await _accountStore.setBackupEnabled(account.localAccountId, true);
    final refreshed =
        await _accountStore.getAccount(account.localAccountId) ?? account;
    await _backup.bootstrapAccount(
      localAccountId: refreshed.localAccountId,
      uid: refreshed.firebaseUid!,
      generation: refreshed.cloudGeneration,
    );
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _refresh();
  }

  Future<void> deleteCloudData() async {
    final operationEpoch = ++_operationEpoch;
    final account = activeAccount;
    if (account == null || !account.isGoogle || account.firebaseUid == null) {
      return;
    }
    await _accountStore.setBackupEnabled(account.localAccountId, false);
    final nextGeneration = account.cloudGeneration + 1;
    await _backup.deleteCloudData(
      uid: account.firebaseUid!,
      expectedGeneration: account.cloudGeneration,
      newGeneration: nextGeneration,
    );
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _accountStore.setCloudGeneration(
      account.localAccountId,
      nextGeneration,
    );
    await _accountStore.clearBackupOperations(account.localAccountId);
    await _refresh();
  }

  Future<void> restoreNow() async {
    final operationEpoch = ++_operationEpoch;
    final account = activeAccount;
    if (account == null || !account.isGoogle || account.firebaseUid == null) return;
    await _reconciliation.restore(
      localAccountId: account.localAccountId,
      uid: account.firebaseUid!,
    );
    _ensureOperationCurrent(operationEpoch, account.localAccountId);
    await _refresh();
  }

  Future<void> _refresh() async {
    final account = await _accountStore.activeAccount();
    _setState(
      AccountSessionState(
        phase: AccountSessionPhase.ready,
        activeLocalAccountId: account?.localAccountId,
        activeAccount: account,
        initialChoiceRequired: await _accountStore.initialChoiceRequired(),
        migrationState: await _accountStore.migrationState(),
        restoreState: 'none',
      ),
    );
  }

  void _setBusy(AccountSessionPhase phase) {
    final current = _state;
    _setState(
      AccountSessionState(
        phase: phase,
        activeLocalAccountId: current.activeLocalAccountId,
        activeAccount: current.activeAccount,
        initialChoiceRequired: false,
        migrationState: current.migrationState,
        restoreState: current.restoreState,
      ),
    );
  }

  void _ensureOperationEpochCurrent(int operationEpoch) {
    if (operationEpoch != _operationEpoch) {
      throw StateError('Stale account operation result rejected.');
    }
  }

  void _ensureOperationCurrent(
    int operationEpoch,
    String? expectedAccountId,
  ) {
    if (operationEpoch != _operationEpoch ||
        activeLocalAccountId != expectedAccountId) {
      throw StateError('Stale account operation result rejected.');
    }
  }

  void _ensureActiveAccount(
    String? expectedAccountId,
    String uid, {
    bool allowGuestUid = false,
  }) {
    final active = _state.activeAccount;
    if (expectedAccountId != null &&
        active?.localAccountId != expectedAccountId) {
      throw StateError('Account changed during account operation.');
    }
    if (!allowGuestUid &&
        (active?.firebaseUid == null || active!.firebaseUid != uid)) {
      throw StateError('Firebase account changed during account operation.');
    }
  }

  void _setState(AccountSessionState value) {
    _state = value;
    onActiveLocalAccountChanged?.call(value.activeLocalAccountId);
    notifyListeners();
  }
}
