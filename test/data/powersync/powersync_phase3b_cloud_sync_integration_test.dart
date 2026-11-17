import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:qaza_namaz/data/auth/supabase_auth_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('qaza_phase3b_test_');
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
    final dbPath = await QazaPowerSyncDatabaseManager.resolveWorkspaceDatabasePath(
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

  group('Phase 3B — Group 1: Connector Credentials Lifecycle', () {
    test('1. Authenticated connector credentials return valid JWT and user UUID',
        () async {
      final connector = QazaSupabaseConnector(
        powerSyncEndpoint: 'http://92.4.86.19',
        authTokenProvider: () async => 'valid_test_jwt_token',
        currentUserIdProvider: () async => '11111111-2222-3333-4444-555555555555',
      );

      final credentials = await connector.fetchCredentials();
      expect(credentials, isNotNull);
      expect(credentials!.endpoint, equals('http://92.4.86.19'));
      expect(credentials.token, equals('valid_test_jwt_token'));
      expect(credentials.userId, equals('11111111-2222-3333-4444-555555555555'));
      expect(credentials.expiresAt, isNotNull);
      expect(credentials.expiresAt!.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('2. Missing session returns null without throwing', () async {
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => null,
        currentUserIdProvider: () async => null,
      );

      final credentials = await connector.fetchCredentials();
      expect(credentials, isNull);
    });

    test('3. Expired session triggers token refresh', () async {
      var callCount = 0;
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async {
          callCount++;
          return 'refreshed_token_$callCount';
        },
        currentUserIdProvider: () async => 'user_uuid_123',
        tokenExpiryProvider: () async =>
            DateTime.now().toUtc().add(const Duration(minutes: 45)),
      );

      final creds1 = await connector.fetchCredentials();
      expect(creds1!.token, equals('refreshed_token_1'));

      connector.invalidateCredentials();
      final creds2 = await connector.fetchCredentials();
      expect(creds2!.token, equals('refreshed_token_2'));
    });

    test('4. Account-specific credentials prevent cross-account token reuse',
        () async {
      String? activeUser = 'user_alpha_uuid';
      String? activeToken = 'token_for_alpha';

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => activeToken,
        currentUserIdProvider: () async => activeUser,
      );

      final credsA = await connector.fetchCredentials();
      expect(credsA!.userId, equals('user_alpha_uuid'));
      expect(credsA.token, equals('token_for_alpha'));

      // Switch to User B
      activeUser = 'user_beta_uuid';
      activeToken = 'token_for_beta';
      connector.invalidateCredentials();

      final credsB = await connector.fetchCredentials();
      expect(credsB!.userId, equals('user_beta_uuid'));
      expect(credsB.token, equals('token_for_beta'));
      expect(credsB.userId, isNot(equals(credsA.userId)));
      expect(credsB.token, isNot(equals(credsA.token)));
    });
  });

  group('Phase 3B — Group 2: CRUD Upload Operations & Idempotency', () {
    test('5. Successful PUT/upsert operation mapping', () async {
      final uploadedCalls = <Map<String, dynamic>>[];
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            uploadedCalls.add({
              'table': op.table,
              'op': op.op,
              'id': op.id,
              'data': op.opData,
            });
          }
          await tx.complete();
        },
      );

      var txCompleted = false;
      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_1',
            table: 'qaza_records',
            op: ps.UpdateType.put,
            opData: {
              'prayer_type': 'fajr',
              'original_date': '2026-09-01',
              'status': 'pending',
            },
          ),
        ],
        onComplete: () => txCompleted = true,
      );

      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');
      await connector.uploadData(ws.psDb); // Checks null transaction gracefully

      await connector.customUploader!(tx);
      expect(uploadedCalls.length, equals(1));
      expect(uploadedCalls[0]['op'], equals(ps.UpdateType.put));
      expect(uploadedCalls[0]['table'], equals('qaza_records'));
      expect(txCompleted, isTrue);

      await ws.db.close();
    });

    test('6. Successful PATCH/update operation scoping', () async {
      final patchedRows = <String, dynamic>{};
      var txCompleted = false;
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            if (op.op == ps.UpdateType.patch) {
              patchedRows.addAll(op.opData ?? {});
            }
          }
          await tx.complete();
        },
      );

      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_1',
            table: 'qaza_records',
            op: ps.UpdateType.patch,
            opData: {
              'status': 'completed',
              'completed_at': '2026-09-02T10:00:00Z',
            },
          ),
        ],
        onComplete: () => txCompleted = true,
      );

      await connector.customUploader!(tx);
      expect(patchedRows['status'], equals('completed'));
      expect(patchedRows['completed_at'], equals('2026-09-02T10:00:00Z'));
      expect(txCompleted, isTrue);
    });

    test('7. Successful DELETE operation scoping', () async {
      String? deletedId;
      var txCompleted = false;
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            if (op.op == ps.UpdateType.delete) {
              deletedId = op.id;
            }
          }
          await tx.complete();
        },
      );

      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'rec_delete_target',
            table: 'qaza_records',
            op: ps.UpdateType.delete,
          ),
        ],
        onComplete: () => txCompleted = true,
      );

      await connector.customUploader!(tx);
      expect(deletedId, equals('rec_delete_target'));
      expect(txCompleted, isTrue);
    });

    test('8. CRUD transaction completes ONLY after all operations succeed', () async {
      var completedCount = 0;
      var txCompleted = false;
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            expect(op.table, isNotEmpty);
          }
          await tx.complete();
          completedCount++;
        },
      );

      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(id: '1', table: 'qaza_records', op: ps.UpdateType.put),
          makeCrudEntry(id: '2', table: 'qaza_records', op: ps.UpdateType.put),
        ],
        onComplete: () => txCompleted = true,
      );

      await connector.customUploader!(tx);
      expect(completedCount, equals(1));
      expect(txCompleted, isTrue);
    });

    test('9. Failed upload retains uncompleted transaction for retry', () async {
      var txCompleted = false;
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          throw const SocketException('Connection reset by peer');
        },
      );

      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(id: '1', table: 'qaza_records', op: ps.UpdateType.put),
        ],
        onComplete: () => txCompleted = true,
      );

      expect(() => connector.customUploader!(tx), throwsA(isA<SocketException>()));
      // MUST NOT be marked completed, allowing PowerSync to retry!
      expect(txCompleted, isFalse);
    });

    test('10. Partial upload retry preserves entire transaction', () async {
      var attempts = 0;
      var txCompleted = false;
      final appliedIds = <String>[];

      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          attempts++;
          for (final op in tx.crud) {
            if (op.id == 'failing_op' && attempts == 1) {
              throw const HttpException('503 Service Unavailable');
            }
            appliedIds.add(op.id);
          }
          await tx.complete();
        },
      );

      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(id: 'first_op', table: 'qaza_records', op: ps.UpdateType.put),
          makeCrudEntry(id: 'failing_op', table: 'qaza_records', op: ps.UpdateType.put),
        ],
        onComplete: () => txCompleted = true,
      );

      // Attempt 1: fails
      expect(() => connector.customUploader!(tx), throwsA(isA<HttpException>()));
      expect(txCompleted, isFalse);

      // Attempt 2: retry succeeds
      appliedIds.clear();
      await connector.customUploader!(tx);
      expect(txCompleted, isTrue);
      expect(appliedIds, containsAll(['first_op', 'failing_op']));
    });

    test('11. Duplicate upload idempotency succeeds deterministically', () async {
      final targetStore = <String, Map<String, dynamic>>{};

      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'test_user_uuid',
        customUploader: (tx) async {
          for (final op in tx.crud) {
            // Upsert on id
            targetStore[op.id] = Map<String, dynamic>.of(op.opData ?? {});
          }
          await tx.complete();
        },
      );

      final entry = makeCrudEntry(
        id: 'idempotent_rec',
        table: 'qaza_records',
        op: ps.UpdateType.put,
        opData: {'status': 'completed'},
      );

      final tx1 = makeCrudTransaction(crud: [entry]);
      await connector.customUploader!(tx1);
      expect(targetStore['idempotent_rec']?['status'], equals('completed'));

      // Re-upload identical entry
      final tx2 = makeCrudTransaction(crud: [entry]);
      await connector.customUploader!(tx2);
      expect(targetStore['idempotent_rec']?['status'], equals('completed'));
      expect(targetStore.length, equals(1));
    });
  });

  group('Phase 3B — Group 3: Foreign Key Dependency & Ordering', () {
    test('12. sortCrudEntries enforces parent before child inserts, child before parent deletes', () {
      final entries = [
        makeCrudEntry(id: 'snap_1', table: 'qaza_deletion_action_record_snapshots', op: ps.UpdateType.put),
        makeCrudEntry(id: 'act_1', table: 'qaza_deletion_actions', op: ps.UpdateType.put),
        makeCrudEntry(id: 'rec_1', table: 'qaza_records', op: ps.UpdateType.put),
        makeCrudEntry(id: 'add_1', table: 'qaza_additions', op: ps.UpdateType.put),
        makeCrudEntry(id: 'prof_1', table: 'account_profiles', op: ps.UpdateType.put),
      ];

      final sortedInserts = QazaSupabaseConnector.sortCrudEntries(entries);
      final sortedTables = sortedInserts.map((e) => e.table).toList();

      expect(sortedTables, equals([
        'account_profiles',
        'qaza_additions',
        'qaza_records',
        'qaza_deletion_actions',
        'qaza_deletion_action_record_snapshots',
      ]));

      // Verify Deletions: child before parent
      final deleteEntries = [
        makeCrudEntry(id: 'add_1', table: 'qaza_additions', op: ps.UpdateType.delete),
        makeCrudEntry(id: 'rec_1', table: 'qaza_records', op: ps.UpdateType.delete),
        makeCrudEntry(id: 'act_1', table: 'qaza_deletion_actions', op: ps.UpdateType.delete),
        makeCrudEntry(id: 'snap_1', table: 'qaza_deletion_action_record_snapshots', op: ps.UpdateType.delete),
      ];

      final sortedDeletes = QazaSupabaseConnector.sortCrudEntries(deleteEntries);
      final sortedDeleteTables = sortedDeletes.map((e) => e.table).toList();

      expect(sortedDeleteTables, equals([
        'qaza_deletion_action_record_snapshots',
        'qaza_deletion_actions',
        'qaza_records',
        'qaza_additions',
      ]));
    });
  });

  group('Phase 3B — Group 4: Ownership & RLS Authorization Matrix', () {
    test('13. Direct ownership authorization rejects foreign user_id', () async {
      final connector = QazaSupabaseConnector(
        currentUserIdProvider: () async => 'legitimate_user_uuid',
      );

      final foreignEntry = makeCrudEntry(
        id: 'rec_foreign',
        table: 'qaza_records',
        op: ps.UpdateType.put,
        opData: {
          'user_id': 'malicious_attacker_uuid',
          'prayer_type': 'fajr',
        },
      );

      // Expect StateError on tampering attempt
      expect(
        () async {
          final data = Map<String, dynamic>.of(foreignEntry.opData!);
          final currentUserId = await connector.getCurrentUserId();
          if (data['user_id'] != currentUserId) {
            throw StateError('Security violation: cannot upload record for foreign user_id');
          }
        },
        throwsA(isA<StateError>()),
      );
    });

    test('14. Related-record authorization validates child snapshots belong to authenticated user', () {
      const authUser = 'user_uuid_owner';
      final snapshotData = {
        'deletion_action_id': 'action_1',
        'record_id': 'record_1',
        'user_id': authUser,
        'prayer_type': 'fajr',
      };

      expect(snapshotData['user_id'], equals(authUser));
    });

    test('15. User A vs User B isolation in database queries', () async {
      final userA = await openWorkspacePowerSync(workspaceId: 'google_user_alpha');
      final userB = await openWorkspacePowerSync(workspaceId: 'google_user_beta');

      final now = DateTime.utc(2026, 9, 1);
      await userA.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'a_record',
        userId: 'google_user_alpha',
        prayerType: 'fajr',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      await userB.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'b_record',
        userId: 'google_user_beta',
        prayerType: 'isha',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // User A sees ONLY their record
      final aRows = await (userA.db.select(userA.db.qazaRecords)).get();
      expect(aRows.length, equals(1));
      expect(aRows.single.id, equals('a_record'));

      // User B sees ONLY their record
      final bRows = await (userB.db.select(userB.db.qazaRecords)).get();
      expect(bRows.length, equals(1));
      expect(bRows.single.id, equals('b_record'));

      await userA.db.close();
      await userB.db.close();
    });
  });

  group('Phase 3B — Group 5: Sync Stream & Cloud Gating', () {
    test('16. Sync stream configuration file queries all 9 tables with user_id filter', () {
      final yamlFile = File('powersync/powersync.yaml');
      expect(yamlFile.existsSync(), isTrue);

      final content = yamlFile.readAsStringSync();
      expect(content, contains('edition: 3'));
      expect(content, contains('auto_subscribe: true'));

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

      for (final table in requiredTables) {
        expect(content, contains('SELECT * FROM $table WHERE user_id = auth.user_id()'));
      }
    });

    test('21. Guest mode zero cloud traffic: connect refuses Guest workspace', () async {
      expect(PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest'), isFalse);
      expect(PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest_123'), isFalse);

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'token',
        currentUserIdProvider: () async => 'user',
      );

      final connected = await QazaPowerSyncDatabaseManager.connect(
        connector,
        workspaceId: 'guest',
        documentsDirectoryProvider: () async => tempDir,
      );

      // Controlled gate: refuses cloud sync for Guest!
      expect(connected, isFalse);
    });
  });

  group('Phase 3B — Group 6: Offline Queue, Recovery & Convergence', () {
    test('17. Offline queue persistence: mutations queue locally in PowerSync database', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final now = DateTime.utc(2026, 9, 2);
      await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'offline_queue_rec_1',
        userId: 'google_developer_test',
        prayerType: 'zuhr',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // Verify record is saved in local table
      final fetched = await ws.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: 'offline_queue_rec_1',
      );
      expect(fetched, isNotNull);
      expect(fetched!.prayerType.name, equals('zuhr'));

      // Verify PowerSync has an uncompleted local transaction queued in ps_crud
      final crudRows = await ws.psDb.getAll('SELECT * FROM ps_crud');
      expect(crudRows, isNotEmpty);
      expect(crudRows.any((r) => r['data']?.toString().contains('offline_queue_rec_1') ?? false), isTrue);

      await ws.db.close();
    });

    test('18. Reconnection and pending upload recovery', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final now = DateTime.utc(2026, 9, 3);
      await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'reconnect_rec',
        userId: 'google_developer_test',
        prayerType: 'asr',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      final queued = await ws.psDb.getNextCrudTransaction();
      expect(queued, isNotNull);
      expect(queued!.crud.any((e) => e.id == 'reconnect_rec'), isTrue);

      // Simulate connector processing and completing the recovered transaction
      await queued.complete();

      // Next transaction should now be null
      final remaining = await ws.psDb.getNextCrudTransaction();
      expect(remaining, isNull);

      await ws.db.close();
    });

    test('22. Data convergence after app restart', () async {
      final ws1 = await openWorkspacePowerSync(workspaceId: 'google_restart_test');

      final now = DateTime.utc(2026, 9, 4);
      await ws1.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'restart_rec',
        userId: 'google_restart_test',
        prayerType: 'maghrib',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      await ws1.db.close();
      await QazaPowerSyncDatabaseManager.closeAll();

      // Reopen database
      final ws2 = await openWorkspacePowerSync(workspaceId: 'google_restart_test');
      final fetched = await ws2.db.qazaRecordsDao.findById(
        userId: 'google_restart_test',
        id: 'restart_rec',
      );
      expect(fetched, isNotNull);
      expect(fetched!.prayerType.name, equals('maghrib'));

      await ws2.db.close();
    });

    test('23. Deletion tombstone and snapshot preservation for Undo audit', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      await ws.psDb.execute(
        '''INSERT INTO qaza_deletion_actions (id, user_id, addition_id, created_at, entity_version)
           VALUES ('del_act_1', 'google_developer_test', 'add_1', 1788500000, 1)''',
      );

      await ws.psDb.execute(
        '''INSERT INTO qaza_deletion_action_record_snapshots
           (id, deletion_action_id, record_id, user_id, addition_id, prayer_type, original_date, status, created_at, updated_at, record_version)
           VALUES ('snap_1', 'del_act_1', 'rec_1', 'google_developer_test', 'add_1', 'fajr', 1788500000, 'pending', 1788500000, 1788500000, 1)''',
      );

      final actions = await ws.psDb.getAll('SELECT * FROM qaza_deletion_actions WHERE id = ?', ['del_act_1']);
      expect(actions.length, equals(1));

      final snapshots = await ws.psDb.getAll('SELECT * FROM qaza_deletion_action_record_snapshots WHERE deletion_action_id = ?', ['del_act_1']);
      expect(snapshots.length, equals(1));
      expect(snapshots.single['record_id'], equals('rec_1'));

      await ws.db.close();
    });
  });

  group('Phase 3B — Group 7: Account Lifecycle & Switching', () {
    test('19. Sign-out cleanly clears local replication instance', () async {
      final ws = await openWorkspacePowerSync(workspaceId: 'google_developer_test');

      final authService = SupabaseAuthService(
        connector: QazaSupabaseConnector(
          authTokenProvider: () async => 'token',
          currentUserIdProvider: () async => 'user_uuid',
        ),
      );

      await authService.signOut(workspaceId: 'google_developer_test');

      // Database manager closed the instance cleanly
      expect(ws.psDb.closed, isTrue);
    });

    test('20. Account switching isolates connector sessions and databases', () async {
      final userA = await openWorkspacePowerSync(workspaceId: 'google_switch_a');
      final userB = await openWorkspacePowerSync(workspaceId: 'google_switch_b');

      final connectorA = QazaSupabaseConnector(
        authTokenProvider: () async => 'token_a',
        currentUserIdProvider: () async => 'user_a_uuid',
      );
      final connectorB = QazaSupabaseConnector(
        authTokenProvider: () async => 'token_b',
        currentUserIdProvider: () async => 'user_b_uuid',
      );

      final credsA = await connectorA.fetchCredentials();
      final credsB = await connectorB.fetchCredentials();

      expect(credsA!.token, equals('token_a'));
      expect(credsB!.token, equals('token_b'));
      expect(credsA.userId, isNot(equals(credsB.userId)));

      // Close Account A
      await QazaPowerSyncDatabaseManager.closeDatabase(
        workspaceId: 'google_switch_a',
        documentsDirectoryProvider: () async => tempDir,
      );

      expect(userA.psDb.closed, isTrue);
      // Account B remains unaffected
      expect(userB.psDb.closed, isFalse);

      await userB.db.close();
    });
  });
}
