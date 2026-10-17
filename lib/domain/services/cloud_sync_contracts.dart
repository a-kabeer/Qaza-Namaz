/// UI-facing contracts for optional cloud capabilities.
///
/// These ports contain no cloud SDK imports or network behavior. The offline
/// application supplies unsupported implementations; cloud hosts inject
/// concrete adapters through Riverpod.
enum CloudAccountStatus {
  unavailable,
  disconnected,
  connected,
  reconnectRequired,
  failed,
}

class CloudAccountSnapshot {
  const CloudAccountSnapshot({
    required this.status,
    this.displayName,
    this.email,
    this.photoUrl,
    this.message,
    this.wasCancelled = false,
  });

  const CloudAccountSnapshot.unavailable()
      : status = CloudAccountStatus.unavailable,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null,
        wasCancelled = false;

  const CloudAccountSnapshot.disconnected()
      : status = CloudAccountStatus.disconnected,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null,
        wasCancelled = false;

  /// A locally cached identity is display-only until the user reconnects.
  /// It must never be treated as proof that Drive authorization is available.
  const CloudAccountSnapshot.reconnectRequired({
    this.displayName,
    this.email,
    this.photoUrl,
  })  : status = CloudAccountStatus.reconnectRequired,
        message = null,
        wasCancelled = false;

  const CloudAccountSnapshot.failed(String value)
      : status = CloudAccountStatus.failed,
        displayName = null,
        email = null,
        photoUrl = null,
        message = value,
        wasCancelled = false;

  /// Sign-in was intentionally dismissed by the user. This is not a failure
  /// and must not trigger an error dialog.
  const CloudAccountSnapshot.cancelled()
      : status = CloudAccountStatus.disconnected,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null,
        wasCancelled = true;

  final CloudAccountStatus status;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? message;

  /// True only when the user intentionally cancelled the interactive flow.
  final bool wasCancelled;

  bool get isConnected => status == CloudAccountStatus.connected;
}

class RememberedCloudAccount {
  const RememberedCloudAccount({
    required this.accountId,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  /// Stable Google account ID. Display fields are hints, never credentials.
  final String accountId;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final address = email?.trim();
    return address == null || address.isEmpty ? 'Google account' : address;
  }
}

abstract interface class CloudAccountProvider {
  bool get isSupported;
  Future<CloudAccountSnapshot> restore();
  Future<CloudAccountSnapshot> signIn();
  Future<List<RememberedCloudAccount>> rememberedAccounts();
  Future<CloudAccountSnapshot> signInWithRememberedAccount(String accountId);
  Future<void> disconnect();
}

enum CloudSyncStatus {
  unavailable,
  disconnected,
  idle,
  syncing,
  synced,
  conflict,
  failed,
  disabled,
  reconnectRequired,
}

/// User-selectable periodic cloud backup cadence.
enum CloudBackupFrequency {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30));

  const CloudBackupFrequency(this.interval);
  final Duration interval;
}

enum CloudBackupProgressStage {
  checking,
  downloading,
  preparing,
  uploading,
  completed
}

/// Progress from the cloud backup flow. The UI must not show 100% until Drive
/// confirms the complete remote write and sync-state persistence succeeds.
class CloudBackupProgress {
  const CloudBackupProgress.checking()
      : stage = CloudBackupProgressStage.checking,
        sentBytes = 0,
        totalBytes = 0;

  const CloudBackupProgress.preparing()
      : stage = CloudBackupProgressStage.preparing,
        sentBytes = 0,
        totalBytes = 0;

  /// Real bytes received while streaming a Drive backup. A zero total means
  /// the server did not provide a trustworthy content length.
  const CloudBackupProgress.downloading({
    required int receivedBytes,
    required this.totalBytes,
  })  : stage = CloudBackupProgressStage.downloading,
        sentBytes = receivedBytes;

  const CloudBackupProgress.uploading({
    required this.sentBytes,
    required this.totalBytes,
  }) : stage = CloudBackupProgressStage.uploading;

  const CloudBackupProgress.completed({required int totalBytes})
      : stage = CloudBackupProgressStage.completed,
        sentBytes = totalBytes,
        totalBytes = totalBytes;

  final CloudBackupProgressStage stage;
  final int sentBytes;
  final int totalBytes;
}

typedef CloudBackupProgressCallback = void Function(
  CloudBackupProgress progress,
);

enum CloudConflictChoice { keepLocal, useRemote }

class CloudConflictInfo {
  const CloudConflictInfo({
    required this.localDeviceId,
    required this.localTimestamp,
    required this.localRevision,
    required this.localBaseBackupId,
    required this.remoteDeviceId,
    required this.remoteTimestamp,
    required this.remoteRevision,
    required this.remoteBackupId,
    required this.remoteBaseBackupId,
    required this.lastSyncedBackupId,
    required this.remoteVersion,
  });

  final String localDeviceId;
  final DateTime localTimestamp;
  final int localRevision;
  final String? localBaseBackupId;
  final String remoteDeviceId;
  final DateTime remoteTimestamp;
  final int remoteRevision;
  final String remoteBackupId;
  final String? remoteBaseBackupId;
  final String? lastSyncedBackupId;
  final String remoteVersion;
}

