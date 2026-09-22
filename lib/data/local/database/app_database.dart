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

  /// Schema version 2 establishes an explicit migration boundary for the
  /// production database. Version 1 databases already contain the same
  /// tables; the upgrade path below is intentionally data-preserving and
  /// idempotently restores the indexes required by the paginated DAOs.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensurePerformanceIndexes();
          await _ensureRecoveryIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await _ensurePerformanceIndexes();
          }
          if (from < 3) {
            await _ensureRecoveryIndexes();
          }
        },
      );

  Future<void> _ensureRecoveryIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_status_updated_idx '
      'ON qaza_records (user_id, status, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_updated_date_idx '
      'ON qaza_records (user_id, updated_at, original_date, id)',
    );
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
