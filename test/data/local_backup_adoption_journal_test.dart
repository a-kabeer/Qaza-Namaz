import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

QazaRecordsCompanion _recordFor(String userId, String id, DateTime date) =>
    QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr.name,
      originalDate: date,
      status: QazaStatus.pending.name,
      createdAt: date,
      updatedAt: date,
    );

/// Process-kill / resume tests for the Guest -> Google adoption journal.
///
/// Each test pre-seeds `workspace_operation_journal` in the state a killed
/// process would have left behind, then calls the adoption entry point
/// again. The retry must resume or fail safely: the Guest data is adopted
/// exactly once, never duplicated, and never lost.
void main() {
  late AppDatabase database;
  late LocalBackupService service;
  late AccountLocalStore store;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
    store = AccountLocalStore(database: database);
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await database.customInsert(
      '''INSERT INTO app_session_state (id, active_local_account_id)
         VALUES (1, ?)''',
      variables: [Variable.withString('guest')],
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Creates a Guest workspace holding one Qaza record and a completed
  /// profile, plus an empty verified Google workspace ready to adopt it.
  Future<({String guestId, String googleId, String operationId})>
      seedAdoptableGuest() async {
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
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'journal_fajr_1', DateTime(2025, 1, 1)),
    );
    const googleId = 'google_stable-journal-account';
    await store.ensureAccountActive(googleId);
    return (
      guestId: guestId,
      googleId: googleId,
      operationId: 'guest-adoption:$guestId=>$googleId',
    );
  }

  Future<void> insertJournal({
    required String operationId,
    required String guestId,
    required String googleId,
    required String phase,
    String? snapshotId,
  }) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, snapshot_id, created_at, updated_at)
         VALUES (?, 'guest_adoption', ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable(operationId),
        Variable(guestId),
        Variable(googleId),
        Variable(phase),
        Variable(snapshotId),
        Variable(now),
        Variable(now),
      ],
    );
  }

  Future<void> expectAdoptedExactlyOnce({
    required String guestId,
    required String googleId,
  }) async {
    expect(await database.qazaRecordsDao.getAll(userId: guestId), isEmpty);
    expect(
      (await database.qazaRecordsDao.getAll(
        userId: googleId,
      ))
          .map((record) => record.id),
      ['journal_fajr_1'],
    );
    expect(
      (await store.getAccount(guestId))?.lifecycleState,
      AccountLifecycleState.adoptedRecovery,
    );
    expect(
      (await store.getAccount(googleId))?.lifecycleState,
      AccountLifecycleState.active,
    );
    final snapshots = await database.customSelect(
      'SELECT payload_json FROM local_account_adoption_snapshots '
      'WHERE source_local_account_id = ? AND target_local_account_id = ?',
      variables: [Variable(guestId), Variable(googleId)],
    ).get();
    expect(snapshots, hasLength(1));
    final recovery = jsonDecode(snapshots.single.read<String>('payload_json'));
    expect(recovery['data']['qaza_records'], hasLength(1));
    final journal = await database
        .customSelect(
          'SELECT phase FROM workspace_operation_journal',
        )
        .get();
    expect(journal, hasLength(1));
    expect(journal.single.read<String>('phase'), 'committed');
    final session = await database
        .customSelect(
          'SELECT active_local_account_id FROM app_session_state WHERE id = 1',
        )
        .get();
    expect(session.single.read<String>('active_local_account_id'), googleId);
  }

  test(
    'adoption resumes when a previous attempt died in the prepared phase',
    () async {
      final seed = await seedAdoptableGuest();
      // The killed attempt had written its journal entry but died before
      // the recovery snapshot was stored.
      await insertJournal(
        operationId: seed.operationId,
        guestId: seed.guestId,
        googleId: seed.googleId,
        phase: 'prepared',
      );

      await service.adoptGuestWorkspace(
        sourceLocalAccountId: seed.guestId,
        targetGoogleLocalAccountId: seed.googleId,
        googleDisplayName: 'Amina Google',
      );

      await expectAdoptedExactlyOnce(
        guestId: seed.guestId,
        googleId: seed.googleId,
      );
    },
  );

  test(
    'adoption resumes when a previous attempt died in the snapshotted phase',
    () async {
      final seed = await seedAdoptableGuest();
      // The killed attempt had stored and verified its recovery snapshot
      // but died before the ownership commit.
      final snapshotJson = await service.exportJson(
        localAccountId: seed.guestId,
      );
      await database.customStatement('''
        CREATE TABLE IF NOT EXISTS local_account_adoption_snapshots (
          snapshot_id TEXT NOT NULL PRIMARY KEY,
          source_local_account_id TEXT NOT NULL,
          target_local_account_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await database.customInsert(
        '''INSERT INTO local_account_adoption_snapshots
           (snapshot_id, source_local_account_id, target_local_account_id,
            created_at, payload_json)
           VALUES (?, ?, ?, ?, ?)''',
        variables: [
          Variable(seed.operationId),
          Variable(seed.guestId),
          Variable(seed.googleId),
          Variable(DateTime.now().toUtc().toIso8601String()),
          Variable(snapshotJson),
        ],
      );
      await insertJournal(
        operationId: seed.operationId,
        guestId: seed.guestId,
        googleId: seed.googleId,
        phase: 'snapshotted',
        snapshotId: seed.operationId,
      );

      await service.adoptGuestWorkspace(
        sourceLocalAccountId: seed.guestId,
        targetGoogleLocalAccountId: seed.googleId,
        googleDisplayName: 'Amina Google',
      );

      await expectAdoptedExactlyOnce(
        guestId: seed.guestId,
        googleId: seed.googleId,
      );
      // The retry must reuse the persisted snapshot bytes, not rewrite them.
      final snapshots = await database.customSelect(
        'SELECT payload_json FROM local_account_adoption_snapshots '
        'WHERE snapshot_id = ?',
        variables: [Variable(seed.operationId)],
      ).get();
      expect(snapshots.single.read<String>('payload_json'), snapshotJson);
    },
  );

  test(
    're-running a committed adoption is a safe no-op',
    () async {
      final seed = await seedAdoptableGuest();
      await service.adoptGuestWorkspace(
        sourceLocalAccountId: seed.guestId,
        targetGoogleLocalAccountId: seed.googleId,
        googleDisplayName: 'Amina Google',
      );
      await expectAdoptedExactlyOnce(
        guestId: seed.guestId,
        googleId: seed.googleId,
      );

      // A retry after the commit (e.g. the UI replays the flow after a
      // restart) must neither throw nor adopt the same records twice.
      await service.adoptGuestWorkspace(
        sourceLocalAccountId: seed.guestId,
        targetGoogleLocalAccountId: seed.googleId,
        googleDisplayName: 'Amina Google',
      );

      await expectAdoptedExactlyOnce(
        guestId: seed.guestId,
        googleId: seed.googleId,
      );
    },
  );
}
