import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

import 'cloud_models.dart';
import 'cloud_state_store.dart';
import 'cloud_workmanager.dart';
import 'google_drive_store.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';
import 'sync_engine.dart';

class GoogleCloudAccountProvider implements CloudAccountProvider {
  GoogleCloudAccountProvider({
    required GoogleSignInGateway gateway,
    required CloudSyncStateStore state,
    required CloudSyncScheduler scheduler,
    this.serverClientId,
  })  : _gateway = gateway,
        _state = state,
        _scheduler = scheduler;

  final GoogleSignInGateway _gateway;
  final CloudSyncStateStore _state;
  final CloudSyncScheduler _scheduler;
  final String? serverClientId;

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async {
    try {
      final account = await _gateway.restoreLightweightAuthentication();
      if (account == null) {
        if (await _state.isCloudSyncEnabled()) {
          await _scheduler.disconnect();
        }
        return const CloudAccountSnapshot.disconnected();
      }

      await _state.setCloudSyncEnabled(true);
      if (await _state.isAutomaticSyncEnabled()) {
        await _scheduler.initializeAndSchedule(
          serverClientId: serverClientId,
        );
      }
      return CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        displayName: account.displayName,
        email: account.email,
      );
    } catch (error) {
      return CloudAccountSnapshot.failed(error.toString());
    }
  }

  @override
  Future<CloudAccountSnapshot> signIn() async {
    try {
      final account = await _gateway.authenticate();
      await _state.setCloudSyncEnabled(true);
      if (await _state.isAutomaticSyncEnabled()) {
        await _scheduler.initializeAndSchedule(
          serverClientId: serverClientId,
        );
      }
      return CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        displayName: account.displayName,
        email: account.email,
      );
    } catch (error) {
      return CloudAccountSnapshot.failed(error.toString());
    }
  }

  @override
  Future<void> disconnect() async {
    // The worker guard is persisted before OAuth sign-out can begin.
    await _scheduler.disconnect();
    await _gateway.signOut();
  }
}

class GoogleCloudSyncProvider implements CloudSyncProvider {
  GoogleCloudSyncProvider({
    required AppDatabase database,
    required GoogleSignInGateway gateway,
    required CloudSyncStateStore state,
    required CloudSyncScheduler scheduler,
    this.serverClientId,
  })  : _phase1 = LocalPhase1BackupSource(database),
        _gateway = gateway,
        _state = state,
        _scheduler = scheduler;

  final LocalPhase1BackupSource _phase1;
  final GoogleSignInGateway _gateway;
  final CloudSyncStateStore _state;
  final CloudSyncScheduler _scheduler;
  final String? serverClientId;
  bool _syncing = false;

  @override
  bool get isSupported => true;

  @override
  Future<CloudSyncSnapshot> status() async {
    final enabled = await _state.isCloudSyncEnabled();
    final automatic = await _state.isAutomaticSyncEnabled();
    return CloudSyncSnapshot(
      status: !enabled
          ? CloudSyncStatus.disconnected
          : (_syncing ? CloudSyncStatus.syncing : CloudSyncStatus.idle),
      automaticSyncEnabled: automatic,
      lastSuccessAt: await _state.lastSuccessfulSyncAt(),
      hasLocalRecoverySnapshot:
          (await _phase1.readRecoverySnapshot()) != null,
    );
  }

