import 'dart:convert';
import 'dart:io';

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

/// Reconcile-chain tests for [GoogleCloudSyncProvider] (final coverage
/// sweep):
///
/// * Scenario 19 — a failed discovery persists `cloud_unverified` across a
///   real database reopen (file-backed, not just in-memory), Backup Now is
///   refused while unverified, and a later successful discovery reconciles
///   the workspace all the way to `clean`.
/// * Scenario 22 — a `legacy_unverified` workspace never gets a silent
///   baseline at discovery time: a found remote backup (even one whose
///   content is provably equal to the local data) produces an explicit
///   conflict decision, and the workspace reconciles to `clean` only
///   through the foreground discovery + Backup Now path.
/// * Scenario 20 — a discovery whose session generation moves on while
///   Drive is being read has its result dropped; no workspace sync state
///   is written.
///
/// The Drive side is a stateful fake at the HTTP layer, mirroring
/// `google_cloud_providers_phase4_test.dart`, with an added total-failure
/// mode and a list-request hook.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';
  const localRecordId = 'google-account-A_fajr_2026-10-01';

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

  GoogleCloudSyncProvider buildProvider({AppDatabase? db}) {
    return GoogleCloudSyncProvider(
      database: db ?? database,
      gateway: _FakeGateway(accountId: accountId, handler: drive.handle),
      state: state,
      scheduler: _FakeScheduler(state: state),
    );
  }

  /// Seeds the fake Drive with a well-formed backup whose payload is the
  /// local workspace's own export, so the remote content is provably equal
  /// to the local data.
  Future<void> seedRemoteFromLocalExport({required String backupId}) async {
    final phase1Json = await LocalBackupService(
      database,
    ).exportJson(localAccountId: workspaceId);
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
        'version': '7',
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
        },
      },
      body: body,
    );
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

  group('Scenario 19 — discovery failure durability and reconcile', () {
    test('cloud_unverified survives a database reopen and still blocks '
        'uploads', () async {
      final directory = await Directory.systemTemp.createTemp(
        'qaza_scenario19_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/qaza.db');

      final firstOpen = AppDatabase(NativeDatabase(file));
      try {
        final store = AccountLocalStore(database: firstOpen);
        await store.ensureInitialized();
        await store.ensureAccountActive(workspaceId);
        drive.failAll = true;
        final provider = buildProvider(db: firstOpen);

        final snapshot = await provider.discoverBackup();

        expect(snapshot.status, CloudBackupDiscoveryStatus.failed);
        expect(
          await firstOpen.readWorkspaceSyncState(workspaceId),
          'cloud_unverified',
        );
      } finally {
        await firstOpen.close();
      }

      // A cold start on the same database file must find the unverified
      // state intact — the upload block is a persisted property of the
      // workspace, not an in-memory one.
      final secondOpen = AppDatabase(NativeDatabase(file));
      try {
        expect(
          await secondOpen.readWorkspaceSyncState(workspaceId),
          'cloud_unverified',
        );
        expect(
          await secondOpen.isWorkspaceCloudUploadBlocked(workspaceId),
          isTrue,
        );
      } finally {
        await secondOpen.close();
      }
    });

    test('a failed discovery blocks Backup Now, then a successful '
        'discovery reconciles the workspace to clean', () async {
      final provider = buildProvider();
      drive.failAll = true;

      final failed = await provider.discoverBackup();
      expect(failed.status, CloudBackupDiscoveryStatus.failed);
      expect(
        await database.readWorkspaceSyncState(workspaceId),
        'cloud_unverified',
      );

      // While unverified, Backup Now is refused before any Drive traffic.
      drive.requestCount = 0;
      final blocked = await provider.backupNow();
      expect(blocked.status, CloudSyncStatus.failed);
      expect(blocked.message, contains('not verified'));
      expect(drive.requestCount, 0);
      expect(
        await database.readWorkspaceSyncState(workspaceId),
        'cloud_unverified',
      );

      // Drive recovers and reports no backup: the state clears to
      // pending, and Backup Now can finally upload and mark it clean.
      drive.failAll = false;
      final rediscovered = await provider.discoverBackup();
      expect(rediscovered.status, CloudBackupDiscoveryStatus.noBackup);
      expect(await database.readWorkspaceSyncState(workspaceId), 'pending');

      final backedUp = await provider.backupNow();
      expect(backedUp.status, CloudSyncStatus.synced);
      expect(drive.createCount, 1);
      expect(await database.readWorkspaceSyncState(workspaceId), 'clean');
    });
  });

  group('Scenario 22 — legacy baseline at the workspace level', () {
    test('a legacy_unverified workspace that finds a remote backup '
        'reaches a conflict decision, not a silent baseline', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'legacy_unverified');
      // The remote content is the local workspace's own export: provably
      // equal. Discovery still surfaces an explicit decision — the silent
      // equal-hash baseline exists only inside the sync engine for
      // workspaces that already hold a verified cursor.
      await seedRemoteFromLocalExport(backupId: 'backup-legacy-equal');
      final provider = buildProvider();

      final snapshot = await provider.discoverBackup();

      expect(snapshot.status, CloudBackupDiscoveryStatus.backupFound);
      expect(await database.readWorkspaceSyncState(workspaceId), 'conflict');
      expect(await conflictMarker(), 'backup-legacy-equal');
    });

    test('a legacy_unverified workspace reconciles to clean when Drive '
        'has no backup and Backup Now uploads', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'legacy_unverified');
      final provider = buildProvider();

      // The legacy state blocks the upload until a foreground discovery
      // has reconciled it.
      drive.requestCount = 0;
      final blocked = await provider.backupNow();
      expect(blocked.status, CloudSyncStatus.failed);
      expect(drive.requestCount, 0);
      expect(
        await database.readWorkspaceSyncState(workspaceId),
        'legacy_unverified',
      );

      final discovered = await provider.discoverBackup();
      expect(discovered.status, CloudBackupDiscoveryStatus.noBackup);
      expect(await database.readWorkspaceSyncState(workspaceId), 'pending');

      final backedUp = await provider.backupNow();
      expect(backedUp.status, CloudSyncStatus.synced);
      expect(drive.createCount, 1);
      expect(await database.readWorkspaceSyncState(workspaceId), 'clean');
    });
  });

  group('Scenario 20 — generation guard on discovery', () {
    test('a discovery result is dropped when the session generation '
        'moves on mid-discovery', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'clean');
      await seedRemoteFromLocalExport(backupId: 'backup-stale-discovery');
      var generationBumped = false;
      drive.onListRequest = () async {
        if (generationBumped) return;
        generationBumped = true;
        // Simulate an account switch landing while discovery is reading
        // Drive: the generation this discovery started with is stale by
        // the time its result returns.
        await database.customStatement(
          'UPDATE app_session_state SET generation = generation + 1 '
          'WHERE id = 1',
        );
      };
      final provider = buildProvider();

      final snapshot = await provider.discoverBackup();

      expect(generationBumped, isTrue);
      expect(snapshot.status, CloudBackupDiscoveryStatus.failed);
      expect(snapshot.message, contains('changed during Drive discovery'));
      // The found result was discarded: the seeded state is untouched and
      // no conflict was recorded for either workspace.
      expect(await database.readWorkspaceSyncState(workspaceId), 'clean');
      expect(await conflictMarker(), isNull);
    });
  });
}

