import 'dart:convert';

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
  Future<int> readDbRevision() {
    final accountId = localAccountId;
    if (accountId == null) return database.readDbRevision();
    return database.readWorkspaceRevision(accountId);
  }

  @override
  Future<String> exportBackup() =>
      _backupService.exportJson(localAccountId: localAccountId);

  @override
  Future<void> validateBackup(String phase1BackupJson) async {
    await _backupService.analyzeImport(phase1BackupJson);
    final expectedWorkspaceId = localAccountId;
    if (expectedWorkspaceId == null) return;

    final decoded = jsonDecode(phase1BackupJson);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const LocalBackupException(
        'The cloud backup is missing its workspace data.',
      );
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final acceptableIds = <String>{expectedWorkspaceId};
    if (expectedWorkspaceId.startsWith('google_')) {
      acceptableIds.add('google:${expectedWorkspaceId.substring(7)}');
    }

    final accountRows = data['local_accounts'];
    if (accountRows is! List ||
        accountRows.length != 1 ||
        accountRows.single is! Map ||
        !acceptableIds.contains(
          (accountRows.single as Map)['local_account_id'],
        )) {
      throw const LocalBackupException(
        'This cloud backup belongs to a different workspace. Local data was not changed.',
      );
    }

    const owners = <(String, String)>[
      ('qaza_records', 'userId'),
      ('daily_salah_logs', 'user_id'),
      ('qaza_additions', 'user_id'),
      ('qaza_deletion_actions', 'user_id'),
      ('qaza_deletion_action_record_snapshots', 'user_id'),
      ('qaza_profile_plan_provenance', 'user_id'),
      ('account_profiles', 'local_account_id'),
      ('account_plan_revisions', 'local_account_id'),
    ];
    for (final (table, column) in owners) {
      final rows = data[table];
      if (rows is! List) {
        throw const LocalBackupException(
          'The cloud backup is missing required workspace-owned data. Local data was not changed.',
        );
      }
      for (final row in rows) {
        if (row is! Map || !acceptableIds.contains(row[column])) {
          throw const LocalBackupException(
            'The cloud backup contains records from another workspace. Local data was not changed.',
          );
        }
      }
    }
    final sessions = data['app_session_state'];
    if (sessions is! List ||
        sessions.length != 1 ||
        sessions.single is! Map ||
        !acceptableIds.contains(
          (sessions.single as Map)['active_local_account_id'],
        )) {
      throw const LocalBackupException(
        'The cloud backup session does not match the selected workspace. Local data was not changed.',
      );
    }
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
