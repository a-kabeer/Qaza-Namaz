import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_models.dart';
import 'cloud_state_store.dart';
import 'google_drive_store.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';
import 'sync_engine.dart';

const String cloudSyncWorkerTaskName = 'qaza_namaz_cloud_periodic_sync';
const String _scheduledFrequencyDaysKey =
    'qaza_cloud_adapter.scheduled_frequency_days_v1';

/// WorkManager may defer a run because of constraints, battery policy, or
/// other system limits. Unsupported custom intervals safely fall back to Daily.
Duration normalizeCloudSyncFrequency(Duration requested) {
  const daily = Duration(days: 1);
  const weekly = Duration(days: 7);
  const monthly = Duration(days: 30);
  if (requested == daily || requested == weekly || requested == monthly) {
    return requested;
  }
  return daily;
}

@pragma('vm:entry-point')
void initializeQazaCloudBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != cloudSyncWorkerTaskName) {
      return true;
    }

    final serverClientId = inputData?['server_client_id'] as String?;
    final state = SharedPreferencesCloudSyncStateStore();

    // Must run before AppDatabase opening, Google authorization or network work.
    if (!await state.isCloudSyncEnabled() ||
        !await state.isAutomaticSyncEnabled()) {
      return true;
    }

    final accountScopedState = state as CloudAccountScopedSyncStateStore;
    final accountId = await accountScopedState.activeAccountId();
    if (accountId == null || accountId.isEmpty) {
      // A legacy or disconnected installation must reconnect interactively.
      return true;
    }
    final operationState = accountScopedState.scopedToAccount(accountId);
    final databaseManager = DatabaseManager();
    final appDatabase = databaseManager.controlDatabase;
    final gateway = GoogleSignInGateway(serverClientId: serverClientId);
    var accountPinned = false;

    try {
      await databaseManager.initialize();
      final localWorkspaceId = googleLocalWorkspaceId(accountId);
      final startGeneration = await appDatabase.readSessionGeneration();
      if (await appDatabase.readActiveLocalAccountId() != localWorkspaceId) {
        // Never open an inactive workspace file from the background isolate.
        return true;
      }

      final registryRows = await appDatabase.customSelect(
        'SELECT db_file_name, db_layout, db_migration_state FROM local_accounts '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(localWorkspaceId)],
      ).get();
      if (registryRows.isEmpty) return true;
      final registry = registryRows.single;
      final expectedFileName =
          DatabaseManager.googleFileNameForWorkspaceId(localWorkspaceId);
      if (registry.read<String>('db_layout') != 'separate' ||
          registry.read<String>('db_migration_state') != 'committed' ||
          registry.read<String?>('db_file_name') != expectedFileName) {
        return true;
      }

      final outstandingOperations = await appDatabase.customSelect(
        '''SELECT 1 FROM workspace_operation_journal
           WHERE target_local_account_id = ?
             AND phase NOT IN ('committed', 'failed', 'cleaned')
           LIMIT 1''',
        variables: [Variable<String>(localWorkspaceId)],
      ).get();
      if (outstandingOperations.isNotEmpty) return true;

      final workspaceDatabase =
          await databaseManager.databaseForWorkspace(localWorkspaceId);
      final phase1 = LocalPhase1BackupSource(
        workspaceDatabase,
        localAccountId: localWorkspaceId,
        databaseManager: databaseManager,
      );
      if (await gateway.accountIdForAuthorization() != accountId) {
        // A foreground account switch can temporarily change the persisted
        // identity binding. Stop without marking either account as broken.
        return true;
      }

      // Verify the Drive grant and its returned account before the engine reads
      // this account's cursor or pending conflict. This path never shows UI.
      final authorization = await gateway.authorizeDrive(
        allowInteractive: false,
      );
      authorization?.close();
      if (await accountScopedState.activeAccountId() != accountId ||
          await gateway.accountIdForAuthorization() != accountId) {
        return true;
      }

      gateway.pinAccountForOperation(accountId);
      accountPinned = true;
      if (await workspaceDatabase.isWorkspaceCloudUploadBlocked(
        localWorkspaceId,
      )) {
        // This account was left local-only because Drive state was uncertain.
        // A scheduled job must never overwrite a backup before an explicit,
        // successful foreground reconciliation has cleared the block.
        return true;
      }
      final remote = GoogleDriveAppDataStore(gateway);
      final engine = CloudSyncEngine(
        phase1: phase1,
        remote: remote,
        state: operationState,
      );
      final result = await engine.sync(allowInteractive: false);
      if (!await appDatabase.isCurrentWorkspaceGeneration(
        localAccountId: localWorkspaceId,
        generation: startGeneration,
      )) {
        // The remote may have accepted the captured snapshot while the user
        // switched accounts. Do not mark it clean; reconcile by hash next time.
        await workspaceDatabase.writeWorkspaceSyncState(
          localWorkspaceId,
          'pending',
          localRevision: await workspaceDatabase.readWorkspaceRevision(
            localWorkspaceId,
          ),
          remoteAccountId: accountId,
        );
        return true;
      }
      if (result.authorizationFailed) {
        // Drive rejected the stored authorization itself (HTTP 401). Park
        // the workspace so the upload block at the top of this worker stops
        // future scheduled runs, and ask the foreground to reconnect rather
        // than letting WorkManager retry a hopeless credential.
        await workspaceDatabase.writeWorkspaceSyncState(
          localWorkspaceId,
          'needs_sign_in',
          localRevision: await workspaceDatabase.readWorkspaceRevision(
            localWorkspaceId,
          ),
          remoteAccountId: accountId,
        );
        await operationState.setReconnectRequired(true);
        return true;
      }
      if (result.kind == CloudSyncResultKind.uploaded ||
          result.kind == CloudSyncResultKind.downloaded) {
        await operationState.setLastSuccessfulSyncAt(DateTime.now().toUtc());
      }

      // A missing token/account in a background isolate must never trigger an
      // account picker. Persist reconnect state only in the account namespace
      // captured at the beginning of this run.
      if (result.kind == CloudSyncResultKind.skipped &&
          (result.message?.toLowerCase().contains('authorization') ?? false)) {
        await operationState.setReconnectRequired(true);
      } else if (result.kind != CloudSyncResultKind.skipped &&
          result.kind != CloudSyncResultKind.failed &&
          result.kind != CloudSyncResultKind.remoteMissing) {
        await operationState.setReconnectRequired(false);
      }

      // A conflict needs a user choice, not an automatic WorkManager retry.
      return result.kind != CloudSyncResultKind.failed &&
          result.kind != CloudSyncResultKind.remoteMissing;
    } on CloudAuthorizationUnavailable catch (error) {
      final message = error.message.toLowerCase();
      if (!message.contains('changed') &&
          !message.contains('different') &&
          !message.contains('does not match')) {
        await operationState.setReconnectRequired(true);
      }
      return true;
    } on CloudAdapterException {
      return true;
    } catch (_) {
      return false;
    } finally {
      if (accountPinned) gateway.releaseAccountOperation(accountId);
      await databaseManager.close();
    }
  });
}