/// A stateful fake of the Drive files API at the HTTP layer, mirroring
/// `google_cloud_providers_phase4_test.dart`: uploads are captured from
/// the real multipart create request and then served back as the latest
/// backup. Adds a [failAll] mode (every request is answered with a
/// permanent 403, as in a discovery outage) and an [onListRequest] hook.
class _FakeDriveServer {
  Map<String, Object?>? _latestFile;
  final Map<String, String> _bodiesByFileId = <String, String>{};

  int requestCount = 0;
  int createCount = 0;
  int downloadCount = 0;
  String? uploadedFileId;
  String? uploadedBody;
  Map<String, String>? uploadedProperties;

  bool failAll = false;
  Future<void> Function()? onListRequest;

  void seed({required Map<String, Object?> file, required String body}) {
    _latestFile = file;
    _bodiesByFileId[file['id']! as String] = body;
  }

  static http.Response _failure() {
    return http.Response(
      jsonEncode(<String, Object?>{
        'error': <String, Object?>{
          'code': 403,
          'message': 'permission denied',
          'errors': <Object?>[
            <String, Object?>{
              'domain': 'global',
              'reason': 'insufficientPermissions',
              'message': 'permission denied',
            },
          ],
        },
      }),
      403,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  Future<http.Response> handle(http.BaseRequest request) async {
    requestCount++;
    if (failAll) return _failure();
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/files')) {
      return _create(request as http.Request);
    }
    if (request.method == 'GET' && path.endsWith('/files')) {
      await onListRequest?.call();
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