class CloudSyncSnapshot {
  const CloudSyncSnapshot({
    required this.status,
    this.automaticSyncEnabled = false,
    this.backupFrequency = CloudBackupFrequency.daily,
    this.lastSuccessAt,
    this.message,
    this.conflict,
    this.hasLocalRecoverySnapshot = false,
    this.restoredRemoteBackup = false,
    this.backupAlreadyUpToDate = false,
    this.hasPendingChanges = false,
  });

  const CloudSyncSnapshot.unavailable()
      : status = CloudSyncStatus.unavailable,
        automaticSyncEnabled = false,
        backupFrequency = CloudBackupFrequency.daily,
        lastSuccessAt = null,
        message = null,
        conflict = null,
        hasLocalRecoverySnapshot = false,
        restoredRemoteBackup = false,
        backupAlreadyUpToDate = false,
        hasPendingChanges = false;

  const CloudSyncSnapshot.disconnected()
      : status = CloudSyncStatus.disconnected,
        automaticSyncEnabled = false,
        backupFrequency = CloudBackupFrequency.daily,
        lastSuccessAt = null,
        message = null,
        conflict = null,
        hasLocalRecoverySnapshot = false,
        restoredRemoteBackup = false,
        backupAlreadyUpToDate = false,
        hasPendingChanges = false;

  final CloudSyncStatus status;
  final bool automaticSyncEnabled;
  final CloudBackupFrequency backupFrequency;
  final DateTime? lastSuccessAt;
  final String? message;
  final CloudConflictInfo? conflict;
  final bool hasLocalRecoverySnapshot;

  /// True only when the operation actually imported a remote cloud backup.
  /// A generic "synced" status can also mean that local data was uploaded.
  final bool restoredRemoteBackup;

  /// True when an explicit backup request required no upload or restore.
  final bool backupAlreadyUpToDate;

  /// True when local changes are newer than the verified account sync cursor,
  /// or a conflict is waiting for a user decision.
  final bool hasPendingChanges;
}

enum CloudBackupDiscoveryStatus {
  unavailable,
  noBackup,
  backupFound,
  invalidBackup,
  failed,
}

/// Read-only remote lookup result. A found backup carries the conflict snapshot
/// needed by the existing explicit restore flow.
class CloudBackupDiscoverySnapshot {
  const CloudBackupDiscoverySnapshot({
    required this.status,
    this.conflict,
    this.message,
  });

  const CloudBackupDiscoverySnapshot.unavailable()
      : status = CloudBackupDiscoveryStatus.unavailable,
        conflict = null,
        message = null;

  const CloudBackupDiscoverySnapshot.noBackup()
      : status = CloudBackupDiscoveryStatus.noBackup,
        conflict = null,
        message = null;

  const CloudBackupDiscoverySnapshot.backupFound(CloudConflictInfo value)
      : status = CloudBackupDiscoveryStatus.backupFound,
        conflict = value,
        message = null;

  const CloudBackupDiscoverySnapshot.invalidBackup(String value)
      : status = CloudBackupDiscoveryStatus.invalidBackup,
        conflict = null,
        message = value;

  const CloudBackupDiscoverySnapshot.failed(String value)
      : status = CloudBackupDiscoveryStatus.failed,
        conflict = null,
        message = value;

  final CloudBackupDiscoveryStatus status;
  final CloudConflictInfo? conflict;
  final String? message;
}

abstract interface class CloudSyncProvider {
  bool get isSupported;
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  });
  Future<CloudSyncSnapshot> status();
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  });
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled);
  Future<CloudSyncSnapshot> setAutomaticBackupFrequency(
    CloudBackupFrequency frequency,
  );
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
    CloudBackupProgressCallback? onProgress,
  });
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  });
}

class UnsupportedCloudAccountProvider implements CloudAccountProvider {
  const UnsupportedCloudAccountProvider();

  @override
  bool get isSupported => false;

  @override
  Future<CloudAccountSnapshot> restore() async =>
      const CloudAccountSnapshot.unavailable();

  @override
  Future<CloudAccountSnapshot> signIn() async =>
      const CloudAccountSnapshot.unavailable();

  @override
  Future<List<RememberedCloudAccount>> rememberedAccounts() async =>
      const <RememberedCloudAccount>[];

  @override
  Future<CloudAccountSnapshot> signInWithRememberedAccount(
    String accountId,
  ) async =>
      const CloudAccountSnapshot.unavailable();

  @override
  Future<void> disconnect() async {}
}

class UnsupportedCloudSyncProvider implements CloudSyncProvider {
  const UnsupportedCloudSyncProvider();

  @override
  bool get isSupported => false;

  @override
  Future<CloudBackupDiscoverySnapshot> discoverBackup({
    bool allowInteractive = false,
  }) async =>
      const CloudBackupDiscoverySnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> backupNow({
    CloudBackupProgressCallback? onProgress,
  }) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> setAutomaticBackupFrequency(
    CloudBackupFrequency frequency,
  ) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
    CloudBackupProgressCallback? onProgress,
  }) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.unavailable();
}
