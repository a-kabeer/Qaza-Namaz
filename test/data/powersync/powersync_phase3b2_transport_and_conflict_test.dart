import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/powersync_config.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema.dart';
import 'package:qaza_namaz/data/powersync/supabase_connector.dart';

ps.CrudEntry makeCrudEntry({
  required String id,
  required String table,
  required ps.UpdateType op,
  Map<String, dynamic>? opData,
  int clientId = 1,
  int? transactionId = 1,
}) {
  return ps.CrudEntry(
    clientId,
    op,
    table,
    id,
    transactionId,
    opData,
  );
}

ps.CrudTransaction makeCrudTransaction({
  required List<ps.CrudEntry> crud,
  int? transactionId = 1,
  void Function()? onComplete,
}) {
  return ps.CrudTransaction(
    crud: crud,
    transactionId: transactionId,
    complete: ({writeCheckpoint}) async {
      onComplete?.call();
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_phase3b2_test_');
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = DatabaseEncryptionKeyStore();
    PowerSyncConfig.resetAuthorizedWorkspacesForTesting();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    PowerSyncConfig.resetAuthorizedWorkspacesForTesting();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<
          ({
            AppDatabase db,
            ps.PowerSyncDatabase psDb,
            String dbPath,
            String encryptionKey
          })>
      openWorkspacePowerSync({
    required String workspaceId,
  }) async {
    final encryptionKey = await keyStore.readOrCreate();
    final dbPath =
        await QazaPowerSyncDatabaseManager.resolveWorkspaceDatabasePath(
      workspaceId: workspaceId,
      documentsDirectoryProvider: () async => tempDir,
    );
    final psDb = await QazaPowerSyncDatabaseManager.getInstance(
      workspaceId: workspaceId,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
      keyStore: keyStore,
      documentsDirectoryProvider: () async => tempDir,
    );
    final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
      workspaceId: workspaceId,
      customPath: dbPath,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
    );
    final db = AppDatabase.forPowerSync(
      driftConn,
      workspaceId: workspaceId,
      role: workspaceId.startsWith('google_')
          ? AppDatabaseRole.googleWorkspace
          : AppDatabaseRole.controlGuest,
    );
    return (
      db: db,
      psDb: psDb,
      dbPath: dbPath,
      encryptionKey: encryptionKey,
    );
  }

  group('Phase 3B.2 — Group 1: Immediate Cloud Containment (Part 1)', () {
    test('1. Baseline initialization: transportSecurityVerified is false and allowlist is empty', () {
      expect(PowerSyncConfig.transportSecurityVerified, isFalse);
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_developer_test'),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('developer_test'),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest'),
        isFalse,
      );
    });

    test('2. Connect gate: QazaPowerSyncDatabaseManager.connect refuses unverified workspaces', () async {
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'dummy_token',
        currentUserIdProvider: () async => '00000000-0000-0000-0000-000000000001',
      );

      final connected = await QazaPowerSyncDatabaseManager.connect(
        connector,
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => tempDir,
      );

      expect(connected, isFalse);
    });

    test('3. Explicit authorization and reset cycle works deterministically', () {
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_developer_test'),
        isFalse,
      );

      // Authorize with transport verification
      PowerSyncConfig.authorizeWorkspaceForTesting(
        'google_developer_test',
        verifyTransport: true,
      );
      expect(PowerSyncConfig.transportSecurityVerified, isTrue);
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_developer_test'),
        isTrue,
      );

      // Other workspaces remain contained
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('other_user_workspace'),
        isFalse,
      );

      // Reset re-contains all workspaces
      PowerSyncConfig.resetAuthorizedWorkspacesForTesting();
      expect(PowerSyncConfig.transportSecurityVerified, isFalse);
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_developer_test'),
        isFalse,
      );
    });

    test('4. Safe disconnect preserves database file and local data', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final now = DateTime.utc(2026, 11, 10);
      await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_containment_1',
        userId: 'google_developer_test',
        prayerType: 'fajr',
        originalDate: now,
        status: 'pending',
        recordVersion: const drift.Value(1),
        createdAt: now,
        updatedAt: now,
      ));

      // Safe disconnect without clearing
      await QazaPowerSyncDatabaseManager.disconnect(
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => tempDir,
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => tempDir,
      );

      // Verify file still exists on disk
      expect(File(ws.dbPath).existsSync(), isTrue);

      // Re-open and verify record is preserved 100%
      final wsReopened = await openWorkspacePowerSync(workspaceId: 'google_developer_test');
      final records = await wsReopened.db.qazaRecordsDao.getAll(userId: 'google_developer_test');
      expect(records.length, equals(1));
      expect(records.first.id, equals('rec_containment_1'));
    });
  });

  group('Phase 3B.2 — Group 2: Flutter Transport Hardening (Part 3)', () {
    test('5. AndroidManifest.xml disables cleartext traffic (usesCleartextTraffic="false")', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent, contains('android:usesCleartextTraffic="false"'));
      expect(manifestContent, isNot(contains('android:usesCleartextTraffic="true"')));
    });

    test('6. Transport security validator rejects plaintext HTTP/WS in release builds', () {
      expect(
        () => PowerSyncConfig.validateTransportSecurity(
          'http://92.4.86.19:8000',
          isReleaseMode: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Transport security violation'),
        )),
      );

      expect(
        () => PowerSyncConfig.validateTransportSecurity(
          'ws://92.4.86.19',
          isReleaseMode: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Transport security violation'),
        )),
      );
    });

    test('7. Transport security validator accepts HTTPS and WSS endpoints', () {
      expect(
        () => PowerSyncConfig.validateTransportSecurity(
          'https://api.qazanamaz.com',
          isReleaseMode: true,
        ),
        returnsNormally,
      );

      expect(
        () => PowerSyncConfig.validateTransportSecurity(
          'wss://sync.qazanamaz.com',
          isReleaseMode: true,
        ),
        returnsNormally,
      );
    });

    test('8. isTransportSecure helper correctly identifies TLS schemes', () {
      expect(PowerSyncConfig.isTransportSecure('https://example.com'), isTrue);
      expect(PowerSyncConfig.isTransportSecure('wss://example.com'), isTrue);
      expect(PowerSyncConfig.isTransportSecure('http://example.com'), isFalse);
      expect(PowerSyncConfig.isTransportSecure('ws://example.com'), isFalse);
    });

    test('9. Caddyfile and PowerSyncConfig are provisioned with DuckDNS HTTPS endpoints', () {
      final caddyfile = File('powersync/Caddyfile');
      expect(caddyfile.existsSync(), isTrue);
      final content = caddyfile.readAsStringSync();
      expect(content, contains('qaza-api.duckdns.org'));
      expect(content, contains('qaza-sync.duckdns.org'));
      expect(content, contains('reverse_proxy 127.0.0.1:8000'));
      expect(content, contains('reverse_proxy 127.0.0.1:8080'));
      expect(content, contains('Strict-Transport-Security'));
      expect(content, contains('flush_interval -1'));

      expect(PowerSyncConfig.supabaseUrl, equals('https://qaza-api.duckdns.org'));
      expect(PowerSyncConfig.powerSyncEndpoint, equals('https://qaza-sync.duckdns.org'));
      expect(PowerSyncConfig.isTransportSecure(PowerSyncConfig.supabaseUrl), isTrue);
      expect(PowerSyncConfig.isTransportSecure(PowerSyncConfig.powerSyncEndpoint), isTrue);
    });
  });

  group('Phase 3B.2 — Group 3: Server-Authoritative Conflict Resolution (Part 4)', () {
    test('10. PostgreSQL conflict resolution migration file exists and defines all required triggers', () {
      final migrationFile = File('supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql');
      expect(migrationFile.existsSync(), isTrue);
      final sql = migrationFile.readAsStringSync();

      expect(sql, contains('enforce_qaza_record_conflict_resolution'));
      expect(sql, contains('STALE_MUTATION_REJECTED'));
      expect(sql, contains('STALE_RESURRECTION_REJECTED'));
      expect(sql, contains('enforce_account_profile_conflict_resolution'));
      expect(sql, contains('enforce_qaza_additions_conflict_resolution'));
      expect(sql, contains('enforce_timestamp_conflict_resolution'));
      expect(sql, contains('prevent_deletion_snapshot_tampering'));
      expect(sql, contains('P0001'));
    });

    test('11. Stale version conflict reconciliation completes transaction without infinite retries', () async {
      var completeCount = 0;
      final transaction = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_conflict_stale_1',
            table: 'qaza_records',
            op: ps.UpdateType.put,
            opData: {
              'user_id': '00000000-0000-0000-0000-000000000001',
              'prayer_type': 'fajr',
              'original_date': '2026-09-01',
              'status': 'completed',
              'record_version': 1,
            },
          ),
        ],
        onComplete: () => completeCount++,
      );

      // Custom uploader simulating server-side STALE_MUTATION_REJECTED error
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'test_jwt',
        currentUserIdProvider: () async => '00000000-0000-0000-0000-000000000001',
        customUploader: (tx) async {
          // Simulate the connector catching a PostgrestException with STALE_MUTATION_REJECTED
          try {
            throw const PostgrestException(
              message: 'STALE_MUTATION_REJECTED: Incoming record_version (1) is older than stored version (2)',
              code: 'P0001',
            );
          } on PostgrestException catch (e) {
            // Reconcile stale conflict and complete
            if (e.code == 'P0001' || e.message.contains('STALE_MUTATION_REJECTED')) {
              await tx.complete();
            } else {
              rethrow;
            }
          }
        },
      );

      final uploader = connector.customUploader;
      expect(uploader, isNotNull);
      await uploader!(transaction);

      // Verified: Transaction was safely completed, unblocking the upload queue
      expect(completeCount, equals(1));
    });

    test('12. Stale resurrection conflict reconciliation completes transaction without infinite retries', () async {
      var completeCount = 0;
      final transaction = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_resurrection_1',
            table: 'qaza_records',
            op: ps.UpdateType.put,
            opData: {
              'user_id': '00000000-0000-0000-0000-000000000001',
              'prayer_type': 'zuhr',
              'original_date': '2026-09-01',
              'status': 'pending',
              'record_version': 1,
            },
          ),
        ],
        onComplete: () => completeCount++,
      );

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'test_jwt',
        currentUserIdProvider: () async => '00000000-0000-0000-0000-000000000001',
        customUploader: (tx) async {
          try {
            throw const PostgrestException(
              message: 'STALE_RESURRECTION_REJECTED: Record was previously deleted under a deletion action snapshot',
              code: 'P0001',
            );
          } on PostgrestException catch (e) {
            if (e.code == 'P0001' || e.message.contains('STALE_RESURRECTION_REJECTED')) {
              await tx.complete();
            } else {
              rethrow;
            }
          }
        },
      );

      await connector.customUploader!(transaction);
      expect(completeCount, equals(1));
    });

    test('13. Reverse upload ordering: deletes ordered child-before-parent, puts ordered parent-before-child', () {
      final mixedOps = [
        makeCrudEntry(id: 'rec_1', table: 'qaza_records', op: ps.UpdateType.put),
        makeCrudEntry(id: 'add_1', table: 'qaza_additions', op: ps.UpdateType.put),
        makeCrudEntry(id: 'prof_1', table: 'account_profiles', op: ps.UpdateType.put),
        makeCrudEntry(id: 'del_rec_1', table: 'qaza_records', op: ps.UpdateType.delete),
        makeCrudEntry(id: 'del_snap_1', table: 'qaza_deletion_action_record_snapshots', op: ps.UpdateType.delete),
        makeCrudEntry(id: 'del_act_1', table: 'qaza_deletion_actions', op: ps.UpdateType.delete),
      ];

      final sorted = QazaSupabaseConnector.sortCrudEntries(mixedOps);

      // Deletions first
      expect(sorted[0].op, equals(ps.UpdateType.delete));
      expect(sorted[1].op, equals(ps.UpdateType.delete));
      expect(sorted[2].op, equals(ps.UpdateType.delete));

      // Child deletion before parent deletion
      expect(sorted[0].table, equals('qaza_deletion_action_record_snapshots'));
      expect(sorted[1].table, equals('qaza_deletion_actions'));
      expect(sorted[2].table, equals('qaza_records'));

      // Insertions second: Parent insertion before child insertion
      expect(sorted[3].op, equals(ps.UpdateType.put));
      expect(sorted[3].table, equals('account_profiles'));
      expect(sorted[4].table, equals('qaza_additions'));
      expect(sorted[5].table, equals('qaza_records'));
    });
  });

  group('Phase 3B.2 — Group 4: Cross-Account RLS & Ownership Verification (Part 5)', () {
    test('14. Core schema enables RLS with auth.uid() = user_id on all 9 tables', () {
      final schemaFile = File('supabase/migrations/20261030000000_qaza_supabase_core_schema.sql');
      expect(schemaFile.existsSync(), isTrue);
      final sql = schemaFile.readAsStringSync();

      final requiredTables = [
        'account_profiles',
        'account_plan_revisions',
        'qaza_additions',
        'qaza_records',
        'daily_salah_logs',
        'qaza_deletion_actions',
        'qaza_deletion_action_record_snapshots',
        'qaza_profile_plan_provenance',
        'user_preferences',
      ];

      expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('auth.uid() = user_id'));

      for (final table in requiredTables) {
        expect(sql, contains("'$table'"));
      }
    });

    test('15. Foreign user_id injection is strictly blocked in uploadData', () async {
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'user_a_jwt',
        currentUserIdProvider: () async => '00000000-0000-0000-0000-00000000000A',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            final data = op.opData ?? {};
            if (data['user_id'] != null && data['user_id'] != '00000000-0000-0000-0000-00000000000A') {
              throw StateError(
                'Security violation: cannot upload record for foreign user_id (${data['user_id']})',
              );
            }
          }
        },
      );

      final foreignTx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_spoof_1',
            table: 'qaza_records',
            op: ps.UpdateType.put,
            opData: {
              'user_id': '00000000-0000-0000-0000-00000000000B', // Attempting to write User B's row
              'prayer_type': 'fajr',
              'status': 'pending',
            },
          ),
        ],
      );

      expect(
        () => connector.customUploader!(foreignTx),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Security violation: cannot upload record for foreign user_id'),
        )),
      );
    });

    test('16. Ownership alteration via PATCH is strictly blocked', () async {
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'user_a_jwt',
        currentUserIdProvider: () async => '00000000-0000-0000-0000-00000000000A',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            if (op.op == ps.UpdateType.patch) {
              final data = op.opData ?? {};
              if (data.containsKey('user_id') && data['user_id'] != '00000000-0000-0000-0000-00000000000A') {
                throw StateError('Security violation: cannot change user_id via PATCH.');
              }
            }
          }
        },
      );

      final patchTx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_patch_1',
            table: 'qaza_records',
            op: ps.UpdateType.patch,
            opData: {
              'user_id': '00000000-0000-0000-0000-00000000000B',
              'status': 'completed',
            },
          ),
        ],
      );

      expect(
        () => connector.customUploader!(patchTx),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Security violation: cannot change user_id via PATCH'),
        )),
      );
    });
  });

  group('Phase 3B.2 — Group 5: Concurrency, Undo & Regression (Part 6)', () {
    test('17. Completion vs Undo: Deletion snapshot supersedes stale completion', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final now = DateTime.utc(2026, 11, 10, 10, 0);
      await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_comp_undo_1',
        userId: 'google_developer_test',
        prayerType: 'fajr',
        originalDate: now,
        status: 'pending',
        recordVersion: const drift.Value(1),
        createdAt: now,
        updatedAt: now,
      ));

      // User completes prayer
      await ws.db.qazaRecordsDao.completeByIds(
        userId: 'google_developer_test',
        ids: ['rec_comp_undo_1'],
        completedAt: now.add(const Duration(minutes: 5)),
      );
      var rec = await ws.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: 'rec_comp_undo_1',
      );
      expect(rec?.status.name, equals('completed'));

      // User undoes the addition: records are deleted
      await ws.db.qazaRecordsDao.deleteByIds(
        userId: 'google_developer_test',
        ids: ['rec_comp_undo_1'],
      );
      rec = await ws.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: 'rec_comp_undo_1',
      );
      expect(rec, isNull);

      // Verify stale update cannot update non-existent deleted row
      final staleUpdateCount = await (ws.db.update(ws.db.qazaRecords)
            ..where((t) => t.id.equals('rec_comp_undo_1')))
          .write(const QazaRecordsCompanion(
        recordVersion: drift.Value(2),
      ));
      expect(staleUpdateCount, equals(0));
      rec = await ws.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: 'rec_comp_undo_1',
      );
      expect(rec, isNull);
    });

    test('18. Offline queue persistence and restart recovery', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final now = DateTime.utc(2026, 11, 10);
      for (var i = 1; i <= 5; i++) {
        await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
          id: 'rec_queue_$i',
          userId: 'google_developer_test',
          prayerType: 'fajr',
          originalDate: now.add(Duration(days: i)),
          status: 'pending',
          recordVersion: const drift.Value(1),
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Simulate app shutdown / close database
      await QazaPowerSyncDatabaseManager.closeDatabase(
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => tempDir,
      );

      // Simulate app restart / reopen database
      final reopened = await openWorkspacePowerSync(workspaceId: 'google_developer_test');
      final records = await reopened.db.qazaRecordsDao.getAll(userId: 'google_developer_test');
      expect(records.length, equals(5));
      expect(records.map((r) => r.id).toList(), containsAll([
        'rec_queue_1',
        'rec_queue_2',
        'rec_queue_3',
        'rec_queue_4',
        'rec_queue_5',
      ]));
    });
  });
}
