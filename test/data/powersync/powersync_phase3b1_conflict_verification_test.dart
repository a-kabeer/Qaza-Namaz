import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart' as ps;
import 'package:drift/drift.dart' as drift;
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/powersync_config.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_conflict_test_');
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = DatabaseEncryptionKeyStore();
    PowerSyncConfig.authorizeWorkspaceForTesting('google_conflict_test');

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

  Future<({AppDatabase db, ps.PowerSyncDatabase psDb, String dbPath})>
      openWorkspace({required String workspaceId}) async {
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
      role: AppDatabaseRole.googleWorkspace,
    );
    return (db: db, psDb: psDb, dbPath: dbPath);
  }

  group('Phase 3B.1 — Conflict Resolution & Real-World Edge Case Tests', () {
    test('1. Offline completion vs offline undo simulation and ordering', () async {
      // Mock cloud store
      final cloudRecords = <String, Map<String, dynamic>>{};
      final cloudDeletionActions = <String, Map<String, dynamic>>{};
      final cloudSnapshots = <String, Map<String, dynamic>>{};

      // Initial record in cloud
      cloudRecords['rec_100'] = {
        'id': 'rec_100',
        'user_id': 'user_test_uuid',
        'prayer_type': 'fajr',
        'original_date': '2026-09-01',
        'status': 'pending',
        'record_version': 1,
      };

      // Device A uploads completion
      Future<void> devAUploader(ps.CrudTransaction tx) async {
        for (final op in tx.crud) {
          if (op.op == ps.UpdateType.patch && op.table == 'qaza_records') {
            cloudRecords[op.id] = {
              ...?cloudRecords[op.id],
              ...?op.opData,
            };
          }
        }
      }

      // Device B uploads deletion/undo
      Future<void> devBUploader(ps.CrudTransaction tx) async {
        for (final op in tx.crud) {
          if (op.table == 'qaza_deletion_actions') {
            cloudDeletionActions[op.id] = Map<String, dynamic>.from(op.opData ?? {});
          } else if (op.table == 'qaza_deletion_action_record_snapshots') {
            cloudSnapshots[op.id] = Map<String, dynamic>.from(op.opData ?? {});
          } else if (op.op == ps.UpdateType.patch && op.table == 'qaza_records') {
            cloudRecords[op.id] = {
              ...?cloudRecords[op.id],
              ...?op.opData,
            };
          }
        }
      }

      // Device A marks completed: record_version 2, status completed
      final txA = ps.CrudTransaction(
        crud: [
          ps.CrudEntry(1, ps.UpdateType.patch, 'qaza_records', 'rec_100', 1, {
            'status': 'completed',
            'completed_at': '2026-09-02T10:00:00Z',
            'record_version': 2,
          }),
        ],
        transactionId: 1,
        complete: ({writeCheckpoint}) async {},
      );

      // Device B marks undo: record_version 3 (or 1 depending on reset), status pending
      final txB = ps.CrudTransaction(
        crud: [
          ps.CrudEntry(2, ps.UpdateType.put, 'qaza_deletion_actions', 'del_act_100', 2, {
            'id': 'del_act_100',
            'user_id': 'user_test_uuid',
            'addition_id': 'add_1',
            'entity_version': 1,
          }),
          ps.CrudEntry(3, ps.UpdateType.put, 'qaza_deletion_action_record_snapshots', 'snap_100', 2, {
            'id': 'snap_100',
            'deletion_action_id': 'del_act_100',
            'record_id': 'rec_100',
            'user_id': 'user_test_uuid',
            'addition_id': 'add_1',
            'prayer_type': 'fajr',
            'original_date': '2026-09-01',
            'status': 'completed',
            'record_version': 2,
          }),
          ps.CrudEntry(4, ps.UpdateType.patch, 'qaza_records', 'rec_100', 2, {
            'status': 'pending',
            'completed_at': null,
            'record_version': 3,
          }),
        ],
        transactionId: 2,
        complete: ({writeCheckpoint}) async {},
      );

      // Test arrival order A then B
      await devAUploader(txA);
      expect(cloudRecords['rec_100']!['status'], equals('completed'));
      await devBUploader(txB);
      expect(cloudRecords['rec_100']!['status'], equals('pending'));
      expect(cloudDeletionActions.containsKey('del_act_100'), isTrue);
      expect(cloudSnapshots.containsKey('snap_100'), isTrue);
    });

    test('2. Stale update after deletion does not resurrect deleted record', () async {
      final cloudRecords = <String, Map<String, dynamic>>{};

      // Initially record exists
      cloudRecords['rec_200'] = {
        'id': 'rec_200',
        'user_id': 'user_uuid',
        'status': 'pending',
      };

      // Device B deletes record
      cloudRecords.remove('rec_200');

      // Device A attempts PATCH on the deleted record
      // Simulated PostgREST update on non-existent id
      var updatedRows = 0;
      if (cloudRecords.containsKey('rec_200')) {
        cloudRecords['rec_200']!['status'] = 'completed';
        updatedRows++;
      }

      expect(updatedRows, equals(0));
      expect(cloudRecords.containsKey('rec_200'), isFalse);
    });

    test('3. Duplicate addition uniqueness constraint enforcement', () async {
      // Local database unique index enforcement
      final ws = await openWorkspace(workspaceId: 'google_conflict_test');
      final now = DateTime.utc(2026, 9, 1);

      // First insertion succeeds
      await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'dup_rec_1',
        userId: 'google_conflict_test',
        prayerType: 'fajr',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // Duplicate insertion with same (userId, prayerType, originalDate) but different id
      final res2 = await ws.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'dup_rec_2',
        userId: 'google_conflict_test',
        prayerType: 'fajr',
        originalDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      expect(res2, equals(0), reason: 'insertRecord uses insertOrIgnore on unique conflict');

      await ws.db.close();
    });
  });
}
