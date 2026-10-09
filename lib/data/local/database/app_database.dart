import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'database_encryption.dart';
import 'qaza_records_dao.dart';
import 'tables/qaza_records.dart';

part 'app_database.g.dart';

/// Application-local encrypted SQLite database.
@DriftDatabase(
  tables: [QazaRecords],
  daos: [QazaRecordsDao],
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

  /// Schema version 18 is the current local-only database schema.
  /// Qaza records, additions, profile data, and completion markers are stored
  /// exclusively in the local encrypted SQLite database.
  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensureQazaAdditionSchema();
          await _ensureQazaProfilePlanProvenanceSchema();
          await _ensurePerformanceIndexes();
          await _ensureAccountSchema();
          await _ensureMetaStoreSchema();
          await _ensureLocalRecoverySnapshotSchema();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await _ensurePerformanceIndexes();
          }
          if (from < 5) {
            await m.addColumn(qazaRecords, qazaRecords.completionId);
          }
          if (from < 6) {
            await _removeLegacyQazaHistorySchema();
          }
          if (from < 7) {
            await m.addColumn(qazaRecords, qazaRecords.additionId);
            await m.addColumn(qazaRecords, qazaRecords.recordVersion);
            await _ensureQazaAdditionSchema();
          }
          if (from < 8) {
            // Keep legacy completed rows visible in the permanent Completed
            // workspace even when older data lacks completedAt.
            await customStatement(
              "UPDATE qaza_records SET completed_at = updated_at "
              "WHERE status = 'completed' AND completed_at IS NULL",
            );
          }
          if (from < 9) {
            // The deletion-action table was introduced during the schema 7
            // migration. Check the actual table shape so an older upgrade
            // does not attempt to add the column twice.
            final columns = await customSelect(
              'PRAGMA table_info(qaza_deletion_actions)',
            ).get();
            final hasResolvedAt = columns.any(
              (row) => row.read<String>('name') == 'resolved_at',
            );
            if (!hasResolvedAt) {
              await customStatement(
                'ALTER TABLE qaza_deletion_actions ADD COLUMN resolved_at TEXT',
              );
            }
          }
          if (from < 10) {
            await _ensureQazaProfilePlanProvenanceSchema();
          }
          if (from < 12) {
            await _ensureDeletionActionVersionColumn();
          }
          if (from < 11) {
            await _ensureAccountSchema();
          }
          await _ensurePerformanceIndexes();
          if (from < 18) {
            await _ensureMetaStoreSchema();
          }
          if (from < 19) {
            await _ensureLocalRecoverySnapshotSchema();
          }
        },
      );

  Future<void> _ensureMetaStoreSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meta_store (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await customStatement(
      "INSERT OR IGNORE INTO meta_store (key, value) VALUES "
      "('is_onboarding_completed', '0')",
    );
    // Drift's schemaVersion is the sole authoritative SQLite schema version.
    // The former meta_store schema_version key is obsolete and must not
    // compete with Drift's generated schema metadata.
    await customStatement(
      "DELETE FROM meta_store WHERE key = 'schema_version'",
    );
    await customStatement(
      "INSERT OR IGNORE INTO meta_store (key, value) VALUES "
      "('db_revision', '1')",
    );
  }


  /// Stores one encrypted, app-private recovery snapshot before a confirmed
  /// destructive restore. The table is excluded from normal export payloads.
  Future<void> _ensureLocalRecoverySnapshotSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_recovery_snapshots (
        snapshot_id TEXT NOT NULL PRIMARY KEY,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveLocalRecoverySnapshot(
    String payloadJson, {
    DateTime? createdAt,
  }) async {
    if (payloadJson.trim().isEmpty) {
      throw ArgumentError.value(payloadJson, 'payloadJson');
    }
    await transaction(() async {
      await _ensureLocalRecoverySnapshotSchema();
      await customStatement('DELETE FROM local_recovery_snapshots');
      await customInsert(
        'INSERT INTO local_recovery_snapshots '
        '(snapshot_id, created_at, payload_json) VALUES (?, ?, ?)',
        variables: [
          Variable('latest'),
          Variable((createdAt ?? DateTime.now()).toUtc().toIso8601String()),
          Variable(payloadJson),
        ],
      );
    });
  }

  Future<String?> readLocalRecoverySnapshot() async {
    await _ensureLocalRecoverySnapshotSchema();
    final rows = await customSelect(
      'SELECT payload_json FROM local_recovery_snapshots '
      "WHERE snapshot_id = 'latest' LIMIT 1",
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('payload_json');
  }

  Future<bool> hasLocalRecoverySnapshot() async {
    final rows = await customSelect(
      "SELECT 1 AS present FROM sqlite_master "
      "WHERE type = 'table' AND name = 'local_recovery_snapshots' LIMIT 1",
    ).get();
    if (rows.isEmpty) return false;
    final snapshots = await customSelect(
      'SELECT 1 AS present FROM local_recovery_snapshots LIMIT 1',
    ).get();
    return snapshots.isNotEmpty;
  }

  Future<void> clearLocalRecoverySnapshot() async {
    await _ensureLocalRecoverySnapshotSchema();
    await customStatement('DELETE FROM local_recovery_snapshots');
  }

  Future<bool> isOnboardingCompleted() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store WHERE key = 'is_onboarding_completed' LIMIT 1",
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<int> readDbRevision() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store WHERE key = 'db_revision' LIMIT 1",
    ).get();
    if (rows.isEmpty) {
      throw StateError('The local database revision is missing.');
    }
    final revision = int.tryParse(rows.first.read<String>('value'));
    if (revision == null || revision < 1) {
      throw StateError('The local database revision is invalid.');
    }
    return revision;
  }

  Future<void> setOnboardingCompletedInTransaction(bool completed) {
    return customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('is_onboarding_completed', ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [Variable(completed ? '1' : '0')],
    );
  }

  Future<void> setDbRevisionInTransaction(int revision) {
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision');
    }
    return customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('db_revision', ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [Variable(revision.toString())],
    );
  }

  Future<int> incrementDbRevisionInTransaction() async {
    await customUpdate(
      '''UPDATE meta_store
         SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT)
         WHERE key = 'db_revision' ''',
    );
    return readDbRevision();
  }

  /// Runs one logical local write transaction and advances db_revision once
  /// when the operation actually mutates local state.
  Future<T> transactionWithRevision<T>(
    Future<T> Function() action, {
    bool Function(T result)? mutationPredicate,
  }) async {
    return transaction(() async {
      final result = await action();
      final mutated = mutationPredicate?.call(result) ??
          switch (result) {
            bool value => value,
            int value => value > 0,
            Iterable<dynamic> value => value.isNotEmpty,
            _ => true,
          };
      if (mutated) {
        await incrementDbRevisionInTransaction();
      }
      return result;
    });
  }

  Future<void> _ensureAccountSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_accounts (
        local_account_id TEXT NOT NULL PRIMARY KEY,
        account_mode TEXT NOT NULL DEFAULT 'local',
        lifecycle_state TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_session_state (
        id INTEGER NOT NULL PRIMARY KEY,
        active_local_account_id TEXT
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS device_metadata (
        id INTEGER NOT NULL PRIMARY KEY,
        device_instance_id TEXT NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS account_profiles (
        local_account_id TEXT NOT NULL PRIMARY KEY,
        payload_json TEXT NOT NULL,
        entity_version INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        writer_device_id TEXT NOT NULL,
        operation_id TEXT NOT NULL
      )
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS account_plan_revisions (
        local_account_id TEXT NOT NULL,
        revision_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (local_account_id, revision_id)
      )
    ''');
  }

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

  Future<void> _ensureQazaAdditionSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_additions (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        input_snapshot TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_deletion_actions (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        addition_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        entity_version INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_deletion_action_record_snapshots (
        deletion_action_id TEXT NOT NULL,
        record_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        addition_id TEXT NOT NULL,
        prayer_type TEXT NOT NULL,
        original_date TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        completion_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        record_version INTEGER NOT NULL,
        PRIMARY KEY (deletion_action_id, record_id)
      )
    ''');
  }

  Future<void> _ensureQazaProfilePlanProvenanceSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_profile_plan_provenance (
        record_id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_revision_id TEXT NOT NULL,
        plan_fingerprint TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureDeletionActionVersionColumn() async {
    final columns = await customSelect(
      'PRAGMA table_info(qaza_deletion_actions)',
    ).get();
    final exists = columns.any(
      (row) => row.read<String>('name') == 'entity_version',
    );
    if (!exists) {
      await customStatement(
        'ALTER TABLE qaza_deletion_actions '
        'ADD COLUMN entity_version INTEGER NOT NULL DEFAULT 1',
      );
    }
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
      'CREATE INDEX IF NOT EXISTS qaza_records_user_status_completed_id_idx '
      'ON qaza_records (user_id, status, completed_at, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_addition_date_idx '
      'ON qaza_records (user_id, addition_id, original_date, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_addition_status_idx '
      'ON qaza_records (user_id, addition_id, status, record_version)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_profile_plan_provenance_user_idx '
      'ON qaza_profile_plan_provenance (user_id, plan_revision_id, record_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_additions_user_created_idx '
      'ON qaza_additions (user_id, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_actions_user_created_idx '
      'ON qaza_deletion_actions (user_id, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_actions_user_resolved_created_idx '
      'ON qaza_deletion_actions '
      '(user_id, resolved_at, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_snapshots_action_idx '
      'ON qaza_deletion_action_record_snapshots (deletion_action_id, record_id)',
    );
  }
}
