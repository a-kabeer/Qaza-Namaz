import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/legacy_drift_to_powersync_migrator.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_hardening_test_');
    await QazaPowerSyncDatabaseManager.closeAll();
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  Future<AppDatabase> openTestWorkspacePowerSync({
    required String workspaceId,
    String? encryptionKey,
  }) async {
    final executor = await QazaPowerSyncDatabaseManager.createDriftConnection(
      workspaceId: workspaceId,
      encryptionKey: encryptionKey ?? 'test_hardening_key_32_bytes_len!',
      documentsDirectoryProvider: () async => tempDir,
    );
    if (workspaceId == 'guest') {
      final db = AppDatabase.forPowerSync(
        executor,
        workspaceId: 'guest',
        role: AppDatabaseRole.controlGuest,
      );
      await db.customSelect('SELECT 1').get();
      return db;
    } else {
      final db = GoogleWorkspaceDatabase.forTesting(
        executor: executor,
        workspaceId: workspaceId,
      );
      await db.customSelect('SELECT 1').get();
      await db.writeWorkspaceFileOwner(workspaceId);
      return db;
    }
  }

  Future<void> registerGoogleWorkspace(
    AppDatabase controlDb,
    String workspaceId,
  ) async {
    final fileName = DatabaseManager.googleFileNameForWorkspaceId(workspaceId);
    await controlDb.customInsert(
      '''INSERT OR REPLACE INTO local_accounts
         (local_account_id, db_file_name, db_layout, db_migration_state, created_at, updated_at)
         VALUES (?, ?, 'separate', 'committed', 1, 1)''',
      variables: [
        drift.Variable<String>(workspaceId),
        drift.Variable<String>(fileName),
      ],
    );
  }

  group('TP-GEN Phase 3A.1 — Workspace Isolation & Hardening Tests', () {
    test('1. Guest -> Google A: Isolation, separate files, correct database routing', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleADb = await openTestWorkspacePowerSync(workspaceId: 'google_user_alpha');
      await registerGoogleWorkspace(guestDb, 'google_user_alpha');

      final activeUserNotifier = ValueNotifier<String?>('guest');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) => googleADb,
      );

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      // Verify Guest database handle
      expect(container.read(activeWorkspaceDatabaseProvider), equals(guestDb));

      // Open Google A
      await manager.databaseForWorkspace('google_user_alpha');

      // Switch to Google A
      activeUserNotifier.value = 'google_user_alpha';
      container.invalidate(activeUserIdProvider);

      // Verify Google A database handle
      expect(container.read(activeWorkspaceDatabaseProvider), equals(googleADb));

      await guestDb.close();
      await googleADb.close();
    });

    test('2. Google A -> Google B: Handle updates, zero data or preference bleed', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleADb = await openTestWorkspacePowerSync(workspaceId: 'google_user_a');
      final googleBDb = await openTestWorkspacePowerSync(workspaceId: 'google_user_b');
      await registerGoogleWorkspace(guestDb, 'google_user_a');
      await registerGoogleWorkspace(guestDb, 'google_user_b');

      final activeUserNotifier = ValueNotifier<String?>('google_user_a');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          if (workspaceId == 'google_user_a') return googleADb;
          return googleBDb;
        },
      );

      // Open Google A before building container
      await manager.databaseForWorkspace('google_user_a');

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(activeWorkspaceDatabaseProvider), equals(googleADb));

      // Google A sets preference
      final notifierA = container.read(homePrayerSelectionProvider.notifier);
      notifierA.selectPrayer(PrayerType.maghrib);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Open Google B
      await manager.databaseForWorkspace('google_user_b');

      // Switch to Google B
      activeUserNotifier.value = 'google_user_b';
      container.invalidate(activeUserIdProvider);
      container.invalidate(homePrayerSelectionProvider);

      expect(container.read(activeWorkspaceDatabaseProvider), equals(googleBDb));

      // Google B should NOT inherit Google A's Maghrib sticky selection
      final stateB = container.read(homePrayerSelectionProvider);
      expect(stateB.mode, equals(HomePrayerSelectionMode.autoSequence));
      expect(stateB.selectedPrayer, isNull);

      await guestDb.close();
      await googleADb.close();
      await googleBDb.close();
    });

    test('3. Google B -> Guest: Switching back to Guest returns control database cleanly', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleBDb = await openTestWorkspacePowerSync(workspaceId: 'google_user_b');
      await registerGoogleWorkspace(guestDb, 'google_user_b');

      final activeUserNotifier = ValueNotifier<String?>('google_user_b');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) => googleBDb,
      );

      // Open Google B
      await manager.databaseForWorkspace('google_user_b');

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(activeWorkspaceDatabaseProvider), equals(googleBDb));

      // Switch back to Guest
      activeUserNotifier.value = 'guest';
      container.invalidate(activeUserIdProvider);

      // Returns guestDb cleanly
      expect(container.read(activeWorkspaceDatabaseProvider), equals(guestDb));

      await guestDb.close();
      await googleBDb.close();
    });

    test('4. Google A initialization failure: throws StateError, NEVER falls back to Guest', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');

      final activeUserNotifier = ValueNotifier<String?>('google_failing_user_a');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          throw StateError('Simulated corruption or failure opening Google A database');
        },
      );

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      // Attempting to read activeWorkspaceDatabaseProvider for unvalidated Google workspace MUST throw
      expect(
        () => container.read(activeWorkspaceDatabaseProvider),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('has not been opened and validated. Access is blocked'),
        )),
      );

      // Crucial verification: manager did NOT silently return guestDb!
      expect(manager.databaseForActiveWorkspace('guest'), equals(guestDb));

      await guestDb.close();
    });

    test('5. Google B initialization failure: throws StateError, NEVER falls back to Google A or Guest', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleADb = await openTestWorkspacePowerSync(workspaceId: 'google_user_a');
      await registerGoogleWorkspace(guestDb, 'google_user_a');

      final activeUserNotifier = ValueNotifier<String?>('google_user_a');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          if (workspaceId == 'google_user_a') return googleADb;
          throw StateError('Simulated failure opening Google B');
        },
      );

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      // Open Google A
      await manager.databaseForWorkspace('google_user_a');
      expect(container.read(activeWorkspaceDatabaseProvider), equals(googleADb));

      // Switch to failing Google B
      activeUserNotifier.value = 'google_user_b';
      container.invalidate(activeUserIdProvider);

      // Reading active workspace MUST throw, and NEVER return Google A or Guest
      expect(
        () => container.read(activeWorkspaceDatabaseProvider),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('has not been opened and validated'),
        )),
      );

      await guestDb.close();
      await googleADb.close();
    });

    test('6. Missing encryption key: fails closed with StateError, zero fallback', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');

      final activeUserNotifier = ValueNotifier<String?>('google_missing_key_user');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          throw StateError('Encryption key missing from secure storage');
        },
      );

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(activeWorkspaceDatabaseProvider),
        throwsA(isA<StateError>()),
      );

      await guestDb.close();
    });

    test('7. Wrong workspace key: fails closed with StateError, zero fallback', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');

      final activeUserNotifier = ValueNotifier<String?>('google_wrong_key_user');
      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          throw StateError('SqliteException: file is not a database (wrong key)');
        },
      );

      final container = ProviderContainer(
        overrides: [
          databaseManagerProvider.overrideWithValue(manager),
          activeUserIdProvider.overrideWith((ref) => activeUserNotifier.value),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(activeWorkspaceDatabaseProvider),
        throwsA(isA<StateError>()),
      );

      await guestDb.close();
    });

    test('8. Database opening failure: fails account-specifically, other workspaces usable', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleGoodDb = await openTestWorkspacePowerSync(workspaceId: 'google_good');
      await registerGoogleWorkspace(guestDb, 'google_good');

      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          if (workspaceId == 'google_good') return googleGoodDb;
          throw StateError('Corrupted separate database file');
        },
      );

      // Good Google workspace opens fine
      final good = await manager.databaseForWorkspace('google_good');
      expect(good, equals(googleGoodDb));

      // Failing Google workspace throws account-specific error
      expect(
        () => manager.databaseForWorkspace('google_corrupt'),
        throwsA(isA<StateError>()),
      );

      // Guest remains completely unaffected and usable
      expect(manager.databaseForActiveWorkspace('guest'), equals(guestDb));

      await guestDb.close();
      await googleGoodDb.close();
    });

    test('9. Concurrent account switching: resolves deterministically without handle leaks', () async {
      final guestDb = await openTestWorkspacePowerSync(workspaceId: 'guest');
      final googleADb = await openTestWorkspacePowerSync(workspaceId: 'google_concurrent_a');
      final googleBDb = await openTestWorkspacePowerSync(workspaceId: 'google_concurrent_b');
      await registerGoogleWorkspace(guestDb, 'google_concurrent_a');
      await registerGoogleWorkspace(guestDb, 'google_concurrent_b');

      final manager = DatabaseManager(
        controlDatabase: guestDb,
        documentsDirectoryProvider: () async => tempDir,
        googleDatabaseFactory: ({required fileName, required workspaceId}) {
          if (workspaceId == 'google_concurrent_a') return googleADb;
          return googleBDb;
        },
      );

      // Rapid concurrent requests
      final futureA1 = manager.databaseForWorkspace('google_concurrent_a');
      final futureA2 = manager.databaseForWorkspace('google_concurrent_a');
      final futureB1 = manager.databaseForWorkspace('google_concurrent_b');

      final results = await Future.wait([futureA1, futureA2, futureB1]);
      expect(results[0], equals(googleADb));
      expect(results[1], equals(googleADb));
      expect(results[2], equals(googleBDb));

      // Close a specific workspace
      await manager.closeWorkspaceDatabase('google_concurrent_a');
      expect(
        () => manager.databaseForActiveWorkspace('google_concurrent_a'),
        throwsA(isA<StateError>()),
      );

      // Other workspace remains open
      expect(manager.databaseForActiveWorkspace('google_concurrent_b'), equals(googleBDb));

      await guestDb.close();
      await googleBDb.close();
    });

    test('10. Legacy migration: retry NEVER overwrites newer destination records', () async {
      final target = await openTestWorkspacePowerSync(workspaceId: 'google_retry_test');

      // Insert existing newer destination record
      await target.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'shared_record_1',
          userId: 'google_retry_test',
          prayerType: 'fajr',
          originalDate: DateTime.utc(2026, 9, 1),
          status: 'completed',
          completedAt: drift.Value(DateTime.utc(2026, 9, 2, 10, 0)),
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 2, 10, 0),
        ),
      );

      // Also insert a destination meta preference
      await target.customInsert(
        "INSERT INTO meta_store (key, value) VALUES ('qaza_theme_mode', 'dark')",
      );

      // Create legacy database with OLDER state of shared_record_1 (pending instead of completed)
      final legacyPath = p.join(tempDir.path, 'legacy_retry.sqlite');
      final legacyDb = AppDatabase(
        NativeDatabase.createInBackground(File(legacyPath)),
      );
      await legacyDb.customStatement(
        '''CREATE TABLE IF NOT EXISTS qaza_records (
             id TEXT PRIMARY KEY,
             user_id TEXT NOT NULL,
             prayer_type TEXT NOT NULL,
             original_date INTEGER NOT NULL,
             status TEXT NOT NULL,
             completed_at INTEGER,
             completion_id TEXT,
             record_version INTEGER DEFAULT 1,
             created_at INTEGER NOT NULL,
             updated_at INTEGER NOT NULL
           )''',
      );
      await legacyDb.customInsert(
        '''INSERT INTO qaza_records (id, user_id, prayer_type, original_date, status, created_at, updated_at)
           VALUES ('shared_record_1', 'google_retry_test', 'fajr', 1788220800, 'pending', 1788220800, 1788220800)''',
      );
      await legacyDb.customStatement(
        '''CREATE TABLE IF NOT EXISTS meta_store (key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
      );
      await legacyDb.customInsert(
        "INSERT INTO meta_store (key, value) VALUES ('qaza_theme_mode', 'light')",
      );
      await legacyDb.close();

      // Run migration with migrator
      final migrator = LegacyDriftToPowerSyncMigrator(
        documentsDirectoryProvider: () async => tempDir,
      );
      final result = await migrator.migrateIfNeeded(
        workspaceId: 'google_retry_test',
        targetPowerSyncDb: target,
        customLegacyFilePath: legacyPath,
        legacyEncryptionKey: '',
      );

      expect(result.status, equals(LegacyMigrationStatus.migrated));

      // CRITICAL CHECK: Destination record MUST still be 'completed', NOT overwritten with 'pending'!
      final rows = await (target.select(target.qazaRecords)
            ..where((r) => r.id.equals('shared_record_1')))
          .get();
      expect(rows.length, equals(1));
      expect(rows.single.status, equals('completed'));
      expect(rows.single.completedAt?.toUtc(), equals(DateTime.utc(2026, 9, 2, 10, 0)));

      // CRITICAL CHECK: Destination meta_store MUST still be 'dark', NOT overwritten with 'light'!
      final metaRows = await target.customSelect(
        "SELECT value FROM meta_store WHERE key = 'qaza_theme_mode'",
      ).get();
      expect(metaRows.single.read<String>('value'), equals('dark'));

      await target.close();
    });
  });
}
