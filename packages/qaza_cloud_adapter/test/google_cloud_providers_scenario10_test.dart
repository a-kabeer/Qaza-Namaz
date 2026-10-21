import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scenario 10 (TP-GEN v4.1 plan, Section 11), chained end to end at the
/// provider level: Google A backs up with Backup Now, signs out, and signs
/// back in — the local dataset and the persisted sync state (the
/// `workspace_sync_metadata` row and the account-scoped sync cursor) must
/// be exactly what the successful backup left behind.
///
/// Sign-out runs through the real [GoogleCloudAccountProvider.disconnect]
/// (scheduler stopped, gateway signed out, cloud sync disabled, account
/// unbound). Re-login restores the binding a verified sign-in writes —
/// active account id plus cloud sync enabled — in front of a fresh
/// [GoogleCloudSyncProvider], modelling a process restart. The native
/// Google account picker itself cannot run in a unit test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';

  late AppDatabase database;
  late SharedPreferencesCloudSyncStateStore state;
  late _FakeDriveServer drive;
  late _FakeGateway gateway;
  late _FakeScheduler scheduler;

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
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'google-account-A_zuhr_2026-10-01',
        userId: workspaceId,
        prayerType: 'zuhr',
        originalDate: DateTime(2026, 10, 1),
        status: 'completed',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    state = SharedPreferencesCloudSyncStateStore(preferences: preferences);
    await state.setActiveAccountId(accountId);
    await state.setCloudSyncEnabled(true);
    drive = _FakeDriveServer();
    gateway = _FakeGateway(accountId: accountId, handler: drive.handle);
    scheduler = _FakeScheduler(state: state);
  });

  tearDown(() async {
    await database.close();
  });

  GoogleCloudSyncProvider buildProvider() {
    return GoogleCloudSyncProvider(
      database: database,
      gateway: gateway,
      state: state,
      scheduler: scheduler,
    );
  }

  /// The workspace dataset as one comparable value: every record with its
  /// type, status, and date, ordered by id.
  Future<List<String>> datasetSnapshot() async {
    final records = await database.qazaRecordsDao.getAll(userId: workspaceId);
    return records
        .map(
          (record) =>
              '${record.id}|${record.prayerType.name}|${record.status.name}|'
              '${record.originalDate.toIso8601String()}',
        )
        .toList();
  }

  /// The persisted per-workspace sync position. `last_checked_at` is
  /// deliberately excluded: a read-only check may refresh it, but it is
  /// not part of the sync position this scenario pins down.
  Future<Map<String, Object?>> metadataSnapshot() async {
    final rows = await database
        .customSelect(
          'SELECT sync_state, local_revision, last_synced_revision, '
          'last_synced_local_hash, last_synced_remote_version, '
          'last_synced_remote_hash, conflict_marker, remote_account_id '
          'FROM workspace_sync_metadata WHERE local_account_id = ?',
          variables: [Variable(workspaceId)],
        )
        .get();
    final row = rows.single;
    return <String, Object?>{
      'sync_state': row.read<String>('sync_state'),
      'local_revision': row.read<int>('local_revision'),
      'last_synced_revision': row.read<int?>('last_synced_revision'),
      'last_synced_local_hash': row.read<String?>('last_synced_local_hash'),
      'last_synced_remote_version': row.read<String?>(
        'last_synced_remote_version',
      ),
      'last_synced_remote_hash': row.read<String?>('last_synced_remote_hash'),
      'conflict_marker': row.read<String?>('conflict_marker'),
      'remote_account_id': row.read<String?>('remote_account_id'),
    };
  }

  test('scenario 10: Backup Now, sign-out, and re-login preserve the dataset '
      'and the persisted sync state', () async {
    await database.writeWorkspaceSyncState(workspaceId, 'pending');
    final provider = buildProvider();

    // Backup Now succeeds against an empty Drive.
    final backup = await provider.backupNow();
    expect(backup.status, CloudSyncStatus.synced);
    expect(drive.createCount, 1);

    final datasetAfterBackup = await datasetSnapshot();
    final metadataAfterBackup = await metadataSnapshot();
    final cursorAfterBackup = await state
        .scopedToAccount(accountId)
        .readCursor();
    expect(metadataAfterBackup['sync_state'], 'clean');
    expect(
      cursorAfterBackup.lastSyncedBackupId,
      drive.uploadedProperties!['backup_id'],
    );

    // Sign out through the real account provider.
    final accountProvider = GoogleCloudAccountProvider(
      gateway: gateway,
      state: state,
      scheduler: scheduler,
    );
    await accountProvider.disconnect();
    expect(gateway.signOutCalls, 1);
    expect(await state.isCloudSyncEnabled(), isFalse);
    expect((await provider.status()).status, CloudSyncStatus.disconnected);

    // Re-login with the same verified Google account.
    await state.setActiveAccountId(accountId);
    await state.setCloudSyncEnabled(true);
    final reloggedProvider = buildProvider();

    // The dataset and the persisted sync state are exactly what the
    // successful backup left behind — sign-out and re-login moved
    // nothing.
    expect(await datasetSnapshot(), datasetAfterBackup);
    expect(await metadataSnapshot(), metadataAfterBackup);
    expect(
      await state.scopedToAccount(accountId).readCursor(),
      cursorAfterBackup,
    );
    // Regression guard for the cross-domain revision comparison: by now
    // the global db_revision and this workspace's revision have diverged
    // (the global counter counts revision transactions, the workspace
    // counter counts this workspace's row writes), yet the account is
    // fully synced, so status() must report no pending changes. The
    // engine-side proof below (a no-op Backup Now) corroborates this.
    expect(
      await database.readDbRevision(),
      isNot(await database.readWorkspaceRevision(workspaceId)),
      reason: 'the regression needs the two revision counters diverged',
    );
    expect((await reloggedProvider.status()).hasPendingChanges, isFalse);

    // The restored session agrees it is in sync: another Backup Now
    // finds the uploaded backup already matches and uploads nothing new.
    final second = await reloggedProvider.backupNow();
    expect(second.status, CloudSyncStatus.synced);
    expect(second.backupAlreadyUpToDate, isTrue);
    expect(drive.createCount, 1);
    expect(await datasetSnapshot(), datasetAfterBackup);
    expect(await metadataSnapshot(), metadataAfterBackup);
    expect(
      await state.scopedToAccount(accountId).readCursor(),
      cursorAfterBackup,
    );
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
/// client closed after one Drive call never poisons the next one. Sign-out
/// is counted instead of hitting the real Google Sign-In plugin.
class _FakeGateway extends GoogleSignInGateway {
  _FakeGateway({required this.accountId, required this.handler});

  final String accountId;
  final Future<http.Response> Function(http.BaseRequest request) handler;
  int signOutCalls = 0;

  @override
  Future<String?> accountIdForAuthorization() async => accountId;

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async {
    return MockClient(handler);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
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
