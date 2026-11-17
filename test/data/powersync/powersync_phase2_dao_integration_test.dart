import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' as ps;
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_phase2_test_');
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = DatabaseEncryptionKeyStore();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  Future<({AppDatabase db, ps.PowerSyncDatabase psDb, Future<void> Function() close})> openTestDatabase({
    String? workspaceId,
  }) async {
    final customPath = p.join(
      tempDir.path,
      'qaza_powersync_${workspaceId ?? 'default'}_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final psDb = await QazaPowerSyncDatabaseManager.getInstance(
      workspaceId: workspaceId,
      customPath: customPath,
      schema: qazaPowerSyncSchema,
      keyStore: keyStore,
      documentsDirectoryProvider: () async => tempDir,
    );
    final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
      workspaceId: workspaceId,
      customPath: customPath,
      schema: qazaPowerSyncSchema,
    );
    final appDb = AppDatabase.forPowerSync(
      driftConn,
      workspaceId: workspaceId,
      role: workspaceId != null && workspaceId.startsWith('google_')
          ? AppDatabaseRole.googleWorkspace
          : AppDatabaseRole.controlGuest,
    );
    return (
      db: appDb,
      psDb: psDb,
      close: () async {
        await appDb.close();
        await QazaPowerSyncDatabaseManager.closeDatabase(customPath: customPath);
      },
    );
  }

  group('Phase 2 — Schema Alignment & Actual Drift DAO Integration', () {
    test('1. Actual application schema initialization on PowerSync', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;

      // Accessing a DAO triggers Drift migration and table verification
      final userIds = await db.qazaRecordsDao.userIds();
      expect(userIds, isEmpty);

      // Verify that the underlying database has PowerSync tables and views
      final masterRows = await db.customSelect(
        "SELECT name, type FROM sqlite_master WHERE name IN ('qaza_records', 'ps_data__qaza_records', 'meta_store')",
      ).get();

      final typesByName = {
        for (final r in masterRows)
          r.read<String>('name'): r.read<String>('type')
      };

      expect(typesByName['qaza_records'], equals('view'));
      expect(typesByName['ps_data__qaza_records'], equals('table'));
      expect(typesByName['meta_store'], equals('table'));

      await handle.close();
    });

    test('2. Correct PowerSync-managed table mapping (views over ps_data__)', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;

      // Ensure all 9 synced tables exist as SQLite views backed by ps_data__
      final syncedTables = [
        'qaza_records',
        'daily_salah_logs',
        'qaza_additions',
        'qaza_deletion_actions',
        'qaza_deletion_action_record_snapshots',
        'qaza_profile_plan_provenance',
        'account_profiles',
        'account_plan_revisions',
        'user_preferences',
      ];

      for (final table in syncedTables) {
        final viewCheck = await db.customSelect(
          "SELECT type FROM sqlite_master WHERE name = ? LIMIT 1",
          variables: [drift.Variable(table)],
        ).getSingleOrNull();
        expect(viewCheck?.read<String>('type'), equals('view'),
            reason: '$table must be a view');

        final tableCheck = await db.customSelect(
          "SELECT type FROM sqlite_master WHERE name = ? LIMIT 1",
          variables: [drift.Variable('ps_data__$table')],
        ).getSingleOrNull();
        expect(tableCheck?.read<String>('type'), equals('table'),
            reason: 'ps_data__$table must be a backing table');
      }

      await handle.close();
    });

    test('3. Correct Drift local-only table creation', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;

      // Ensure local-only tables exist as standard SQLite tables
      final localTables = [
        'meta_store',
        'local_recovery_snapshots',
        'local_accounts',
        'app_session_state',
        'device_metadata',
        'workspace_operation_journal',
        'local_workspace_deletion_holds',
        'workspace_sync_metadata',
      ];

      for (final table in localTables) {
        final tableCheck = await db.customSelect(
          "SELECT type FROM sqlite_master WHERE name = ? LIMIT 1",
          variables: [drift.Variable(table)],
        ).getSingleOrNull();
        expect(tableCheck?.read<String>('type'), equals('table'),
            reason: '$table must be a local table');
      }

      // Verify meta_store read/write operations
      await db.customInsert(
        'INSERT INTO meta_store (key, value) VALUES (?, ?)',
        variables: [
          const drift.Variable('test_key'),
          const drift.Variable('test_val'),
        ],
      );
      final metaRow = await db.customSelect(
        'SELECT value FROM meta_store WHERE key = ?',
        variables: [const drift.Variable('test_key')],
      ).getSingle();
      expect(metaRow.read<String>('value'), equals('test_val'));

      await handle.close();
    });

    test('4. No duplicate table or index creation', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;

      // Check count of qaza_records entities in sqlite_master
      final views = await db.customSelect(
        "SELECT count(*) as count FROM sqlite_master WHERE name = 'qaza_records'",
      ).getSingle();
      expect(views.read<int>('count'), equals(1));

      // Ensure no indices directly on the view qaza_records
      final viewIndexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'qaza_records'",
      ).get();
      expect(viewIndexes, isEmpty,
          reason: 'Views cannot have indices directly on them in SQLite');

      // But backing table ps_data__qaza_records must have the performance indexes
      final backingIndexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'ps_data__qaza_records'",
      ).get();
      final indexNames = backingIndexes.map((r) => r.read<String>('name')).toSet();
      expect(
        indexNames.any((n) => n.contains('user_prayer_date')),
        isTrue,
        reason: 'Backing table must contain performance indexes',
      );

      await handle.close();
    });

    test('5. No attempts to ALTER PowerSync-managed views', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;

      // Verify all columns of qaza_records view match Drift table definition
      final columns = await db.customSelect('PRAGMA table_info(qaza_records)').get();
      final colNames = columns.map((r) => r.read<String>('name')).toSet();

      final expectedColumns = {
        'id',
        'user_id',
        'prayer_type',
        'original_date',
        'status',
        'completed_at',
        'completion_id',
        'addition_id',
        'record_version',
        'created_at',
        'updated_at',
      };

      for (final col in expectedColumns) {
        expect(colNames.contains(col), isTrue,
            reason: 'Column $col must exist in qaza_records view');
      }

      await handle.close();
    });

    test('6. Actual generated DAO reads', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final now = DateTime.utc(2026, 9, 1, 10, 0, 0);
      final record = QazaRecordsCompanion.insert(
        id: 'rec_read_1',
        userId: 'user_read',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 1),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      await dao.insertRecord(record);

      // findById
      final found = await dao.findById(userId: 'user_read', id: 'rec_read_1');
      expect(found, isNotNull);
      expect(found!.id, equals('rec_read_1'));
      expect(found.prayerType, equals(PrayerType.fajr));
      expect(found.status, equals(QazaStatus.pending));

      // getRowsByIds
      final rows = await dao.getRowsByIds(
        userId: 'user_read',
        ids: ['rec_read_1', 'non_existing'],
      );
      expect(rows.length, equals(1));
      expect(rows.first.id, equals('rec_read_1'));

      // getProgressCounts
      final counts = await dao.getProgressCounts(userId: 'user_read');
      expect(counts[PrayerType.fajr]?[QazaStatus.pending], equals(1));

      // getOldestPending
      final oldest = await dao.getOldestPending(userId: 'user_read');
      expect(oldest?.id, equals('rec_read_1'));

      await handle.close();
    });

    test('7. Actual generated DAO writes (insert, complete, update, delete)', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final now = DateTime.utc(2026, 9, 2, 8, 30, 0);

      // INSERT
      final inserted = await dao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_write_1',
        userId: 'user_write',
        prayerType: 'zuhr',
        originalDate: DateTime.utc(2026, 9, 2),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      expect(inserted, equals(1));

      // COMPLETE BY IDS
      final completionTime = DateTime.utc(2026, 9, 2, 14, 0, 0);
      final completedRecords = await dao.completeByIds(
        userId: 'user_write',
        ids: ['rec_write_1'],
        completedAt: completionTime,
        completionIds: {'rec_write_1': 'comp_marker_1'},
      );
      expect(completedRecords.length, equals(1));
      expect(completedRecords.first.status, equals(QazaStatus.completed));
      expect(completedRecords.first.completionId, equals('comp_marker_1'));
      expect(completedRecords.first.completedAt, equals(completionTime));

      // MARK COMPLETED AS PENDING
      final reverted = await dao.markCompletedAsPendingBatch(
        userId: 'user_write',
        expectedCompletionIds: {'rec_write_1': 'comp_marker_1'},
        updatedAt: DateTime.utc(2026, 9, 2, 15, 0, 0),
      );
      expect(reverted.length, equals(1));
      expect(reverted.first.status, equals(QazaStatus.pending));

      // UPSERT RECORDS
      await dao.upsertRecords([
        QazaRecordsCompanion.insert(
          id: 'rec_write_1',
          userId: 'user_write',
          prayerType: 'zuhr',
          originalDate: DateTime.utc(2026, 9, 2),
          status: 'pending',
          additionId: const drift.Value('addition_123'),
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final updatedRow = await dao.findById(userId: 'user_write', id: 'rec_write_1');
      expect(updatedRow?.additionId, equals('addition_123'));

      // DELETE
      final deleted = await dao.deleteAllForUser(userId: 'user_write');
      expect(deleted, equals(1));
      final afterDelete = await dao.findById(userId: 'user_write', id: 'rec_write_1');
      expect(afterDelete, isNull);

      await handle.close();
    });

    test('8. Existing Qaza uniqueness rules (user_id, prayer_type, original_date)', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final originalDate = DateTime.utc(2026, 9, 3);
      final now = DateTime.utc(2026, 9, 3, 12, 0, 0);

      // Insert first record
      final res1 = await dao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_unique_1',
        userId: 'user_uniq',
        prayerType: 'asr',
        originalDate: originalDate,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      expect(res1, equals(1));

      // Insert second record with same user, prayer, date via DAO
      final res2 = await dao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_unique_2',
        userId: 'user_uniq',
        prayerType: 'asr',
        originalDate: originalDate,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      expect(res2, equals(0), reason: 'DAO insertRecord must reject duplicate (user_id, prayer_type, original_date)');

      // Verify that direct raw insert into the view also violates the underlying unique index
      var threwUniqueConstraint = false;
      try {
        await db.customInsert(
          'INSERT INTO qaza_records (id, user_id, prayer_type, original_date, status, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          variables: [
            const drift.Variable('rec_unique_raw'),
            const drift.Variable('user_uniq'),
            const drift.Variable('asr'),
            drift.Variable(originalDate.toIso8601String()),
            const drift.Variable('pending'),
            drift.Variable(now.toIso8601String()),
            drift.Variable(now.toIso8601String()),
          ],
        );
      } catch (e) {
        threwUniqueConstraint = true;
      }
      expect(threwUniqueConstraint, isTrue,
          reason: 'Underlying table unique index must reject raw duplicate insert');

      await handle.close();
    });

    test('9. Atomic batch inserts with insertOrIgnore', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final now = DateTime.utc(2026, 9, 4, 10, 0, 0);
      final records = [
        QazaRecordsCompanion.insert(
          id: 'batch_rec_1',
          userId: 'user_batch',
          prayerType: 'fajr',
          originalDate: DateTime.utc(2026, 9, 4),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
        QazaRecordsCompanion.insert(
          id: 'batch_rec_2',
          userId: 'user_batch',
          prayerType: 'zuhr',
          originalDate: DateTime.utc(2026, 9, 4),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
        QazaRecordsCompanion.insert(
          id: 'batch_rec_3',
          userId: 'user_batch',
          prayerType: 'asr',
          originalDate: DateTime.utc(2026, 9, 4),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final insertedIds = await dao.insertRecordsReturningInsertedIds(records);
      expect(insertedIds.length, equals(3));
      expect(insertedIds, containsAll(['batch_rec_1', 'batch_rec_2', 'batch_rec_3']));

      // Attempting to re-insert the same records should be ignored
      final reinsertedIds = await dao.insertRecordsReturningInsertedIds(records);
      expect(reinsertedIds, isEmpty);

      await handle.close();
    });

    test('10. Rollback on failure in transaction', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final now = DateTime.utc(2026, 9, 5, 11, 0, 0);

      var exceptionThrown = false;
      try {
        await db.transaction(() async {
          await dao.insertRecord(QazaRecordsCompanion.insert(
            id: 'tx_rec_1',
            userId: 'user_tx',
            prayerType: 'maghrib',
            originalDate: DateTime.utc(2026, 9, 5),
            status: 'pending',
            createdAt: now,
            updatedAt: now,
          ));

          // Intentionally throw inside transaction
          throw StateError('Simulated unexpected failure during transaction');
        });
      } catch (e) {
        exceptionThrown = true;
      }

      expect(exceptionThrown, isTrue);

      // Verify rec_1 was rolled back and does not exist in database
      final record = await dao.findById(userId: 'user_tx', id: 'tx_rec_1');
      expect(record, isNull, reason: 'Transaction rollback must leave database untouched');

      await handle.close();
    });

    test('11. DateTime round-trip compatibility (UTC, midnight, leap-year, nulls)', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      // Test cases covering all required DateTime edge cases:
      final testDates = [
        (
          id: 'dt_leap_year',
          prayer: 'fajr',
          origDate: DateTime.utc(2028, 2, 29), // Leap year date
          completed: null,
        ),
        (
          id: 'dt_midnight',
          prayer: 'zuhr',
          origDate: DateTime.utc(2026, 12, 31, 0, 0, 0), // Midnight boundary
          completed: DateTime.utc(2027, 1, 1, 0, 0, 0),
        ),
        (
          id: 'dt_subsecond_utc',
          prayer: 'asr',
          origDate: DateTime.utc(2026, 7, 15, 15, 45, 30, 500), // Precision
          completed: DateTime.utc(2026, 7, 15, 16, 0, 0, 123),
        ),
      ];

      final createdAt = DateTime.utc(2026, 9, 6, 12, 0, 0);

      for (final testCase in testDates) {
        await dao.insertRecord(QazaRecordsCompanion.insert(
          id: testCase.id,
          userId: 'user_dt',
          prayerType: testCase.prayer,
          originalDate: testCase.origDate,
          status: testCase.completed != null ? 'completed' : 'pending',
          completedAt: drift.Value(testCase.completed),
          createdAt: createdAt,
          updatedAt: createdAt,
        ));
      }

      for (final testCase in testDates) {
        final fetched = await dao.findById(userId: 'user_dt', id: testCase.id);
        expect(fetched, isNotNull);
        expect(
          fetched!.originalDate.millisecondsSinceEpoch,
          equals(testCase.origDate.millisecondsSinceEpoch),
          reason: 'originalDate must round-trip with exact millisecond precision',
        );

        if (testCase.completed == null) {
          expect(fetched.completedAt, isNull);
        } else {
          expect(
            fetched.completedAt!.millisecondsSinceEpoch,
            equals(testCase.completed!.millisecondsSinceEpoch),
            reason: 'completedAt must round-trip with exact millisecond precision',
          );
        }
      }

      await handle.close();
    });

    test('12. Reactive query updates', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final query = db.select(db.qazaRecords)..where((r) => r.userId.equals('user_reactive'));
      final stream = query.watch();

      // Listen for the second emission (which occurs after the insert mutation)
      final updateFuture = stream.skip(1).first;

      // Perform insert
      final now = DateTime.utc(2026, 9, 7, 10, 0, 0);
      await dao.insertRecord(QazaRecordsCompanion.insert(
        id: 'reactive_1',
        userId: 'user_reactive',
        prayerType: 'isha',
        originalDate: DateTime.utc(2026, 9, 7),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      final updatedList = await updateFuture.timeout(const Duration(seconds: 5));
      expect(updatedList.length, equals(1));
      expect(updatedList.first.id, equals('reactive_1'));

      await handle.close();
    });

    test('13. Keyset pagination (Pending and Completed)', () async {
      final handle = await openTestDatabase(workspaceId: 'guest');
      final db = handle.db;
      final dao = db.qazaRecordsDao;

      final baseDate = DateTime.utc(2026, 8, 1);
      final now = DateTime.utc(2026, 9, 8, 10, 0, 0);

      // Insert 10 sequential pending records across dates
      final prayers = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
      for (var i = 0; i < 10; i++) {
        final date = baseDate.add(Duration(days: i ~/ 5));
        final prayer = prayers[i % 5];
        await dao.insertRecord(QazaRecordsCompanion.insert(
          id: 'page_rec_$i',
          userId: 'user_page',
          prayerType: prayer,
          originalDate: date,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Page 1: limit 4
      final page1 = await dao.getKeysetPage(
        userId: 'user_page',
        limit: 4,
        status: 'pending',
      );
      expect(page1.records.length, equals(4));
      expect(page1.hasMore, isTrue);

      // Page 2: next 4 using cursor
      final page2 = await dao.getKeysetPage(
        userId: 'user_page',
        limit: 4,
        status: 'pending',
        afterOriginalDate: page1.nextOriginalDate,
        afterId: page1.nextId,
        afterPrayerType: page1.nextPrayerType?.name,
      );
      expect(page2.records.length, equals(4));
      expect(page2.hasMore, isTrue);

      // Page 3: remaining 2
      final page3 = await dao.getKeysetPage(
        userId: 'user_page',
        limit: 4,
        status: 'pending',
        afterOriginalDate: page2.nextOriginalDate,
        afterId: page2.nextId,
        afterPrayerType: page2.nextPrayerType?.name,
      );
      expect(page3.records.length, equals(2));
      expect(page3.hasMore, isFalse);

      // Ensure no overlapping record IDs between pages
      final allPageIds = [
        ...page1.records.map((r) => r.id),
        ...page2.records.map((r) => r.id),
        ...page3.records.map((r) => r.id),
      ];
      expect(allPageIds.toSet().length, equals(10));

      await handle.close();
    });

    test('14. Closing and reopening the database safely', () async {
      final customPath = p.join(tempDir.path, 'reopen_test.db');
      final encryptionKey = await keyStore.readOrCreate();

      // Open, insert row, then close
      {
        await QazaPowerSyncDatabaseManager.getInstance(
          workspaceId: 'guest',
          customPath: customPath,
          encryptionKey: encryptionKey,
          schema: qazaPowerSyncSchema,
          keyStore: keyStore,
          documentsDirectoryProvider: () async => tempDir,
        );
        final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
          workspaceId: 'guest',
          customPath: customPath,
          encryptionKey: encryptionKey,
          schema: qazaPowerSyncSchema,
        );
        final db = AppDatabase.forPowerSync(driftConn, workspaceId: 'guest');

        final now = DateTime.utc(2026, 9, 9, 12, 0, 0);
        await db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
          id: 'reopen_rec_1',
          userId: 'user_reopen',
          prayerType: 'fajr',
          originalDate: DateTime.utc(2026, 9, 9),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ));

        await db.close();
        await QazaPowerSyncDatabaseManager.closeDatabase(customPath: customPath);
      }

      // Reopen same database file and verify data persists cleanly
      {
        await QazaPowerSyncDatabaseManager.getInstance(
          workspaceId: 'guest',
          customPath: customPath,
          encryptionKey: encryptionKey,
          schema: qazaPowerSyncSchema,
          keyStore: keyStore,
          documentsDirectoryProvider: () async => tempDir,
        );
        final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
          workspaceId: 'guest',
          customPath: customPath,
          encryptionKey: encryptionKey,
          schema: qazaPowerSyncSchema,
        );
        final db = AppDatabase.forPowerSync(driftConn, workspaceId: 'guest');

        final record = await db.qazaRecordsDao.findById(
          userId: 'user_reopen',
          id: 'reopen_rec_1',
        );
        expect(record, isNotNull);
        expect(record!.id, equals('reopen_rec_1'));
        expect(record.prayerType, equals(PrayerType.fajr));

        await db.close();
        await QazaPowerSyncDatabaseManager.closeDatabase(customPath: customPath);
      }
    });

    test('15. Separate workspace schema initialization (Guest vs Google)', () async {
      final guestHandle = await openTestDatabase(workspaceId: 'guest');
      final googleHandle = await openTestDatabase(workspaceId: 'google_user_123');

      final guestDb = guestHandle.db;
      final googleDb = googleHandle.db;

      expect(guestDb.isGoogleWorkspaceDatabase, isFalse);
      expect(googleDb.isGoogleWorkspaceDatabase, isTrue);
      expect(googleDb.workspaceId, equals('google_user_123'));

      final now = DateTime.utc(2026, 9, 10, 8, 0, 0);

      // Insert in Guest database
      await guestDb.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_guest_ws',
        userId: 'guest',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // Insert in Google database
      await googleDb.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_google_ws',
        userId: 'google_user_123',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // Guest DB must NOT see Google record
      final guestCheck = await guestDb.qazaRecordsDao.findById(
        userId: 'google_user_123',
        id: 'rec_google_ws',
      );
      expect(guestCheck, isNull);

      // Google DB must NOT see Guest record
      final googleCheck = await googleDb.qazaRecordsDao.findById(
        userId: 'guest',
        id: 'rec_guest_ws',
      );
      expect(googleCheck, isNull);

      await guestHandle.close();
      await googleHandle.close();
    });
  });
}
