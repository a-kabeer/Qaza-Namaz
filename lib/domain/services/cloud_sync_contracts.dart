/// UI-facing contracts for optional cloud capabilities.
///
/// These ports contain no cloud SDK imports or network behavior. The offline
/// application supplies unsupported implementations; cloud hosts inject
/// concrete adapters through Riverpod.
enum CloudAccountStatus { unavailable, disconnected, connected, failed }

class CloudAccountSnapshot {
  const CloudAccountSnapshot({
    required this.status,
    this.displayName,
    this.email,
    this.message,
  });

  const CloudAccountSnapshot.unavailable()
      : status = CloudAccountStatus.unavailable,
        displayName = null,
        email = null,
        message = null;

  const CloudAccountSnapshot.disconnected()
      : status = CloudAccountStatus.disconnected,
        displayName = null,
        email = null,
        message = null;

  const CloudAccountSnapshot.failed(String value)
      : status = CloudAccountStatus.failed,
        displayName = null,
        email = null,
        message = value;

  final CloudAccountStatus status;
  final String? displayName;
  final String? email;
  final String? message;

  bool get isConnected => status == CloudAccountStatus.connected;
}

abstract interface class CloudAccountProvider {
  bool get isSupported;
  Future<CloudAccountSnapshot> restore();
  Future<CloudAccountSnapshot> signIn();
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
}

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
    this.lastSuccessAt,
    this.message,
    this.conflict,
    this.hasLocalRecoverySnapshot = false,
  });

  const CloudSyncSnapshot.unavailable()
      : status = CloudSyncStatus.unavailable,
        automaticSyncEnabled = false,
        lastSuccessAt = null,
        message = null,
        conflict = null,
        hasLocalRecoverySnapshot = false;

  const CloudSyncSnapshot.disconnected()
      : status = CloudSyncStatus.disconnected,
        automaticSyncEnabled = false,
        lastSuccessAt = null,
        message = null,
        conflict = null,
        hasLocalRecoverySnapshot = false;

  final CloudSyncStatus status;
  final bool automaticSyncEnabled;
  final DateTime? lastSuccessAt;
  final String? message;
  final CloudConflictInfo? conflict;
  final bool hasLocalRecoverySnapshot;
}

abstract interface class CloudSyncProvider {
  bool get isSupported;
  Future<CloudSyncSnapshot> status();
  Future<CloudSyncSnapshot> backupNow();
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled);
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
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
  Future<void> disconnect() async {}
}

class UnsupportedCloudSyncProvider implements CloudSyncProvider {
  const UnsupportedCloudSyncProvider();

  @override
  bool get isSupported => false;

  @override
  Future<CloudSyncSnapshot> status() async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> backupNow() async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> setAutomaticSyncEnabled(bool enabled) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> resolveConflict({
    required CloudConflictInfo conflict,
    required CloudConflictChoice choice,
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.unavailable();

  @override
  Future<CloudSyncSnapshot> restoreLocalRecoverySnapshot({
    required bool confirmed,
  }) async =>
      const CloudSyncSnapshot.unavailable();
}
