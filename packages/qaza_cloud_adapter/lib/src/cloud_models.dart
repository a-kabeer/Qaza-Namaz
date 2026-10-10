import 'dart:convert';

const int cloudSchemaVersion = 1;
const String phase1AppId = 'qaza_namaz_app';
const String cloudDriveScope = 'https://www.googleapis.com/auth/drive.appdata';
const String cloudBackupFilePrefix = 'qaza_namaz_cloud_backup_';

enum CloudSyncResultKind {
  noOp,
  uploaded,
  downloaded,
  conflict,
  remoteMissing,
  skipped,
  failed,
}

enum CloudConflictDecision { keepLocal, useRemote }

class CloudAdapterException implements Exception {
  const CloudAdapterException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudAuthenticationRequired extends CloudAdapterException {
  const CloudAuthenticationRequired([
    super.message = 'Google authentication is required.',
  ]);
}

class CloudAuthorizationUnavailable extends CloudAdapterException {
  const CloudAuthorizationUnavailable([
    super.message =
        'Google Drive authorization is not available without user interaction.',
  ]);
}

class CloudRemoteFormatException extends CloudAdapterException {
  const CloudRemoteFormatException(super.message);
}

class CloudConflictStaleException extends CloudAdapterException {
  const CloudConflictStaleException([
    super.message =
        'The cloud state changed while the conflict was being resolved.',
  ]);
}

class CloudLineage {
  const CloudLineage({
    required this.deviceId,
    required this.backupId,
    required this.baseBackupId,
    required this.dbRevision,
    required this.createdAt,
  });

  final String deviceId;
  final String backupId;
  final String? baseBackupId;
  final int dbRevision;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'device_id': deviceId,
    'backup_id': backupId,
    'base_backup_id': baseBackupId,
    'db_revision': dbRevision,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static CloudLineage fromJson(Map<dynamic, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw CloudRemoteFormatException(
          'Cloud lineage field "$key" is invalid.',
        );
      }
      return value;
    }

    final rawBase = json['base_backup_id'];
    String? base;
    if (rawBase != null) {
      if (rawBase is! String || rawBase.trim().isEmpty) {
        throw const CloudRemoteFormatException(
          'Cloud lineage field "base_backup_id" is invalid.',
        );
      }
      base = rawBase;
    }

    final rawRevision = json['db_revision'];
    if (rawRevision is! int || rawRevision < 1) {
      throw const CloudRemoteFormatException(
        'Cloud lineage field "db_revision" is invalid.',
      );
    }

    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is! String) {
      throw const CloudRemoteFormatException(
        'Cloud lineage field "created_at" is missing.',
      );
    }
    final createdAt = DateTime.tryParse(rawCreatedAt);
    if (createdAt == null || !createdAt.isUtc) {
      throw const CloudRemoteFormatException(
        'Cloud lineage field "created_at" must be a UTC timestamp.',
      );
    }

    return CloudLineage(
      deviceId: requiredString('device_id'),
      backupId: requiredString('backup_id'),
      baseBackupId: base,
      dbRevision: rawRevision,
      createdAt: createdAt,
    );
  }
}

class CloudBackup {
  const CloudBackup({required this.lineage, required this.phase1BackupJson});

  final CloudLineage lineage;
  final String phase1BackupJson;

  String toJsonString() {
    final decoded = _decodePhase1(phase1BackupJson);
    _validatePhase1Metadata(decoded, lineage.dbRevision);

    return jsonEncode(<String, dynamic>{
      'cloud_schema_version': cloudSchemaVersion,
      'lineage': lineage.toJson(),
      'phase1_backup': decoded,
    });
  }

  static CloudBackup fromJsonString(String jsonText) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const CloudRemoteFormatException(
        'The cloud backup is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const CloudRemoteFormatException(
        'The cloud backup root must be a JSON object.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);
    if (root['cloud_schema_version'] != cloudSchemaVersion) {
      throw const CloudRemoteFormatException(
        'The cloud backup schema version is not supported.',
      );
    }

    final rawLineage = root['lineage'];
    final rawPhase1 = root['phase1_backup'];
    if (rawLineage is! Map || rawPhase1 is! Map) {
      throw const CloudRemoteFormatException(
        'Cloud lineage or Phase 1 payload is missing.',
      );
    }

    final lineage = CloudLineage.fromJson(rawLineage);
    _validatePhase1Metadata(
      Map<String, dynamic>.from(rawPhase1),
      lineage.dbRevision,
    );

    return CloudBackup(
      lineage: lineage,
      phase1BackupJson: jsonEncode(rawPhase1),
    );
  }