class CloudSyncScheduler {
  CloudSyncScheduler({Workmanager? workmanager, CloudSyncStateStore? state})
    : _workmanager = workmanager ?? Workmanager(),
      _state = state ?? SharedPreferencesCloudSyncStateStore();

  final Workmanager _workmanager;
  final CloudSyncStateStore _state;
  bool _initialized = false;

  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {
    if (!await _state.isCloudSyncEnabled()) {
      throw const CloudAdapterException(
        'Connect a Google account before scheduling automatic backup.',
      );
    }
    await _state.setAutomaticSyncEnabled(true);
    try {
      if (!_initialized) {
        await _workmanager.initialize(initializeQazaCloudBackgroundDispatcher);
        _initialized = true;
      }

      // Avoid resetting the next run every time the Account screen restores
      // status. Re-register only for a new schedule, or a cadence change.
      final normalized = normalizeCloudSyncFrequency(frequency);
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getInt(_scheduledFrequencyDaysKey) == normalized.inDays) {
        return;
      }
      final inputData = <String, dynamic>{
        if (serverClientId != null) 'server_client_id': serverClientId,
      };

      await _workmanager.registerPeriodicTask(
        cloudSyncWorkerTaskName,
        cloudSyncWorkerTaskName,
        frequency: normalized,
        inputData: inputData,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      await preferences.setInt(_scheduledFrequencyDaysKey, normalized.inDays);
    } catch (_) {
      // Keep the user's intended preference intact if scheduling fails. The
      // caller receives the registration error and can surface it in the UI.
      rethrow;
    }
  }

  Future<void> _cancelScheduledWork() async {
    try {
      await _workmanager.cancelByUniqueName(cloudSyncWorkerTaskName);
    } finally {
      // A subsequent re-enable must register work even if cancellation throws.
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_scheduledFrequencyDaysKey);
    }
  }

  Future<void> cancel() async {
    // Persist the disabled state before cancelling unique periodic work.
    await _state.setAutomaticSyncEnabled(false);
    await _cancelScheduledWork();
  }

  Future<void> disconnect() async {
    // The hard stop is durable before cancellation or account sign-out.
    await _state.setCloudSyncEnabled(false);
    // The cloud flag hard-stops workers; preserve the user's saved preference
    // so reconnecting does not silently change their choice.
    await _cancelScheduledWork();
  }
}
