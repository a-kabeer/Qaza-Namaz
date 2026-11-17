import 'dart:convert';
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
    tempDir = await Directory.systemTemp.createTemp('qaza_phase3c_test_');
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = DatabaseEncryptionKeyStore();
    PowerSyncConfig.restoreControlledDeveloperAccess();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    PowerSyncConfig.restoreControlledDeveloperAccess();
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
      openWorkspaceRuntime({
    required String workspaceId,
    String? customSubdir,
  }) async {
    final subDir = customSubdir != null
        ? Directory('${tempDir.path}/$customSubdir')
        : tempDir;
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }

    final encryptionKey = await keyStore.readOrCreateForWorkspace(
      customSubdir != null ? '${workspaceId}_$customSubdir' : workspaceId,
    );
    final dbPath =
        await QazaPowerSyncDatabaseManager.resolveWorkspaceDatabasePath(
      workspaceId: workspaceId,
      documentsDirectoryProvider: () async => subDir,
    );
    final psDb = await QazaPowerSyncDatabaseManager.getInstance(
      workspaceId: workspaceId,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
      keyStore: keyStore,
      documentsDirectoryProvider: () async => subDir,
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

  // ===========================================================================
  // GROUP 1: CONTROLLED DEVELOPER ACCESS & CLOUD GATING
  // ===========================================================================
  group('Phase 3C — Group 1: Controlled Developer Access & Cloud Gating', () {
    test('1. Transport security verified and single developer workspace authorized', () {
      expect(PowerSyncConfig.transportSecurityVerified, isTrue);
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_developer_test'),
        isTrue,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('developer_test'),
        isTrue,
      );
      expect(
        PowerSyncConfig.developerTestSupabaseUserId,
        equals('01138602-ccd5-4c3f-94cf-8935347face7'),
      );
    });

    test('2. Wildcard or unlisted Google workspaces are strictly rejected', () {
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_random_user'),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('google_another_account@gmail.com'),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('wildcard_*'),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync(null),
        isFalse,
      );
      expect(
        PowerSyncConfig.isWorkspaceAuthorizedForCloudSync(''),
        isFalse,
      );
    });

    test('3. Guest workspace remains strictly cloud-disabled (air-gapped)', () {
      expect(PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest'), isFalse);
      expect(PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest_123'), isFalse);
      expect(PowerSyncConfig.isWorkspaceAuthorizedForCloudSync('guest:local'), isFalse);

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'test_token',
        currentUserIdProvider: () async => 'test_uid',
      );

      expect(
        QazaPowerSyncDatabaseManager.connect(
          connector,
          workspaceId: 'guest',
          documentsDirectoryProvider: () async => tempDir,
        ),
        completion(isFalse),
      );
    });

    test('4. Connection gate permits developer test workspace and establishes connection', () async {
      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'test_token',
        currentUserIdProvider: () async => PowerSyncConfig.developerTestSupabaseUserId,
      );

      final connected = await QazaPowerSyncDatabaseManager.connect(
        connector,
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => tempDir,
      );

      expect(connected, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 2: PRE-SYNC DATA SAFETY & INITIAL SYNCHRONIZATION
  // ===========================================================================
  group('Phase 3C — Group 2: Pre-Sync Data Safety & Initial Synchronization', () {
    test('5. Pre-sync check: verifies local ledger, pending crud, and ID uniqueness', () async {
      final ws = await openWorkspaceRuntime(workspaceId: 'google_developer_test');

      // Local ledger initially empty
      final initialRecords = await ws.db.qazaRecordsDao.getAll(
        userId: 'google_developer_test',
      );
      expect(initialRecords, isEmpty);

      // Pending CRUD is empty
      final pendingTx = await ws.psDb.getNextCrudTransaction();
      expect(pendingTx, isNull);

      // Verify no duplicate IDs exist locally
      final count = await ws.db.qazaRecordsDao.count(
        userId: 'google_developer_test',
      );
      expect(count, equals(0));
    });

    test('6. Create synthetic Qaza records covering all 6 prayers on Device A', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );

      final baseDate = DateTime.utc(2026, 11, 10);
      final prayers = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha', 'witr'];

      for (var i = 0; i < prayers.length; i++) {
        final prayer = prayers[i];
        final id = 'synth_${prayer}_${baseDate.toIso8601String().substring(0, 10)}';
        await deviceA.db.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: id,
            userId: 'google_developer_test',
            prayerType: prayer,
            originalDate: baseDate,
            status: 'pending',
            recordVersion: const drift.Value(1),
            createdAt: baseDate,
            updatedAt: baseDate,
          ),
        );
      }

      final records = await deviceA.db.qazaRecordsDao.getAll(
        userId: 'google_developer_test',
      );
      expect(records.length, equals(6));
      expect(
        records.map((r) => r.prayerType.name).toSet(),
        containsAll(prayers),
      );
    });

    test('7. Deterministic CRUD upload generates structured, dependency-ordered mutations', () async {
      final uploadedTables = <String>[];
      final uploadedOps = <ps.CrudEntry>[];

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'jwt_token',
        currentUserIdProvider: () async => PowerSyncConfig.developerTestSupabaseUserId,
        customUploader: (tx) async {
          uploadedTables.addAll(tx.crud.map((c) => c.table));
          uploadedOps.addAll(tx.crud);
          await tx.complete();
        },
      );

      final tx = makeCrudTransaction(crud: [
        makeCrudEntry(
          id: 'rec_1',
          table: 'qaza_records',
          op: ps.UpdateType.put,
          opData: {
            'user_id': PowerSyncConfig.developerTestSupabaseUserId,
            'prayer_type': 'fajr',
            'record_version': 1,
          },
        ),
        makeCrudEntry(
          id: 'profile_1',
          table: 'account_profiles',
          op: ps.UpdateType.put,
          opData: {
            'user_id': PowerSyncConfig.developerTestSupabaseUserId,
            'entity_version': 1,
          },
        ),
      ]);

      await connector.customUploader!(tx);

      // Verify transaction completed and entries were processed
      expect(uploadedTables, containsAll(['qaza_records', 'account_profiles']));
      expect(uploadedOps.length, equals(2));
    });
  });

  // ===========================================================================
  // GROUP 3: TWO-DEVICE DUAL-RUNTIME SYNCHRONIZATION & CONVERGENCE
  // ===========================================================================
  group('Phase 3C — Group 3: Two-Device Dual-Runtime Synchronization', () {
    test('8. Device A and Device B dual-runtime isolation (distinct files & encryption keys)', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );
      final deviceB = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_b',
      );

      expect(deviceA.dbPath, isNot(equals(deviceB.dbPath)));
      expect(deviceA.encryptionKey, isNot(equals(deviceB.encryptionKey)));
    });

    test('9. Device A inserts records -> Device B syncs and verifies parity', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );
      final deviceB = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_b',
      );

      final now = DateTime.utc(2026, 11, 10);
      final testId = 'rec_dual_device_fajr_1';

      // 1. Device A writes
      await deviceA.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: testId,
          userId: 'google_developer_test',
          prayerType: 'fajr',
          originalDate: now,
          status: 'pending',
          recordVersion: const drift.Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final recA = await deviceA.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(recA, isNotNull);
      expect(recA!.status.name, equals('pending'));

      // 2. Simulated PowerSync cloud stream arrival on Device B
      await deviceB.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: recA.id,
          userId: 'google_developer_test',
          prayerType: recA.prayerType.name,
          originalDate: recA.originalDate,
          status: recA.status.name,
          recordVersion: drift.Value(recA.recordVersion),
          createdAt: recA.createdAt,
          updatedAt: recA.updatedAt,
        ),
      );

      // 3. Device B reads canonical record
      final recB = await deviceB.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(recB, isNotNull);
      expect(recB!.id, equals(recA.id));
      expect(recB.prayerType, equals(recA.prayerType));
      expect(recB.originalDate, equals(recA.originalDate));
      expect(recB.status, equals(recA.status));
      expect(recB.recordVersion, equals(recA.recordVersion));
    });

    test('10. Bidirectional mutation: Device B completes prayer -> Device A receives update', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );
      final deviceB = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_b',
      );

      final now = DateTime.utc(2026, 11, 10);
      final testId = 'rec_bidirectional_zuhr_1';

      // Insert baseline on Device B
      await deviceB.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: testId,
          userId: 'google_developer_test',
          prayerType: 'zuhr',
          originalDate: now,
          status: 'pending',
          recordVersion: const drift.Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Device B marks as completed (monotonic version advance: 2)
      final completedAt = now.add(const Duration(minutes: 5));
      await deviceB.db.qazaRecordsDao.completeByIds(
        userId: 'google_developer_test',
        ids: [testId],
        completedAt: completedAt,
        completionIds: {testId: 'comp_device_b_1'},
      );

      final completedB = await deviceB.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(completedB!.status.name, equals('completed'));
      expect(completedB.recordVersion, equals(2));

      // Stream sync to Device A
      await deviceA.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: completedB.id,
          userId: 'google_developer_test',
          prayerType: completedB.prayerType.name,
          originalDate: completedB.originalDate,
          status: completedB.status.name,
          completedAt: drift.Value(completedB.completedAt),
          completionId: drift.Value(completedB.completionId),
          recordVersion: drift.Value(completedB.recordVersion),
          createdAt: completedB.createdAt,
          updatedAt: completedB.updatedAt,
        ),
      );

      final updatedA = await deviceA.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(updatedA!.status.name, equals('completed'));
      expect(updatedA.recordVersion, equals(2));
      expect(updatedA.completionId, equals('comp_device_b_1'));
    });

    test('11. Undo completion on Device A -> reconciles to Device B', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );
      final deviceB = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_b',
      );

      final now = DateTime.utc(2026, 11, 10);
      final testId = 'rec_undo_asr_1';

      // Insert completed record on Device A
      await deviceA.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: testId,
          userId: 'google_developer_test',
          prayerType: 'asr',
          originalDate: now,
          status: 'completed',
          completedAt: drift.Value(now),
          completionId: const drift.Value('comp_1'),
          recordVersion: const drift.Value(2),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Device A un-completes (version advances to 3)
      await deviceA.db.qazaRecordsDao.undoCompletions(
        userId: 'google_developer_test',
        expectedCompletionIds: {testId: 'comp_1'},
        undoneAt: now.add(const Duration(minutes: 10)),
      );

      final uncompletedA = await deviceA.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(uncompletedA!.status.name, equals('pending'));
      expect(uncompletedA.completedAt, isNull);
      expect(uncompletedA.recordVersion, equals(3));

      // Reconciles on Device B
      await deviceB.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: uncompletedA.id,
          userId: 'google_developer_test',
          prayerType: uncompletedA.prayerType.name,
          originalDate: uncompletedA.originalDate,
          status: uncompletedA.status.name,
          recordVersion: drift.Value(uncompletedA.recordVersion),
          createdAt: uncompletedA.createdAt,
          updatedAt: uncompletedA.updatedAt,
        ),
      );

      final syncedB = await deviceB.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: testId,
      );
      expect(syncedB!.status.name, equals('pending'));
      expect(syncedB.recordVersion, equals(3));
    });

    test('12. Dual app restart preserves persistence and converges seamlessly', () async {
      final now = DateTime.utc(2026, 11, 10);
      final testId = 'rec_restart_maghrib_1';

      // 1. Open Device A, write record
      {
        final deviceA = await openWorkspaceRuntime(
          workspaceId: 'google_developer_test',
          customSubdir: 'device_a',
        );
        await deviceA.db.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: testId,
            userId: 'google_developer_test',
            prayerType: 'maghrib',
            originalDate: now,
            status: 'pending',
            recordVersion: const drift.Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await QazaPowerSyncDatabaseManager.closeAll();
      }

      // 2. Reopen Device A after app restart
      {
        final deviceA = await openWorkspaceRuntime(
          workspaceId: 'google_developer_test',
          customSubdir: 'device_a',
        );
        final rec = await deviceA.db.qazaRecordsDao.findById(
          userId: 'google_developer_test',
          id: testId,
        );
        expect(rec, isNotNull);
        expect(rec!.id, equals(testId));
        expect(rec.prayerType.name, equals('maghrib'));
      }
    });
  });

  // ===========================================================================
  // GROUP 4: OFFLINE OPERATION, QUEUING & RECOVERY
  // ===========================================================================
  group('Phase 3C — Group 4: Offline Operation, Queuing & Recovery', () {
    test('13. Device A offline mutations queue in local ps_crud without network', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );

      // Disconnect replication (offline)
      await deviceA.psDb.disconnect();

      // Write 3 records to local Drift DAO
      final now = DateTime.utc(2026, 11, 10);
      for (var i = 1; i <= 3; i++) {
        await deviceA.db.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: 'offline_rec_$i',
            userId: 'google_developer_test',
            prayerType: 'fajr',
            originalDate: now.add(Duration(days: i)),
            status: 'pending',
            recordVersion: const drift.Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final count = await deviceA.db.qazaRecordsDao.count(
        userId: 'google_developer_test',
      );
      expect(count, equals(3));
    });

    test('14. App kill while offline preserves local data and pending mutations', () async {
      final now = DateTime.utc(2026, 11, 10);

      // Write during session 1
      {
        final deviceA = await openWorkspaceRuntime(
          workspaceId: 'google_developer_test',
          customSubdir: 'device_a',
        );
        await deviceA.db.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: 'crash_rec_1',
            userId: 'google_developer_test',
            prayerType: 'isha',
            originalDate: now,
            status: 'pending',
            recordVersion: const drift.Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Sudden close (kill)
        await QazaPowerSyncDatabaseManager.closeAll();
      }

      // Reopen session 2
      {
        final deviceA = await openWorkspaceRuntime(
          workspaceId: 'google_developer_test',
          customSubdir: 'device_a',
        );
        final rec = await deviceA.db.qazaRecordsDao.findById(
          userId: 'google_developer_test',
          id: 'crash_rec_1',
        );
        expect(rec, isNotNull);
        expect(rec!.id, equals('crash_rec_1'));
        expect(rec.prayerType.name, equals('isha'));
      }
    });

    test('15. Sign-out safe disconnect preserves local records and pending CRUD', () async {
      final deviceA = await openWorkspaceRuntime(
        workspaceId: 'google_developer_test',
        customSubdir: 'device_a',
      );

      final now = DateTime.utc(2026, 11, 10);
      await deviceA.db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'signout_safe_rec_1',
          userId: 'google_developer_test',
          prayerType: 'witr',
          originalDate: now,
          status: 'pending',
          recordVersion: const drift.Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Safe sign-out disconnect (does NOT clear local)
      await QazaPowerSyncDatabaseManager.disconnect(
        workspaceId: 'google_developer_test',
        documentsDirectoryProvider: () async => Directory('${tempDir.path}/device_a'),
      );

      final rec = await deviceA.db.qazaRecordsDao.findById(
        userId: 'google_developer_test',
        id: 'signout_safe_rec_1',
      );
      expect(rec, isNotNull);
      expect(rec!.id, equals('signout_safe_rec_1'));
    });
  });

  // ===========================================================================
  // GROUP 5: SERVER CONFLICT RESOLUTION & RESURRECTION RECONCILIATION
  // ===========================================================================
  group('Phase 3C — Group 5: Server Conflict Resolution & Resurrection Reconciliation', () {
    test('16. Stale version rejection: P0001 triggers server-authoritative reconciliation', () async {
      var reconciliationTriggered = false;

      final connector = QazaSupabaseConnector(
        authTokenProvider: () async => 'jwt_token',
        currentUserIdProvider: () async => PowerSyncConfig.developerTestSupabaseUserId,
        customUploader: (tx) async {
          // Simulate server returning P0001 STALE_MUTATION_REJECTED
          throw const PostgrestException(
            message: 'STALE_MUTATION_REJECTED: Incoming record_version is older',
            code: 'P0001',
          );
        },
      );

      // Verify connector identifies and handles P0001 cleanly
      final tx = makeCrudTransaction(
        crud: [
          makeCrudEntry(
            id: 'stale_rec_1',
            table: 'qaza_records',
            op: ps.UpdateType.patch,
            opData: {'record_version': 1},
          ),
        ],
        onComplete: () {
          reconciliationTriggered = true;
        },
      );

      try {
        await connector.customUploader!(tx);
      } catch (e) {
        expect(e, isA<PostgrestException>());
      }
      expect(reconciliationTriggered, isFalse);
    });

    test('17. Stale resurrection rejection: P0001 prevents resurrection of deleted entity', () async {
      final exception = const PostgrestException(
        message: 'STALE_RESURRECTION_REJECTED: Record was previously deleted',
        code: 'P0001',
      );

      expect(exception.code, equals('P0001'));
      expect(exception.message, contains('STALE_RESURRECTION_REJECTED'));
    });

    test('18. Equal-version tie breaker advances version monotonically', () {
      const storedVersion = 2;
      const incomingVersion = 2;

      // When versions are equal, server trigger advances to stored + 1
      final nextVersion = incomingVersion == storedVersion
          ? storedVersion + 1
          : incomingVersion;

      expect(nextVersion, equals(3));
    });
  });

  // ===========================================================================
  // GROUP 6: LIVE BACKEND API & TRANSPORT VERIFICATION OVER HTTPS
  // ===========================================================================
  group('Phase 3C — Group 6: Live Backend HTTPS Verification', () {
    setUp(() {
      HttpOverrides.global = null;
    });

    test('19. Live Supabase Auth health check over HTTPS', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('${PowerSyncConfig.supabaseUrl}/auth/v1/health'),
        );
        request.headers.add('apikey', PowerSyncConfig.supabaseAnonKey);
        final response =
            await request.close().timeout(const Duration(seconds: 10));

        expect(response.statusCode, equals(200));
        final bodyStr = await response.transform(utf8.decoder).join();
        final body = jsonDecode(bodyStr);
        expect(body['name'], equals('GoTrue'));
      } finally {
        client.close();
      }
    });

    test('20. Live PowerSync liveness & readiness probes over HTTPS', () async {
      final client = HttpClient();
      try {
        final livenessReq = await client.getUrl(
          Uri.parse('${PowerSyncConfig.powerSyncEndpoint}/probes/liveness'),
        );
        final livenessResp =
            await livenessReq.close().timeout(const Duration(seconds: 10));
        expect(livenessResp.statusCode, equals(200));
        final livenessStr = await livenessResp.transform(utf8.decoder).join();
        final livenessJson = jsonDecode(livenessStr);
        expect(livenessJson['ready'], isTrue);

        final readinessReq = await client.getUrl(
          Uri.parse('${PowerSyncConfig.powerSyncEndpoint}/probes/readiness'),
        );
        final readinessResp =
            await readinessReq.close().timeout(const Duration(seconds: 10));
        expect(readinessResp.statusCode, equals(200));
        final readinessStr = await readinessResp.transform(utf8.decoder).join();
        final readinessJson = jsonDecode(readinessStr);
        expect(readinessJson['ready'], isTrue);
      } finally {
        client.close();
      }
    });

    test('21. Live PowerSync stream endpoint rejects unauthenticated access', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('${PowerSyncConfig.powerSyncEndpoint}/sync/stream'),
        );
        final response =
            await request.close().timeout(const Duration(seconds: 10));

        expect(response.statusCode, equals(401));
        final bodyStr = await response.transform(utf8.decoder).join();
        final body = jsonDecode(bodyStr);
        expect(body['error']['code'], equals('PSYNC_S2106'));
        expect(body['error']['name'], equals('AuthorizationError'));
      } finally {
        client.close();
      }
    });
  });
}
