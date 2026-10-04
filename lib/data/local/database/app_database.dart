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

  /// Schema version 11 adds account/session and cloud-backup infrastructure.
  /// Schema version 6 removes the legacy Qaza History operation/recovery schema.
  /// Existing pending/completed records and completion markers are preserved.
  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensureQazaAdditionSchema();
          await _ensureQazaProfilePlanProvenanceSchema();
          await _ensurePerformanceIndexes();
          await _ensureAccountSchema();
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
          if (from < 11) {
            await _ensureAccountSchema();
          }
          if (from < 12) {
            await _ensureDeletionActionVersionColumn();
          }
          await _ensurePerformanceIndexes();
        },
      );


  Future<void> _ensureAccountSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_accounts (
        local_account_id TEXT NOT NULL PRIMARY KEY,
        account_mode TEXT NOT NULL,
        firebase_uid TEXT,
        google_email TEXT,
        lifecycle_state TEXT NOT NULL,
        cloud_backup_enabled INTEGER NOT NULL DEFAULT 0,
        cloud_generation INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS local_accounts_uid_idx '
      'ON local_accounts (firebase_uid) WHERE firebase_uid IS NOT NULL',
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_session_state (
        id INTEGER NOT NULL PRIMARY KEY,
        active_local_account_id TEXT,
        initial_choice_required INTEGER NOT NULL DEFAULT 0,
        migration_state TEXT NOT NULL DEFAULT 'none',
        restore_state TEXT NOT NULL DEFAULT 'none'
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
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entity_metadata (
        local_account_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        entity_version INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        writer_device_id TEXT NOT NULL,
        operation_id TEXT NOT NULL,
        PRIMARY KEY (local_account_id, entity_type, entity_id)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_record_tombstones (
        local_account_id TEXT NOT NULL,
        record_id TEXT NOT NULL,
        record_version INTEGER NOT NULL,
        deleted_at INTEGER NOT NULL,
        writer_device_id TEXT NOT NULL,
        operation_id TEXT NOT NULL,
        cloud_generation INTEGER NOT NULL,
        PRIMARY KEY (local_account_id, record_id)
      )
    ''');

    final columns = await customSelect('PRAGMA table_info(sync_outbox)').get();
    final existing = columns.map((row) => row.read<String>('name')).toSet();
    final extensions = <String, String>{
      'firebase_uid': 'TEXT',
      'cloud_generation': 'INTEGER',
      'entity_type': 'TEXT',
      'operation': 'TEXT',
      'payload_json': 'TEXT',
      'next_attempt_at': 'INTEGER',
      'writer_device_id': 'TEXT',
      'lease_until': 'INTEGER',
      'worker_id': 'TEXT',
    };
    for (final entry in extensions.entries) {
      if (existing.contains(entry.key)) continue;
      await customStatement(
        'ALTER TABLE sync_outbox ADD COLUMN ' + entry.key + ' ' + entry.value,
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sync_outbox_modern_ready_idx '
      'ON sync_outbox (user_id, type, next_attempt_at, queued_at)',
    );
    await _ensureBackupTriggers();
  }

  Future<void> _ensureBackupTriggers() async {
    const timestamp = "(CAST(strftime('%s','now') AS INTEGER) * 1000000)";
    const queue = '''
      INSERT INTO sync_outbox
        (id, user_id, type, queued_at, firebase_uid, cloud_generation,
         entity_type, operation, next_attempt_at, attempts,
         writer_device_id)
      SELECT lower(hex(randomblob(16))), local_account_id, 'account_snapshot',
             $timestamp, firebase_uid, cloud_generation, 'account',
             'snapshot', $timestamp, 0,
             (SELECT device_instance_id FROM device_metadata WHERE id = 1)
      FROM local_accounts
      WHERE local_account_id = %USER%
        AND account_mode = 'google'
        AND cloud_backup_enabled = 1
        AND firebase_uid IS NOT NULL;
    ''';

    const triggers = <String>[
      'qaza_records_backup_insert',
      'qaza_records_backup_update',
      'qaza_records_backup_delete',
      'qaza_additions_backup_insert',
      'qaza_additions_backup_update',
      'qaza_additions_backup_delete',
      'qaza_deletion_actions_backup_insert',
      'qaza_deletion_actions_backup_update',
      'qaza_deletion_snapshots_backup_insert',
      'qaza_plan_revisions_backup_insert',
    ];
    for (final name in triggers) {
      await customStatement('DROP TRIGGER IF EXISTS $name');
    }

    await customStatement('''
      CREATE TRIGGER qaza_records_backup_insert
      AFTER INSERT ON qaza_records
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'qazaRecord', NEW.id, NEW.record_version,
               NEW.updated_at,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_records_backup_update
      AFTER UPDATE ON qaza_records
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'qazaRecord', NEW.id, NEW.record_version,
               NEW.updated_at,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_records_backup_delete
      AFTER DELETE ON qaza_records
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = OLD.user_id AND account_mode = 'google'
      )
      BEGIN
        INSERT OR REPLACE INTO qaza_record_tombstones
          (local_account_id, record_id, record_version, deleted_at,
           writer_device_id, operation_id, cloud_generation)
        SELECT OLD.user_id, OLD.id, OLD.record_version + 1, $timestamp,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16))),
               COALESCE(
                 (SELECT cloud_generation FROM local_accounts
                  WHERE local_account_id = OLD.user_id), 1
               );
        $queue
      END
    '''.replaceFirst('%USER%', 'OLD.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_additions_backup_insert
      AFTER INSERT ON qaza_additions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'qazaAddition', NEW.id, NEW.revision, $timestamp,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_additions_backup_update
      AFTER UPDATE ON qaza_additions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'qazaAddition', NEW.id, NEW.revision, $timestamp,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_additions_backup_delete
      AFTER DELETE ON qaza_additions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = OLD.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        $queue
      END
    '''.replaceFirst('%USER%', 'OLD.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_deletion_actions_backup_insert
      AFTER INSERT ON qaza_deletion_actions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'deletionAction', NEW.id, NEW.entity_version, $timestamp,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_deletion_actions_backup_update
      AFTER UPDATE ON qaza_deletion_actions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        INSERT OR REPLACE INTO entity_metadata
          (local_account_id, entity_type, entity_id, entity_version, updated_at,
           writer_device_id, operation_id)
        SELECT NEW.user_id, 'deletionAction', NEW.id, NEW.entity_version, $timestamp,
               (SELECT device_instance_id FROM device_metadata WHERE id = 1),
               lower(hex(randomblob(16)));
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER qaza_deletion_snapshots_backup_insert
      AFTER INSERT ON qaza_deletion_action_record_snapshots
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.user_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.user_id'));

    await customStatement('''
      CREATE TRIGGER account_plan_revisions_backup_insert
      AFTER INSERT ON account_plan_revisions
      WHEN EXISTS (
        SELECT 1 FROM local_accounts
        WHERE local_account_id = NEW.local_account_id
          AND account_mode = 'google'
          AND cloud_backup_enabled = 1
          AND firebase_uid IS NOT NULL
      )
      BEGIN
        $queue
      END
    '''.replaceFirst('%USER%', 'NEW.local_account_id'));
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
