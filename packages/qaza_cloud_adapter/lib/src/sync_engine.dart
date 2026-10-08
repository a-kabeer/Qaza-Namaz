import 'dart:convert';
import 'dart:math';

import 'cloud_models.dart';
import 'cloud_state_store.dart';
import 'phase1_backup_bridge.dart';

class CloudSyncEngine {
  CloudSyncEngine({
    required Phase1BackupSource phase1,
    required CloudRemoteStore remote,
    required CloudSyncStateStore state,
  }) : _phase1 = phase1,
       _remote = remote,
       _state = state;

  final Phase1BackupSource _phase1;
  final CloudRemoteStore _remote;
  final CloudSyncStateStore _state;

  Future<CloudSyncResult> sync({bool allowInteractive = false}) async {
    final cursor = await _state.readCursor();
    final deviceId = await _state.deviceId();
    final localRevision = await _phase1.readDbRevision();

    CloudRemoteSnapshot? remote;
    try {
      remote = await _remote.latest(allowInteractive: allowInteractive);
    } on CloudAuthorizationUnavailable catch (error) {
      return CloudSyncResult.skipped(error.message);
    } on CloudAdapterException catch (error) {
      return CloudSyncResult.failed(error.message);
    } catch (error) {
      return CloudSyncResult.failed('Cloud read failed: $error');
    }

    final localUnsynced = cursor.lastSyncedLocalRevision == null
        ? localRevision > 1
        : localRevision > cursor.lastSyncedLocalRevision!;

    final remoteChanged = cursor.lastSyncedBackupId == null
        ? remote != null
        : remote == null ||
              remote.backup.lineage.backupId != cursor.lastSyncedBackupId;

    if (!localUnsynced && !remoteChanged) {
      return CloudSyncResult.noOp();
    }

    if (remote == null) {
      if (cursor.lastSyncedBackupId != null) {
        return CloudSyncResult.remoteMissing(
          'The last cloud backup is no longer available. Local data was not changed.',
        );
      }
      return CloudSyncResult.noOp();
    }

    if (localUnsynced && remoteChanged) {
      final localPreview = await _localPreview();
      return CloudSyncResult.conflict(
        CloudConflict(
          localDeviceId: deviceId,
          localTimestamp: localPreview.timestamp,
          localRevision: localRevision,
          localBaseBackupId: cursor.lastSyncedBackupId,
          remoteLineage: remote.backup.lineage,
          remoteTimestamp: remote.modifiedAt,
          remoteVersion: remote.remoteVersion,
          lastSyncedBackupId: cursor.lastSyncedBackupId,
        ),
      );
    }

    if (localUnsynced) {
      final localJson = await _phase1.exportBackup();
      final localPreview = _parsePhase1Preview(localJson);
      final backup = CloudBackup(
        lineage: CloudLineage(
          deviceId: deviceId,
          backupId: _newBackupId(),
          baseBackupId: cursor.lastSyncedBackupId,
          dbRevision: localRevision,
          createdAt: localPreview.timestamp,
        ),
        phase1BackupJson: localJson,
      );

      final written = await _remote.write(
        backup,
        allowInteractive: allowInteractive,
      );
      await _state.writeCursor(
        CloudSyncCursor(
          lastSyncedLocalRevision: localRevision,
          lastSyncedBackupId: written.backup.lineage.backupId,
          lastSyncedRemoteVersion: written.remoteVersion,
        ),
      );
      return CloudSyncResult.uploaded(backup);
    }

    await _phase1.importBackup(remote.backup.phase1BackupJson);
    final importedLocalRevision = await _phase1.readDbRevision();
    await _state.writeCursor(
      CloudSyncCursor(
        lastSyncedLocalRevision: importedLocalRevision,
        lastSyncedBackupId: remote.backup.lineage.backupId,
        lastSyncedRemoteVersion: remote.remoteVersion,
      ),
    );
    return CloudSyncResult.downloaded(remote.backup);
  }

  Future<CloudSyncResult> resolveConflict({
    required CloudConflict conflict,
    required CloudConflictDecision decision,
    required bool confirmed,
    bool allowInteractive = true,
  }) async {
    if (!confirmed) {
      throw const CloudAdapterException(
        'Explicit user confirmation is required before resolving a conflict.',
      );
    }

    final cursor = await _state.readCursor();
    final currentLocalRevision = await _phase1.readDbRevision();
    if (currentLocalRevision != conflict.localRevision ||
        cursor.lastSyncedBackupId != conflict.lastSyncedBackupId) {
      throw const CloudConflictStaleException();
    }

    final remote = await _remote.latest(allowInteractive: allowInteractive);
    if (remote == null ||
        remote.backup.lineage.backupId != conflict.remoteLineage.backupId) {
      throw const CloudConflictStaleException();
    }

    final deviceId = await _state.deviceId();

    switch (decision) {
      case CloudConflictDecision.keepLocal:
        final localJson = await _phase1.exportBackup();
        final localPreview = _parsePhase1Preview(localJson);
        final backup = CloudBackup(
          lineage: CloudLineage(
            deviceId: deviceId,
            backupId: _newBackupId(),
            baseBackupId: remote.backup.lineage.backupId,
            dbRevision: currentLocalRevision,
            createdAt: localPreview.timestamp,
          ),
          phase1BackupJson: localJson,
        );

        final written = await _remote.write(
          backup,
          allowInteractive: allowInteractive,
        );
        await _state.writeCursor(
          CloudSyncCursor(
            lastSyncedLocalRevision: currentLocalRevision,
            lastSyncedBackupId: written.backup.lineage.backupId,
            lastSyncedRemoteVersion: written.remoteVersion,
          ),
        );
        return CloudSyncResult.uploaded(backup);

      case CloudConflictDecision.useRemote:
        await _phase1.importBackup(remote.backup.phase1BackupJson);
        final importedRevision = await _phase1.readDbRevision();
        await _state.writeCursor(
          CloudSyncCursor(
            lastSyncedLocalRevision: importedRevision,
            lastSyncedBackupId: remote.backup.lineage.backupId,
            lastSyncedRemoteVersion: remote.remoteVersion,
          ),
        );
        return CloudSyncResult.downloaded(remote.backup);
    }
  }

  Future<_Phase1Preview> _localPreview() async {
    return _parsePhase1Preview(await _phase1.exportBackup());
  }

  _Phase1Preview _parsePhase1Preview(String jsonText) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup payload is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup root is not a JSON object.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);
    final metadata = root['metadata'];
    if (metadata is! Map) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup metadata is missing.',
      );
    }

    final timestamp = metadata['export_timestamp'];
    final parsed = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final revision = metadata['db_revision'];
    if (parsed == null || !parsed.isUtc || revision is! int || revision < 1) {
      throw const CloudRemoteFormatException(
        'The Phase 1 backup metadata is invalid.',
      );
    }

    return _Phase1Preview(timestamp: parsed, revision: revision);
  }

  String _newBackupId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'backup-' +
        DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        '-' +
        suffix;
  }
}

class _Phase1Preview {
  const _Phase1Preview({required this.timestamp, required this.revision});

  final DateTime timestamp;
  final int revision;
}
