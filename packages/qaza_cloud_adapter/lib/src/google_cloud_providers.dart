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

  static const _cachedAccountIdKey =
      'qaza_cloud_adapter.cached_account_id_v1';
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
      final scopedState = _state is CloudAccountScopedSyncStateStore
          ? _state
          : null;
      final activeAccountId = await scopedState?.activeAccountId();
      final accountState = scopedState != null && activeAccountId != null
          ? scopedState.scopedToAccount(activeAccountId)
          : _state;

      if (scopedState != null && activeAccountId == null) {
        if (_state is SharedPreferencesCloudSyncStateStore &&
            await (_state as SharedPreferencesCloudSyncStateStore)
                .hasUnscopedLegacyConnection()) {
          // Older releases persisted a connected flag without a stable Google
          // account ID. Show the saved profile only as a reconnect hint; never
          // authorize or sync until the user verifies the account again.
          return await _cachedProfileSnapshot(reconnectRequired: true);
        }
        return const CloudAccountSnapshot.disconnected();
      }

      if (!await accountState.isCloudSyncEnabled()) {
        return const CloudAccountSnapshot.disconnected();
      }

      if (scopedState != null) {
        final boundAccountId = await _gateway.accountIdForAuthorization();
        if (boundAccountId == null || boundAccountId != activeAccountId) {
          if (await scopedState.activeAccountId() == activeAccountId) {
            await accountState.setReconnectRequired(true);
          }
          return await _cachedProfileSnapshot(reconnectRequired: true);
        }
      }

      final account = await _gateway.currentAccount();
      if (account != null &&
          activeAccountId != null &&
          account.id != activeAccountId) {
        if (await scopedState?.activeAccountId() == activeAccountId) {
          await accountState.setReconnectRequired(true);
        }
        return CloudAccountSnapshot.reconnectRequired(
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
        );
      }

      try {
        // Require a fresh non-interactive Drive authorization before scheduling
        // background work or exposing account-scoped sync status.
        final client = await _gateway.authorizeDrive(allowInteractive: false);
        client?.close();
        if (scopedState != null &&
            (await scopedState.activeAccountId() != activeAccountId ||
                await _gateway.accountIdForAuthorization() !=
                    activeAccountId)) {
          return await _cachedProfileSnapshot(reconnectRequired: true);
        }
        await accountState.setReconnectRequired(false);

        if (!await accountState.hasAutomaticSyncPreference()) {
          await accountState.setAutomaticSyncEnabled(true);
        }
        if (await accountState.isAutomaticSyncEnabled()) {
          await _scheduler.initializeAndSchedule(
            frequency: (await accountState.backupFrequency()).interval,
            serverClientId: serverClientId,
          );
        }

        if (account != null) {
          await _persistAccountProfile(
            accountId: account.id,
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

        // A new Flutter runtime has no GoogleSignInAccount object. The native
        // authorization path returns the account it actually authorized, and
        // the stable ID/email binding was verified before any sync state read.
        return await _cachedProfileSnapshot(reconnectRequired: false);
      } on CloudAuthorizationUnavailable {
        if (scopedState != null &&
            (await scopedState.activeAccountId() != activeAccountId ||
                await _gateway.accountIdForAuthorization() !=
                    activeAccountId)) {
          return await _cachedProfileSnapshot(reconnectRequired: true);
        }
        await accountState.setReconnectRequired(true);
        if (account != null) {
          await _persistAccountProfile(
            accountId: account.id,
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
    required String accountId,
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

    // Save a stable Google account ID alongside the email used only to select
    // the native Android account. Both are written before activating the
    // account-scoped sync namespace.
    await writeValue(_cachedAccountIdKey, accountId);
    await writeValue(_cachedDisplayNameKey, displayName);
    await writeValue(_cachedEmailKey, email);
    await writeValue(_cachedPhotoUrlKey, photoUrl);
  }

  Future<void> _clearCachedAccountProfile() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cachedAccountIdKey);
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
        accountId: account.id,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
      if (_state is CloudAccountScopedSyncStateStore) {
        await (_state as CloudAccountScopedSyncStateStore)
            .setActiveAccountId(account.id);
      }
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
      final scopedState = _state is CloudAccountScopedSyncStateStore
          ? _state as CloudAccountScopedSyncStateStore
          : null;
      final activeAccountId = await scopedState?.activeAccountId();
      final authenticatedAccountId = await _gateway.accountIdForAuthorization();
      if (activeAccountId != null &&
          authenticatedAccountId == activeAccountId &&
          await _state.isCloudSyncEnabled()) {
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

  Future<({String? accountId, CloudSyncStateStore state})>
  _verifyAccountBeforeSync({required bool allowInteractive}) async {
    final scopedState = _state is CloudAccountScopedSyncStateStore
        ? _state as CloudAccountScopedSyncStateStore
        : null;
    if (scopedState == null) return (accountId: null, state: _state);

    final expectedAccountId = await scopedState.activeAccountId();
    if (expectedAccountId == null || expectedAccountId.isEmpty) {
      throw const CloudAuthorizationUnavailable(
        'A verified Google account is required before cloud sync.',
      );
    }

    final initiallyResolvedId = await _gateway.accountIdForAuthorization();
    if (initiallyResolvedId != expectedAccountId) {
      throw const CloudAuthorizationUnavailable(
        'The authenticated Google account does not match the account selected for backup.',
      );
    }

    // Verify the Drive grant before the sync engine reads a cursor or conflict.
    // This may present UI only for explicit foreground actions.
    final client = await _gateway.authorizeDrive(
      allowInteractive: allowInteractive,
    );
    client?.close();

    if (await _gateway.accountIdForAuthorization() != expectedAccountId ||
        await scopedState.activeAccountId() != expectedAccountId) {
      throw const CloudAuthorizationUnavailable(
        'The Google account changed during verification. Sync was stopped safely.',
      );
    }

    return (
      accountId: expectedAccountId,
      state: scopedState.scopedToAccount(expectedAccountId),
    );
  }

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async {
    if (!await _state.isCloudSyncEnabled()) {
      return const CloudBackupDiscoverySnapshot.failed(
        'Cloud sync is disabled.',
      );
    }

    try {
      final verified = await _verifyAccountBeforeSync(
        allowInteractive: allowInteractive,
      );
      final accountId = verified.accountId;
      if (accountId != null) _gateway.pinAccountForOperation(accountId);
      try {
        final result = await _engine(state: verified.state).discoverBackup(
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
      } finally {
        if (accountId != null) _gateway.releaseAccountOperation(accountId);
      }
    } catch (error) {
      return CloudBackupDiscoverySnapshot.failed(
        'Could not verify the Google account before backup discovery: $error',
      );
    }
  }

  @override
  Future<CloudSyncSnapshot> status() async {
    final enabled = await _state.isCloudSyncEnabled();
    final automatic = await _state.isAutomaticSyncEnabled();
    final frequency = await _state.backupFrequency();

    if (enabled && _state is CloudAccountScopedSyncStateStore) {
      final scopedState = _state as CloudAccountScopedSyncStateStore;
      final activeAccountId = await scopedState.activeAccountId();
      final authenticatedAccountId = await _gateway.accountIdForAuthorization();
      if (activeAccountId == null ||
          authenticatedAccountId == null ||
          authenticatedAccountId != activeAccountId) {
        // Do not expose timestamps or conflict details from the selected
        // namespace until its stable identity binding matches again.
        return CloudSyncSnapshot(
          status: CloudSyncStatus.reconnectRequired,
          automaticSyncEnabled: automatic,
          backupFrequency: frequency,
          lastSuccessAt: null,
          message: 'Reconnect the Google account to verify backup ownership.',
          hasLocalRecoverySnapshot:
              (await _phase1.readRecoverySnapshot()) != null,
        );
      }
    }

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
    CloudSyncStateStore? operationState;
    String? operationAccountId;
    var accountPinned = false;
    try {
      final verified = await _verifyAccountBeforeSync(allowInteractive: true);
      operationState = verified.state;
      operationAccountId = verified.accountId;
      if (operationAccountId != null) {
        _gateway.pinAccountForOperation(operationAccountId);
        accountPinned = true;
      }

      final result = await _engine(state: operationState).sync(
        allowInteractive: true,
        createInitialBackup: true,
        onProgress: (progress) {
          latestProgress = progress;
          onProgress?.call(progress);
        },
      );
      // Persist the successful-sync state before emitting 100% completion.
      final snapshot = await _snapshotFromResult(
        result,
        state: operationState,
      );
      if (result.kind == CloudSyncResultKind.uploaded &&
          latestProgress != null &&
          latestProgress!.totalBytes > 0) {
        onProgress?.call(
          CloudBackupProgress.completed(totalBytes: latestProgress!.totalBytes),
        );
      }
      return snapshot;
    } catch (error) {
      return await _snapshot(
        CloudSyncStatus.failed,
        message: error.toString(),
        state: operationState,
        includeAccountState: operationState != null,
      );
    } finally {
      if (accountPinned && operationAccountId != null) {
        _gateway.releaseAccountOperation(operationAccountId);
      }
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
    CloudSyncStateStore? operationState;
    String? operationAccountId;
    var accountPinned = false;
    try {
      final verified = await _verifyAccountBeforeSync(allowInteractive: true);
      operationState = verified.state;
      operationAccountId = verified.accountId;
      if (operationAccountId != null) {
        _gateway.pinAccountForOperation(operationAccountId);
        accountPinned = true;
      }

      final result = await _engine(state: operationState).resolveConflict(
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
      final snapshot = await _snapshotFromResult(
        result,
        state: operationState,
      );
      if (result.kind == CloudSyncResultKind.uploaded &&
          latestProgress != null &&
          latestProgress!.totalBytes > 0) {
        onProgress?.call(
          CloudBackupProgress.completed(totalBytes: latestProgress!.totalBytes),
        );
      }
      return snapshot;
    } catch (error) {
      return await _snapshot(
        CloudSyncStatus.failed,
        message: error.toString(),
        state: operationState,
        includeAccountState: operationState != null,
      );
    } finally {
      if (accountPinned && operationAccountId != null) {
        _gateway.releaseAccountOperation(operationAccountId);
      }
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

  CloudSyncEngine _engine({CloudSyncStateStore? state}) => CloudSyncEngine(
    phase1: _phase1,
    remote: GoogleDriveAppDataStore(_gateway),
    state: state ?? _state,
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

  Future<CloudSyncSnapshot> _snapshotFromResult(
    CloudSyncResult result, {
    CloudSyncStateStore? state,
  }) async {
    final stateStore = state ?? _state;
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
      await stateStore.setLastSuccessfulSyncAt(DateTime.now().toUtc());
    }
    return await _snapshot(
      status,
      message: result.message,
      conflict: result.conflict == null
          ? null
          : _toCoreConflict(result.conflict!),
      restoredRemoteBackup: result.kind == CloudSyncResultKind.downloaded,
      backupAlreadyUpToDate: result.kind == CloudSyncResultKind.noOp,
      state: stateStore,
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
    bool backupAlreadyUpToDate = false,
    CloudSyncStateStore? state,
    bool includeAccountState = true,
  }) async {
    final stateStore = state ?? _state;
    return CloudSyncSnapshot(
      status: status,
      automaticSyncEnabled: await _state.isAutomaticSyncEnabled(),
      backupFrequency: await _state.backupFrequency(),
      lastSuccessAt: includeAccountState
          ? await stateStore.lastSuccessfulSyncAt()
          : null,
      message: message,
      conflict: conflict,
      hasLocalRecoverySnapshot: (await _phase1.readRecoverySnapshot()) != null,
      restoredRemoteBackup: restoredRemoteBackup,
      backupAlreadyUpToDate: backupAlreadyUpToDate,
    );
  }
}
