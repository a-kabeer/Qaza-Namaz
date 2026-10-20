import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

import 'cloud_models.dart';
import 'google_sign_in_gateway.dart';
import 'phase1_backup_bridge.dart';

const int _maxDriveRetries = 3;
const Duration _driveRetryBudget = Duration(seconds: 20);
final Random _driveRetryRandom = Random();

/// Streams serialized backup bytes and reports request-body consumption. These
/// updates are not server acknowledgements; completion is reported only after
/// Drive confirms the write and the sync cursor is persisted.
Stream<List<int>> cloudUploadProgressStream(
  List<int> bytes, {
  CloudBackupProgressCallback? onProgress,
}) async* {
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

/// Retries safe Drive GETs only. Create/upload requests are never automatically
/// replayed by this client because a lost response may hide a successful write.
class _RetryingDriveClient extends http.BaseClient {
  _RetryingDriveClient(this._inner);

  final http.Client _inner;
  Duration? lastRetryAfter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRetryAfter = null;
    if (request.method.toUpperCase() != 'GET') {
      final response = await _inner.send(request);
      lastRetryAfter = _parseRetryAfter(response.headers['retry-after']);
      return response;
    }

    final requestBytes = await request.finalize().toBytes();
    final deadline = DateTime.now().add(_driveRetryBudget);
    for (var attempt = 0; ; attempt++) {
      final retryRequest = http.Request('GET', request.url)
        ..headers.addAll(request.headers)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection;
      if (requestBytes.isNotEmpty) retryRequest.bodyBytes = requestBytes;

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Google Drive read retry budget exhausted.');
      }
      final response = await _inner.send(retryRequest).timeout(remaining);
      lastRetryAfter = _parseRetryAfter(response.headers['retry-after']);

      if (!_isPotentiallyRetryableStatus(response.statusCode)) return response;
      final responseBytes = await response.stream.toBytes();
      if (!_isRetryableResponse(response.statusCode, responseBytes) ||
          attempt >= _maxDriveRetries) {
        return _restoreResponse(response, responseBytes);
      }

      final delay = _retryDelay(
        attempt,
        retryAfter: response.headers['retry-after'],
        deadline: deadline,
      );
      if (delay == null) return _restoreResponse(response, responseBytes);
      await Future<void>.delayed(delay);
    }
  }

  @override
  void close() => _inner.close();

  Duration? delayForWriteRetry(int attempt, DateTime deadline) => _retryDelay(
    attempt,
    retryAfter: lastRetryAfter == null
        ? null
        : _durationAsRetryAfter(lastRetryAfter!),
    deadline: deadline,
  );

  static bool _isPotentiallyRetryableStatus(int status) =>
      status == 403 ||
      status == 408 ||
      status == 429 ||
      status == 500 ||
      status == 502 ||
      status == 503 ||
      status == 504;

  static bool _isRetryableResponse(int status, List<int> bodyBytes) {
    if (status == 408 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504) {
      return true;
    }
    return status == 403 && _hasRateLimitReason(bodyBytes);
  }

  static bool _hasRateLimitReason(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! Map) return false;
      final error = decoded['error'];
      if (error is! Map) return false;
      final details = error['errors'];
      if (details is! List) return false;
      return details.any((item) {
        if (item is! Map) return false;
        final reason = item['reason'];
        return reason == 'rateLimitExceeded' ||
            reason == 'userRateLimitExceeded';
      });
    } catch (_) {
      return false;
    }
  }

  static http.StreamedResponse _restoreResponse(
    http.StreamedResponse response,
    List<int> bytes,
  ) => http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    response.statusCode,
    request: response.request,
    headers: response.headers,
    reasonPhrase: response.reasonPhrase,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    contentLength: bytes.length,
  );

  static Duration? _retryDelay(
    int attempt, {
    String? retryAfter,
    required DateTime deadline,
  }) {
    final requested =
        _parseRetryAfter(retryAfter) ??
        Duration(
          milliseconds: (500 * (1 << attempt)) + _driveRetryRandom.nextInt(251),
        );
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero || requested > remaining) return null;
    return requested;
  }
}

