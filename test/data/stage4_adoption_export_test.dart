import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/database_manager.dart';
import 'package:qaza_namaz/data/local/database/workspace_canonical_content.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

/// Recovery Stage 4 — §8 matrix evidence for cross-file Guest adoption
/// with the §4 finalizing + staging-publish sequence (R-05), retry at
/// the finalizing boundaries, and full-export completeness across
/// layouts including §5.4 retained superseded rows (R-14).
void main() {
  late Directory directory;
  late AppDatabase control;
  late DatabaseManager manager;
  late AccountLocalStore store;
  late LocalBackupService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qaza-stage4-svc-');
    control = AppDatabase(
      NativeDatabase(File('${directory.path}/control.sqlite')),
    );
    manager = DatabaseManager(
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
    );
    store = AccountLocalStore(database: control, databaseManager: manager);
    service = LocalBackupService(control, databaseManager: manager);
    await control.readDbRevision();
  });

  tearDown(() async {
    await manager.close();
    // DatabaseManager does not own the injected control connection.
    // Close it before deleting the temp directory (required on Windows).
    await control.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Future<String> seedGuestWithRecord() async {
    final guestId = await store.createGuestWorkspace(displayName: 'Amina');
    await store.saveProfile(
      guestId,
      UserProfile(
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(1990, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 15,
        witrIncluded: true,
        onboardingCompleted: true,
      ),
    );
    await control.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'stage4_record',
        userId: guestId,
        prayerType: PrayerType.fajr.name,
        originalDate: DateTime(2025, 1, 1),
        status: QazaStatus.pending.name,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );
    await store.activate(guestId);
    return guestId;
  }

  Future<void> seedAdoptionJournalAndSnapshot({
    required String guestId,
    required String googleId,
    required String phase,
  }) async {
    final operationId = 'guest-adoption:$guestId=>$googleId';
    final payload = await service.exportJson(localAccountId: guestId);
    await control.customStatement('''
      CREATE TABLE IF NOT EXISTS local_account_adoption_snapshots (
        snapshot_id TEXT NOT NULL PRIMARY KEY,
        source_local_account_id TEXT NOT NULL,
        target_local_account_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    await control.customInsert(
      '''INSERT INTO local_account_adoption_snapshots
         (snapshot_id, source_local_account_id, target_local_account_id,
          created_at, payload_json)
         VALUES (?, ?, ?, ?, ?)''',
      variables: [
        Variable<String>(operationId),
        Variable<String>(guestId),
        Variable<String>(googleId),
        Variable<String>(DateTime.now().toUtc().toIso8601String()),
        Variable<String>(payload),
      ],
    );
    final now = DateTime.now().microsecondsSinceEpoch;
    final finalName = DatabaseManager.googleFileNameForWorkspaceId(googleId);
    // A real finalizing record carries the full intent: staging/final
    // file names and the canonical content hash.
    final contentHash =
        await WorkspaceCanonicalContent.ownedContentHash(control, guestId);
    await control.customInsert(
      '''INSERT INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, snapshot_id, created_at, updated_at,
          staging_file, final_file, content_hash)
         VALUES (?, 'guest_adoption', ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable<String>(operationId),
        Variable<String>(guestId),
        Variable<String>(googleId),
        Variable<String>(phase),
        Variable<String>(operationId),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>('$finalName.adoption-staging'),
        Variable<String>(finalName),
        Variable<String>(contentHash),
      ],
    );
  }

  Future<void> expectAdoptionCommitted(
    String guestId,
    String googleId,
  ) async {
    final target = await manager.databaseForWorkspace(googleId);
    final records = await target.qazaRecordsDao.getAll(userId: googleId);
    expect(records.map((r) => r.id), ['stage4_record']);
    final states = await control.customSelect(
      'SELECT local_account_id, lifecycle_state FROM local_accounts '
      'WHERE local_account_id IN (?, ?)',
      variables: [Variable<String>(guestId), Variable<String>(googleId)],
    ).get();
    final byId = {
      for (final row in states)
        row.read<String>('local_account_id'):
            row.read<String>('lifecycle_state'),
    };
    expect(byId[guestId], 'adopted_recovery');
    expect(byId[googleId], 'active');
    final journal = await control.customSelect(
      'SELECT phase, staging_file, final_file, content_hash '
      'FROM workspace_operation_journal WHERE operation_id = ?',
      variables: [Variable<String>('guest-adoption:$guestId=>$googleId')],
    ).get();
    expect(journal.single.read<String>('phase'), 'committed');
    expect(journal.single.read<String?>('staging_file'),
        '${DatabaseManager.googleFileNameForWorkspaceId(googleId)}.adoption-staging');
    expect(journal.single.read<String?>('final_file'),
        DatabaseManager.googleFileNameForWorkspaceId(googleId));
    expect(journal.single.read<String?>('content_hash'), isNotNull);
    // No staging or pre-adoption files are left behind.
    final names =
        await directory.list().map((e) => e.uri.pathSegments.last).toList();
    expect(names.where((n) => n.contains('.adoption-')), isEmpty);
  }

  test('cross-file adoption publishes via staging and commits (§4)', () async {
    final guestId = await seedGuestWithRecord();
    const googleId = 'google_stage4_adopt';
    await manager.ensureGoogleWorkspace(googleId);

    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
    await expectAdoptionCommitted(guestId, googleId);
    expect(manager.activeWorkspaceId, googleId);
  });

  test(
      'retry at finalizing after publish but before commit resumes '
      'without duplicating', () async {
    final guestId = await seedGuestWithRecord();
    const googleId = 'google_stage4_resume_published';
    await manager.ensureGoogleWorkspace(googleId);
    await seedAdoptionJournalAndSnapshot(
      guestId: guestId,
      googleId: googleId,
      phase: 'finalizing',
    );
    // The publish already happened before the crash: the live target
    // file holds the adopted content (via the same scoped import the
    // staging step performs), but the adoption journal never committed.
    final payload = await service.exportJson(localAccountId: guestId);
    await service.importJson(payload, targetLocalAccountId: googleId);

    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
    await expectAdoptionCommitted(guestId, googleId);
  });

  test('retry at finalizing with staging lost redoes the staging import',
      () async {
    final guestId = await seedGuestWithRecord();
    const googleId = 'google_stage4_resume_lost';
    await manager.ensureGoogleWorkspace(googleId);
    await seedAdoptionJournalAndSnapshot(
      guestId: guestId,
      googleId: googleId,
      phase: 'finalizing',
    );

    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
    await expectAdoptionCommitted(guestId, googleId);
  });

  test('retry at copied phase redoes the staging import exactly once',
      () async {
    final guestId = await seedGuestWithRecord();
    const googleId = 'google_stage4_resume_copied';
    await manager.ensureGoogleWorkspace(googleId);
    await seedAdoptionJournalAndSnapshot(
      guestId: guestId,
      googleId: googleId,
      phase: 'copied',
    );

    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
    await expectAdoptionCommitted(guestId, googleId);
  });

  test(
      'full export contains every workspace exactly once across layouts, '
      'including after migration retention (R-14)', () async {
    final guestId = await seedGuestWithRecord();

    Future<void> addRecord(AppDatabase db, String owner, String id) async {
      await db.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: id,
          userId: owner,
          prayerType: PrayerType.fajr.name,
          originalDate: DateTime(2025, 1, 1),
          status: QazaStatus.pending.name,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      );
    }

    const separateA = 'google_export_a';
    final aDb = await manager.ensureGoogleWorkspace(separateA);
    await addRecord(aDb, separateA, 'export_a_record');

    const sharedB = 'google_export_b';
    await store.ensureAccountActive(sharedB); // registry row, shared layout
    await addRecord(control, sharedB, 'export_b_record');

    const separateC = 'google_export_c';
    final cDb = await manager.ensureGoogleWorkspace(separateC);
    await addRecord(cDb, separateC, 'export_c_record');

    List<String> exportedRecordIds(String json) {
      final root = jsonDecode(json) as Map<String, dynamic>;
      final data = root['data'] as Map<String, dynamic>;
      return [
        for (final row in data['qaza_records'] as List<dynamic>)
          (row as Map)['id'] as String,
      ];
    }

    const expected = [
      'export_a_record',
      'export_b_record',
      'export_c_record',
      'stage4_record',
    ];
    final first = exportedRecordIds(await service.exportJson());
    expect(first..sort(), expected);
    expect(first.toSet().length, first.length, reason: 'no duplicates');

    // Migrate the shared workspace: its rows are retained in control as
    // superseded (§5.4) AND live in its file. The export must still
    // contain the record exactly once.
    final report = await manager.runStartupMigrations();
    expect(report.migrated, [sharedB]);
    final second = exportedRecordIds(await service.exportJson());
    expect(second..sort(), expected);
    expect(second.toSet().length, second.length, reason: 'no duplicates');
    expect(guestId, isNotEmpty); // guest leg came from control throughout
  });

  test('full export fails explicitly when a separate workspace cannot open',
      () async {
    const separateD = 'google_export_d';
    await manager.ensureGoogleWorkspace(separateD);
    final fileName = DatabaseManager.googleFileNameForWorkspaceId(separateD);
    // Close the original manager before removing its open database file.
    await manager.close();
    // A fresh manager has no cached handle, so the open must fail
    // against the missing file instead of silently skipping the
    // workspace.
    final freshManager = DatabaseManager(
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
    );
    addTearDown(freshManager.close);
    await File('${directory.path}/$fileName').delete();
    final failingService =
        LocalBackupService(control, databaseManager: freshManager);
    await expectLater(failingService.exportJson(), throwsStateError);
  });
}
