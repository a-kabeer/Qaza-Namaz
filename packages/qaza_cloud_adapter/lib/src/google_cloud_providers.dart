import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) : _gateway = gateway,
       _state = state,
       _scheduler = scheduler;

  final GoogleSignInGateway _gateway;
  final CloudSyncStateStore _state;
  final CloudSyncScheduler _scheduler;
  final String? serverClientId;

  static const _cachedDisplayNameKey =
      'qaza_cloud_adapter.cached_account_display_name_v1';
  static const _cachedEmailKey = 'qaza_cloud_adapter.cached_account_email_v1';
  static const _cachedPhotoUrlKey =
      'qaza_cloud_adapter.cached_account_photo_url_v1';

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async {
    try {
      if (!await _state.isCloudSyncEnabled()) {
        return const CloudAccountSnapshot.disconnected();
      }
      // An unset preference means no user choice has been saved. Default to
      // ON for connected accounts, but preserve an explicit persisted OFF.
      if (!await _state.hasAutomaticSyncPreference()) {
        await _state.setAutomaticSyncEnabled(true);
      }
      if (await _state.isAutomaticSyncEnabled()) {
        await _scheduler.initializeAndSchedule(
          frequency: (await _state.backupFrequency()).interval,
          serverClientId: serverClientId,
        );
      }

      final account = await _gateway.currentAccount();
      try {
        // Connection is reported only after the required Drive scope can be
        // obtained non-interactively. On Android this call uses the native
        // Identity AuthorizationClient, including after process recreation.
        final client = await _gateway.authorizeDrive(allowInteractive: false);
        client?.close();
        await _state.setReconnectRequired(false);

        if (account != null) {
          await _persistAccountProfile(
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
          return CloudAccountSnapshot(
            status: CloudAccountStatus.connected,
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
        }

        // A new Flutter runtime has no GoogleSignInAccount object. A successful
        // native Drive authorization independently proves that the default
        // account has a usable backup grant; cached fields are display-only.
        return await _cachedProfileSnapshot(reconnectRequired: false);
      } on CloudAuthorizationUnavailable {
        await _state.setReconnectRequired(true);
        if (account != null) {
          await _persistAccountProfile(
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
          return CloudAccountSnapshot.reconnectRequired(
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
        }
        return await _cachedProfileSnapshot(reconnectRequired: true);
      }
    } catch (error) {
      return CloudAccountSnapshot.failed(error.toString());
    }
  }

  Future<void> _persistAccountProfile({
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    Future<void> writeValue(String key, String? rawValue) async {
      final value = rawValue?.trim();
      if (value == null || value.isEmpty) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, value);
      }
    }

    await writeValue(_cachedDisplayNameKey, displayName);
    await writeValue(_cachedEmailKey, email);
    await writeValue(_cachedPhotoUrlKey, photoUrl);
  }

  Future<void> _clearCachedAccountProfile() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cachedDisplayNameKey);
    await preferences.remove(_cachedEmailKey);
    await preferences.remove(_cachedPhotoUrlKey);
  }

  Future<CloudAccountSnapshot> _cachedProfileSnapshot({
    required bool reconnectRequired,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    String? readValue(String key) {
      final value = preferences.getString(key)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final displayName = readValue(_cachedDisplayNameKey);
    final email = readValue(_cachedEmailKey);
    final photoUrl = readValue(_cachedPhotoUrlKey);
    if (reconnectRequired) {
      return CloudAccountSnapshot.reconnectRequired(
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
      );
    }

    return CloudAccountSnapshot(
      status: CloudAccountStatus.connected,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<CloudAccountSnapshot> signIn() async {
    try {
      final automaticPreferenceConfigured = await _state
          .hasAutomaticSyncPreference();
      final account = await _gateway.authenticate();

      // Do not mark cloud backup connected until the specific Drive app-data
      // scope is authorized. This call follows the explicit Connect/Reconnect
      // action, so a required consent resolution may be presented safely.
      final client = await _gateway.authorizeDrive(allowInteractive: true);
      client?.close();

      await _persistAccountProfile(
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
      await _state.setCloudSyncEnabled(true);
      await _state.setReconnectRequired(false);
      if (!automaticPreferenceConfigured) {
        await _state.setAutomaticSyncEnabled(true);
      }
      if (await _state.isAutomaticSyncEnabled()) {
        await _scheduler.initializeAndSchedule(
          frequency: (await _state.backupFrequency()).interval,
          serverClientId: serverClientId,
        );
      }
      return CloudAccountSnapshot(
        status: CloudAccountStatus.connected,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
    } catch (error) {
      if (await _state.isCloudSyncEnabled()) {
        await _state.setReconnectRequired(true);
      }
      return CloudAccountSnapshot.failed(error.toString());
    }
  }

  @override
  Future<void> disconnect() async {
    // The worker guard is persisted before OAuth sign-out can begin.
    await _scheduler.disconnect();
    await _gateway.signOut();
    await _clearCachedAccountProfile();
  }
}

class GoogleCloudSyncProvider implements CloudSyncProvider {
  GoogleCloudSyncProvider({
    required AppDatabase database,
    required GoogleSignInGateway gateway,
    required CloudSyncStateStore state,
    required CloudSyncScheduler scheduler,
    this.serverClientId,
  }) : _phase1 = LocalPhase1BackupSource(database),
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
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async {
    final result = await _engine().discoverBackup(
      allowInteractive: allowInteractive,
    );
    switch (result.kind) {
      case CloudBackupDiscoveryKind.noBackup:
        return const CloudBackupDiscoverySnapshot.noBackup();
      case CloudBackupDiscoveryKind.found:
        final conflict = result.conflict;
        if (conflict == null) {
          return const CloudBackupDiscoverySnapshot.failed(
            'The discovered backup could not be prepared for safe restoration.',
          );
        }
        return CloudBackupDiscoverySnapshot.backupFound(
          _toCoreConflict(conflict),
        );
      case CloudBackupDiscoveryKind.invalidBackup:
        return CloudBackupDiscoverySnapshot.invalidBackup(
          result.message ?? 'The cloud backup is invalid or incompatible.',
        );
      case CloudBackupDiscoveryKind.failed:
        return CloudBackupDiscoverySnapshot.failed(
          result.message ?? 'Cloud backup discovery failed.',
        );
    }
  }

  @override
  Future<CloudSyncSnapshot> status() async {
    final enabled = await _state.isCloudSyncEnabled();
    final automatic = await _state.isAutomaticSyncEnabled();
    final frequency = await _state.backupFrequency();
    final reconnectRequired = enabled && await _state.isReconnectRequired();
    final pendingConflict = enabled ? await _state.readPendingConflict() : null;
    return CloudSyncSnapshot(
      status: !enabled
          ? CloudSyncStatus.disconnected
          : pendingConflict != null
          ? CloudSyncStatus.conflict
          : reconnectRequired
          ? CloudSyncStatus.reconnectRequired
          : (_syncing ? CloudSyncStatus.syncing : CloudSyncStatus.idle),
      automaticSyncEnabled: automatic,
      backupFrequency: frequency,
      lastSuccessAt: await _state.lastSuccessfulSyncAt(),
      conflict: pendingConflict == null
          ? null
          : _toCoreConflict(pendingConflict),
      hasLocalRecoverySnapshot: (await _phase1.readRecoverySnapshot()) != null,
    );
  }

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) async {
    if (!await _state.isCloudSyncEnabled()) {
      return await _snapshot(
        CloudSyncStatus.disconnected,
        message: 'Connect a Google account before backing up.',
      );
    }

    _syncing = true;
    CloudBackupProgress? latestProgress;
    try {
      final result = await _engine().sync(
        allowInteractive: true,
        forceUpload: true,
        onProgress: (progress) {
          latestProgress = progress;
          onProgress?.call(progress);
        },
      );
      // Show 100% only after the engine's upload and sync-cursor update succeed.
      if (result.kind == CloudSyncResultKind.uploaded &&
          latestProgress != null &&
          latestProgress!.totalBytes > 0) {
        onProgress?.call(
          CloudBackupProgress.completed(totalBytes: latestProgress!.totalBytes),
        );
      }
      return await _snapshotFromResult(result);
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
            message:
                'Connect a Google account before enabling automatic backup.',
          );
        }
        await _scheduler.initializeAndSchedule(
          frequency: (await _state.backupFrequency()).interval,
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
  Future<CloudSyncSnapshot> setAutomaticBackupFrequency(
    CloudBackupFrequency frequency,
  ) async {
    try {
      await _state.setBackupFrequency(frequency);
      if (await _state.isCloudSyncEnabled() &&
          await _state.isAutomaticSyncEnabled()) {
        await _scheduler.initializeAndSchedule(
          frequency: frequency.interval,
          serverClientId: serverClientId,
        );
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
    CloudBackupProgressCallback? onProgress,
  }) async {
    CloudBackupProgress? latestProgress;
    try {
      final result = await _engine().resolveConflict(
        conflict: _toAdapterConflict(conflict),
        decision: choice == CloudConflictChoice.keepLocal
            ? CloudConflictDecision.keepLocal
            : CloudConflictDecision.useRemote,
        confirmed: confirmed,
        allowInteractive: true,
        onProgress: (progress) {
          latestProgress = progress;
          onProgress?.call(progress);
        },
      );
      if (result.kind == CloudSyncResultKind.uploaded &&
          latestProgress != null &&
          latestProgress!.totalBytes > 0) {
        onProgress?.call(
          CloudBackupProgress.completed(totalBytes: latestProgress!.totalBytes),
        );
      }
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
      // Restoring a local safety snapshot is not a successful cloud backup.
      // Preserve the actual last successful remote sync timestamp.
      return await _snapshot(
        result.kind == CloudSyncResultKind.downloaded
            ? CloudSyncStatus.synced
            : CloudSyncStatus.failed,
        message: result.message,
        conflict: result.conflict == null
            ? null
            : _toCoreConflict(result.conflict!),
      );
    } catch (error) {
      return await _snapshot(CloudSyncStatus.failed, message: error.toString());
    }
  }

  CloudSyncEngine _engine() => CloudSyncEngine(
    phase1: _phase1,
    remote: GoogleDriveAppDataStore(_gateway),
    state: _state,
  );

  CloudConflict _toAdapterConflict(CloudConflictInfo conflict) => CloudConflict(
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

  Future<CloudSyncSnapshot> _snapshotFromResult(CloudSyncResult result) async {
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
      restoredRemoteBackup: result.kind == CloudSyncResultKind.downloaded,
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
    bool restoredRemoteBackup = false,
  }) async => CloudSyncSnapshot(
    status: status,
    automaticSyncEnabled: await _state.isAutomaticSyncEnabled(),
    backupFrequency: await _state.backupFrequency(),
    lastSuccessAt: await _state.lastSuccessfulSyncAt(),
    message: message,
    conflict: conflict,
    hasLocalRecoverySnapshot: (await _phase1.readRecoverySnapshot()) != null,
    restoredRemoteBackup: restoredRemoteBackup,
  );
}
