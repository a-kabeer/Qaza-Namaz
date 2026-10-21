import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 4 provider-level tests for [GoogleCloudSyncProvider]:
///
/// * Keep Both conflict resolution end to end — the local workspace is kept,
///   the remote backup is preserved as a verified `recovery_copy` workspace,
///   and the conflict is cleared by publishing the local data.
/// * Keep Both stale-remote rejection — if the remote backup's ID or version
///   changes while the conflict is open, nothing is copied or uploaded.
/// * Drive metadata validation at discovery — a backup whose Drive metadata
///   names a different Google account or workspace, or whose payload uses an
///   unsupported database schema, is rejected before any local change.
/// * Backup Now verified read-back — a successful backup reads the uploaded
///   bytes back before the workspace may be marked clean, and a corrupted
///   read-back is reported as a failure with local data untouched.
///
/// The Drive side is a stateful fake at the HTTP layer (uploads are captured
/// from the real multipart request), so discovery, upload, and read-back all
/// run through the real Drive store, sync engine, and backup service.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';
  const localRecordId = 'google-account-A_fajr_2026-10-01';
  const remoteRecordId = 'google-account-A_zuhr_2026-09-15';

  late AppDatabase database;
  late SharedPreferencesCloudSyncStateStore state;
  late _FakeDriveServer drive;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());
    final store = AccountLocalStore(database: database);
    await store.ensureInitialized();
    await store.ensureAccountActive(workspaceId);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: localRecordId,
        userId: workspaceId,
        prayerType: 'fajr',
        originalDate: DateTime(2026, 10, 1),
        status: 'pending',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    state = SharedPreferencesCloudSyncStateStore(preferences: preferences);
    await state.setActiveAccountId(accountId);
    await state.setCloudSyncEnabled(true);
    drive = _FakeDriveServer();
  });

  tearDown(() async {
    await database.close();
  });

  GoogleCloudSyncProvider buildProvider() {
    return GoogleCloudSyncProvider(
      database: database,
      gateway: _FakeGateway(accountId: accountId, handler: drive.handle),
      state: state,
      scheduler: _FakeScheduler(state: state),
    );
  }

  /// A Phase 1 export of the same Google workspace taken from a separate
  /// database whose only record differs from the local one, so a conflict
  /// between "local" and "remote" data is meaningful.
  Future<String> remotePhase1Json() async {
    final remoteDatabase = AppDatabase(NativeDatabase.memory());
    try {
      final remoteStore = AccountLocalStore(database: remoteDatabase);
      await remoteStore.ensureInitialized();
      await remoteStore.ensureAccountActive(workspaceId);
      await remoteDatabase.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: remoteRecordId,
          userId: workspaceId,
          prayerType: 'zuhr',
          originalDate: DateTime(2026, 9, 15),
          status: 'pending',
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 9, 15),
        ),
      );
      // Awaited (not returned directly) so the finally block closes the
      // throwaway database only after the export has completed.
      final phase1Json = await LocalBackupService(
        remoteDatabase,
      ).exportJson(localAccountId: workspaceId);
      return phase1Json;
    } finally {
      await remoteDatabase.close();
    }
  }

  /// Seeds the fake Drive with a well-formed remote backup wrapping
  /// [phase1Json], optionally overriding its Drive appProperties.
  void seedRemote({
    required String phase1Json,
    required String backupId,
    String version = '7',
    Map<String, String> propertyOverrides = const <String, String>{},
  }) {
    final metadata =
        (jsonDecode(phase1Json) as Map<String, dynamic>)['metadata']
            as Map<String, dynamic>;
    final backup = CloudBackup(
      lineage: CloudLineage(
        deviceId: 'device-remote',
        backupId: backupId,
        baseBackupId: null,
        dbRevision: metadata['db_revision'] as int,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      phase1BackupJson: phase1Json,
    );
    final body = backup.toJsonString();
    final bytes = utf8.encode(body);
    drive.seed(
      file: <String, Object?>{
        'id': 'file-$backupId',
        'name': '$cloudBackupFilePrefix$backupId.json',
        'modifiedTime': '2026-10-01T00:00:00.000Z',
        'version': version,
        'size': '${bytes.length}',
        'md5Checksum': md5.convert(bytes).toString(),
        'appProperties': <String, String>{
          'backup_id': backupId,
          'device_id': 'device-remote',
          'base_backup_id': '',
          'db_revision': '${metadata['db_revision']}',
          'google_account_id': accountId,
          'workspace_id': workspaceId,
          'content_sha256': sha256.convert(bytes).toString(),
          'database_schema_version': '${metadata['database_schema_version']}',
          ...propertyOverrides,
        },
      },
      body: body,
    );
  }

  Future<List<String>> recordIdsFor(String userId) async {
    final rows = await database
        .customSelect(
          'SELECT id FROM qaza_records WHERE user_id = ? ORDER BY id',
          variables: [Variable(userId)],
        )
        .get();
    return rows.map((row) => row.read<String>('id')).toList();
  }

  Future<List<String>> recoveryCopyIds() async {
    final rows = await database
        .customSelect(
          'SELECT local_account_id FROM local_accounts '
          "WHERE lifecycle_state = 'recovery_copy'",
        )
        .get();
    return rows.map((row) => row.read<String>('local_account_id')).toList();
  }

  Future<String?> conflictMarker() async {
    final rows = await database
        .customSelect(
          'SELECT conflict_marker FROM workspace_sync_metadata '
          'WHERE local_account_id = ?',
          variables: [Variable(workspaceId)],
        )
        .get();
    return rows.single.read<String?>('conflict_marker');
  }

  group('Keep Both conflict resolution', () {
    test('Keep Both preserves local data, saves the remote as a recovery copy, '
        'and clears the conflict', () async {
      seedRemote(
        phase1Json: await remotePhase1Json(),
        backupId: 'backup-remote-1',
      );
      final provider = buildProvider();

      final discovery = await provider.discoverBackup();
      expect(discovery.status, CloudBackupDiscoveryStatus.backupFound);
      expect(discovery.conflict?.remoteBackupId, 'backup-remote-1');
      expect(await database.readWorkspaceSyncState(workspaceId), 'conflict');

      final result = await provider.resolveConflict(
        conflict: discovery.conflict!,
        choice: CloudConflictChoice.keepBoth,
        confirmed: true,
      );

      expect(result.status, CloudSyncStatus.synced);
      // (a) The local workspace still holds exactly its own record; the
      // remote record was not merged into it.
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
      // (b) A recovery copy workspace now holds the remote backup's
      // record (its ID is namespaced with the copy workspace's prefix by
      // the import, so match on the remote record's suffix and type).
      final copies = await recoveryCopyIds();
      expect(copies, hasLength(1));
      expect(copies.single, startsWith('recovery_copy_'));
      final copyRecordIds = await recordIdsFor(copies.single);
      expect(copyRecordIds, hasLength(1));
      expect(copyRecordIds.single, endsWith(remoteRecordId));
      final copyRows = await database
          .customSelect(
            'SELECT prayer_type FROM qaza_records WHERE user_id = ?',
            variables: [Variable(copies.single)],
          )
          .get();
      expect(copyRows.map((row) => row.read<String>('prayer_type')), <String>[
        'zuhr',
      ]);
      // (c) The conflict is cleared and the local data was published as
      // the new cloud backup after the copy was preserved.
      expect(await database.readWorkspaceSyncState(workspaceId), 'clean');
      expect(await conflictMarker(), isNull);
      expect(drive.createCount, 1);
      final uploadedEnvelope =
          jsonDecode(drive.uploadedBody!) as Map<String, dynamic>;
      final uploadedRecords =
          ((uploadedEnvelope['phase1_backup'] as Map<String, dynamic>)['data']
                  as Map<String, dynamic>)['qaza_records']
              as List<dynamic>;
      expect(
        uploadedRecords.map((row) => (row as Map)['id']),
        contains(localRecordId),
      );
    });

    test('Keep Both refuses when the remote backup ID changes while the '
        'conflict is open', () async {
      final phase1Json = await remotePhase1Json();
      seedRemote(phase1Json: phase1Json, backupId: 'backup-remote-1');
      final provider = buildProvider();
      final discovery = await provider.discoverBackup();
      expect(discovery.status, CloudBackupDiscoveryStatus.backupFound);

      // Another device replaces the cloud backup before the user confirms.
      seedRemote(phase1Json: phase1Json, backupId: 'backup-remote-2');

      final result = await provider.resolveConflict(
        conflict: discovery.conflict!,
        choice: CloudConflictChoice.keepBoth,
        confirmed: true,
      );

      expect(result.status, CloudSyncStatus.failed);
      expect(result.message, contains('changed while the conflict was open'));
      // Nothing was copied, nothing was uploaded, local data is untouched,
      // and the original conflict is still recorded.
      expect(await recoveryCopyIds(), isEmpty);
      expect(drive.createCount, 0);
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
      expect(await database.readWorkspaceSyncState(workspaceId), 'conflict');
      expect(await conflictMarker(), 'backup-remote-1');
    });

    test('Keep Both refuses when only the remote version changes while the '
        'conflict is open', () async {
      final phase1Json = await remotePhase1Json();
      seedRemote(phase1Json: phase1Json, backupId: 'backup-remote-1');
      final provider = buildProvider();
      final discovery = await provider.discoverBackup();
      expect(discovery.status, CloudBackupDiscoveryStatus.backupFound);
      expect(discovery.conflict?.remoteVersion, '7');

      // Same backup file, but Drive reports a newer version of it.
      seedRemote(
        phase1Json: phase1Json,
        backupId: 'backup-remote-1',
        version: '8',
      );

      final result = await provider.resolveConflict(
        conflict: discovery.conflict!,
        choice: CloudConflictChoice.keepBoth,
        confirmed: true,
      );

      expect(result.status, CloudSyncStatus.failed);
      expect(result.message, contains('changed while the conflict was open'));
      expect(await recoveryCopyIds(), isEmpty);
      expect(drive.createCount, 0);
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
      expect(await database.readWorkspaceSyncState(workspaceId), 'conflict');
      expect(await conflictMarker(), 'backup-remote-1');
    });
  });

  group('Drive metadata validation at discovery', () {
    test('a backup whose Drive metadata names a different Google account is '
        'rejected', () async {
      seedRemote(
        phase1Json: await LocalBackupService(
          database,
        ).exportJson(localAccountId: workspaceId),
        backupId: 'backup-foreign-account',
        propertyOverrides: const <String, String>{
          'google_account_id': 'google-account-OTHER',
          'workspace_id': 'google_google-account-OTHER',
        },
      );
      final provider = buildProvider();

      final snapshot = await provider.discoverBackup();

      expect(snapshot.status, CloudBackupDiscoveryStatus.failed);
      expect(
        await database.readWorkspaceSyncState(workspaceId),
        'cloud_unverified',
      );
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
      expect(drive.createCount, 0);
    });

    test(
      'a backup whose Drive metadata names the wrong workspace is rejected',
      () async {
        seedRemote(
          phase1Json: await LocalBackupService(
            database,
          ).exportJson(localAccountId: workspaceId),
          backupId: 'backup-wrong-workspace',
          propertyOverrides: const <String, String>{
            'workspace_id': 'google_someone-else',
          },
        );
        final provider = buildProvider();

        final snapshot = await provider.discoverBackup();

        expect(snapshot.status, CloudBackupDiscoveryStatus.failed);
        expect(
          await database.readWorkspaceSyncState(workspaceId),
          'cloud_unverified',
        );
        expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
        expect(drive.createCount, 0);
      },
    );

    test(
      'a backup with an unsupported database schema version is rejected',
      () async {
        final phase1 =
            jsonDecode(
                  await LocalBackupService(
                    database,
                  ).exportJson(localAccountId: workspaceId),
                )
                as Map<String, dynamic>;
        (phase1['metadata']
                as Map<String, dynamic>)['database_schema_version'] =
            999;
        seedRemote(
          phase1Json: jsonEncode(phase1),
          backupId: 'backup-future-schema',
        );
        final provider = buildProvider();

        final snapshot = await provider.discoverBackup();

        expect(snapshot.status, CloudBackupDiscoveryStatus.invalidBackup);
        expect(
          await database.readWorkspaceSyncState(workspaceId),
          'legacy_unverified',
        );
        expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
        expect(drive.createCount, 0);
      },
    );
  });

  group('Backup Now verified read-back', () {
    test('a successful Backup Now uploads, reads the backup back, and only '
        'then marks the workspace clean', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'pending');
      final provider = buildProvider();

      final snapshot = await provider.backupNow();

      expect(snapshot.status, CloudSyncStatus.synced);
      expect(drive.createCount, 1);
      // The Drive store reads the created file back before reporting
      // success; the captured upload is byte-identical to the content
      // hash Drive confirmed in its create response.
      expect(drive.downloadCount, greaterThanOrEqualTo(1));
      expect(
        sha256.convert(utf8.encode(drive.uploadedBody!)).toString(),
        drive.uploadedProperties!['content_sha256'],
      );
      expect(await database.readWorkspaceSyncState(workspaceId), 'clean');
      final cursor = await state.scopedToAccount(accountId).readCursor();
      expect(cursor.lastSyncedBackupId, drive.uploadedProperties!['backup_id']);
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
    });

    test('Backup Now fails and keeps local data when the read-back bytes do '
        'not match the uploaded content hash', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'pending');
      drive.tamperReadBack = true;
      final provider = buildProvider();

      final snapshot = await provider.backupNow();

      expect(snapshot.status, CloudSyncStatus.failed);
      expect(snapshot.message, contains('SHA-256'));
      expect(drive.createCount, 1);
      // The failed verification must not advance the sync state or cursor,
      // and local records are untouched.
      expect(await database.readWorkspaceSyncState(workspaceId), 'pending');
      final cursor = await state.scopedToAccount(accountId).readCursor();
      expect(cursor.lastSyncedBackupId, isNull);
      expect(await recordIdsFor(workspaceId), <String>[localRecordId]);
    });
  });
}

