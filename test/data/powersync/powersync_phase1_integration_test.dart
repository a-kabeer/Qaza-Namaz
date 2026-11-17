import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' as ps;
import 'package:qaza_namaz/data/local/database/database_encryption.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/powersync/powersync_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Minimal Drift database for Phase 1 integration verification.
/// Verifies Drift QueryExecutor operations over PowerSync without
/// executing the full application schema or unsupported view indexes.
class Phase1TestDriftDatabase extends drift.GeneratedDatabase {
  Phase1TestDriftDatabase(super.executor);

  @override
  Iterable<drift.TableInfo<drift.Table, dynamic>> get allTables => [];

  @override
  int get schemaVersion => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const testSchema = ps.Schema([
    ps.Table('test_records', [
      ps.Column.text('name'),
      ps.Column.integer('quantity'),
      ps.Column.text('category'),
    ]),
  ]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qaza_phase1_test_');

    // Silence multiple database instances debug warning for testing
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // Mock secure storage in memory for tests
    FlutterSecureStorage.setMockInitialValues({});

    // Mock path_provider to route to tempDir
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDown(() async {
    await QazaPowerSyncDatabaseManager.closeAll();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 1: PowerSync Database Foundation & Encryption Integration', () {
    // 1. Opening an encrypted PowerSync database
    test('1. Opening an encrypted PowerSync database', () async {
      final dbPath = p.join(tempDir.path, 'db_1.sqlite');
      const key = 'test_key_phase1_32_bytes_long_01';

      final db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );

      expect(db, isNotNull);
      expect(db.database.closed, isFalse);

      await db.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Fajr Missed', 5, 'fajr'],
      );

      final row = await db.get(
        'SELECT name, quantity FROM test_records WHERE category = ?',
        ['fajr'],
      );
      expect(row['name'], equals('Fajr Missed'));
      expect(row['quantity'], equals(5));

      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 2. Reopening with the correct key
    test('2. Reopening with the correct key', () async {
      final dbPath = p.join(tempDir.path, 'db_2.sqlite');
      const key = 'test_key_phase1_32_bytes_long_02';

      // First open: write record
      var db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      await db.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Zuhr Missed', 12, 'zuhr'],
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);

      // Reopen with same key: read record
      db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      final row = await db.get(
        'SELECT name, quantity FROM test_records WHERE category = ?',
        ['zuhr'],
      );
      expect(row['name'], equals('Zuhr Missed'));
      expect(row['quantity'], equals(12));

      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 3. Rejecting an incorrect encryption key
    test('3. Rejecting an incorrect encryption key', () async {
      final dbPath = p.join(tempDir.path, 'db_3.sqlite');
      const correctKey = 'test_key_phase1_32_bytes_long_03';
      const wrongKey = 'wrong_key_phase1_32_bytes_long_03';

      final db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: correctKey,
        schema: testSchema,
      );
      await db.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Asr Missed', 3, 'asr'],
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);

      // Attempting to open with wrong key must fail
      expect(
        () async => await QazaPowerSyncDatabaseManager.getInstance(
          customPath: dbPath,
          encryptionKey: wrongKey,
          schema: testSchema,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // 4. Confirming that the database cannot be opened as an ordinary plaintext SQLite database
    test(
        '4. Confirming that the database cannot be opened as an ordinary plaintext SQLite database',
        () async {
      final dbPath = p.join(tempDir.path, 'db_4.sqlite');
      const key = 'test_key_phase1_32_bytes_long_04';

      final db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      await db.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Maghrib Missed', 7, 'maghrib'],
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);

      // Raw sqlite3 open without PRAGMA key should fail on query execution
      final rawSqlite = sqlite3.sqlite3.open(dbPath);
      expect(
        () => rawSqlite.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<sqlite3.SqliteException>()),
      );
      rawSqlite.close();
    });

    // 5. Creating two isolated account databases with separate keys
    test('5. Creating two isolated account databases with separate keys',
        () async {
      final dbPathA = p.join(tempDir.path, 'account_a.sqlite');
      final dbPathB = p.join(tempDir.path, 'account_b.sqlite');
      const keyA = 'account_a_key_32_bytes_long_0001';
      const keyB = 'account_b_key_32_bytes_long_0002';

      final dbA = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPathA,
        encryptionKey: keyA,
        schema: testSchema,
      );
      final dbB = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPathB,
        encryptionKey: keyB,
        schema: testSchema,
      );

      await dbA.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['User A Record', 10, 'account_a'],
      );
      await dbB.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['User B Record', 20, 'account_b'],
      );

      // Verify dbA only has User A data
      final rowsA = await dbA.getAll('SELECT * FROM test_records');
      expect(rowsA.length, equals(1));
      expect(rowsA.first['category'], equals('account_a'));

      // Verify dbB only has User B data
      final rowsB = await dbB.getAll('SELECT * FROM test_records');
      expect(rowsB.length, equals(1));
      expect(rowsB.first['category'], equals('account_b'));

      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPathA);
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPathB);
    });

    // 6. Preventing cross-account database access
    test('6. Preventing cross-account database access', () async {
      final dbPathA = p.join(tempDir.path, 'account_a_secure.sqlite');
      const keyA = 'account_a_key_32_bytes_long_0001';
      const keyB = 'account_b_key_32_bytes_long_0002';

      // Create Database A with Key A
      final dbA = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPathA,
        encryptionKey: keyA,
        schema: testSchema,
      );
      await dbA.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['User A Secret Data', 99, 'secret_a'],
      );
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPathA);

      // Attempting to open Database A with Key B must fail
      expect(
        () async => await QazaPowerSyncDatabaseManager.getInstance(
          customPath: dbPathA,
          encryptionKey: keyB,
          schema: testSchema,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // 7. Drift SELECT operations through the shared connection
    test('7. Drift SELECT operations through the shared connection', () async {
      final dbPath = p.join(tempDir.path, 'drift_shared_select.sqlite');
      const key = 'test_key_phase1_32_bytes_long_07';

      // Seed data via PowerSync
      final psDb = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      await psDb.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Isha Missed', 4, 'isha'],
      );

      // Create Drift connection through the shared PowerSync connection
      final driftConnection =
          await QazaPowerSyncDatabaseManager.createDriftConnection(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      final driftDb = Phase1TestDriftDatabase(driftConnection);

      // Execute SELECT via Drift
      final rows = await driftDb
          .customSelect(
            'SELECT name, quantity FROM test_records WHERE category = ?',
            variables: [drift.Variable<String>('isha')],
          )
          .get();

      expect(rows.length, equals(1));
      expect(rows.first.read<String>('name'), equals('Isha Missed'));
      expect(rows.first.read<int>('quantity'), equals(4));

      await driftDb.close();
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 8. Drift INSERT, UPDATE and DELETE operations
    test('8. Drift INSERT, UPDATE and DELETE operations', () async {
      final dbPath = p.join(tempDir.path, 'drift_shared_crud.sqlite');
      const key = 'test_key_phase1_32_bytes_long_08';

      final driftConnection =
          await QazaPowerSyncDatabaseManager.createDriftConnection(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      final driftDb = Phase1TestDriftDatabase(driftConnection);

      // INSERT via Drift
      await driftDb.customInsert(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        variables: [
          drift.Variable<String>('Witr Missed'),
          drift.Variable<int>(1),
          drift.Variable<String>('witr'),
        ],
      );

      var rows = await driftDb
          .customSelect(
              'SELECT quantity FROM test_records WHERE category = ?',
              variables: [drift.Variable<String>('witr')])
          .get();
      expect(rows.first.read<int>('quantity'), equals(1));

      // UPDATE via Drift
      await driftDb.customUpdate(
        'UPDATE test_records SET quantity = ? WHERE category = ?',
        variables: [
          drift.Variable<int>(6),
          drift.Variable<String>('witr'),
        ],
      );

      rows = await driftDb
          .customSelect(
              'SELECT quantity FROM test_records WHERE category = ?',
              variables: [drift.Variable<String>('witr')])
          .get();
      expect(rows.first.read<int>('quantity'), equals(6));

      // DELETE via Drift
      await driftDb.customStatement(
        'DELETE FROM test_records WHERE category = ?',
        ['witr'],
      );

      rows = await driftDb
          .customSelect(
              'SELECT quantity FROM test_records WHERE category = ?',
              variables: [drift.Variable<String>('witr')])
          .get();
      expect(rows, isEmpty);

      await driftDb.close();
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 9. Drift transaction and rollback behavior
    test('9. Drift transaction and rollback behavior', () async {
      final dbPath = p.join(tempDir.path, 'drift_transaction.sqlite');
      const key = 'test_key_phase1_32_bytes_long_09';

      final driftConnection =
          await QazaPowerSyncDatabaseManager.createDriftConnection(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      final driftDb = Phase1TestDriftDatabase(driftConnection);

      final abortException = Exception('Transaction aborted for rollback');

      try {
        await driftDb.transaction(() async {
          await driftDb.customInsert(
            'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
            variables: [
              drift.Variable<String>('Will Be Rolled Back'),
              drift.Variable<int>(50),
              drift.Variable<String>('rollback_test'),
            ],
          );
          throw abortException;
        });
      } catch (e) {
        expect(e, equals(abortException));
      }

      // Verify row was rolled back and does not exist in database
      final rows = await driftDb
          .customSelect(
            'SELECT * FROM test_records WHERE category = ?',
            variables: [drift.Variable<String>('rollback_test')],
          )
          .get();
      expect(rows, isEmpty);

      await driftDb.close();
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 10. Reactive update notifications
    test('10. Reactive update notifications', () async {
      final dbPath = p.join(tempDir.path, 'reactive_updates.sqlite');
      const key = 'test_key_phase1_32_bytes_long_10';

      final driftConnection =
          await QazaPowerSyncDatabaseManager.createDriftConnection(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      final driftDb = Phase1TestDriftDatabase(driftConnection);

      // Listen for updates on 'test_records'
      final updatesFuture = driftDb
          .tableUpdates(drift.TableUpdateQuery.onTableName('test_records'))
          .first;

      // Trigger mutation
      await driftDb.customInsert(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        variables: [
          drift.Variable<String>('Reactive Record'),
          drift.Variable<int>(1),
          drift.Variable<String>('reactive'),
        ],
      );

      final event =
          await updatesFuture.timeout(const Duration(milliseconds: 2000));
      expect(event.any((u) => u.table == 'test_records'), isTrue);

      await driftDb.close();
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 11. Safe database closure and reopening
    test('11. Safe database closure and reopening', () async {
      final dbPath = p.join(tempDir.path, 'safe_closure.sqlite');
      const key = 'test_key_phase1_32_bytes_long_11';

      var db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      expect(db.database.closed, isFalse);

      await db.execute(
        'INSERT INTO test_records(id, name, quantity, category) VALUES(uuid(), ?, ?, ?)',
        ['Closure Test', 1, 'closure'],
      );

      // Safe closure
      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
      expect(db.database.closed, isTrue);

      // Reopening cleanly without multiple instances warning
      db = await QazaPowerSyncDatabaseManager.getInstance(
        customPath: dbPath,
        encryptionKey: key,
        schema: testSchema,
      );
      expect(db.database.closed, isFalse);

      final count = await db.get('SELECT count(*) as cnt FROM test_records');
      expect(count['cnt'], equals(1));

      await QazaPowerSyncDatabaseManager.closeDatabase(customPath: dbPath);
    });

    // 12. Guest database isolation
    test('12. Guest database isolation', () async {
      final guestPath = await QazaPowerSyncDatabaseManager
          .resolveWorkspaceDatabasePath(workspaceId: 'guest');
      final googlePath = await QazaPowerSyncDatabaseManager
          .resolveWorkspaceDatabasePath(workspaceId: 'google_user_alpha_789');

      // 1. Paths are distinct
      expect(guestPath, isNot(equals(googlePath)));
      expect(guestPath, contains('guest'));
      expect(googlePath, contains('google'));

      // 2. Encryption keys are workspace-isolated
      final keyStore = DatabaseEncryptionKeyStore();
      final guestKey =
          await keyStore.readOrCreateForWorkspace('guest');
      final googleKey =
          await keyStore.readOrCreateForWorkspace('google_user_alpha_789');

      expect(guestKey, isNot(equals(googleKey)));
      expect(guestKey.length, greaterThanOrEqualTo(32));
      expect(googleKey.length, greaterThanOrEqualTo(32));

      // 3. DatabaseManager factory integration
      final guestExecutor =
          await DatabaseManager.createPowerSyncDriftConnection(
        workspaceId: 'guest',
        encryptionKey: guestKey,
        customPath: p.join(tempDir.path, 'guest_factory_test.sqlite'),
        schema: testSchema,
      );
      expect(guestExecutor, isNotNull);

      await QazaPowerSyncDatabaseManager.closeAll();
    });
  });
}
