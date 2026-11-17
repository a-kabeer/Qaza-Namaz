import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' as ps;
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/powersync/legacy_drift_to_powersync_migrator.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/data/powersync/powersync_schema.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseEncryptionKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_phase3a_test_');
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
    final customPath = p.join(
      tempDir.path,
      'qaza_powersync_${workspaceId}_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final encryptionKey = await keyStore.readOrCreate();
    final psDb = await QazaPowerSyncDatabaseManager.getInstance(
      workspaceId: workspaceId,
      customPath: customPath,
      encryptionKey: encryptionKey,
      schema: qazaPowerSyncSchema,
      keyStore: keyStore,
      documentsDirectoryProvider: () async => tempDir,
    );
    final driftConn = await DatabaseManager.createPowerSyncDriftConnection(
      workspaceId: workspaceId,
      customPath: customPath,
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
      dbPath: customPath,
      encryptionKey: encryptionKey,
    );
  }

  group('Phase 3A — PowerSync Local Runtime Cutover Integration Tests', () {
    test('1. Actual application provider routing (PowerSync Drift connection)',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(guest.db),
          activeUserIdProvider.overrideWith((ref) => 'guest'),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(appDatabaseProvider);
      expect(db.isPowerSync, isTrue);

      final activeDb = container.read(activeWorkspaceDatabaseProvider);
      expect(activeDb.isPowerSync, isTrue);

      final localStore = container.read(qazaLocalStoreProvider);
      expect(localStore, isA<DriftQazaLocalStore>());

      final repo = container.read(qazaRepositoryProvider);
      expect(repo, isA<OfflineFirstQazaRepository>());

      await guest.db.close();
    });

    test('2. Guest workspace local persistence without cloud connectivity',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final now = DateTime.utc(2026, 9, 10, 10, 0, 0);
      final rec = QazaRecordsCompanion.insert(
        id: 'guest_local_1',
        userId: 'guest_user',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      final inserted = await guest.db.qazaRecordsDao.insertRecord(rec);
      expect(inserted, equals(1));

      final fetched = await guest.db.qazaRecordsDao.findById(
        userId: 'guest_user',
        id: 'guest_local_1',
      );
      expect(fetched, isNotNull);
      expect(fetched!.prayerType, equals(PrayerType.fajr));
      expect(fetched.status, equals(QazaStatus.pending));

      // Guest database has no PowerSync connection established
      expect(guest.psDb.connected, isFalse);

      await guest.db.close();
    });

    test('3. Google workspace local persistence in dedicated file', () async {
      final googleA =
          await openWorkspacePowerSync(workspaceId: 'google_account_1');

      final now = DateTime.utc(2026, 9, 10, 11, 0, 0);
      final rec = QazaRecordsCompanion.insert(
        id: 'google_local_1',
        userId: 'google_account_1',
        prayerType: 'zuhr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      final inserted = await googleA.db.qazaRecordsDao.insertRecord(rec);
      expect(inserted, equals(1));

      final fetched = await googleA.db.qazaRecordsDao.findById(
        userId: 'google_account_1',
        id: 'google_local_1',
      );
      expect(fetched, isNotNull);
      expect(fetched!.userId, equals('google_account_1'));
      expect(fetched.prayerType, equals(PrayerType.zuhr));

      expect(googleA.psDb.connected, isFalse);

      await googleA.db.close();
    });

    test('4. Workspace switching (Guest -> Google A -> Google B -> Guest)',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');
      final googleA =
          await openWorkspacePowerSync(workspaceId: 'google_user_alpha');
      final googleB =
          await openWorkspacePowerSync(workspaceId: 'google_user_beta');

      // Populate unique record in each workspace
      final now = DateTime.utc(2026, 9, 10, 12, 0, 0);
      await guest.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_guest',
        userId: 'guest',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      await googleA.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_google_a',
        userId: 'google_user_alpha',
        prayerType: 'asr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      await googleB.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'rec_google_b',
        userId: 'google_user_beta',
        prayerType: 'isha',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));

      // Verify each workspace contains ONLY its own record
      final guestRecords =
          await (guest.db.select(guest.db.qazaRecords)).get();
      expect(guestRecords.length, equals(1));
      expect(guestRecords.first.id, equals('rec_guest'));

      final aRecords = await (googleA.db.select(googleA.db.qazaRecords)).get();
      expect(aRecords.length, equals(1));
      expect(aRecords.first.id, equals('rec_google_a'));

      final bRecords = await (googleB.db.select(googleB.db.qazaRecords)).get();
      expect(bRecords.length, equals(1));
      expect(bRecords.first.id, equals('rec_google_b'));

      await guest.db.close();
      await googleA.db.close();
      await googleB.db.close();
    });

    test('5. Account preference isolation (P1-02 verification)', () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final activeUserNotifier = ValueNotifier<String?>('guest');
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(guest.db),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      // Guest sets sticky Prayer Selection mode with Zuhr
      final guestNotifier =
          container.read(homePrayerSelectionProvider.notifier);
      guestNotifier.selectPrayer(PrayerType.zuhr);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final guestState = container.read(homePrayerSelectionProvider);
      expect(guestState.mode, equals(HomePrayerSelectionMode.prayerSelection));
      expect(guestState.selectedPrayer, equals(PrayerType.zuhr));

      // Switch to Google Account A
      activeUserNotifier.value = 'google_user_a';
      container.invalidate(activeUserIdProvider);
      container.invalidate(homePrayerSelectionProvider);

      // Google Account A should default cleanly to autoSequence / Fajr, NOT inherit Guest's Zuhr!
      final googleAState = container.read(homePrayerSelectionProvider);
      expect(googleAState.mode, equals(HomePrayerSelectionMode.autoSequence));
      expect(googleAState.selectedPrayer, isNull);

      // Google Account A sets sticky mode with Asr
      final googleANotifier =
          container.read(homePrayerSelectionProvider.notifier);
      googleANotifier.selectPrayer(PrayerType.asr);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(homePrayerSelectionProvider).selectedPrayer,
          equals(PrayerType.asr));

      // Switch to Google Account B
      activeUserNotifier.value = 'google_user_b';
      container.invalidate(activeUserIdProvider);
      container.invalidate(homePrayerSelectionProvider);

      // Google Account B should default cleanly to autoSequence, NOT inherit Account A's Asr or Guest's Zuhr!
      final googleBState = container.read(homePrayerSelectionProvider);
      expect(googleBState.mode, equals(HomePrayerSelectionMode.autoSequence));
      expect(googleBState.selectedPrayer, isNull);

      // Switch back to Guest
      activeUserNotifier.value = 'guest';
      container.invalidate(activeUserIdProvider);
      container.invalidate(homePrayerSelectionProvider);

      // Trigger build and await asynchronous restore from meta_store
      container.read(homePrayerSelectionProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final restoredGuestState = container.read(homePrayerSelectionProvider);
      expect(restoredGuestState.mode,
          equals(HomePrayerSelectionMode.prayerSelection));
      expect(restoredGuestState.selectedPrayer, equals(PrayerType.zuhr));

      await guest.db.close();
    });

    test('6. Local database migration (legacy Drift -> PowerSync)', () async {
      // Create a legacy encrypted Drift SQLite database file
      final legacyPath = p.join(tempDir.path, 'qaza_namaz.sqlite');
      final legacyKey = 'test_key_123';
      final legacyDb = AppDatabase(
        NativeDatabase.createInBackground(
          File(legacyPath),
          setup: (rawDb) {
            rawDb.execute("PRAGMA key = '$legacyKey';");
            rawDb.select('SELECT count(*) FROM sqlite_master;');
          },
        ),
      );

      // Populate legacy database
      final now = DateTime.utc(2026, 9, 8, 9, 0, 0);
      await legacyDb.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'legacy_rec_1',
        userId: 'guest',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 8),
        status: 'completed',
        completedAt: drift.Value(now),
        createdAt: now,
        updatedAt: now,
      ));
      await legacyDb.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'legacy_rec_2',
        userId: 'guest',
        prayerType: 'maghrib',
        originalDate: DateTime.utc(2026, 9, 8),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      await legacyDb.close();

      // Open target PowerSync database
      final target = await openWorkspacePowerSync(workspaceId: 'guest');

      // Run migrator
      final migrator = LegacyDriftToPowerSyncMigrator(
        documentsDirectoryProvider: () async => tempDir,
        keyStore: keyStore,
      );

      final result = await migrator.migrateIfNeeded(
        workspaceId: 'guest',
        targetPowerSyncDb: target.db,
        customLegacyFilePath: legacyPath,
        legacyEncryptionKey: legacyKey,
      );

      expect(result.status, equals(LegacyMigrationStatus.migrated));
      expect(result.recordsMigrated, equals(2));

      // Verify records in PowerSync database
      final targetRows =
          await (target.db.select(target.db.qazaRecords)).get();
      expect(targetRows.length, equals(2));

      final rec1 = targetRows.firstWhere((r) => r.id == 'legacy_rec_1');
      expect(rec1.prayerType, equals('fajr'));
      expect(rec1.status, equals('completed'));
      expect(rec1.completedAt, equals(now));

      final rec2 = targetRows.firstWhere((r) => r.id == 'legacy_rec_2');
      expect(rec2.prayerType, equals('maghrib'));
      expect(rec2.status, equals('pending'));

      // Verify legacy file was NOT deleted
      expect(File(legacyPath).existsSync(), isTrue);

      await target.db.close();
    });

    test('7. Migration interruption and recovery (idempotent)', () async {
      final legacyPath = p.join(tempDir.path, 'qaza_namaz.sqlite');
      final legacyKey = 'test_key_resumable';
      final legacyDb = AppDatabase(
        NativeDatabase.createInBackground(
          File(legacyPath),
          setup: (rawDb) {
            rawDb.execute("PRAGMA key = '$legacyKey';");
            rawDb.select('SELECT count(*) FROM sqlite_master;');
          },
        ),
      );

      final now = DateTime.utc(2026, 9, 8, 9, 0, 0);
      await legacyDb.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'resumable_1',
        userId: 'guest',
        prayerType: 'fajr',
        originalDate: DateTime.utc(2026, 9, 8),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ));
      await legacyDb.close();

      final target = await openWorkspacePowerSync(workspaceId: 'guest');

      final migrator = LegacyDriftToPowerSyncMigrator(
        documentsDirectoryProvider: () async => tempDir,
        keyStore: keyStore,
      );

      // Run migration first time
      final result1 = await migrator.migrateIfNeeded(
        workspaceId: 'guest',
        targetPowerSyncDb: target.db,
        customLegacyFilePath: legacyPath,
        legacyEncryptionKey: legacyKey,
      );
      expect(result1.status, equals(LegacyMigrationStatus.migrated));

      // Run migration second time (resuming / re-executing)
      final result2 = await migrator.migrateIfNeeded(
        workspaceId: 'guest',
        targetPowerSyncDb: target.db,
        customLegacyFilePath: legacyPath,
        legacyEncryptionKey: legacyKey,
      );
      expect(result2.status, equals(LegacyMigrationStatus.alreadyMigrated));

      // Target database must still have exactly 1 record without duplicates
      final targetRows =
          await (target.db.select(target.db.qazaRecords)).get();
      expect(targetRows.length, equals(1));

      await target.db.close();
    });

    test('8. Qaza insertion and completion via DAO', () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final now = DateTime.utc(2026, 9, 10, 14, 0, 0);
      final rec = QazaRecordsCompanion.insert(
        id: 'complete_test_1',
        userId: 'user_complete',
        prayerType: 'asr',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      await guest.db.qazaRecordsDao.insertRecord(rec);

      final completedNow = DateTime.utc(2026, 9, 10, 15, 30, 0);
      final completed = await guest.db.qazaRecordsDao.completeByIds(
        userId: 'user_complete',
        ids: ['complete_test_1'],
        completedAt: completedNow,
        completionIds: {'complete_test_1': 'completion_marker_1'},
      );

      expect(completed.length, equals(1));
      expect(completed.first.status, equals(QazaStatus.completed));
      expect(completed.first.completedAt, equals(completedNow));

      final updated = await guest.db.qazaRecordsDao.findById(
        userId: 'user_complete',
        id: 'complete_test_1',
      );
      expect(updated!.status, equals(QazaStatus.completed));

      await guest.db.close();
    });

    test('9. Undo and deletion via DAO', () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final now = DateTime.utc(2026, 9, 10, 16, 0, 0);
      await guest.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'undo_test_1',
        userId: 'user_undo',
        prayerType: 'maghrib',
        originalDate: DateTime.utc(2026, 9, 10),
        status: 'completed',
        completedAt: drift.Value(now),
        completionId: const drift.Value('comp_123'),
        createdAt: now,
        updatedAt: now,
      ));

      // Mark completed as pending (Undo)
      final restored =
          await guest.db.qazaRecordsDao.markCompletedAsPendingBatch(
        userId: 'user_undo',
        expectedCompletionIds: {'undo_test_1': 'comp_123'},
        updatedAt: now,
      );
      expect(restored.length, equals(1));

      final recordAfterUndo = await guest.db.qazaRecordsDao.findById(
        userId: 'user_undo',
        id: 'undo_test_1',
      );
      expect(recordAfterUndo!.status, equals(QazaStatus.pending));
      expect(recordAfterUndo.completedAt, isNull);

      // Delete by ID
      final deleted = await guest.db.qazaRecordsDao.deleteById(
        userId: 'user_undo',
        id: 'undo_test_1',
      );
      expect(deleted, equals(1));

      final afterDelete = await guest.db.qazaRecordsDao.findById(
        userId: 'user_undo',
        id: 'undo_test_1',
      );
      expect(afterDelete, isNull);

      await guest.db.close();
    });

    test('10. Daily Salah tracking persistence over PowerSync database',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(guest.db),
          activeUserIdProvider.overrideWith((ref) => 'guest_daily_user'),
        ],
      );
      addTearDown(container.dispose);

      final dailyService = container.read(dailySalahTrackingServiceProvider);
      expect(dailyService, isNotNull);

      // Insert daily salah log directly
      await guest.db.customInsert(
        '''INSERT INTO daily_salah_logs
           (id, user_id, prayer_date, prayer_type, status, updated_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        variables: [
          drift.Variable.withString('daily_log_1'),
          drift.Variable.withString('guest_daily_user'),
          drift.Variable.withString('2026-09-10'),
          drift.Variable.withString('fajr'),
          drift.Variable.withString('prayed'),
          drift.Variable.withString(DateTime.now().toUtc().toIso8601String()),
        ],
      );

      final rows = await guest.db.customSelect(
        "SELECT * FROM daily_salah_logs WHERE user_id = 'guest_daily_user'",
      ).get();
      expect(rows.length, equals(1));
      expect(rows.first.read<String>('prayer_type'), equals('fajr'));
      expect(rows.first.read<String>('status'), equals('prayed'));

      await guest.db.close();
    });

    test('11. Analytics correctness over PowerSync database', () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final now = DateTime.utc(2026, 9, 10, 18, 0, 0);
      final userId = 'analytics_user';

      // Insert 3 completed, 2 pending
      for (var i = 1; i <= 3; i++) {
        await guest.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
          id: 'analytics_c_$i',
          userId: userId,
          prayerType: 'fajr',
          originalDate: DateTime.utc(2026, 9, i),
          status: 'completed',
          completedAt: drift.Value(now),
          completionId: drift.Value('marker_$i'),
          createdAt: now,
          updatedAt: now,
        ));
      }
      for (var i = 4; i <= 5; i++) {
        await guest.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
          id: 'analytics_p_$i',
          userId: userId,
          prayerType: 'fajr',
          originalDate: DateTime.utc(2026, 9, i),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ));
      }

      final counts = await guest.db.qazaRecordsDao.getProgressCounts(
        userId: userId,
      );
      expect(counts[PrayerType.fajr]?[QazaStatus.pending], equals(2));
      expect(counts[PrayerType.fajr]?[QazaStatus.completed], equals(3));

      await guest.db.close();
    });

    test('12. Calendar and DateTime correctness (leap year, midnight, UTC)',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final leapDay = DateTime.utc(2028, 2, 29, 0, 0, 0);
      final createdAt = DateTime.utc(2028, 2, 29, 12, 34, 56, 789);

      await guest.db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
        id: 'leap_rec',
        userId: 'calendar_user',
        prayerType: 'fajr',
        originalDate: leapDay,
        status: 'pending',
        createdAt: createdAt,
        updatedAt: createdAt,
      ));

      final fetched = await guest.db.qazaRecordsDao.findById(
        userId: 'calendar_user',
        id: 'leap_rec',
      );
      expect(fetched!.originalDate, equals(leapDay));
      expect(fetched.createdAt.millisecondsSinceEpoch,
          equals(createdAt.millisecondsSinceEpoch));

      // Range query
      final rangeRows = await (guest.db.select(guest.db.qazaRecords)
            ..where((r) =>
                r.userId.equals('calendar_user') &
                r.originalDate.isBiggerOrEqualValue(DateTime.utc(2028, 1, 1))))
          .get();
      expect(rangeRows.length, equals(1));
      expect(rangeRows.first.id, equals('leap_rec'));

      await guest.db.close();
    });

    test('13. App restart & database reopening', () async {
      final customPath = p.join(tempDir.path, 'restart_test.db');
      final encryptionKey = await keyStore.readOrCreate();

      // Session 1: open, write, close
      {
        final psDb = await QazaPowerSyncDatabaseManager.getInstance(
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

        final now = DateTime.utc(2026, 9, 10, 20, 0, 0);
        await db.qazaRecordsDao.insertRecord(QazaRecordsCompanion.insert(
          id: 'restart_rec_1',
          userId: 'user_restart',
          prayerType: 'isha',
          originalDate: DateTime.utc(2026, 9, 10),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ));

        await db.close();
        await psDb.close();
        await QazaPowerSyncDatabaseManager.closeDatabase(customPath: customPath);
      }

      // Session 2: reopen same file, verify data persists
      {
        final psDb = await QazaPowerSyncDatabaseManager.getInstance(
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

        final row = await db.qazaRecordsDao.findById(
          userId: 'user_restart',
          id: 'restart_rec_1',
        );
        expect(row, isNotNull);
        expect(row!.prayerType, equals(PrayerType.isha));
        expect(row.status, equals(QazaStatus.pending));

        await db.close();
        await psDb.close();
        await QazaPowerSyncDatabaseManager.closeDatabase(customPath: customPath);
      }
    });

    test('14. Connection disposal on workspace close', () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');
      expect(guest.psDb.database.closed, isFalse);

      await guest.db.close();
      await QazaPowerSyncDatabaseManager.closeAll();

      expect(guest.psDb.database.closed, isTrue);
    });

    test('15. Offline application functionality (zero network calls)',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');

      final store = DriftQazaLocalStore(database: guest.db);
      final repo = OfflineFirstQazaRepository(localStore: store);
      await repo.setActiveUser('offline_user');

      final now = DateTime.utc(2026, 9, 10, 21, 0, 0);
      final records = [
        QazaRecord(
          id: 'offline_rec_1',
          userId: 'offline_user',
          prayerType: PrayerType.fajr,
          originalDate: DateTime.utc(2026, 9, 10),
          status: QazaStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await repo.addRecords(records);

      final fetchedList = await repo.getRecords(
        userId: 'offline_user',
      );
      expect(fetchedList.length, equals(1));
      expect(fetchedList.first.id, equals('offline_rec_1'));

      await guest.db.close();
    });

    test('16. No accidental Supabase connectivity during Phase 3A',
        () async {
      final guest = await openWorkspacePowerSync(workspaceId: 'guest');
      final google =
          await openWorkspacePowerSync(workspaceId: 'google_offline_check');

      // Verify neither database called connect()
      expect(guest.psDb.connected, isFalse);
      expect(google.psDb.connected, isFalse);

      // Verify sync status reports disconnected
      expect(guest.psDb.currentStatus.connected, isFalse);
      expect(google.psDb.currentStatus.connected, isFalse);

      await guest.db.close();
      await google.db.close();
    });
  });
}
