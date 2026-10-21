import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

/// First direct tests for the scheduled cloud backup worker
/// (`cloud_workmanager.dart`), covering the Phase 5 / Scenario 11 and
/// Scenario 20 behaviours that are reachable from a test environment.
///
/// Seam note: the production dispatcher
/// ([initializeQazaCloudBackgroundDispatcher]) is driven through its real
/// Pigeon entry point below, which exercises its entry-guard chain — an
/// unknown task name, disabled cloud sync, disabled automatic sync, and a
/// signed-out installation all return before any Drive authorization,
/// database, or sync-engine work starts. The deeper branches construct the
/// production encrypted `AppDatabase` internally with no injection point,
/// and that executor cannot open under this package's standalone test
/// resolution (stock sqlite3 without cipher support; the cipher-enabled
/// sqlite3mc build is wired only into the app build). Those branches are
/// therefore covered at the exact seams the worker delegates to:
///
/// * the blocked-state upload predicate the worker consults immediately
///   before constructing the sync engine (`cloud_workmanager.dart:97-104`),
///   tested here against [AppDatabase.isWorkspaceCloudUploadBlocked] for
///   every state (provider-level proof that a blocked workspace never
///   reaches Drive lives in `google_cloud_providers_test.dart`), and
/// * the generation-drop settlement the worker relies on — after a dropped
///   run leaves the workspace `pending`, the next run's engine pass must
///   settle the orphaned upload by remote metadata/hash instead of
///   uploading a duplicate or raising a false conflict
///   (`cloud_workmanager.dart:112-127`), tested here against the real
///   [CloudSyncEngine] and Drive store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'google-account-A';
  const workspaceId = 'google_google-account-A';
  const localRecordId = 'google-account-A_fajr_2026-10-01';
  const authorizationChannel = MethodChannel(
    'qaza_cloud_adapter/google_drive_authorization',
  );

  group('scheduled worker entry guards (real dispatcher)', () {
    var authorizationCalls = 0;

    setUpAll(() {
      // Registration is one-shot per process (the workmanager plugin
      // stores the handler and its Pigeon API in late-final fields). The
      // handler reads preferences at invocation time, so each test still
      // controls its own installation state.
      initializeQazaCloudBackgroundDispatcher();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      authorizationCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(authorizationChannel, (call) async {
            authorizationCalls++;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(authorizationChannel, null);
    });

    /// Invokes the registered background task handler exactly the way the
    /// platform side does: a Pigeon `executeTask` message carrying the
    /// task name, whose reply is the handler's success flag.
    Future<bool> runWorkerTask(String taskName) async {
      const codec = WorkmanagerFlutterApi.pigeonChannelCodec;
      final completer = Completer<bool>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'dev.flutter.pigeon.workmanager_platform_interface.'
            'WorkmanagerFlutterApi.executeTask',
            codec.encodeMessage(<Object?>[taskName, null]),
            (ByteData? data) {
              if (data == null) {
                completer.completeError(
                  StateError('The dispatcher sent no reply'),
                );
                return;
              }
              final decoded = codec.decodeMessage(data) as List<Object?>;
              completer.complete(decoded.single as bool);
            },
          );
      return completer.future;
    }

    test(
      'an unknown task name is acknowledged without any cloud work',
      () async {
        expect(await runWorkerTask('some_unrelated_task'), isTrue);
        expect(authorizationCalls, 0);
      },
    );

    test(
      'cloud sync disabled stops the scheduled run at the entry gate',
      () async {
        final state = SharedPreferencesCloudSyncStateStore();
        await state.setActiveAccountId(accountId);
        // Cloud sync was never enabled for this account.
        expect(await runWorkerTask(cloudSyncWorkerTaskName), isTrue);
        expect(authorizationCalls, 0);
      },
    );

    test(
      'automatic sync disabled stops the scheduled run at the entry gate',
      () async {
        final state = SharedPreferencesCloudSyncStateStore();
        await state.setActiveAccountId(accountId);
        await state.setCloudSyncEnabled(true);
        // Automatic sync was never enabled for this installation.
        expect(await runWorkerTask(cloudSyncWorkerTaskName), isTrue);
        expect(authorizationCalls, 0);
      },
    );

    test('a signed-out installation starts no background cloud work', () async {
      // No active account is bound, so the worker must stop before any
      // authorization, database, or sync-engine work: a background job
      // must never run for a signed-out workspace.
      expect(await runWorkerTask(cloudSyncWorkerTaskName), isTrue);
      expect(authorizationCalls, 0);
    });
  });

  group('worker upload-block predicate', () {
    late AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(NativeDatabase.memory());
      final store = AccountLocalStore(database: database);
      await store.ensureInitialized();
      await store.ensureAccountActive(workspaceId);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'every unverified or conflicted state blocks the scheduled upload',
      () async {
        // This is the exact predicate the worker checks before it builds the
        // sync engine; if it returns true the run ends without syncing.
        for (final blockedState in <String>[
          'cloud_unverified',
          'legacy_unverified',
          'conflict',
          'needs_sign_in',
        ]) {
          await database.writeWorkspaceSyncState(workspaceId, blockedState);
          expect(
            await database.isWorkspaceCloudUploadBlocked(workspaceId),
            isTrue,
            reason: '$blockedState must block a scheduled upload',
          );
        }
      },
    );

    test('pending and clean workspaces are allowed to sync', () async {
      for (final allowedState in <String>['pending', 'clean']) {
        await database.writeWorkspaceSyncState(workspaceId, allowedState);
        expect(
          await database.isWorkspaceCloudUploadBlocked(workspaceId),
          isFalse,
          reason: '$allowedState must not block a scheduled upload',
        );
      }
    });
  });

  group('orphaned upload settlement (Scenario 20)', () {
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

    CloudSyncEngine buildEngine() {
      return CloudSyncEngine(
        phase1: LocalPhase1BackupSource(database, localAccountId: workspaceId),
        remote: GoogleDriveAppDataStore(
          _FakeGateway(accountId: accountId, handler: drive.handle),
        ),
        state: state.scopedToAccount(accountId),
      );
    }

    test('an upload orphaned by a dropped worker result is settled by '
        'metadata on the next run, not re-uploaded', () async {
      // First scheduled run: the engine uploads the workspace backup and
      // advances the sync cursor, exactly as it does inside a worker run.
      final firstRun = await buildEngine().sync(allowInteractive: false);
      expect(firstRun.kind, CloudSyncResultKind.uploaded);
      expect(drive.createCount, 1);
      final scopedState = state.scopedToAccount(accountId);
      final cursor = await scopedState.readCursor();
      expect(cursor.lastSyncedBackupId, isNotNull);
      final downloadsAfterFirstRun = drive.downloadCount;

      // The worker then notices the session generation moved on (the user
      // switched accounts mid-run) and drops the result: it must not mark
      // the workspace clean, only pending reconciliation. This is the
      // write the worker performs in that branch.
      await database.writeWorkspaceSyncState(
        workspaceId,
        'pending',
        localRevision: await database.readWorkspaceRevision(workspaceId),
        remoteAccountId: accountId,
      );
      expect(await database.readWorkspaceSyncState(workspaceId), 'pending');

      // Next scheduled run: the remote backup the dropped run uploaded is
      // recognised through its verified metadata (backup ID, authoritative
      // version, content hash), so the engine settles it as already synced
      // — no duplicate upload, no re-download, and no false conflict.
      final secondRun = await buildEngine().sync(allowInteractive: false);
      expect(secondRun.kind, CloudSyncResultKind.noOp);
      expect(drive.createCount, 1);
      expect(drive.downloadCount, downloadsAfterFirstRun);
      expect(await scopedState.readPendingConflict(), isNull);
      expect(
        (await scopedState.readCursor()).lastSyncedBackupId,
        cursor.lastSyncedBackupId,
      );
      // Local data is untouched by the settlement.
      final rows = await database
          .customSelect(
            'SELECT id FROM qaza_records WHERE user_id = ?',
            variables: [Variable(workspaceId)],
          )
          .get();
      expect(rows.map((row) => row.read<String>('id')), <String>[
        localRecordId,
      ]);
    });
  });
}

/// A stateful fake of the Drive files API at the HTTP layer, mirroring the
/// harness in `google_cloud_providers_phase4_test.dart`: uploads are
/// captured from the real multipart create request and then served back as
/// the latest backup with their client-supplied appProperties intact.
class _FakeDriveServer {
  Map<String, Object?>? _latestFile;
  final Map<String, String> _bodiesByFileId = <String, String>{};

  int createCount = 0;
  int downloadCount = 0;

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
    final fileId = 'file-upload-$createCount';
    final created = <String, Object?>{
      'id': fileId,
      'name': metadata['name'],
      'modifiedTime': '2026-10-02T00:00:00.000Z',
      'version': '1',
      'md5Checksum': md5.convert(utf8.encode(mediaBody!)).toString(),
      'appProperties': properties,
    };
    _latestFile = created;
    _bodiesByFileId[fileId] = mediaBody;
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
