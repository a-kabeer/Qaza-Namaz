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

/// Direct tests for [GoogleCloudSyncProvider], the provider layer that maps
/// Drive discovery results onto the persisted per-workspace sync state,
/// enforces the Backup Now upload block for unverified workspaces, and drops
/// results that arrive after the session generation has moved on.
///
/// The Drive side is faked at the HTTP layer: the fake gateway hands the real
/// [GoogleDriveAppDataStore] a [MockClient], so discovery still runs through
/// the real sync engine, metadata checks, and download verification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';

  late AppDatabase database;
  late SharedPreferencesCloudSyncStateStore state;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());
    final store = AccountLocalStore(database: database);
    await store.ensureInitialized();
    await store.ensureAccountActive(workspaceId);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'google-account-A_fajr_2026-10-01',
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
  });

  tearDown(() async {
    await database.close();
  });

  GoogleCloudSyncProvider buildProvider(
    Future<http.Response> Function(http.BaseRequest request) handler,
  ) {
    return GoogleCloudSyncProvider(
      database: database,
      gateway: _FakeGateway(accountId: accountId, handler: handler),
      state: state,
      scheduler: _FakeScheduler(state: state),
    );
  }

  /// Builds a Drive file-list response whose single file downloads to a
  /// well-formed cloud backup envelope wrapping [phase1Json].
  ({String body, Map<String, Object?> file}) remoteBackupFile({
    required String phase1Json,
    required String backupId,
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
    return (
      body: body,
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
    );
  }

  Future<http.Response> Function(http.BaseRequest) driveHandler({
    required Map<String, Object?>? latestFile,
    String? downloadBody,
    Future<void> Function()? onListRequest,
  }) {
    return (http.BaseRequest request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/files')) {
        await onListRequest?.call();
        return http.Response(
          jsonEncode(<String, Object?>{
            'files': latestFile == null ? <Object?>[] : <Object?>[latestFile],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' &&
          path.contains('/files/') &&
          downloadBody != null) {
        return http.Response(
          downloadBody,
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('Unexpected request: ${request.method} $path', 500);
    };
  }

  group('discovery result to workspace sync-state mapping', () {
    test('no remote backup persists the pending state', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'cloud_unverified');
      final provider = buildProvider(
        driveHandler(latestFile: null, downloadBody: null),
      );

      final snapshot = await provider.discoverBackup();

      expect(snapshot.status, CloudBackupDiscoveryStatus.noBackup);
      expect(await database.readWorkspaceSyncState(workspaceId), 'pending');
    });

    test('a valid remote backup persists the conflict state', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'pending');
      final phase1Json = await LocalBackupService(
        database,
      ).exportJson(localAccountId: workspaceId);
      final remote = remoteBackupFile(
        phase1Json: phase1Json,
        backupId: 'backup-remote-1',
      );
      final provider = buildProvider(
        driveHandler(latestFile: remote.file, downloadBody: remote.body),
      );

      final snapshot = await provider.discoverBackup();

      expect(snapshot.status, CloudBackupDiscoveryStatus.backupFound);
      expect(snapshot.conflict?.remoteBackupId, 'backup-remote-1');
      expect(await database.readWorkspaceSyncState(workspaceId), 'conflict');
      final rows = await database
          .customSelect(
            'SELECT conflict_marker FROM workspace_sync_metadata '
            'WHERE local_account_id = ?',
            variables: [Variable(workspaceId)],
          )
          .get();
      expect(rows.single.read<String?>('conflict_marker'), 'backup-remote-1');
    });

    test(
      'a backup that fails workspace validation persists legacy_unverified',
      () async {
        await database.writeWorkspaceSyncState(workspaceId, 'pending');
        // A well-formed backup of a different (Guest) workspace: the cloud
        // envelope parses, but the payload can never be adopted for this
        // Google workspace, which is the legacy/unverifiable Drive state.
        final store = AccountLocalStore(database: database);
        final guestId = await store.createGuestWorkspace(displayName: 'Guest');
        await database.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: 'guest_fajr_2026-09-01',
            userId: guestId,
            prayerType: 'fajr',
            originalDate: DateTime(2026, 9, 1),
            status: 'pending',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
        await store.activate(workspaceId);
        final guestPhase1Json = await LocalBackupService(
          database,
        ).exportJson(localAccountId: guestId);
        final remote = remoteBackupFile(
          phase1Json: guestPhase1Json,
          backupId: 'backup-legacy-guest',
        );
        final provider = buildProvider(
          driveHandler(latestFile: remote.file, downloadBody: remote.body),
        );

        final snapshot = await provider.discoverBackup();

        expect(snapshot.status, CloudBackupDiscoveryStatus.invalidBackup);
        expect(
          await database.readWorkspaceSyncState(workspaceId),
          'legacy_unverified',
        );
      },
    );

    test('a failed discovery persists cloud_unverified', () async {
      await database.writeWorkspaceSyncState(workspaceId, 'pending');
      final provider = buildProvider((http.BaseRequest request) async {
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
      });

      final snapshot = await provider.discoverBackup();

      expect(snapshot.status, CloudBackupDiscoveryStatus.failed);
      expect(
        await database.readWorkspaceSyncState(workspaceId),
        'cloud_unverified',
      );
    });
  });

  group('Backup Now upload block', () {
    for (final blockedState in <String>[
      'cloud_unverified',
      'legacy_unverified',
    ]) {
      test(
        'backupNow refuses while $blockedState and never reaches Drive',
        () async {
          await database.writeWorkspaceSyncState(workspaceId, blockedState);
          var driveRequests = 0;
          final provider = buildProvider((http.BaseRequest request) async {
            driveRequests++;
            return http.Response('Drive must not be contacted', 500);
          });

          final snapshot = await provider.backupNow();

          expect(snapshot.status, CloudSyncStatus.failed);
          expect(snapshot.message, contains('not verified'));
          // The sync engine talks to Drive over HTTP; zero requests prove
          // the blocked backup never invoked it.
          expect(driveRequests, 0);
          expect(
            await database.readWorkspaceSyncState(workspaceId),
            blockedState,
          );
        },
      );
    }
  });

  group('session generation guard', () {
    test(
      'backupNow drops its result when the session generation moves on',
      () async {
        await database.writeWorkspaceSyncState(workspaceId, 'clean');
        final phase1Json = await LocalBackupService(
          database,
        ).exportJson(localAccountId: workspaceId);
        final remote = remoteBackupFile(
          phase1Json: phase1Json,
          backupId: 'backup-remote-stale',
        );
        var generationBumped = false;
        final provider = buildProvider(
          driveHandler(
            latestFile: remote.file,
            downloadBody: remote.body,
            onListRequest: () async {
              if (generationBumped) return;
              generationBumped = true;
              // Simulate an account/session change landing while the sync
              // engine is talking to Drive: the generation this backup
              // started with is no longer current when its result returns.
              await database.customStatement(
                'UPDATE app_session_state SET generation = generation + 1 '
                'WHERE id = 1',
              );
            },
          ),
        );

        final snapshot = await provider.backupNow();

        expect(generationBumped, isTrue);
        expect(snapshot.status, CloudSyncStatus.failed);
        expect(snapshot.message, contains('changed during backup'));
        // The engine produced a conflict result, but it must not be applied:
        // the workspace is left pending reconciliation instead of conflict.
        expect(await database.readWorkspaceSyncState(workspaceId), 'pending');
      },
    );
  });
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
