import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

import 'cloud_models.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';

/// Streams the serialized backup in chunks and reports bytes consumed by
/// the HTTP request body. These are stream-consumption updates, not a server
/// acknowledgement; callers must wait for the remote write response to show
/// 100% completion.
Stream<List<int>> cloudUploadProgressStream(
  List<int> bytes, {
  CloudBackupProgressCallback? onProgress,
}) async* {
  // About 100 updates for large backups, but several updates for small payloads.
  final chunkSize = bytes.length < 16 * 1024
      ? 1024
      : (bytes.length / 100).ceil().clamp(1024, 16 * 1024).toInt();
  onProgress?.call(
    CloudBackupProgress.uploading(sentBytes: 0, totalBytes: bytes.length),
  );
  var offset = 0;
  while (offset < bytes.length) {
    final end = offset + chunkSize < bytes.length
        ? offset + chunkSize
        : bytes.length;
    yield bytes.sublist(offset, end);
    offset = end;
    onProgress?.call(
      CloudBackupProgress.uploading(
        sentBytes: offset,
        totalBytes: bytes.length,
      ),
    );
  }
}

class GoogleDriveAppDataStore implements CloudRemoteStore {
  GoogleDriveAppDataStore(this._auth);

  final GoogleSignInGateway _auth;

  @override
  Future<CloudRemoteSnapshot?> latest({required bool allowInteractive}) async {
    return _withDrive<CloudRemoteSnapshot?>(
      allowInteractive: allowInteractive,
      action: (driveApi) async {
        final response = await driveApi.files.list(
          spaces: 'appDataFolder',
          q:
              "name contains '" +
              cloudBackupFilePrefix +
              "' and trashed = false",
          orderBy: 'modifiedTime desc,name desc',
          pageSize: 1,
          $fields:
              'files(id,name,modifiedTime,version,md5Checksum,appProperties)',
        );

        final files = response.files ?? const <drive.File>[];
        if (files.isEmpty) return null;

        final file = files.first;
        final fileId = file.id;
        if (fileId == null || fileId.isEmpty) {
          throw const CloudRemoteFormatException(
            'The latest cloud backup has no Drive file ID.',
          );
        }

        final raw = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        if (raw is! drive.Media) {
          throw const CloudRemoteFormatException(
            'The latest cloud backup could not be downloaded as media.',
          );
        }

        final bytes = <int>[];
        await for (final chunk in raw.stream) {
          bytes.addAll(chunk);
        }

        final backup = CloudBackup.fromJsonString(utf8.decode(bytes));
        final modifiedAt =
            file.modifiedTime?.toUtc() ?? backup.lineage.createdAt;
        final remoteVersion =
            file.version ?? file.md5Checksum ?? modifiedAt.toIso8601String();

        return CloudRemoteSnapshot(
          fileId: fileId,
          remoteVersion: remoteVersion,
          modifiedAt: modifiedAt,
          backup: backup,
        );
      },
    );
  }

  @override
  Future<CloudRemoteSnapshot> write(
    CloudBackup backup, {
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  }) async {
    return _withDrive<CloudRemoteSnapshot>(
      allowInteractive: allowInteractive,
      action: (driveApi) async {
        final bytes = utf8.encode(backup.toJsonString());
        final fileName =
            cloudBackupFilePrefix + backup.lineage.backupId + '.json';

        final created = await driveApi.files.create(
          drive.File()
            ..name = fileName
            ..mimeType = 'application/json'
            ..parents = <String>['appDataFolder']
            ..appProperties = <String, String>{
              'backup_id': backup.lineage.backupId,
              'device_id': backup.lineage.deviceId,
              'base_backup_id': backup.lineage.baseBackupId ?? '',
              'db_revision': backup.lineage.dbRevision.toString(),
            },
          uploadMedia: drive.Media(
            cloudUploadProgressStream(bytes, onProgress: onProgress),
            bytes.length,
            contentType: 'application/json',
          ),
          $fields: 'id,name,modifiedTime,version,md5Checksum,appProperties',
        );

        final fileId = created.id;
        if (fileId == null || fileId.isEmpty) {
          throw const CloudAdapterException(
            'Google Drive did not return a cloud backup file ID.',
          );
        }

        final modifiedAt =
            created.modifiedTime?.toUtc() ?? backup.lineage.createdAt;
        final remoteVersion =
            created.version ??
            created.md5Checksum ??
            modifiedAt.toIso8601String();

        return CloudRemoteSnapshot(
          fileId: fileId,
          remoteVersion: remoteVersion,
          modifiedAt: modifiedAt,
          backup: backup,
        );
      },
    );
  }

  Future<T> _withDrive<T>({
    required bool allowInteractive,
    required Future<T> Function(drive.DriveApi) action,
  }) async {
    final client = await _auth.authorizeDrive(
      allowInteractive: allowInteractive,
    );
    if (client == null) {
      throw const CloudAuthorizationUnavailable();
    }

    try {
      return await action(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }
}
