import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
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

  static const _cachedAccountIdKey = 'qaza_cloud_adapter.cached_account_id_v1';
  static const _cachedDisplayNameKey =
      'qaza_cloud_adapter.cached_account_display_name_v1';
  static const _cachedEmailKey = 'qaza_cloud_adapter.cached_account_email_v1';
  static const _cachedPhotoUrlKey =
      'qaza_cloud_adapter.cached_account_photo_url_v1';
  static const _rememberedAccountsKey =
      'qaza_cloud_adapter.remembered_accounts_v1';

  @override
  bool get isSupported => true;

  @override
  Future<CloudAccountSnapshot> restore() async {
    try {
      final CloudAccountScopedSyncStateStore? scopedState =
          _state is CloudAccountScopedSyncStateStore
          ? _state as CloudAccountScopedSyncStateStore
          : null;
      final activeAccountId = await scopedState?.activeAccountId();
      final accountState = scopedState != null && activeAccountId != null
          ? scopedState.scopedToAccount(activeAccountId)
          : _state;

      if (scopedState != null && activeAccountId == null) {
        if (_state is SharedPreferencesCloudSyncStateStore) {
          if (await _state.hasUnscopedLegacyConnection()) {
            // Older releases persisted a connected flag without a stable
            // Google account ID. Show the saved profile only as a reconnect
            // hint; never authorize or sync until the account is verified.
            return await _cachedProfileSnapshot(reconnectRequired: true);
          }
        }
        return const CloudAccountSnapshot.disconnected();
      }

      if (!await accountState.isCloudSyncEnabled()) {
        return const CloudAccountSnapshot.disconnected();
      }

      if (scopedState != null) {
        final boundAccountId = await _gateway.accountIdForAuthorization();
        if (boundAccountId == null || boundAccountId != activeAccountId) {
          // The profile binding can belong to a partially completed account
          // switch. Do not mutate the currently selected namespace based on an
          // identity mismatch; require explicit reconnection instead.
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
          accountId: activeAccountId,
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
            accountId: account.id,
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
        }

        // A new Flutter runtime has no GoogleSignInAccount object. The native
        // authorization path returns the account it actually authorized, and
        // the stable ID/email binding was verified before any sync state read.
        if (activeAccountId != null) {
          await _rememberCachedProfile(activeAccountId);
        }
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
            accountId: account.id,
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
        }
        return await _cachedProfileSnapshot(reconnectRequired: true);
      }
    } catch (error) {
      final scopedState = _state is CloudAccountScopedSyncStateStore
          ? _state as CloudAccountScopedSyncStateStore
          : null;
      final activeAccountId = await scopedState?.activeAccountId();
      return CloudAccountSnapshot.failed(
        error.toString(),
        accountId: activeAccountId,
      );
    }
  }

  @override
  Future<List<RememberedCloudAccount>> rememberedAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_rememberedAccountsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <RememberedCloudAccount>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <RememberedCloudAccount>[];
      final result = <RememberedCloudAccount>[];
      final seen = <String>{};
      for (final value in decoded) {
        if (value is! Map) continue;
        final accountId = value['accountId'];
        if (accountId is! String ||
            accountId.trim().isEmpty ||
            !seen.add(accountId)) {
          continue;
        }
        String? optionalString(String key) {
          final item = value[key];
          if (item is! String || item.trim().isEmpty) return null;
          return item.trim();
        }

        result.add(
          RememberedCloudAccount(
            accountId: accountId,
            displayName: optionalString('displayName'),
            email: optionalString('email'),
            photoUrl: optionalString('photoUrl'),
          ),
        );
      }
      return List<RememberedCloudAccount>.unmodifiable(result);
    } catch (_) {
      return const <RememberedCloudAccount>[];
    }
  }

  Future<void> _rememberAccount({
    required String accountId,
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final current = await rememberedAccounts();
    final next = <Map<String, dynamic>>[
      <String, dynamic>{
        'accountId': accountId,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
      },
      for (final item in current)
        if (item.accountId != accountId)
          <String, dynamic>{
            'accountId': item.accountId,
            'displayName': item.displayName,
            'email': item.email,
            'photoUrl': item.photoUrl,
          },
    ];
    // A small, bounded recent-account list is sufficient for account choice.
    await preferences.setString(
      _rememberedAccountsKey,
      jsonEncode(next.take(8).toList(growable: false)),
    );
  }

  @override
  Future<CloudAccountSnapshot> signInWithRememberedAccount(
    String accountId,
  ) async {
    final normalized = accountId.trim();
    if (normalized.isEmpty ||
        !(await rememberedAccounts()).any(
          (item) => item.accountId == normalized,
        )) {
      return const CloudAccountSnapshot.failed(
        'This saved account is no longer available. Continue with a new account.',
      );
    }
    return _signIn(expectedAccountId: normalized);
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
    await _rememberAccount(
      accountId: accountId,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
    );
  }

  Future<void> _clearCachedAccountProfile() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cachedAccountIdKey);
    await preferences.remove(_cachedDisplayNameKey);
    await preferences.remove(_cachedEmailKey);
    await preferences.remove(_cachedPhotoUrlKey);
  }

  Future<void> _rememberCachedProfile(String accountId) async {
    final preferences = await SharedPreferences.getInstance();
    String? readValue(String key) {
      final value = preferences.getString(key)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    await _rememberAccount(
      accountId: accountId,
      displayName: readValue(_cachedDisplayNameKey),
      email: readValue(_cachedEmailKey),
      photoUrl: readValue(_cachedPhotoUrlKey),
    );
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
    final cachedAccountId = readValue(_cachedAccountIdKey);
    final scopedState = _state is CloudAccountScopedSyncStateStore
        ? _state as CloudAccountScopedSyncStateStore
        : null;
    final activeAccountId = await scopedState?.activeAccountId();
    // The active sync namespace is authoritative if a stale cached profile
    // belongs to a different Google account.
    final accountId = activeAccountId ?? cachedAccountId;
    if (reconnectRequired) {
      return CloudAccountSnapshot.reconnectRequired(
        accountId: accountId,
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
      );
    }

    return CloudAccountSnapshot(
      status: CloudAccountStatus.connected,
      accountId: accountId,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<CloudAccountSnapshot> signIn() => _signIn();

  Future<CloudAccountSnapshot> _signIn({String? expectedAccountId}) async {
    try {
      final automaticPreferenceConfigured = await _state
          .hasAutomaticSyncPreference();
      final account = await _gateway.authenticate();
      if (expectedAccountId != null && account.id != expectedAccountId) {
        await _gateway.signOut();
        return const CloudAccountSnapshot.failed(
          'The selected Google account did not match the remembered account. Please choose it again.',
        );
      }

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
        await (_state as CloudAccountScopedSyncStateStore).setActiveAccountId(
          account.id,
        );
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
        accountId: account.id,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
    } catch (error) {
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return const CloudAccountSnapshot.cancelled();
      }

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
    // Stop work before removing the active binding. The account-specific sync
    // cursor remains namespaced and can be reused if the user signs in again.
    await _scheduler.disconnect();
    await _gateway.signOut();
    await _state.setCloudSyncEnabled(false);
    if (_state is CloudAccountScopedSyncStateStore) {
      await (_state as CloudAccountScopedSyncStateStore).setActiveAccountId(
        null,
      );
    }
    await _clearCachedAccountProfile();
  }
}

class GoogleCloudSyncProvider implements CloudSyncProvider {
  GoogleCloudSyncProvider({
    required AppDatabase database,
    DatabaseManager? databaseManager,
    required GoogleSignInGateway gateway,
    required CloudSyncStateStore state,
    required CloudSyncScheduler scheduler,
    this.serverClientId,
  }) : _databaseManager = databaseManager,
       _phase1 = LocalPhase1BackupSource(
         database,
         databaseManager: databaseManager,
       ),
       _gateway = gateway,
       _state = state,
       _scheduler = scheduler;

  final DatabaseManager? _databaseManager;
  final LocalPhase1BackupSource _phase1;

  Future<AppDatabase> _workspaceDatabase(String localWorkspaceId) {
    final manager = _databaseManager;
    if (manager == null) return Future.value(_phase1.database);
    return manager.databaseForWorkspace(localWorkspaceId);
  }

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
      final localWorkspaceId = accountId == null
          ? null
          : googleLocalWorkspaceId(accountId);
      final startGeneration = await _phase1.database.readSessionGeneration();
      if (localWorkspaceId != null &&
          await _phase1.database.readActiveLocalAccountId() !=
              localWorkspaceId) {
        return const CloudBackupDiscoverySnapshot.failed(
          'The selected Google workspace is not active. Reopen that account and retry discovery.',
        );
      }
      if (accountId != null) _gateway.pinAccountForOperation(accountId);
      try {
        final result = await _engine(
          state: verified.state,
          localAccountId: accountId == null
              ? null
              : googleLocalWorkspaceId(accountId),
        ).discoverBackup(allowInteractive: allowInteractive);
        if (localWorkspaceId != null) {
          if (!await _phase1.database.isCurrentWorkspaceGeneration(
            localAccountId: localWorkspaceId,
            generation: startGeneration,
          )) {
            return const CloudBackupDiscoverySnapshot.failed(
              'The active workspace changed during Drive discovery. No backup state was changed; retry when the intended account is active.',
            );
          }
          final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
          final workspaceRevision = await workspaceDatabase
              .readWorkspaceRevision(localWorkspaceId);
          final (syncState, conflictMarker) = switch (result.kind) {
            CloudBackupDiscoveryKind.noBackup => ('pending', null),
            CloudBackupDiscoveryKind.found => (
              'conflict',
              result.conflict?.remoteLineage.backupId,
            ),
            CloudBackupDiscoveryKind.invalidBackup => (
              'legacy_unverified',
              null,
            ),
            CloudBackupDiscoveryKind.failed => ('cloud_unverified', null),
          };
          await workspaceDatabase.writeWorkspaceSyncState(
            localWorkspaceId,
            syncState,
            localRevision: workspaceRevision,
            conflictMarker: conflictMarker,
            remoteAccountId: accountId,
          );
        }
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
          hasPendingChanges: true,
        );
      }
    }

    final reconnectRequired = enabled && await _state.isReconnectRequired();
    final pendingConflict = enabled ? await _state.readPendingConflict() : null;
    final hasPendingChanges =
        enabled &&
        ((pendingConflict != null) ||
            await _hasPendingLocalChanges(state: _state));
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
      hasPendingChanges: hasPendingChanges,
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
      final startGeneration = await _phase1.database.readSessionGeneration();
      if (operationAccountId != null) {
        final localWorkspaceId = googleLocalWorkspaceId(operationAccountId);
        if (await _phase1.database.readActiveLocalAccountId() !=
            localWorkspaceId) {
          return await _snapshot(
            CloudSyncStatus.failed,
            message:
                'The selected Google workspace is no longer active. No upload was started; reopen that account and retry.',
            state: operationState,
            includeAccountState: true,
          );
        }
        _gateway.pinAccountForOperation(operationAccountId);
        accountPinned = true;
        final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
        if (await workspaceDatabase.isWorkspaceCloudUploadBlocked(
          localWorkspaceId,
        )) {
          return await _snapshot(
            CloudSyncStatus.failed,
            message:
                'Drive backup status is not verified. Retry backup discovery first; local records have been kept and no upload was started.',
            state: operationState,
            includeAccountState: true,
          );
        }
      }

      final result =
          await _engine(
            state: operationState,
            localAccountId: operationAccountId == null
                ? null
                : googleLocalWorkspaceId(operationAccountId),
          ).sync(
            allowInteractive: true,
            createInitialBackup: true,
            onProgress: (progress) {
              latestProgress = progress;
              onProgress?.call(progress);
            },
          );
      if (operationAccountId != null) {
        final localWorkspaceId = googleLocalWorkspaceId(operationAccountId);
        if (!await _phase1.database.isCurrentWorkspaceGeneration(
          localAccountId: localWorkspaceId,
          generation: startGeneration,
        )) {
          final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
          await workspaceDatabase.writeWorkspaceSyncState(
            localWorkspaceId,
            'pending',
            localRevision: await workspaceDatabase.readWorkspaceRevision(
              localWorkspaceId,
            ),
            remoteAccountId: operationAccountId,
          );
          return await _snapshot(
            CloudSyncStatus.failed,
            message:
                'The active workspace changed during backup. Local records remain safe; the result will be reconciled when that account is reopened.',
            state: operationState,
            includeAccountState: true,
          );
        }
      }
      // Persist the successful-sync state before emitting 100% completion.
      if (operationAccountId != null) {
        final localWorkspaceId = googleLocalWorkspaceId(operationAccountId);
        final nextState = switch (result.kind) {
          CloudSyncResultKind.uploaded ||
          CloudSyncResultKind.downloaded ||
          CloudSyncResultKind.noOp => 'clean',
          CloudSyncResultKind.conflict => 'conflict',
          // Drive rejected the authorization itself (expired/revoked
          // token): park the workspace so uploads stay blocked until the
          // user signs in again, instead of retrying a hopeless credential.
          CloudSyncResultKind.failed when result.authorizationFailed =>
            'needs_sign_in',
          _ => 'pending',
        };
        final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
        await workspaceDatabase.writeWorkspaceSyncState(
          localWorkspaceId,
          nextState,
          localRevision: await workspaceDatabase.readWorkspaceRevision(
            localWorkspaceId,
          ),
          remoteAccountId: operationAccountId,
          conflictMarker: result.conflict?.remoteLineage.backupId,
        );
      }
      final snapshot = await _snapshotFromResult(result, state: operationState);
      if (result.kind == CloudSyncResultKind.uploaded &&
          latestProgress != null &&
          latestProgress!.totalBytes > 0) {
        onProgress?.call(
          CloudBackupProgress.completed(totalBytes: latestProgress!.totalBytes),
        );
      }
      return snapshot;
    } catch (error) {
      // A Drive 401 thrown mid-upload/download bypasses the engine's
      // result mapping; park the workspace exactly like a failed result
      // that carries the authorization flag.
      if (error is CloudDriveRequestException &&
          error.authorizationFailed &&
          operationAccountId != null) {
        final localWorkspaceId = googleLocalWorkspaceId(operationAccountId);
        final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
        await workspaceDatabase.writeWorkspaceSyncState(
          localWorkspaceId,
          'needs_sign_in',
          localRevision: await workspaceDatabase.readWorkspaceRevision(
            localWorkspaceId,
          ),
          remoteAccountId: operationAccountId,
        );
      }
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

      var adapterDecision = choice == CloudConflictChoice.useRemote
          ? CloudConflictDecision.useRemote
          : CloudConflictDecision.keepLocal;
      if (choice == CloudConflictChoice.keepBoth) {
        final googleId = operationAccountId;
        if (googleId == null) {
          throw CloudAdapterException(
            'A verified Google account is required to save a recovery copy.',
          );
        }
        final latest = await GoogleDriveAppDataStore(_gateway).latest(
          allowInteractive: true,
          onProgress: (progress) {
            latestProgress = progress;
            onProgress?.call(progress);
          },
        );
        if (latest == null ||
            latest.backup.lineage.backupId != conflict.remoteBackupId ||
            latest.remoteVersion != conflict.remoteVersion) {
          throw const CloudAdapterException(
            'The cloud backup changed while the conflict was open. '
            'Nothing was overwritten; refresh the comparison and try again.',
          );
        }
        await LocalBackupService(
          _phase1.database,
          databaseManager: _databaseManager,
        ).saveCloudRecoveryCopyFromBackup(
          phase1BackupJson: latest.backup.phase1BackupJson,
          googleAccountId: googleId,
          remoteBackupId: conflict.remoteBackupId,
          remoteVersion: conflict.remoteVersion,
        );
        // Upload local data only after the cloud copy is safely preserved.
        adapterDecision = CloudConflictDecision.keepLocal;
      }
      final result =
          await _engine(
            state: operationState,
            localAccountId: operationAccountId == null
                ? null
                : googleLocalWorkspaceId(operationAccountId),
          ).resolveConflict(
            conflict: _toAdapterConflict(conflict),
            decision: adapterDecision,
            confirmed: confirmed,
            allowInteractive: true,
            onProgress: (progress) {
              latestProgress = progress;
              onProgress?.call(progress);
            },
          );
      if (operationAccountId != null) {
        final localWorkspaceId = googleLocalWorkspaceId(operationAccountId);
        final workspaceDatabase = await _workspaceDatabase(localWorkspaceId);
        final syncState = switch (result.kind) {
          CloudSyncResultKind.uploaded ||
          CloudSyncResultKind.downloaded ||
          CloudSyncResultKind.noOp => 'clean',
          CloudSyncResultKind.conflict => 'conflict',
          _ => await workspaceDatabase.readWorkspaceSyncState(localWorkspaceId),
        };
        await workspaceDatabase.writeWorkspaceSyncState(
          localWorkspaceId,
          syncState,
          localRevision: await workspaceDatabase.readWorkspaceRevision(
            localWorkspaceId,
          ),
          remoteAccountId: operationAccountId,
          conflictMarker: result.conflict?.remoteLineage.backupId,
        );
      }
      final snapshot = await _snapshotFromResult(result, state: operationState);
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
      final scopedState = _state is CloudAccountScopedSyncStateStore
          ? _state as CloudAccountScopedSyncStateStore
          : null;
      final activeAccountId = await scopedState?.activeAccountId();
      if (scopedState != null &&
          (activeAccountId == null || activeAccountId.trim().isEmpty)) {
        return await _snapshot(
          CloudSyncStatus.failed,
          message:
              'Reconnect the Google account before restoring its recovery snapshot.',
        );
      }
      final result = await _engine(
        localAccountId: activeAccountId == null
            ? null
            : googleLocalWorkspaceId(activeAccountId),
      ).restoreLocalRecoverySnapshot(confirmed: confirmed);
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

  CloudSyncEngine _engine({
    CloudSyncStateStore? state,
    String? localAccountId,
  }) => CloudSyncEngine(
    // Cloud work is pinned to the verified Google identity rather than the
    // currently visible account. This also protects background sync.
    phase1: localAccountId == null
        ? _phase1
        : LocalPhase1BackupSource(
            _phase1.database,
            localAccountId: localAccountId,
            databaseManager: _databaseManager,
          ),
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
      hasPendingChanges: includeAccountState
          ? await _hasPendingLocalChanges(state: stateStore)
          : true,
    );
  }

  Future<bool> _hasPendingLocalChanges({
    required CloudSyncStateStore state,
  }) async {
    final cursor = await state.readCursor();
    final revision = await _cursorWorkspaceRevision(state);
    final localChanges = cursor.lastSyncedLocalRevision == null
        ? revision > 1
        : revision != cursor.lastSyncedLocalRevision;
    return localChanges || await state.readPendingConflict() != null;
  }

  /// The revision [CloudSyncCursor.lastSyncedLocalRevision] is compared
  /// against. The sync engine writes that field from its workspace-scoped
  /// backup source, so it lives in the workspace revision domain of the
  /// account that owns the cursor — read the same workspace's revision, not
  /// the global db_revision. When the owning account cannot be determined
  /// (no active account, or a store without account scoping), fall back to
  /// the global counter exactly as before.
  Future<int> _cursorWorkspaceRevision(CloudSyncStateStore state) async {
    if (state is CloudAccountScopedSyncStateStore) {
      final accountId = await (state as CloudAccountScopedSyncStateStore)
          .activeAccountId();
      if (accountId != null && accountId.isNotEmpty) {
        final workspaceId = googleLocalWorkspaceId(accountId);
        return (await _workspaceDatabase(
          workspaceId,
        )).readWorkspaceRevision(workspaceId);
      }
    }
    return _phase1.readDbRevision();
  }
}