  @override
  Future<CloudSyncSnapshot> backupNow() async {
    if (!await _state.isCloudSyncEnabled()) {
      return await _snapshot(
        CloudSyncStatus.disconnected,
        message: 'Connect a Google account before backing up.',
      );
    }

    _syncing = true;
    try {
      return await _snapshotFromResult(
        await _engine().sync(allowInteractive: true),
      );
    } catch (error) {
      return await _snapshot(CloudSyncStatus.failed, message: error.toString());
    } finally {
      _syncing = false;
    }
  }

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async {
    try {
      if (enabled) {
        if (!await _state.isCloudSyncEnabled()) {
          return await _snapshot(
            CloudSyncStatus.disconnected,
            message: 'Connect a Google account before enabling automatic backup.',
          );
        }
        await _scheduler.initializeAndSchedule(
          serverClientId: serverClientId,
        );
      } else {
        await _scheduler.cancel();
      }
      return await status();
    } catch (error) {
      return await _snapshot(CloudSyncStatus.failed, message: error.toString());
    }
  }

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
  }) async {
    try {
      final result = await _engine().resolveConflict(
        conflict: _toAdapterConflict(conflict),
        decision: choice == CloudConflictChoice.keepLocal
            ? CloudConflictDecision.keepLocal
            : CloudConflictDecision.useRemote,
        confirmed: confirmed,
        allowInteractive: true,
      );
      return await _snapshotFromResult(result);
    } catch (error) {
      return await _snapshot(CloudSyncStatus.failed, message: error.toString());
    }
  }

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async {
    try {
      final result = await _engine().restoreLocalRecoverySnapshot(
        confirmed: confirmed,
      );
      return await _snapshotFromResult(result);
    } catch (error) {
      return await _snapshot(CloudSyncStatus.failed, message: error.toString());
    }
  }

  CloudSyncEngine _engine() => CloudSyncEngine(
        phase1: _phase1,
        remote: GoogleDriveAppDataStore(_gateway),
        state: _state,
      );

  CloudConflict _toAdapterConflict(CloudConflictInfo conflict) =>
      CloudConflict(
        localDeviceId: conflict.localDeviceId,
        localTimestamp: conflict.localTimestamp,
        localRevision: conflict.localRevision,
        localBaseBackupId: conflict.localBaseBackupId,
        remoteLineage: CloudLineage(
          deviceId: conflict.remoteDeviceId,
          backupId: conflict.remoteBackupId,
          baseBackupId: conflict.remoteBaseBackupId,
          dbRevision: conflict.remoteRevision,
          createdAt: conflict.remoteTimestamp.toUtc(),
        ),
        remoteTimestamp: conflict.remoteTimestamp,
        remoteVersion: conflict.remoteVersion,
        lastSyncedBackupId: conflict.lastSyncedBackupId,
      );

  Future<CloudSyncSnapshot> _snapshotFromResult(
    CloudSyncResult result,
  ) async {
    final status = switch (result.kind) {
      CloudSyncResultKind.noOp => CloudSyncStatus.synced,
      CloudSyncResultKind.uploaded => CloudSyncStatus.synced,
      CloudSyncResultKind.downloaded => CloudSyncStatus.synced,
      CloudSyncResultKind.conflict => CloudSyncStatus.conflict,
      CloudSyncResultKind.remoteMissing => CloudSyncStatus.failed,
      CloudSyncResultKind.skipped => CloudSyncStatus.disabled,
      CloudSyncResultKind.failed => CloudSyncStatus.failed,
    };

    if (status == CloudSyncStatus.synced &&
        result.kind != CloudSyncResultKind.noOp) {
      await _state.setLastSuccessfulSyncAt(DateTime.now().toUtc());
    }
    return await _snapshot(
      status,
      message: result.message,
      conflict: result.conflict == null
          ? null
          : _toCoreConflict(result.conflict!),
    );
  }

  CloudConflictInfo _toCoreConflict(CloudConflict conflict) =>
      CloudConflictInfo(
        localDeviceId: conflict.localDeviceId,
        localTimestamp: conflict.localTimestamp,
        localRevision: conflict.localRevision,
        localBaseBackupId: conflict.localBaseBackupId,
        remoteDeviceId: conflict.remoteLineage.deviceId,
        remoteTimestamp: conflict.remoteTimestamp,
        remoteRevision: conflict.remoteLineage.dbRevision,
        remoteBackupId: conflict.remoteLineage.backupId,
        remoteBaseBackupId: conflict.remoteLineage.baseBackupId,
        lastSyncedBackupId: conflict.lastSyncedBackupId,
        remoteVersion: conflict.remoteVersion,
      );

  Future<CloudSyncSnapshot> _snapshot(
    CloudSyncStatus status, {
    String? message,
    CloudConflictInfo? conflict,
  }) async =>
      CloudSyncSnapshot(
        status: status,
        automaticSyncEnabled: await _state.isAutomaticSyncEnabled(),
        lastSuccessAt: await _state.lastSuccessfulSyncAt(),
        message: message,
        conflict: conflict,
        hasLocalRecoverySnapshot:
            (await _phase1.readRecoverySnapshot()) != null,
      );
}