/// A stateful fake of the Drive files API at the HTTP layer. It serves the
/// seeded latest backup, captures uploads from the real multipart create
/// request (echoing the client-supplied appProperties exactly as Drive
/// would), and serves downloads from whatever was seeded or uploaded.
class _FakeDriveServer {
  Map<String, Object?>? _latestFile;
  final Map<String, String> _bodiesByFileId = <String, String>{};

  int createCount = 0;
  int downloadCount = 0;
  String? uploadedFileId;
  String? uploadedBody;
  Map<String, String>? uploadedProperties;

  /// When true, downloads of the uploaded file return corrupted bytes, as
  /// if Drive stored or returned something other than what was uploaded.
  bool tamperReadBack = false;

  void seed({required Map<String, Object?> file, required String body}) {
    _latestFile = file;
    _bodiesByFileId[file['id']! as String] = body;
  }

  Future<http.Response> handle(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/files')) {
      return _create(request as http.Request);
    }
    if (request.method == 'GET' && path.endsWith('/files')) {
      return http.Response(
        jsonEncode(<String, Object?>{
          'files': _latestFile == null ? <Object?>[] : <Object?>[_latestFile],
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }
    if (request.method == 'GET' && path.contains('/files/')) {
      downloadCount++;
      final fileId = path.split('/').last;
      if (tamperReadBack && fileId == uploadedFileId) {
        return http.Response(
          '{"tampered":true}',
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      final body = _bodiesByFileId[fileId];
      if (body == null) {
        return http.Response('Unknown file: $fileId', 404);
      }
      return http.Response(
        body,
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response('Unexpected request: ${request.method} $path', 500);
  }

  http.Response _create(http.Request request) {
    createCount++;
    final contentType = request.headers['content-type'] ?? '';
    final boundary = RegExp(
      'boundary="?([^";]+)"?',
    ).firstMatch(contentType)!.group(1)!;
    String? metadataJson;
    String? mediaBody;
    for (final part in request.body.split('--$boundary')) {
      final headerEnd = part.indexOf('\r\n\r\n');
      if (headerEnd < 0) continue;
      final headers = part.substring(0, headerEnd);
      var content = part.substring(headerEnd + 4);
      if (content.endsWith('\r\n')) {
        content = content.substring(0, content.length - 2);
      }
      if (content.contains('"appProperties"')) {
        metadataJson = content;
      } else if (headers.contains('Content-Transfer-Encoding: base64')) {
        // The googleapis client sends the media part base64-encoded.
        mediaBody = utf8.decode(
          base64.decode(content.replaceAll(RegExp(r'\s'), '')),
        );
      } else if (content.contains('"phase1_backup"')) {
        mediaBody = content;
      }
    }
    final metadata = jsonDecode(metadataJson!) as Map<String, dynamic>;
    final properties = (metadata['appProperties'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    uploadedFileId = 'file-upload-$createCount';
    uploadedBody = mediaBody;
    uploadedProperties = properties;
    final created = <String, Object?>{
      'id': uploadedFileId,
      'name': metadata['name'],
      'modifiedTime': '2026-10-02T00:00:00.000Z',
      'version': '1',
      'md5Checksum': md5.convert(utf8.encode(mediaBody!)).toString(),
      'appProperties': properties,
    };
    seed(file: created, body: mediaBody);
    return http.Response(
      jsonEncode(created),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

/// Hands the real Drive store a fresh [MockClient] per authorization, so a
/// client closed after one Drive call never poisons the next one.
class _FakeGateway extends GoogleSignInGateway {
  _FakeGateway({required this.accountId, required this.handler});

  final String accountId;
  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<String?> accountIdForAuthorization() async => accountId;

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async {
    return MockClient(handler);
  }
}

class _FakeScheduler extends CloudSyncScheduler {
  _FakeScheduler({required CloudSyncStateStore state}) : super(state: state);

  @override
  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {}

  @override
  Future<void> disconnect() async {}
}