class GoogleDriveAppDataStore
    implements CloudRemoteStore, CloudRemoteMetadataStore {
  GoogleDriveAppDataStore(this._auth);

  final GoogleSignInGateway _auth;

  @override
  Future<CloudRemoteSnapshot?> latest({
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  }) => _withDrive<CloudRemoteSnapshot?>(
    allowInteractive: allowInteractive,
    action: (driveApi, _) async {
      final metadata = await _latestMetadata(driveApi);
      if (metadata == null) return null;
      return _downloadBackup(driveApi, metadata, onProgress: onProgress);
    },
  );

  @override
  Future<CloudRemoteMetadata?> latestMetadata({
    required bool allowInteractive,
  }) => _withDrive<CloudRemoteMetadata?>(
    allowInteractive: allowInteractive,
    action: (driveApi, _) => _latestMetadata(driveApi),
  );

  @override
  Future<CloudRemoteSnapshot> download(
    CloudRemoteMetadata metadata, {
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  }) => _withDrive<CloudRemoteSnapshot>(
    allowInteractive: allowInteractive,
    action: (driveApi, _) =>
        _downloadBackup(driveApi, metadata, onProgress: onProgress),
  );

  Future<CloudRemoteMetadata?> _latestMetadata(drive.DriveApi driveApi) async {
    final response = await _retryReadAfterTransportFailure(
      () => driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$cloudBackupFilePrefix' and trashed = false",
        orderBy: 'modifiedTime desc,name desc',
        pageSize: 1,
        $fields:
            'files(id,name,size,modifiedTime,version,md5Checksum,appProperties)',
      ),
    );
    final files = response.files ?? const <drive.File>[];
    if (files.isEmpty) return null;
    final metadata = _metadataFromFile(files.first);
    final metadataGoogleId = metadata.googleAccountId?.trim();
    if (metadataGoogleId != null && metadataGoogleId.isNotEmpty) {
      final actualGoogleId = await _auth.accountIdForAuthorization();
      if (actualGoogleId == null || actualGoogleId.trim() != metadataGoogleId) {
        throw const CloudAccountIdentityMismatch(
          'The latest cloud backup belongs to a different Google account.',
        );
      }
      if (metadata.workspaceId != 'google_$metadataGoogleId') {
        throw const CloudRemoteFormatException(
          'The latest cloud backup has an invalid workspace identity.',
        );
      }
    }
    return metadata;
  }

  CloudRemoteMetadata _metadataFromFile(drive.File file) {
    final fileId = file.id;
    if (fileId == null || fileId.isEmpty) {
      throw const CloudRemoteFormatException(
        'The latest cloud backup has no Drive file ID.',
      );
    }
    final properties = file.appProperties ?? const <String, String>{};
    final rawBackupId = properties['backup_id'];
    final backupId = rawBackupId == null || rawBackupId.trim().isEmpty
        ? null
        : rawBackupId;
    final version = file.version ?? file.md5Checksum;
    return CloudRemoteMetadata(
      fileId: fileId,
      backupId: backupId,
      remoteVersion: version,
      modifiedAt: file.modifiedTime?.toUtc(),
      hasAuthoritativeVersion: version != null && version.isNotEmpty,
      sizeBytes: int.tryParse(file.size ?? ''),
      googleAccountId: properties['google_account_id'],
      workspaceId: properties['workspace_id'],
      contentSha256: properties['content_sha256'],
      databaseSchemaVersion: properties['database_schema_version'],
      contentMd5: file.md5Checksum,
    );
  }

  Future<CloudRemoteSnapshot> _downloadBackup(
    drive.DriveApi driveApi,
    CloudRemoteMetadata metadata, {
    CloudBackupProgressCallback? onProgress,
  }) async {
    final bytes = await _retryReadAfterTransportFailure(() async {
      final raw = await driveApi.files.get(
        metadata.fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (raw is! drive.Media) {
        throw const CloudRemoteFormatException(
          'The latest cloud backup could not be downloaded as media.',
        );
      }
      final result = <int>[];
      final totalBytes = metadata.sizeBytes ?? 0;
      onProgress?.call(
        CloudBackupProgress.downloading(
          receivedBytes: 0,
          totalBytes: totalBytes,
        ),
      );
      await for (final chunk in raw.stream) {
        result.addAll(chunk);
        onProgress?.call(
          CloudBackupProgress.downloading(
            receivedBytes: result.length,
            totalBytes: totalBytes,
          ),
        );
      }
      return result;
    });

    final actualSha256 = sha256.convert(bytes).toString();
    if (metadata.contentSha256 != null &&
        metadata.contentSha256!.toLowerCase() != actualSha256) {
      throw const CloudRemoteFormatException(
        'The downloaded cloud backup failed its SHA-256 content check.',
      );
    }
    if (metadata.contentMd5 != null &&
        metadata.contentMd5!.toLowerCase() != md5.convert(bytes).toString()) {
      throw const CloudRemoteFormatException(
        'The downloaded cloud backup failed Google Drive’s MD5 content check.',
      );
    }

    final backup = CloudBackup.fromJsonString(utf8.decode(bytes));
    if (metadata.backupId != null &&
        metadata.backupId != backup.lineage.backupId) {
      throw const CloudRemoteFormatException(
        'Drive backup metadata does not match the backup lineage.',
      );
    }

    final expectedGoogleId = metadata.googleAccountId?.trim();
    if (expectedGoogleId != null && expectedGoogleId.isNotEmpty) {
      final actualGoogleId = await _auth.accountIdForAuthorization();
      if (actualGoogleId == null || actualGoogleId.trim() != expectedGoogleId) {
        throw const CloudAccountIdentityMismatch(
          'The backup metadata belongs to a different Google account. No local data was changed.',
        );
      }
      if (metadata.workspaceId != 'google_$expectedGoogleId') {
        throw const CloudRemoteFormatException(
          'The cloud backup workspace identity does not match its Google account.',
        );
      }
      if (metadata.databaseSchemaVersion !=
          _databaseSchemaVersion(backup.phase1BackupJson)) {
        throw const CloudRemoteFormatException(
          'Cloud backup database schema metadata does not match its payload.',
        );
      }
    }
    return CloudRemoteSnapshot(
      fileId: metadata.fileId,
      remoteVersion:
          metadata.remoteVersion ?? backup.lineage.createdAt.toIso8601String(),
      modifiedAt: metadata.modifiedAt ?? backup.lineage.createdAt,
      backup: backup,
    );
  }

  @override
  Future<CloudRemoteSnapshot> write(
    CloudBackup backup, {
    required bool allowInteractive,
    CloudBackupProgressCallback? onProgress,
  }) => _withDrive<CloudRemoteSnapshot>(
    allowInteractive: allowInteractive,
    action: (driveApi, client) async {
      final googleAccountId = await _auth.accountIdForAuthorization();
      if (googleAccountId == null || googleAccountId.trim().isEmpty) {
        throw const CloudAccountIdentityMismatch(
          'The Google account could not be verified before upload. No backup was written.',
        );
      }
      final normalizedGoogleId = googleAccountId.trim();
      final workspaceId = 'google_$normalizedGoogleId';
      final bytes = utf8.encode(backup.toJsonString());
      final contentSha256 = sha256.convert(bytes).toString();
      final databaseSchemaVersion =
          _databaseSchemaVersion(backup.phase1BackupJson);
      final fileName =
          cloudBackupFilePrefix + backup.lineage.backupId + '.json';

      drive.File created;
      try {
        created = await _createWithRateLimitRetries(
          driveApi,
          client,
          backup: backup,
          fileName: fileName,
          bytes: bytes,
          googleAccountId: normalizedGoogleId,
          workspaceId: workspaceId,
          contentSha256: contentSha256,
          databaseSchemaVersion: databaseSchemaVersion,
          onProgress: onProgress,
        );
      } catch (error) {
        if (!_isAmbiguousUploadFailure(error)) rethrow;
        final recovered = await _reconcileAmbiguousUpload(
          driveApi,
          backup: backup,
          fileName: fileName,
          googleAccountId: normalizedGoogleId,
          workspaceId: workspaceId,
          contentSha256: contentSha256,
          databaseSchemaVersion: databaseSchemaVersion,
        );
        if (recovered != null) return recovered;
        throw CloudDriveRequestException(
          'Google Drive could not confirm whether the backup finished. Your local data is safe; tap Back up now again to check the remote status before retrying.',
          error,
        );
      }

      final fileId = created.id;
      if (fileId == null || fileId.isEmpty) {
        final recovered = await _reconcileAmbiguousUpload(
          driveApi,
          backup: backup,
          fileName: fileName,
          googleAccountId: normalizedGoogleId,
          workspaceId: workspaceId,
          contentSha256: contentSha256,
          databaseSchemaVersion: databaseSchemaVersion,
        );
        if (recovered != null) return recovered;
        throw CloudDriveRequestException(
          'Google Drive did not confirm the uploaded backup. Your local data is safe; retry after checking the connection.',
          StateError('Drive create response did not include a file ID.'),
        );
      }

      final metadata = _metadataFromFile(created);
      if (!metadata.hasVerifiedWorkspaceMetadata ||
          metadata.googleAccountId != normalizedGoogleId ||
          metadata.workspaceId != workspaceId ||
          metadata.contentSha256 != contentSha256 ||
          metadata.databaseSchemaVersion != databaseSchemaVersion) {
        throw const CloudRemoteFormatException(
          'Google Drive did not confirm the backup identity, schema, and content-hash metadata. The local ledger was not changed.',
        );
      }

      // A successful create response confirms acceptance, not that uploaded
      // bytes can be read intact. Verify the exact envelope before advancing
      // the sync cursor.
      final verified = await _downloadBackup(
        driveApi,
        metadata,
        onProgress: onProgress,
      );
      if (!_sameLineage(verified.backup.lineage, backup.lineage) ||
          verified.backup.toJsonString() != backup.toJsonString()) {
        throw const CloudRemoteFormatException(
          'Google Drive read-back verification did not match the uploaded backup. The local ledger was not changed.',
        );
      }
      return verified;
    },
  );

  Future<drive.File> _createWithRateLimitRetries(
    drive.DriveApi driveApi,
    _RetryingDriveClient client, {
    required CloudBackup backup,
    required String fileName,
    required List<int> bytes,
    required String googleAccountId,
    required String workspaceId,
    required String contentSha256,
    required String databaseSchemaVersion,
    required CloudBackupProgressCallback? onProgress,
  }) async {
    final deadline = DateTime.now().add(_driveRetryBudget);
    for (var attempt = 0; ; attempt++) {
      try {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('Google Drive upload retry budget exhausted.');
        }
        return await driveApi.files
            .create(
              drive.File()
                ..name = fileName
                ..mimeType = 'application/json'
                ..parents = <String>['appDataFolder']
                ..appProperties = <String, String>{
                  'backup_id': backup.lineage.backupId,
                  'device_id': backup.lineage.deviceId,
                  'base_backup_id': backup.lineage.baseBackupId ?? '',
                  'db_revision': backup.lineage.dbRevision.toString(),
                  'google_account_id': googleAccountId,
                  'workspace_id': workspaceId,
                  'content_sha256': contentSha256,
                  'database_schema_version': databaseSchemaVersion,
                },
              uploadMedia: drive.Media(
                cloudUploadProgressStream(bytes, onProgress: onProgress),
                bytes.length,
                contentType: 'application/json',
              ),
              $fields: 'id,name,modifiedTime,version,md5Checksum,appProperties',
            )
            .timeout(remaining);
      } catch (error) {
        if (!_isExplicitRateLimit(error) || attempt >= _maxDriveRetries) {
          rethrow;
        }
        final delay = client.delayForWriteRetry(attempt, deadline);
        if (delay == null) rethrow;
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<CloudRemoteSnapshot?> _reconcileAmbiguousUpload(
    drive.DriveApi driveApi, {
    required CloudBackup backup,
    required String fileName,
    required String googleAccountId,
    required String workspaceId,
    required String contentSha256,
    required String databaseSchemaVersion,
  }) async {
    // Never create a second snapshot until the exact prior write is reconciled.
    final response = await _retryReadAfterTransportFailure(
      () => driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName' and trashed = false",
        pageSize: 10,
        $fields:
            'files(id,name,modifiedTime,version,md5Checksum,appProperties)',
      ),
    );
    final files = response.files ?? const <drive.File>[];
    if (files.isEmpty) return null;

    final matches = files.where((file) {
      final properties = file.appProperties ?? const <String, String>{};
      return file.name == fileName &&
          properties['backup_id'] == backup.lineage.backupId &&
          properties['device_id'] == backup.lineage.deviceId &&
          (properties['base_backup_id'] ?? '') ==
              (backup.lineage.baseBackupId ?? '') &&
          properties['db_revision'] == backup.lineage.dbRevision.toString() &&
          properties['google_account_id'] == googleAccountId &&
          properties['workspace_id'] == workspaceId &&
          properties['content_sha256'] == contentSha256 &&
          properties['database_schema_version'] == databaseSchemaVersion;
    }).toList();

    if (matches.length > 1) {
      throw const CloudRemoteFormatException(
        'Google Drive returned multiple copies of the pending backup. No second upload was attempted.',
      );
    }
    if (matches.isEmpty) return null;

    final metadata = _metadataFromFile(matches.single);
    final snapshot = await _downloadBackup(driveApi, metadata);
    if (!_sameLineage(snapshot.backup.lineage, backup.lineage) ||
        snapshot.backup.toJsonString() != backup.toJsonString()) {
      throw const CloudRemoteFormatException(
        'The uploaded backup could not be verified against its expected lineage.',
      );
    }
    return snapshot;
  }

  Future<T> _retryReadAfterTransportFailure<T>(
    Future<T> Function() request,
  ) async {
    final deadline = DateTime.now().add(_driveRetryBudget);
    for (var attempt = 0; ; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Google Drive read retry budget exhausted.');
      }
      try {
        return await request().timeout(remaining);
      } catch (error) {
        if (!_isTransientTransportFailure(error) ||
            attempt >= _maxDriveRetries) {
          rethrow;
        }
        final delay = Duration(
          milliseconds: (500 * (1 << attempt)) + _driveRetryRandom.nextInt(251),
        );
        if (delay > deadline.difference(DateTime.now())) rethrow;
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<T> _withDrive<T>({
    required bool allowInteractive,
    required Future<T> Function(drive.DriveApi, _RetryingDriveClient) action,
  }) async {
    final client = await _auth.authorizeDrive(
      allowInteractive: allowInteractive,
    );
    if (client == null) throw const CloudAuthorizationUnavailable();

    final retryingClient = _RetryingDriveClient(client);
    try {
      return await action(drive.DriveApi(retryingClient), retryingClient);
    } on CloudAdapterException {
      rethrow;
    } catch (error) {
      throw CloudDriveRequestException(_friendlyDriveError(error), error);
    } finally {
      retryingClient.close();
    }
  }
}

String _databaseSchemaVersion(String phase1BackupJson) {
  dynamic decoded;
  try {
    decoded = jsonDecode(phase1BackupJson);
  } catch (_) {
    throw const CloudRemoteFormatException(
      'The cloud backup payload is not valid JSON.',
    );
  }
  if (decoded is! Map || decoded['metadata'] is! Map) {
    throw const CloudRemoteFormatException(
      'The cloud backup payload is missing metadata.',
    );
  }
  final rawVersion = (decoded['metadata'] as Map)['database_schema_version'];
  final version = rawVersion is int
      ? rawVersion
      : rawVersion is String
          ? int.tryParse(rawVersion)
          : null;
  if (version == null || version < 1) {
    throw const CloudRemoteFormatException(
      'The cloud backup payload is missing a valid database schema version.',
    );
  }
  return version.toString();
}

bool _sameLineage(CloudLineage a, CloudLineage b) =>
    a.deviceId == b.deviceId &&
    a.backupId == b.backupId &&
    a.baseBackupId == b.baseBackupId &&
    a.dbRevision == b.dbRevision &&
    a.createdAt.toUtc() == b.createdAt.toUtc();

bool _isExplicitRateLimit(Object error) {
  if (error is! drive.DetailedApiRequestError) return false;
  if (error.status == 429) return true;
  return error.status == 403 &&
      error.errors.any(
        (detail) =>
            detail.reason == 'rateLimitExceeded' ||
            detail.reason == 'userRateLimitExceeded',
      );
}

bool _isAmbiguousUploadFailure(Object error) {
  if (_isTransientTransportFailure(error)) return true;
  if (error is! drive.DetailedApiRequestError) return false;
  return error.status == 408 ||
      error.status == 500 ||
      error.status == 502 ||
      error.status == 503 ||
      error.status == 504;
}

bool _isTransientTransportFailure(Object error) =>
    error is http.ClientException ||
    error is IOException ||
    error is TimeoutException;

String _friendlyDriveError(Object error) {
  if (error is drive.DetailedApiRequestError) {
    final status = error.status;
    if (status == 401) {
      return 'Google Drive authorization may have expired. Reconnect Google from Account settings and try again.';
    }
    if (status == 403) {
      if (_isExplicitRateLimit(error)) {
        return 'Google Drive is temporarily limiting requests. Wait a moment and try again.';
      }
      return 'Google Drive denied access. Reconnect Google and check the requested Drive permission.';
    }
    if (status == 404) {
      return 'The cloud backup could not be found. Refresh the Account screen and try again.';
    }
    if (status == 408 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504) {
      return 'Google Drive is temporarily unavailable. Check your connection and try again.';
    }
    if (status == 400) {
      return 'Google Drive rejected the backup request. Reconnect Google and try again.';
    }
  }
  if (_isTransientTransportFailure(error)) {
    return 'Could not reach Google Drive. Check your internet connection and try again.';
  }
  return 'Google Drive could not complete the backup. Please try again.';
}

Duration? _parseRetryAfter(String? header) {
  if (header == null || header.trim().isEmpty) return null;
  final seconds = int.tryParse(header.trim());
  if (seconds != null) {
    return seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
  }
  DateTime? date;
  try {
    date = HttpDate.parse(header.trim());
  } catch (_) {
    date = DateTime.tryParse(header);
  }
  if (date == null) return null;
  final delay = date.toUtc().difference(DateTime.now().toUtc());
  return delay.isNegative ? Duration.zero : delay;
}

String _durationAsRetryAfter(Duration duration) =>
    (duration.inMilliseconds / 1000).ceil().toString();
