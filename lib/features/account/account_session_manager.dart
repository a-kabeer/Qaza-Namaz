
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _operationEpoch = 0;

  AccountSessionState get state => _state;
  String? get activeLocalAccountId => _state.activeLocalAccountId;
  LocalAccount? get activeAccount => _state.activeAccount;
  bool get initialChoiceRequired => _state.initialChoiceRequired;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
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

      await _accountStore.ensureInitialized(
        hasLegacyProfile: rawLegacyProfile != null,
        hasLegacyQaza:
            await _accountStore.hasAnyQaza(UserProfile.localLedgerUserId),
        legacyProfile: legacyProfile,
      );

      final account = await _accountStore.activeAccount();
      final initialChoice = await _accountStore.initialChoiceRequired();
      final migrationState = await _accountStore.migrationState();
      if (account != null) {
        _setState(
          AccountSessionState(
            phase: AccountSessionPhase.ready,
            activeLocalAccountId: account.localAccountId,
            activeAccount: account,
            initialChoiceRequired: initialChoice,
            migrationState: migrationState,
            restoreState: 'none',
          ),
        );
      }

      try {
        // A fresh Guest-only installation has no reason to initialize Firebase,
        // Google Sign-In, or App Check during startup. Google connection can
        // initialize the cloud stack on demand later.
        if (await _accountStore.hasAnyGoogleAccount() &&
            await _firebase.initialize()) {
          final firebaseUser = _auth.currentUser;
          final terminalMigrationState =
              migrationState == 'none' ||
              migrationState == 'completed' ||
              migrationState == 'failed';

          if (firebaseUser != null) {
            if (!terminalMigrationState) {
              await _resumeInterruptedMigration(
                firebaseUser.uid,
                firebaseUser.email,
              );
            } else {
              final local =
                  await _accountStore.findGoogleByUid(firebaseUser.uid);
              if (local != null) {
                if (local.lifecycleState == AccountLifecycleState.migrating) {
                  await _resumeInterruptedMigration(
                    firebaseUser.uid,
                    firebaseUser.email,
                  );
                } else {
                  await _accountStore.activate(local.localAccountId);
                  await _restoreExisting(local);
                }
              } else if (account == null || account.isGuest) {
                await _resumeInterruptedGoogle(
                  firebaseUser.uid,
                  firebaseUser.email,
                );
              } else {
                await _auth.signOut();
              }
            }
          } else if (!terminalMigrationState) {
            // No Firebase session remains after an interrupted in-place
            // conversion. The converted local account can safely be restored
            // to Guest because no second partition is created for the normal
            // Guest -> Google migration path.
            final migratingId = await _accountStore.migratingGoogleAccount();
            if (migratingId != null) {
              await _accountStore.rollbackGoogleMigration(migratingId);
            }
          }
        }
      } catch (error) {
        if (_state.activeAccount != null) {
          _setState(
            AccountSessionState(
              phase: AccountSessionPhase.ready,
              activeLocalAccountId: _state.activeLocalAccountId,
              activeAccount: _state.activeAccount,
              initialChoiceRequired: false,
              migrationState: await _accountStore.migrationState(),
              restoreState: 'failed',
              message: error.toString(),
            ),
          );
        }
      }

      final refreshed = await _accountStore.activeAccount();
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: refreshed?.localAccountId,
          activeAccount: refreshed,
          initialChoiceRequired:
              await _accountStore.initialChoiceRequired(),
          migrationState: await _accountStore.migrationState(),
          restoreState: 'none',
        ),
      );
    } catch (error) {
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

  Future<void> continueAsGuest() async {
    final operationEpoch = ++_operationEpoch;
    final operationAccountId = _state.activeLocalAccountId;
    await _accountStore.ensureGuestActive();
    _ensureOperationCurrent(operationEpoch, activeLocalAccountId);
    await _accountStore.setInitialChoiceRequired(false);
    await _refresh();
  }

  Future<void> connectGoogle() async {
    _setBusy(AccountSessionPhase.connecting);
    final operationEpoch = ++_operationEpoch;
    final previous = await _accountStore.activeAccount();
    final operationAccountId = previous?.localAccountId;
    final guestWasActive = previous?.isGuest == true;
    var createdTarget = false;
    String? createdTargetId;

    try {
      await _accountStore.setMigrationState('prepared');
      final user = await _auth.signIn();
      if (user == null) {
        throw StateError('Google authentication returned no user.');
      }

      await _accountStore.setMigrationState('authenticated');
      _ensureOperationCurrent(operationEpoch, operationAccountId);
      _ensureActiveAccount(
        operationAccountId,
        user.uid,
        allowGuestUid: true,
      );
      var target = await _accountStore.findGoogleByUid(user.uid);

      if (guestWasActive) {
        await _accountStore.setMigrationState('localStateSnapshotSecured');
        final targetId = await _accountStore.cloneGuestToGoogle(
          firebaseUid: user.uid,
          email: user.email,
        );
        target = await _accountStore.getAccount(targetId);
        await _accountStore.setMigrationState('targetPartitionPrepared');
      } else if (target == null) {
        final targetId = await _accountStore.createGooglePartition(
          firebaseUid: user.uid,
          email: user.email,
        );
        createdTarget = true;
        createdTargetId = targetId;
        target = await _accountStore.getAccount(targetId);
      }

      if (target == null) {
        throw StateError('Unable to create Google partition.');
      }
      _ensureOperationCurrent(operationEpoch, operationAccountId);

      await _accountStore.setInitialChoiceRequired(false);

      final root = await _backup.readCloudRoot(user.uid);
      await _accountStore.setMigrationState('cloudStateRead');

      if (root == null) {
        await _accountStore.setMigrationState('canonicalStateCalculated');
        await _accountStore.setMigrationState('localCanonicalCommit');
        await _accountStore.setMigrationState('cloudBackupInProgress');
        await _backup.bootstrapAccount(
          localAccountId: target.localAccountId,
          uid: user.uid,
          generation: target.cloudGeneration,
        );
      } else {
        await _accountStore.setMigrationState('canonicalStateCalculated');
        await _reconciliation.restore(
          localAccountId: target.localAccountId,
          uid: user.uid,
        );
        _ensureOperationCurrent(operationEpoch, operationAccountId);
        final refreshedTarget =
            await _accountStore.getAccount(target.localAccountId) ?? target;
        await _accountStore.setMigrationState('localCanonicalCommit');
        await _accountStore.setMigrationState('cloudBackupInProgress');
        await _backup.snapshotAccount(
          localAccountId: refreshedTarget.localAccountId,
          uid: user.uid,
          generation: refreshedTarget.cloudGeneration,
        );
        _ensureOperationCurrent(operationEpoch, operationAccountId);
        target = refreshedTarget;
      }

      if (guestWasActive && previous != null) {
        if (target.localAccountId == previous.localAccountId) {
          await _accountStore.activate(target.localAccountId);
          await _accountStore.setMigrationState('completed');
        } else {
          await _accountStore.finalizeGuestMigration(
            guestLocalAccountId: previous.localAccountId,
            googleLocalAccountId: target.localAccountId,
          );
        }
      } else {
        await _accountStore.activate(target.localAccountId);
        await _accountStore.setMigrationState('completed');
      }
      await _accountStore.completeMigration();
      _ensureOperationCurrent(operationEpoch, operationAccountId);
      await _refresh();
    } catch (error) {
      if (operationEpoch != _operationEpoch) return;
      await _accountStore.setMigrationState('rollbackRequired');
      if (createdTarget && createdTargetId != null) {
        await _accountStore.deleteLocalAccount(createdTargetId);
      }
      if (guestWasActive && previous != null) {
        await _accountStore.rollbackGoogleMigration(previous.localAccountId);
      } else if (previous == null) {
        await _accountStore.ensureGuestActive();
      }
      await _auth.signOut();
      await _accountStore.setMigrationState('failed');
      final restoredActive = await _accountStore.activeAccount();
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: restoredActive?.localAccountId,
          activeAccount: restoredActive,
          initialChoiceRequired: false,
          migrationState: 'failed',
          restoreState: 'none',
          message: 'Google connection could not be completed.',
        ),
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

    final guestMigration =
        active?.isGuest == true &&
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
    if (target == null) throw StateError('Google recovery partition unavailable.');

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
    if (account == null || !account.isGoogle || account.firebaseUid == null) return;
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
        initialChoiceRequired:
            await _accountStore.initialChoiceRequired(),
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
