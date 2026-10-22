import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/workspace_canonical_content.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Recovery Stage 4 — §8 item 8 evidence (register R-13): a realistic
/// schema 25 → 26 upgrade. A database is populated with records,
/// profiles, and sync metadata for multiple Guest + Google workspaces,
/// then downgraded at the raw SQLite level to the exact v25 shape
/// (registry routing columns and journal hash columns absent,
/// user_version 25), then reopened through the production upgrade
/// path. The upgrade must initialise the registry rows to
/// shared / NULL / not_started and move, duplicate, or delete nothing.
void main() {
  test('realistic schema 25 database upgrades to 26 with content preserved',
      () async {
    final directory = await Directory.systemTemp.createTemp('qaza-upgrade-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/control.sqlite');

    // ---- Populate at the current schema, as a pre-upgrade install
    // would look after the v25-era app wrote it (all workspaces share
    // the one file; the routing columns do not exist yet at v25, so
    // seed with them present and drop them below). ----
    final seed = AppDatabase(NativeDatabase(file));
    Future<void> register(String id, String mode) async {
      await seed.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
           VALUES (?, ?, 'active', 1, 1)''',
        variables: [Variable<String>(id), Variable<String>(mode)],
      );
    }

    Future<void> insertRecord(String id, String owner) async {
      await seed.customInsert(
        '''INSERT INTO qaza_records
           (id, user_id, prayer_type, original_date, status, created_at, updated_at)
           VALUES (?, ?, 'fajr', 1, 'pending', 1, 1)''',
        variables: [Variable<String>(id), Variable<String>(owner)],
      );
    }

    await register('guest_main', 'local');
    await register('google_one', 'local');
    await register('google_two', 'local');
    await insertRecord('guest_r', 'guest_main');
    await insertRecord('g1_r', 'google_one');
    await insertRecord('g2_r', 'google_two');
    for (final id in ['guest_main', 'google_one', 'google_two']) {
      await seed.customInsert(
        '''INSERT INTO account_profiles
           (local_account_id, payload_json, entity_version, updated_at,
            writer_device_id, operation_id)
           VALUES (?, '{"onboardingCompleted":true}', 1, 1, 'device', 'op')''',
        variables: [Variable<String>(id)],
      );
      await seed.customInsert(
        '''INSERT INTO workspace_sync_metadata
           (local_account_id, sync_state, local_revision)
           VALUES (?, 'pending', 3)''',
        variables: [Variable<String>(id)],
      );
    }
    final hashesBefore = <String, String>{};
    for (final id in ['guest_main', 'google_one', 'google_two']) {
      hashesBefore[id] = await WorkspaceCanonicalContent.hash(seed, id);
    }
    await seed.close();

    // ---- Downgrade the file to the exact v25 shape. ----
    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute('ALTER TABLE local_accounts DROP COLUMN db_file_name;');
    raw.execute('ALTER TABLE local_accounts DROP COLUMN db_layout;');
    raw.execute('ALTER TABLE local_accounts DROP COLUMN db_migration_state;');
    raw.execute(
        'ALTER TABLE workspace_operation_journal DROP COLUMN source_hash;');
    raw.execute(
        'ALTER TABLE workspace_operation_journal DROP COLUMN target_hash;');
    raw.execute('PRAGMA user_version = 25;');
    raw.close();

    // ---- Reopen through the production upgrade path. ----
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.readDbRevision();

    final versionRows =
        await upgraded.customSelect('PRAGMA user_version').get();
    expect(versionRows.single.read<int>('user_version'), 26);
    expect(upgraded.schemaVersion, 26);

    // Registry rows initialised exactly as §8 item 8 requires.
    final registry = await upgraded
        .customSelect(
          'SELECT local_account_id, db_file_name, db_layout, db_migration_state '
          'FROM local_accounts ORDER BY local_account_id',
        )
        .get();
    expect(registry.length, 3);
    for (final row in registry) {
      expect(row.read<String?>('db_file_name'), isNull);
      expect(row.read<String>('db_layout'), 'shared');
      expect(row.read<String>('db_migration_state'), 'not_started');
    }

    // Nothing moved, duplicated, or deleted; content hashes identical.
    for (final id in ['guest_main', 'google_one', 'google_two']) {
      final records = await upgraded.customSelect(
        'SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = ?',
        variables: [Variable<String>(id)],
      ).get();
      expect(records.single.read<int>('row_count'), 1);
      final profiles = await upgraded.customSelect(
        'SELECT COUNT(*) AS row_count FROM account_profiles '
        'WHERE local_account_id = ?',
        variables: [Variable<String>(id)],
      ).get();
      expect(profiles.single.read<int>('row_count'), 1);
      final sync = await WorkspaceCanonicalContent.syncRowValues(upgraded, id);
      expect(sync, isNotNull);
      expect(sync![2], 3); // local_revision preserved
      expect(
        await WorkspaceCanonicalContent.hash(upgraded, id),
        hashesBefore[id],
      );
    }
  });
}