  static Map<String, dynamic> _decodePhase1(String value) {
    dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup payload is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup payload must be a JSON object.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  static void _validatePhase1Metadata(
    Map<String, dynamic> root,
    int lineageRevision,
  ) {
    final metadata = root['metadata'];
    if (metadata is! Map) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup metadata is missing.',
      );
    }

    final metadataMap = Map<String, dynamic>.from(metadata);
    if (metadataMap['app_id'] != phase1AppId) {
      throw const CloudRemoteFormatException(
        'The cloud payload is not a Qaza Namaz Phase 1 backup.',
      );
    }
    if (metadataMap['db_revision'] != lineageRevision) {
      throw const CloudRemoteFormatException(
        'Cloud lineage db_revision does not match the Phase 1 payload revision.',
      );
    }
  }
}

class CloudRemoteSnapshot {
  const CloudRemoteSnapshot({
    required this.fileId,
    required this.remoteVersion,
    required this.modifiedAt,
    required this.backup,
  });

  final String fileId;
  final String remoteVersion;
  final DateTime modifiedAt;
  final CloudBackup backup;
}

class CloudSyncCursor {
  const CloudSyncCursor({
    required this.lastSyncedLocalRevision,
    required this.lastSyncedBackupId,
    required this.lastSyncedRemoteVersion,
  });

  const CloudSyncCursor.empty()
    : lastSyncedLocalRevision = null,
      lastSyncedBackupId = null,
      lastSyncedRemoteVersion = null;

  final int? lastSyncedLocalRevision;
  final String? lastSyncedBackupId;
  final String? lastSyncedRemoteVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'last_synced_local_revision': lastSyncedLocalRevision,
    'last_synced_backup_id': lastSyncedBackupId,
    'last_synced_remote_version': lastSyncedRemoteVersion,
  };

  static CloudSyncCursor fromJson(Map<dynamic, dynamic> json) {
    final rawRevision = json['last_synced_local_revision'];
    if (rawRevision != null && (rawRevision is! int || rawRevision < 1)) {
      throw const CloudAdapterException(
        'Stored cloud sync cursor has an invalid local revision.',
      );
    }

    String? optionalString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        throw CloudAdapterException(
          'Stored cloud sync cursor has an invalid $key.',
        );
      }
      return value;
    }

    return CloudSyncCursor(
      lastSyncedLocalRevision: rawRevision as int?,
      lastSyncedBackupId: optionalString('last_synced_backup_id'),
      lastSyncedRemoteVersion: optionalString('last_synced_remote_version'),
    );
  }
}

class CloudConflict {
  const CloudConflict({
    required this.localDeviceId,
    required this.localTimestamp,
    required this.localRevision,
    required this.localBaseBackupId,
    required this.remoteLineage,
    required this.remoteTimestamp,
    required this.remoteVersion,
    required this.lastSyncedBackupId,
  });

  final String localDeviceId;
  final DateTime localTimestamp;
  final int localRevision;
  final String? localBaseBackupId;
  final CloudLineage remoteLineage;
  final DateTime remoteTimestamp;
  final String remoteVersion;
  final String? lastSyncedBackupId;

  Map<String, dynamic> toDisplayData() => <String, dynamic>{
    'local_timestamp': localTimestamp.toUtc().toIso8601String(),
    'local_originating_device': localDeviceId,
    'local_revision': localRevision,
    'local_base_backup_id': localBaseBackupId,
    'remote_timestamp': remoteTimestamp.toUtc().toIso8601String(),
    'remote_originating_device': remoteLineage.deviceId,
    'remote_revision': remoteLineage.dbRevision,
    'remote_backup_id': remoteLineage.backupId,
    'remote_base_backup_id': remoteLineage.baseBackupId,
    'last_synced_backup_id': lastSyncedBackupId,
    'remote_version': remoteVersion,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'local_device_id': localDeviceId,
    'local_timestamp': localTimestamp.toUtc().toIso8601String(),
    'local_revision': localRevision,
    'local_base_backup_id': localBaseBackupId,
    'remote_lineage': remoteLineage.toJson(),
    'remote_timestamp': remoteTimestamp.toUtc().toIso8601String(),
    'remote_version': remoteVersion,
    'last_synced_backup_id': lastSyncedBackupId,
  };

