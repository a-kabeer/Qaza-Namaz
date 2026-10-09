import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

import 'cloud_models.dart';

abstract interface class Phase1BackupSource {
  Future<int> readDbRevision();
  Future<String> exportBackup();
  Future<void> importBackup(String phase1BackupJson);
  Future<void> saveRecoverySnapshot(String phase1BackupJson);
  Future<String?> readRecoverySnapshot();
  Future<void> clearRecoverySnapshot();
}

class LocalPhase1BackupSource implements Phase1BackupSource {
  LocalPhase1BackupSource(this.database)
    : _backupService = LocalBackupService(database);

  final AppDatabase database;
  final LocalBackupService _backupService;

  @override
  Future<int> readDbRevision() => database.readDbRevision();

  @override
  Future<String> exportBackup() => _backupService.exportJson();

  @override
  Future<void> importBackup(String phase1BackupJson) =>
      _backupService.importJson(phase1BackupJson);

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
  Future<CloudRemoteSnapshot?> latest({required bool allowInteractive});

  Future<CloudRemoteSnapshot> write(
    CloudBackup backup, {
    required bool allowInteractive,
  });
}
