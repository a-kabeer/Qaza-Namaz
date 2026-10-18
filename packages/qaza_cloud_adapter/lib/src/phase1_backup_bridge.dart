import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

import 'cloud_models.dart';

abstract interface class Phase1BackupSource {
  Future<int> readDbRevision();
  Future<String> exportBackup();

  /// Validates a remote payload without applying it to the local database.
  Future<void> validateBackup(String phase1BackupJson);

  Future<void> importBackup(String phase1BackupJson);
  Future<void> saveRecoverySnapshot(String phase1BackupJson);
  Future<String?> readRecoverySnapshot();
  Future<void> clearRecoverySnapshot();
}

/// Optional metadata-first capability. Drive can avoid downloading the full
/// snapshot when its backup identity and authoritative version match the cursor.
abstract interface class CloudRemoteMetadataStore {
  Future<CloudRemoteMetadata?> latestMetadata({required bool allowInteractive});

  Future<CloudRemoteSnapshot> download(
    CloudRemoteMetadata metadata, {
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  });
}

class LocalPhase1BackupSource implements Phase1BackupSource {
  LocalPhase1BackupSource(this.database, {this.localAccountId})
    : _backupService = LocalBackupService(database);

  final AppDatabase database;

  /// When set, cloud exports/imports are restricted to one local workspace.
  /// Null preserves the all-workspace behavior for explicit full local exports.
  final String? localAccountId;
  final LocalBackupService _backupService;

  @override
  Future<int> readDbRevision() => database.readDbRevision();

  @override
  Future<String> exportBackup() =>
      _backupService.exportJson(localAccountId: localAccountId);

  @override
  Future<void> validateBackup(String phase1BackupJson) async {
    await _backupService.analyzeImport(phase1BackupJson);
  }

  @override
  Future<void> importBackup(String phase1BackupJson) => _backupService
      .importJson(phase1BackupJson, targetLocalAccountId: localAccountId);

  @override
  Future<void> saveRecoverySnapshot(String phase1BackupJson) =>
      database.saveLocalRecoverySnapshot(phase1BackupJson);

  @override
  Future<String?> readRecoverySnapshot() =>
      database.readLocalRecoverySnapshot();

  @override
  Future<void> clearRecoverySnapshot() => database.clearLocalRecoverySnapshot();
}

abstract interface class CloudRemoteStore {
  Future<CloudRemoteSnapshot?> latest({
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  });

  Future<CloudRemoteSnapshot> write(
    CloudBackup backup, {
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  });
}