  static CloudConflict fromJson(Map<dynamic, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw CloudAdapterException(
          'Stored pending conflict has an invalid $key.',
        );
      }
      return value;
    }

    String? optionalString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        throw CloudAdapterException(
          'Stored pending conflict has an invalid $key.',
        );
      }
      return value;
    }

    int requiredInt(String key) {
      final value = json[key];
      if (value is! int || value < 1) {
        throw CloudAdapterException(
          'Stored pending conflict has an invalid $key.',
        );
      }
      return value;
    }

    DateTime requiredUtcTimestamp(String key) {
      final value = json[key];
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null || !parsed.isUtc) {
        throw CloudAdapterException(
          'Stored pending conflict has an invalid $key.',
        );
      }
      return parsed;
    }

    final rawLineage = json['remote_lineage'];
    if (rawLineage is! Map) {
      throw const CloudAdapterException(
        'Stored pending conflict has no remote lineage.',
      );
    }

    return CloudConflict(
      localDeviceId: requiredString('local_device_id'),
      localTimestamp: requiredUtcTimestamp('local_timestamp'),
      localRevision: requiredInt('local_revision'),
      localBaseBackupId: optionalString('local_base_backup_id'),
      remoteLineage: CloudLineage.fromJson(rawLineage),
      remoteTimestamp: requiredUtcTimestamp('remote_timestamp'),
      remoteVersion: requiredString('remote_version'),
      lastSyncedBackupId: optionalString('last_synced_backup_id'),
    );
  }
}

enum CloudBackupDiscoveryKind { noBackup, found, invalidBackup, failed }

/// Read-only remote lookup result. It never applies or uploads application data.
class CloudBackupDiscoveryResult {
  const CloudBackupDiscoveryResult._({
    required this.kind,
    this.conflict,
    this.message,
  });

  factory CloudBackupDiscoveryResult.noBackup() =>
      const CloudBackupDiscoveryResult._(
        kind: CloudBackupDiscoveryKind.noBackup,
      );

  factory CloudBackupDiscoveryResult.found(CloudConflict conflict) =>
      CloudBackupDiscoveryResult._(
        kind: CloudBackupDiscoveryKind.found,
        conflict: conflict,
      );

  factory CloudBackupDiscoveryResult.invalidBackup(String message) =>
      CloudBackupDiscoveryResult._(
        kind: CloudBackupDiscoveryKind.invalidBackup,
        message: message,
      );

  factory CloudBackupDiscoveryResult.failed(String message) =>
      CloudBackupDiscoveryResult._(
        kind: CloudBackupDiscoveryKind.failed,
        message: message,
      );

  final CloudBackupDiscoveryKind kind;
  final CloudConflict? conflict;
  final String? message;
}

class CloudSyncResult {
  const CloudSyncResult._({
    required this.kind,
    this.conflict,
    this.message,
    this.backup,
  });

  factory CloudSyncResult.noOp() =>
      const CloudSyncResult._(kind: CloudSyncResultKind.noOp);

  factory CloudSyncResult.uploaded(CloudBackup backup) =>
      CloudSyncResult._(kind: CloudSyncResultKind.uploaded, backup: backup);

  factory CloudSyncResult.downloaded(CloudBackup backup) =>
      CloudSyncResult._(kind: CloudSyncResultKind.downloaded, backup: backup);

  factory CloudSyncResult.conflict(CloudConflict conflict) =>
      CloudSyncResult._(kind: CloudSyncResultKind.conflict, conflict: conflict);

  factory CloudSyncResult.remoteMissing(String message) => CloudSyncResult._(
    kind: CloudSyncResultKind.remoteMissing,
    message: message,
  );

  factory CloudSyncResult.skipped(String message) =>
      CloudSyncResult._(kind: CloudSyncResultKind.skipped, message: message);

  factory CloudSyncResult.failed(String message) =>
      CloudSyncResult._(kind: CloudSyncResultKind.failed, message: message);

  final CloudSyncResultKind kind;
  final CloudConflict? conflict;
  final String? message;
  final CloudBackup? backup;

  bool get isSuccessful =>
      kind != CloudSyncResultKind.failed &&
      kind != CloudSyncResultKind.conflict;
}
