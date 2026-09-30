import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'database_encryption.dart';
import 'qaza_records_dao.dart';
import 'sync_outbox_dao.dart';
import 'tables/qaza_records.dart';
import 'tables/sync_outbox.dart';

part 'app_database.g.dart';

/// Application-local encrypted SQLite database.
@DriftDatabase(
  tables: [QazaRecords, SyncOutbox],
  daos: [QazaRecordsDao, SyncOutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openEncryptedDatabase());

  static QueryExecutor _openEncryptedDatabase() {
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final databaseFile = File('${directory.path}/qaza_namaz.sqlite');
      final key = await DatabaseEncryptionKeyStore().readOrCreate();

      await PlaintextDatabaseMigrator.migrateIfNeeded(
        databaseFile: databaseFile,
        key: key,
      );

      return NativeDatabase.createInBackground(
        databaseFile,
        setup: (rawDb) {
          final cipher = rawDb.select('PRAGMA cipher;');
          if (cipher.isEmpty) {
            throw StateError(
              'Encrypted SQLite support is unavailable in this build.',
            );
          }

          final escapedKey = key.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escapedKey';");

          // Force SQLite to validate the key before Drift starts issuing
          // application queries.
          rawDb.select('SELECT count(*) FROM sqlite_master;');
        },
      );
    });
  }

  /// Schema version 6 removes the legacy Qaza History operation/recovery schema.
  /// Existing pending/completed records and completion markers are preserved.
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensurePerformanceIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await _ensurePerformanceIndexes();
          }
          if (from < 5) {
            await m.addColumn(qazaRecords, qazaRecords.completionId);
            await m.addColumn(syncOutbox, syncOutbox.completionId);
          }
          if (from < 6) {
            await _removeLegacyQazaHistorySchema();
          }
        },
      );

  Future<void> _removeLegacyQazaHistorySchema() async {
    final statuses = await customSelect(
      'SELECT DISTINCT status FROM qaza_records',
    ).get();
    for (final row in statuses) {
      final status = row.read<String?>('status');
      if (status != 'pending' && status != 'completed' && status != 'deleted') {
        throw StateError(
          'Unsupported legacy Qaza status during migration: $status',
        );
      }
    }

    // Permanently remove the old Recently Deleted records. They have no
    // representation in the new ledger model.
    await customStatement(
      "DELETE FROM qaza_records WHERE status = 'deleted'",
    );

    // Remove queued soft-delete payloads so startup can never attempt to decode
    // a legacy deleted QazaRecord after the enum value has been removed.
    await customStatement(
      '''DELETE FROM sync_outbox
         WHERE record_json LIKE '%"status":"deleted"%'
            OR record_json LIKE '%"status": "deleted"%' '''
    );

    // Rebuild the table so the obsolete operation_id column is physically
    // removed. This is deliberately not implemented as an ALTER-only change.
    await customStatement('''
      CREATE TABLE qaza_records_new (
        id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        prayer_type TEXT NOT NULL,
        original_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        completed_at INTEGER,
        completion_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (id),
        UNIQUE (user_id, prayer_type, original_date)
      )
    ''');
    await customStatement('''
      INSERT INTO qaza_records_new
        (id, user_id, prayer_type, original_date, status, completed_at,
         completion_id, created_at, updated_at)
      SELECT
        id, user_id, prayer_type, original_date, status, completed_at,
        completion_id, created_at, updated_at
      FROM qaza_records
    ''');
    await customStatement('DROP TABLE qaza_records');
    await customStatement(
      'ALTER TABLE qaza_records_new RENAME TO qaza_records',
    );
    await _ensurePerformanceIndexes();
  }

  Future<void> _ensurePerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_date_idx '
      'ON qaza_records (user_id, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_prayer_date_idx '
      'ON qaza_records (user_id, prayer_type, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_prayer_status_date_idx '
      'ON qaza_records '
      '(user_id, prayer_type, status, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_status_completed_idx '
      'ON qaza_records (user_id, status, completed_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sync_outbox_user_queued_idx '
      'ON sync_outbox (user_id, queued_at, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sync_outbox_user_type_idx '
      'ON sync_outbox (user_id, type, queued_at)',
    );
  }
}
