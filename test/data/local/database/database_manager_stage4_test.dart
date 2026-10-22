import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/local/database/workspace_canonical_content.dart';

/// Recovery Stage 4 — §8 matrix evidence for the §5 migration mechanics
/// (R-04), the §6 quarantine scan (R-08), the R-15 scoped snapshot
/// selection, and the §4 adoption staging/publish manager API (R-05).
void main() {
  late Directory directory;
  late AppDatabase control;
  late DatabaseManager manager;

  DatabaseManager buildManager({int? freeSpaceOverride}) {
    return DatabaseManager(
      controlDatabase: control,
      documentsDirectoryProvider: () async => directory,
      googleDatabaseFactory: ({
        required String fileName,
        required String workspaceId,
      }) =>
          GoogleWorkspaceDatabase.forTesting(
        executor: NativeDatabase(File('${directory.path}/$fileName')),
        workspaceId: workspaceId,
      ),
      freeSpaceBytesProvider:
          freeSpaceOverride == null ? null : (_) async => freeSpaceOverride,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qaza-stage4-');
    control = AppDatabase(
      NativeDatabase(File('${directory.path}/control.sqlite')),
    );
    manager = buildManager();
    await control.readDbRevision();
  });

  tearDown(() async {
    await manager.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Future<void> registerSharedGoogle(String id) async {
    await control.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', 1, 1)''',
      variables: [Variable<String>(id)],
    );
  }

  Future<void> insertRecord(
    AppDatabase db, {
    required String id,
    required String owner,
  }) async {
    await db.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status, created_at, updated_at)
         VALUES (?, ?, 'fajr', 1, 'pending', 1, 1)''',
      variables: [Variable<String>(id), Variable<String>(owner)],
    );
  }

  Future<int> recordCount(AppDatabase db, String owner) async {
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = ?',
      variables: [Variable<String>(owner)],
    ).get();
    return rows.single.read<int>('row_count');
  }

  test('startup run migrates every resident shared workspace in one run',
      () async {
    await registerSharedGoogle('google_one');
    await registerSharedGoogle('google_two');
    await insertRecord(control, id: 'r1', owner: 'google_one');
    await insertRecord(control, id: 'r2', owner: 'google_two');

    final report = await manager.runStartupMigrations();
    expect(report.migrated, ['google_one', 'google_two']);
    expect(report.failed, isEmpty);
    expect(report.preCheckPassed, isTrue);
    expect(report.safetyCopyEnsured, isTrue);

    for (final id in ['google_one', 'google_two']) {
      final registry = await control.customSelect(
        'SELECT db_layout, db_migration_state FROM local_accounts '
        'WHERE local_account_id = ?',
        variables: [Variable<String>(id)],
      ).get();
      expect(registry.single.read<String>('db_layout'), 'separate');
      expect(registry.single.read<String>('db_migration_state'), 'committed');
      final workspace = await manager.databaseForWorkspace(id);
      expect(await recordCount(workspace, id), 1);
      // §5.4 retention: superseded rows remain in control, unread.
      expect(await recordCount(control, id), 1);
      // §5.1 manifest: committed journal with distinct hashes recorded.
      final journal = await control.customSelect(
        'SELECT phase, source_hash, target_hash FROM workspace_operation_journal '
        'WHERE operation_id = ?',
        variables: [Variable<String>('google-workspace-migration:$id')],
      ).get();
      expect(journal.single.read<String>('phase'), 'committed');
      final sourceHash = journal.single.read<String?>('source_hash');
      final targetHash = journal.single.read<String?>('target_hash');
      expect(sourceHash, isNotNull);
      expect(targetHash, sourceHash);
    }

    // The safety copy exists, opens, and holds the pre-migration data.
    final copyFile =
        File('${directory.path}/qaza_namaz.sqlite.migration-safety-copy');
    expect(await copyFile.exists(), isTrue);
    final copy = AppDatabase(NativeDatabase(copyFile));
    addTearDown(copy.close);
    expect(await recordCount(copy, 'google_one'), 1);
    final integrity = await copy.customSelect('PRAGMA integrity_check').get();
    expect(integrity.first.read<String>('integrity_check'), 'ok');
  });

  test('safety copy is created once and never refreshed by later runs',
      () async {
    await registerSharedGoogle('google_one');
    await insertRecord(control, id: 'r1', owner: 'google_one');
    await manager.runStartupMigrations();
    final copyFile =
        File('${directory.path}/qaza_namaz.sqlite.migration-safety-copy');
    final firstBytes = await copyFile.readAsBytes();

    // A second resident workspace migrates in a later run; new control
    // data written after the first run must NOT leak into the copy.
    await registerSharedGoogle('google_two');
    await insertRecord(control, id: 'r2', owner: 'google_two');
    final second = buildManager();
    addTearDown(second.close);
    final report = await second.runStartupMigrations();
    expect(report.migrated, ['google_two']);
    expect(await copyFile.readAsBytes(), firstBytes);
  });

  test('storage pre-check blocks before any file is modified', () async {
    await registerSharedGoogle('google_one');
    await insertRecord(control, id: 'r1', owner: 'google_one');
    final blocked = buildManager(freeSpaceOverride: 0);
    addTearDown(blocked.close);

    final report = await blocked.runStartupMigrations();
    expect(report.preCheckPassed, isFalse);
    expect(report.migrated, isEmpty);
    expect(report.failed.keys, contains('google_one'));

    final fileName = DatabaseManager.googleFileNameForWorkspaceId('google_one');
    expect(await File('${directory.path}/$fileName').exists(), isFalse);
    expect(
      await File('${directory.path}/qaza_namaz.sqlite.migration-safety-copy')
          .exists(),
      isFalse,
    );
    final registry = await control.customSelect(
      'SELECT db_layout FROM local_accounts WHERE local_account_id = ?',
      variables: [const Variable<String>('google_one')],
    ).get();
    expect(registry.single.read<String>('db_layout'), 'shared');
    // The workspace remains fully operational on the shared layout.
    final resolved = await blocked.databaseForWorkspace('google_one');
    expect(identical(resolved, control), isTrue);
  });

  test('§5.3: adopting/restoring and in-flight workspaces are skipped',
      () async {
    await registerSharedGoogle('google_busy');
    await registerSharedGoogle('google_inflight');
    await registerSharedGoogle('google_free');
    await control.customUpdate(
      "UPDATE local_accounts SET lifecycle_state = 'adopting' "
      "WHERE local_account_id = 'google_busy'",
    );
    await control.customInsert(
      '''INSERT INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, created_at, updated_at)
         VALUES ('guest-adoption:guest_x=>google_inflight', 'guest_adoption',
                 'guest_x', 'google_inflight', 'copied', 1, 1)''',
    );

    final report = await manager.runStartupMigrations();
    expect(report.skippedMidOperation,
        containsAll(['google_busy', 'google_inflight']));
    expect(report.migrated, ['google_free']);
    for (final id in ['google_busy', 'google_inflight']) {
      final registry = await control.customSelect(
        'SELECT db_layout FROM local_accounts WHERE local_account_id = ?',
        variables: [Variable<String>(id)],
      ).get();
      expect(registry.single.read<String>('db_layout'), 'shared');
    }
  });

  test('one workspace failing does not block or corrupt the others', () async {
    await registerSharedGoogle('google_good');
    await registerSharedGoogle('google_blocked');
    await insertRecord(control, id: 'good_r', owner: 'google_good');
    await insertRecord(control, id: 'blocked_r', owner: 'google_blocked');
    // An unregistered file already sits at the blocked workspace's final
    // name: migration must refuse to overwrite it and fail that
    // workspace only.
    final blockedName =
        DatabaseManager.googleFileNameForWorkspaceId('google_blocked');
    await File('${directory.path}/$blockedName').writeAsString('not a db');

    final report = await manager.runStartupMigrations();
    expect(report.migrated, ['google_good']);
    expect(report.failed.keys, contains('google_blocked'));
    // The foreign file is untouched, and the blocked workspace remains
    // operational on the shared layout with its data intact.
    expect(
      await File('${directory.path}/$blockedName').readAsString(),
      'not a db',
    );
    final resolved = await manager.databaseForWorkspace('google_blocked');
    expect(identical(resolved, control), isTrue);
    expect(await recordCount(control, 'google_blocked'), 1);
  });

  test('§6: unrecognized Google files are quarantined, never exposed',
      () async {
    await registerSharedGoogle('google_known');
    final knownName =
        DatabaseManager.googleFileNameForWorkspaceId('google_known');
    final unknownName = 'qaza_google_${'a' * 32}.sqlite';
    await File('${directory.path}/$unknownName').writeAsString('junk');
    // The registered file of a separate workspace must not be touched;
    // google_known is shared, so simulate its file existing as junk too
    // would block migration — instead only assert the unknown file.
    final report = await manager.runStartupMigrations();
    expect(report.migrated, ['google_known']);
    expect(await File('${directory.path}/$unknownName').exists(), isFalse);
    expect(
      await File('${directory.path}/$unknownName.quarantine').exists(),
      isTrue,
    );
    expect(await File('${directory.path}/$knownName').exists(), isTrue);
  });

  test(
      'R-15: migration carries this workspace\'s scoped recovery snapshot, '
      'not the newest overall', () async {
    await registerSharedGoogle('google_alpha');
    await registerSharedGoogle('google_beta');
    String snapshotPayload(String id) => jsonEncode({
          'data': {
            'local_accounts': [
              {'local_account_id': id}
            ],
            'app_session_state': [
              {'active_local_account_id': id}
            ],
          }
        });
    // Beta's snapshot is NEWER; alpha's must still be selected for alpha.
    await control.customInsert(
      'INSERT INTO local_recovery_snapshots (snapshot_id, created_at, payload_json) '
      'VALUES (?, ?, ?)',
      variables: [
        const Variable<String>('snap_alpha'),
        const Variable<String>('2026-01-01T00:00:00.000Z'),
        Variable<String>(snapshotPayload('google_alpha')),
      ],
    );
    await control.customInsert(
      'INSERT INTO local_recovery_snapshots (snapshot_id, created_at, payload_json) '
      'VALUES (?, ?, ?)',
      variables: [
        const Variable<String>('snap_beta'),
        const Variable<String>('2026-02-01T00:00:00.000Z'),
        Variable<String>(snapshotPayload('google_beta')),
      ],
    );

    await manager.runStartupMigrations();
    final alphaDb = await manager.databaseForWorkspace('google_alpha');
    final rows = await alphaDb
        .customSelect(
          'SELECT snapshot_id FROM local_recovery_snapshots',
        )
        .get();
    expect(rows.map((r) => r.read<String>('snapshot_id')), ['snap_alpha']);
  });

  test('§8 handle lifecycle: one handle per workspace, concurrent dedup',
      () async {
    final created = await manager.ensureGoogleWorkspace('google_handles');
    final again = await manager.databaseForWorkspace('google_handles');
    expect(identical(created, again), isTrue);
    final concurrent = await Future.wait([
      manager.databaseForWorkspace('google_handles'),
      manager.databaseForWorkspace('google_handles'),
    ]);
    expect(identical(concurrent[0], concurrent[1]), isTrue);
  });

  test(
      '§4 manager API: adoption staging publish swaps verified content '
      'and rolls back on verification failure', () async {
    final target = await manager.ensureGoogleWorkspace('google_stage');
    final staging = await manager.createAdoptionStagingDatabase('google_stage');
    await insertRecord(staging, id: 'adopted_r', owner: 'google_stage');
    await staging.close();

    // Verification failure: the previous live file is restored and the
    // unverified file is quarantined, never left live.
    await expectLater(
      manager.publishAdoptionStagingDatabase(
        'google_stage',
        verify: (_) async => throw StateError('verify failed'),
      ),
      throwsStateError,
    );
    final restored = await manager.databaseForWorkspace('google_stage');
    expect(identical(restored, target), isFalse); // reopened after rollback
    expect(await recordCount(restored, 'google_stage'), 0);
    final names =
        await directory.list().map((e) => e.uri.pathSegments.last).toList();
    expect(names.where((n) => n.endsWith('.adoption-staging')), isEmpty);
    expect(names.where((n) => n.endsWith('.quarantine')), isNotEmpty);

    // Successful publish: staging content becomes the live file.
    await manager.discardAdoptionStagingDatabase('google_stage');
    final staging2 =
        await manager.createAdoptionStagingDatabase('google_stage');
    await insertRecord(staging2, id: 'adopted_r', owner: 'google_stage');
    await staging2.close();
    final published = await manager.publishAdoptionStagingDatabase(
      'google_stage',
      verify: (db) async {
        expect(await recordCount(db, 'google_stage'), 1);
      },
    );
    expect(await recordCount(published, 'google_stage'), 1);
    await manager.discardAdoptionPreviousDatabase('google_stage');
    final after =
        await directory.list().map((e) => e.uri.pathSegments.last).toList();
    expect(after.where((n) => n.contains('.adoption-')), isEmpty);
  });

  test(
      '§8 isolation: a corrupt separate file fails account-specifically, '
      'never falls back, and leaves other workspaces usable', () async {
    final good = await manager.ensureGoogleWorkspace('google_iso_good');
    await insertRecord(good, id: 'iso_good_r', owner: 'google_iso_good');
    await manager.ensureGoogleWorkspace('google_iso_bad');
    final badName =
        DatabaseManager.googleFileNameForWorkspaceId('google_iso_bad');
    await manager.close();

    // Corrupt the bad workspace's file on disk.
    await File('${directory.path}/$badName')
        .writeAsString('corrupted-not-a-database');

    final fresh = buildManager();
    addTearDown(fresh.close);
    await expectLater(
      fresh.databaseForWorkspace('google_iso_bad'),
      throwsStateError,
    );
    // No silent fallback happened: the registry still says separate.
    final registry = await control.customSelect(
      'SELECT db_layout FROM local_accounts WHERE local_account_id = ?',
      variables: [const Variable<String>('google_iso_bad')],
    ).get();
    expect(registry.single.read<String>('db_layout'), 'separate');
    // The unrelated workspace is fully usable.
    final goodAgain = await fresh.databaseForWorkspace('google_iso_good');
    expect(await recordCount(goodAgain, 'google_iso_good'), 1);
  });

  test('§8 isolation: a wrong-owner file is rejected for that workspace only',
      () async {
    await manager.ensureGoogleWorkspace('google_owner_a');
    await manager.ensureGoogleWorkspace('google_owner_b');
    final aName =
        DatabaseManager.googleFileNameForWorkspaceId('google_owner_a');
    final bName =
        DatabaseManager.googleFileNameForWorkspaceId('google_owner_b');
    await manager.close();
    // Swap the two files: each now carries the other's owner marker.
    final tmp = File('${directory.path}/swap_tmp');
    await File('${directory.path}/$aName').rename(tmp.path);
    await File('${directory.path}/$bName').rename('${directory.path}/$aName');
    await tmp.rename('${directory.path}/$bName');

    final fresh = buildManager();
    addTearDown(fresh.close);
    await expectLater(
      fresh.databaseForWorkspace('google_owner_a'),
      throwsStateError,
    );
    await expectLater(
      fresh.databaseForWorkspace('google_owner_b'),
      throwsStateError,
    );
  });

  test('canonical hash is mapping-invariant and content-sensitive', () async {
    await registerSharedGoogle('google_hash');
    await insertRecord(control, id: 'hr', owner: 'google_hash');
    final before = await WorkspaceCanonicalContent.hash(control, 'google_hash');
    await manager.runStartupMigrations();
    final target = await manager.databaseForWorkspace('google_hash');
    final after = await WorkspaceCanonicalContent.hash(target, 'google_hash');
    expect(after, before);
    await target.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status, created_at, updated_at)
         VALUES ('hr2', 'google_hash', 'zuhr', 1, 'pending', 1, 1)''',
    );
    final changed = await WorkspaceCanonicalContent.hash(target, 'google_hash');
    expect(changed, isNot(before));
  });
}
