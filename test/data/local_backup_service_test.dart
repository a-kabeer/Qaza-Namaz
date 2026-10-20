import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';

QazaRecordsCompanion _record(String id, DateTime date) =>
    _recordFor('guest', id, date);

QazaRecordsCompanion _recordFor(
  String userId,
  String id,
  DateTime date,
) =>
    QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr.name,
      originalDate: date,
      status: QazaStatus.pending.name,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  late AppDatabase database;
  late LocalBackupService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
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

  test('fresh meta store starts at revision 1', () async {
    expect(await database.isOnboardingCompleted(), isFalse);
    expect(await database.readDbRevision(), 1);
  });

  test('one logical multi-row transaction increments revision once', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_2', DateTime(2025, 1, 2)),
      );
      return <int>[1, 1];
    });

    expect(await database.readDbRevision(), 2);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      2,
    );
  });

  test('no-op transaction does not advance db revision', () async {
    final beforeRevision = await database.readDbRevision();

    final changed = await database.transactionWithRevision(() async => false);

    expect(changed, isFalse);
    expect(await database.readDbRevision(), beforeRevision);
  });

  test('failed transaction rolls back state and db revision', () async {
    final beforeRevision = await database.readDbRevision();

    expect(
      () => database.transactionWithRevision(() async {
        await database.qazaRecordsDao.insertRecord(
          _record('guest_fajr_failed', DateTime(2025, 1, 1)),
        );
        throw StateError('forced transaction failure');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await database.readDbRevision(), beforeRevision);
    expect(
      await database.qazaRecordsDao.getAll(userId: 'guest'),
      isEmpty,
    );
  });

  test('export uses the stable versioned metadata header', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded = jsonDecode(await service.exportJson());
    expect(decoded['metadata']['app_id'], 'qaza_namaz_app');
    expect(decoded['metadata']['backup_schema_version'], 1);
    expect(
      decoded['metadata']['database_schema_version'],
      database.schemaVersion,
    );
    expect(decoded['metadata']['db_revision'], 2);
    expect(decoded['metadata']['export_timestamp'], isA<String>());
    expect(decoded['data']['qaza_records'], hasLength(1));
    expect(decoded['data']['local_accounts'], isA<List<dynamic>>());
    expect(decoded['data']['daily_salah_logs'], isA<List<dynamic>>());
    expect(decoded['data']['meta_store']['is_onboarding_completed'], false);
    expect(
      decoded['data']['meta_store']['daily_salah_tracking_enabled'],
      false,
    );
  });

  test('cloud export contains only the requested local workspace', () async {
    const googleId = 'google:account-A';
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString(googleId),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await database.qazaRecordsDao.insertRecord(
      _record('guest_record', DateTime(2025, 1, 1)),
    );
    await database.qazaRecordsDao.insertRecord(
      _recordFor(googleId, 'google_record', DateTime(2025, 1, 2)),
    );
    await AccountLocalStore(database: database).saveWorkspaceDisplayName(
      googleId,
      'Google Account A',
    );

    final decoded = jsonDecode(
      await service.exportJson(localAccountId: googleId),
    );

    expect(decoded['data']['local_accounts'], hasLength(1));
    expect(
      decoded['data']['local_accounts'].single['local_account_id'],
      googleId,
    );
    expect(decoded['data']['qaza_records'], hasLength(1));
    expect(decoded['data']['qaza_records'].single['userId'], googleId);
    expect(
      decoded['data']['app_session_state'].single['active_local_account_id'],
      googleId,
    );
    expect(
      decoded['data']['meta_store']['workspace_display_names_by_account'],
      {googleId: 'Google Account A'},
    );
  });

  test('workspace revisions ignore writes to other workspaces', () async {
    const accountA = 'google:account-A';
    const accountB = 'google:account-B';
    final now = DateTime.now().microsecondsSinceEpoch;
    for (final accountId in [accountA, accountB]) {
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
           VALUES (?, 'local', 'active', ?, ?)''',
        variables: [
          Variable.withString(accountId),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );
    }

    final beforeA = await database.readWorkspaceRevision(accountA);
    final beforeB = await database.readWorkspaceRevision(accountB);
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _recordFor(accountB, 'workspace_b_record', DateTime(2025, 1, 3)),
      );
      return true;
    });

    expect(await database.readWorkspaceRevision(accountA), beforeA);
    expect(
      await database.readWorkspaceRevision(accountB),
      greaterThan(beforeB),
    );

    final decoded = jsonDecode(
      await service.exportJson(localAccountId: accountA),
    ) as Map<String, dynamic>;
    expect(
      (decoded['metadata'] as Map<String, dynamic>)['db_revision'],
      beforeA,
    );
  });

  test(
      'scoped restore restores onboarding and tracking settings for the active workspace',
      () async {
    const googleId = 'google:account-onboarding';
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString(googleId),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    final accounts = AccountLocalStore(database: database);
    await accounts.saveProfile(
      googleId,
      const UserProfile(onboardingCompleted: true),
    );
    await accounts.activate(googleId);
    await database.setDailySalahTrackingEnabled(true, userId: googleId);
    final remoteBackup = await service.exportJson(localAccountId: googleId);

    // Simulate a fresh local copy of the target workspace before restore.
    await database.customUpdate(
      'DELETE FROM account_profiles WHERE local_account_id = ?',
      variables: [Variable.withString(googleId)],
    );
    await accounts.activate(googleId);
    expect(await database.isOnboardingCompleted(), isFalse);
    await database.setDailySalahTrackingEnabled(false, userId: googleId);

    await service.importJson(
      remoteBackup,
      targetLocalAccountId: googleId,
    );

    expect(await database.isOnboardingCompleted(), isTrue);
    expect(
      await database.isDailySalahTrackingEnabled(userId: googleId),
      isTrue,
    );
    final restored = await accounts.loadProfile(googleId);
    expect(restored?.onboardingCompleted, isTrue);
    expect(
      (await accounts.activeAccount())!.localAccountId,
      googleId,
    );
  });

  test('scoped cloud restore replaces only its workspace', () async {
    const googleId = 'google:account-A';
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString(googleId),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await database.qazaRecordsDao.insertRecord(
      _record('guest_record', DateTime(2025, 1, 1)),
    );
    await database.qazaRecordsDao.insertRecord(
      _recordFor(googleId, 'remote_google_record', DateTime(2025, 1, 2)),
    );
    final remoteBackup = await service.exportJson(localAccountId: googleId);

    await database.qazaRecordsDao.deleteById(
      userId: googleId,
      id: 'remote_google_record',
    );
    await database.qazaRecordsDao.insertRecord(
      _recordFor(googleId, 'local_google_record', DateTime(2025, 1, 3)),
    );

    await service.importJson(
      remoteBackup,
      targetLocalAccountId: googleId,
    );

    final guestRows = await database.qazaRecordsDao.getAll(userId: 'guest');
    final googleRows = await database.qazaRecordsDao.getAll(userId: googleId);
    expect(guestRows.map((row) => row.id), contains('guest_record'));
    expect(googleRows.map((row) => row.id), contains('remote_google_record'));
    expect(googleRows.map((row) => row.id),
        isNot(contains('local_google_record')));
    final activeSession = await database
        .customSelect(
          'SELECT active_local_account_id FROM app_session_state WHERE id = 1',
        )
        .getSingle();
    expect(activeSession.read<String>('active_local_account_id'), 'guest');
  });

  test(
      'legacy Guest cloud backup adoption remaps Qaza IDs and linked references',
      () async {
    const googleId = 'google:account-adopt';
    final date = DateTime(2025, 1, 1);
    const guestRecordId = 'guest_fajr_2025-01-01';
    await database.qazaRecordsDao.insertRecord(
      _record(guestRecordId, date),
    );
    const additionId = 'guest_addition_adopt';
    const deletionActionId = 'guest_delete_action_adopt';
    final timestamp = DateTime.utc(2025, 1, 1).toIso8601String();
    await database.customInsert(
      '''INSERT INTO qaza_additions
         (id, user_id, mode, input_snapshot, revision, created_at, updated_at)
         VALUES (?, ?, 'single', '{}', 1, ?, ?)''',
      variables: [
        Variable.withString(additionId),
        Variable.withString('guest'),
        Variable.withString(timestamp),
        Variable.withString(timestamp),
      ],
    );
    await database.customInsert(
      '''INSERT INTO qaza_deletion_actions
         (id, user_id, addition_id, created_at, resolved_at, entity_version)
         VALUES (?, ?, ?, ?, NULL, 1)''',
      variables: [
        Variable.withString(deletionActionId),
        Variable.withString('guest'),
        Variable.withString(additionId),
        Variable.withString(timestamp),
      ],
    );
    await database.customInsert(
      '''INSERT INTO qaza_deletion_action_record_snapshots
         (deletion_action_id, record_id, user_id, addition_id, prayer_type,
          original_date, status, completed_at, completion_id, created_at,
          updated_at, record_version)
         VALUES (?, ?, ?, ?, 'fajr', '2025-01-01', 'pending', NULL, NULL,
                 ?, ?, 1)''',
      variables: [
        Variable.withString(deletionActionId),
        Variable.withString(guestRecordId),
        Variable.withString('guest'),
        Variable.withString(additionId),
        Variable.withString(timestamp),
        Variable.withString(timestamp),
      ],
    );
    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status,
          tracker_created_qaza_id, linked_qaza_id, completion_sync_id,
          updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withString('2025-01-01'),
        Variable.withString('fajr'),
        Variable.withString('missed'),
        Variable.withString(guestRecordId),
        Variable.withString(guestRecordId),
        Variable.withString('sync-adopt-1'),
        Variable.withString(DateTime.utc(2025, 1, 1).toIso8601String()),
      ],
    );

    final backup = await service.exportJson(localAccountId: 'guest');
    await service.importJson(backup, targetLocalAccountId: googleId);

    final guestRows = await database.qazaRecordsDao.getAll(userId: 'guest');
    final googleRows = await database.qazaRecordsDao.getAll(userId: googleId);
    const adoptedRecordId = 'google:account-adopt_fajr_2025-01-01';
    expect(guestRows.map((row) => row.id), contains(guestRecordId));
    expect(googleRows.map((row) => row.id), contains(adoptedRecordId));
    expect(
      googleRows.map((row) => row.id).toSet().intersection(
            guestRows.map((row) => row.id).toSet(),
          ),
      isEmpty,
    );

    final links = await database.customSelect(
      'SELECT tracker_created_qaza_id, linked_qaza_id FROM daily_salah_logs '
      'WHERE user_id = ?',
      variables: [Variable.withString(googleId)],
    ).get();
    expect(links, hasLength(1));
    expect(
      links.single.read<String?>('tracker_created_qaza_id'),
      adoptedRecordId,
    );
    expect(links.single.read<String?>('linked_qaza_id'), adoptedRecordId);

    const adoptedAdditionId = 'google:account-adopt_guest_addition_adopt';
    const adoptedDeletionActionId =
        'google:account-adopt_guest_delete_action_adopt';
    final actions = await database.customSelect(
      'SELECT id, addition_id FROM qaza_deletion_actions WHERE user_id = ?',
      variables: [Variable.withString(googleId)],
    ).get();
    expect(actions, hasLength(1));
    expect(actions.single.read<String>('id'), adoptedDeletionActionId);
    expect(actions.single.read<String>('addition_id'), adoptedAdditionId);

    final snapshots = await database.customSelect(
      'SELECT record_id, user_id, deletion_action_id, addition_id '
      'FROM qaza_deletion_action_record_snapshots WHERE user_id = ?',
      variables: [Variable.withString(googleId)],
    ).get();
    expect(snapshots, hasLength(1));
    expect(snapshots.single.read<String>('record_id'), adoptedRecordId);
    expect(snapshots.single.read<String>('user_id'), googleId);
    expect(
      snapshots.single.read<String>('deletion_action_id'),
      adoptedDeletionActionId,
    );
    expect(snapshots.single.read<String>('addition_id'), adoptedAdditionId);
  });

  test('workspace sync block prevents cloud uploads after uncertain discovery', () async {
    const googleWorkspace = 'google:account-unverified';
    await database.writeWorkspaceSyncState(
      googleWorkspace,
      'cloud_unverified',
      localRevision: 4,
    );
    expect(
      await database.isWorkspaceCloudUploadBlocked(googleWorkspace),
      isTrue,
    );

    await database.writeWorkspaceSyncState(
      googleWorkspace,
      'pending',
      localRevision: 4,
    );
    expect(
      await database.isWorkspaceCloudUploadBlocked(googleWorkspace),
      isFalse,
    );
  });

  test('Guest deletion is undoable and retains records during the hold', () async {
    final store = AccountLocalStore(database: database);
    final guestId = await store.createGuestWorkspace(displayName: 'Study Guest');
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'guest_retained_during_hold', DateTime(2025, 2, 1)),
    );
    final otherGuest = await store.createGuestWorkspace(displayName: 'Other Guest');
    await store.activate(otherGuest);

    final requested = DateTime(2026, 10, 1);
    final expiry = await store.scheduleGuestWorkspaceDeletion(
      guestId,
      requestedAt: requested,
    );
    expect(expiry, requested.add(const Duration(days: 7)));
    expect(await store.getAccount(guestId), isNotNull);
    expect(await store.hasAnyAccountData(guestId), isTrue);
    expect(
      (await store.listGuestWorkspaces()).map((account) => account.localAccountId),
      isNot(contains(guestId)),
    );
    expect(await store.undoGuestWorkspaceDeletion(guestId), isTrue);
    expect(
      (await store.getAccount(guestId))!.lifecycleState,
      AccountLifecycleState.active,
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: guestId)).single.id,
      'guest_retained_during_hold',
    );
  });

  test('expired Guest deletion is purged only after seven days', () async {
    final store = AccountLocalStore(database: database);
    final guestId = await store.createGuestWorkspace(displayName: 'Expired Guest');
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'guest_expired_record', DateTime(2025, 2, 2)),
    );
    final otherGuest = await store.createGuestWorkspace(displayName: 'Keep Guest');
    await store.activate(otherGuest);
    final requested = DateTime(2026, 10, 1);
    await store.scheduleGuestWorkspaceDeletion(guestId, requestedAt: requested);

    expect(
      await store.purgeExpiredGuestWorkspaceDeletions(
        now: requested.add(const Duration(days: 6)),
      ),
      0,
    );
    expect(await store.getAccount(guestId), isNotNull);
    expect(
      await store.purgeExpiredGuestWorkspaceDeletions(
        now: requested.add(const Duration(days: 8)),
      ),
      1,
    );
    expect(await store.getAccount(guestId), isNull);
    expect(await database.qazaRecordsDao.getAll(userId: guestId), isEmpty);
  });

  test('backup preserves daily Salah links and the tracking preference',
      () async {
    await database.qazaRecordsDao.insertRecord(
      _record('guest_fajr_linked', DateTime(2025, 1, 1)),
    );
    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status,
          tracker_created_qaza_id, linked_qaza_id, completion_sync_id,
          updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withString('2026-10-16'),
        Variable.withString('fajr'),
        Variable.withString('prayed'),
        Variable.withString('guest_fajr_linked'),
        Variable.withString('guest_fajr_linked'),
        Variable.withString('completion-sync-1'),
        Variable.withString(DateTime.utc(2026, 10, 16).toIso8601String()),
      ],
    );
    await database.setDailySalahTrackingEnabled(true);
    final backup = await service.exportJson();

    await database.customStatement('DELETE FROM daily_salah_logs');
    await database.setDailySalahTrackingEnabled(false);
    expect(await database.isDailySalahTrackingEnabled(), isFalse);

    await service.importJson(backup);

    expect(await database.isDailySalahTrackingEnabled(), isTrue);
    final logs = await database
        .customSelect(
          'SELECT user_id, prayer_date, prayer_type, status, '
          'linked_qaza_id, completion_sync_id FROM daily_salah_logs',
        )
        .get();
    expect(logs, hasLength(1));
    expect(logs.single.read<String>('prayer_date'), '2026-10-16');
    expect(logs.single.read<String>('status'), 'prayed');
    expect(logs.single.read<String?>('linked_qaza_id'), 'guest_fajr_linked');
    expect(
      logs.single.read<String?>('completion_sync_id'),
      'completion-sync-1',
    );
  });

  test('schema 19 backups without daily tracking fields remain importable',
      () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    metadata['database_schema_version'] = 19;
    data.remove('daily_salah_logs');
    (data['meta_store'] as Map<String, dynamic>)
        .remove('daily_salah_tracking_enabled');

    await service.importJson(jsonEncode(decoded));

    expect(await database.isDailySalahTrackingEnabled(), isFalse);
    final logs = await database
        .customSelect(
          'SELECT user_id FROM daily_salah_logs',
        )
        .get();
    expect(logs, isEmpty);
  });

  test('schema 20 backups migrate Daily Salah links into schema 22', () async {
    await database.qazaRecordsDao.insertRecord(
      _record('guest_fajr_linked', DateTime(2025, 1, 1)),
    );
    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status,
          tracker_created_qaza_id, linked_qaza_id, completion_sync_id,
          updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withString('2026-10-16'),
        Variable.withString('fajr'),
        Variable.withString('prayed'),
        Variable.withString('guest_fajr_linked'),
        Variable.withString('guest_fajr_linked'),
        Variable.withString('completion-sync-before-v20'),
        Variable.withString(DateTime.utc(2026, 10, 16).toIso8601String()),
      ],
    );
    await database.setDailySalahTrackingEnabled(true);

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    metadata['database_schema_version'] = 20;
    data['daily_salah_logs'] =
        (data['daily_salah_logs'] as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('linked_qaza_id');
      row.remove('completion_sync_id');
      return row;
    }).toList();
    final legacyBackup = jsonEncode(decoded);

    expect((await service.analyzeImport(legacyBackup)).recordCount, 1);
    await database.customStatement('DELETE FROM daily_salah_logs');
    await database.setDailySalahTrackingEnabled(false);

    await service.importJson(legacyBackup);

    expect(await database.isDailySalahTrackingEnabled(), isTrue);
    final logs = await database
        .customSelect(
          'SELECT linked_qaza_id, completion_sync_id FROM daily_salah_logs',
        )
        .get();
    expect(logs, hasLength(1));
    expect(logs.single.read<String?>('linked_qaza_id'), 'guest_fajr_linked');
    expect(logs.single.read<String?>('completion_sync_id'), equals(null));
  });

  test('malformed import leaves existing local database untouched', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final before = await database.qazaRecordsDao.getAll(userId: 'guest');
    final beforeRevision = await database.readDbRevision();

    expect(
      () => service.importJson('{bad json'),
      throwsA(isA<LocalBackupException>()),
    );

    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .map((record) => record.toJson())
          .toList(),
      before.map((record) => record.toJson()).toList(),
    );
    expect(await database.readDbRevision(), beforeRevision);
  });

  test('malformed daily Salah rows are rejected before database mutation',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_existing', DateTime(2025, 1, 1)),
      );
      return true;
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['data'] as Map<String, dynamic>)['daily_salah_logs'] = [
      <String, dynamic>{
        'user_id': 'guest',
        'prayer_date': '2026-10-16',
        'prayer_type': 'not-a-prayer',
        'status': 'prayed',
        'tracker_created_qaza_id': null,
        'linked_qaza_id': null,
        'completion_sync_id': null,
        'updated_at': DateTime.utc(2026, 10, 16).toIso8601String(),
      },
    ];

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .map((record) => record.id)
          .toList(),
      ['guest_fajr_existing'],
    );
    expect(await database.readDbRevision(), 2);
  });

  test('failed restore transaction preserves existing local data', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_existing', DateTime(2025, 1, 1)),
      );
      return true;
    });
    final backup = await service.exportJson();

    await database.customStatement('''
      CREATE TRIGGER fail_qaza_restore_insert
      BEFORE INSERT ON qaza_records
      BEGIN
        SELECT RAISE(ABORT, 'forced restore failure');
      END
    ''');

    expect(() => service.importJson(backup), throwsA(anything));
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .map((record) => record.id)
          .toList(),
      ['guest_fajr_existing'],
    );
    expect(await database.readDbRevision(), 2);
  });

  test('wrong app id is rejected before database mutation', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['app_id'] = 'other_app';

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('newer backup schema is rejected before database mutation', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['backup_schema_version'] = 2;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('App update required'),
        ),
      ),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('newer database schema requires an app update without data loss',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_existing', DateTime(2025, 1, 1)),
      );
      return true;
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['database_schema_version'] =
        23;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('Update Qaza Namaz'),
        ),
      ),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .map((record) => record.id)
          .toList(),
      ['guest_fajr_existing'],
    );
    expect(await database.readDbRevision(), 2);
  });

  test('export normalizes a supplied timestamp to UTC', () async {
    final json = await service.exportJson(
      exportedAt: DateTime(2026, 10, 8, 12, 34, 56),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final timestamp = (decoded['metadata']
        as Map<String, dynamic>)['export_timestamp'] as String;

    expect(timestamp, '2026-10-08T12:34:56.000Z');
  });

  test('unsupported older backup schema is rejected without mutation',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['backup_schema_version'] = 0;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('invalid'),
        ),
      ),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('restoring an older revision never rewinds the local revision',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });
    final olderBackup = await service.exportJson();

    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_2', DateTime(2025, 1, 2)),
      );
    });
    expect(await database.readDbRevision(), 3);

    final restored = await service.importJson(olderBackup);

    expect(restored.recordCount, 1);
    expect(await database.readDbRevision(), 4);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).map((r) => r.id),
      ['guest_fajr_1'],
    );
  });

  test('backup restore preserves the receiving device instance id', () async {
    await database.customInsert(
      'INSERT INTO device_metadata (id, device_instance_id) VALUES (1, ?)',
      variables: [Variable.withString('device-local-test')],
    );

    final backup = await service.exportJson();
    await service.importJson(backup);

    final after = await database
        .customSelect(
          'SELECT device_instance_id FROM device_metadata WHERE id = 1',
        )
        .get();

    expect(
      after.single.read<String>('device_instance_id'),
      'device-local-test',
    );

    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(jsonEncode(decoded['data']).contains('device-local-test'), isFalse);
  });

  test(
      'Guest adoption is recoverable, atomic, and remaps plan owner references',
      () async {
    final store = AccountLocalStore(database: database);
    final guestId = await store.createGuestWorkspace(displayName: 'Amina');
    final profile = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1990, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    await store.saveProfile(guestId, profile);
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'guest_adoption_fajr', DateTime(2025, 1, 1)),
    );
    await database.customInsert(
      '''INSERT INTO account_plan_revisions
         (local_account_id, revision_id, payload_json, created_at)
         VALUES (?, ?, ?, ?)''',
      variables: [
        Variable(guestId),
        Variable('guest-plan-revision'),
        Variable(jsonEncode({
          'userId': guestId,
          'revisionId': 'guest-plan-revision',
        })),
        Variable(DateTime(2025, 1, 1).microsecondsSinceEpoch),
      ],
    );

    const googleId = 'google:stable-adoption-account';
    await store.ensureAccountActive(googleId);
    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );

    expect(await database.qazaRecordsDao.getAll(userId: guestId), isEmpty);
    expect(
      (await database.qazaRecordsDao.getAll(userId: googleId))
          .map((record) => record.id),
      ['guest_adoption_fajr'],
    );
    expect((await store.getAccount(guestId))?.lifecycleState,
        AccountLifecycleState.archived);
    expect((await store.getAccount(googleId))?.displayName, 'Amina Google');
    expect(await store.hasAnyAccountData(guestId), isFalse);
    expect(await store.hasAnyAccountData(googleId), isTrue);

    final revisionRows = await database.customSelect(
      'SELECT payload_json FROM account_plan_revisions '
      'WHERE local_account_id = ?',
      variables: [Variable(googleId)],
    ).get();
    expect(revisionRows, hasLength(1));
    expect(
      jsonDecode(revisionRows.single.read<String>('payload_json'))['userId'],
      googleId,
    );

    final snapshots = await database.customSelect(
      'SELECT payload_json FROM local_account_adoption_snapshots '
      'WHERE source_local_account_id = ? AND target_local_account_id = ?',
      variables: [Variable(guestId), Variable(googleId)],
    ).get();
    expect(snapshots, hasLength(1));
    final recovery = jsonDecode(snapshots.single.read<String>('payload_json'));
    expect(
      recovery['data']['local_accounts'].single['local_account_id'],
      guestId,
    );
    expect(recovery['data']['qaza_records'], hasLength(1));
    final activeRows = await database
        .customSelect(
          'SELECT active_local_account_id FROM app_session_state WHERE id = 1',
        )
        .get();
    expect(activeRows.single.read<String>('active_local_account_id'), googleId);
  });

  test('Guest adoption refuses to overwrite an existing Google workspace',
      () async {
    final store = AccountLocalStore(database: database);
    final guestId = await store.createGuestWorkspace(displayName: 'Amina');
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'guest_must_survive', DateTime(2025, 1, 2)),
    );
    const googleId = 'google:existing-workspace';
    await store.ensureAccountActive(googleId);
    await database.qazaRecordsDao.insertRecord(
      _recordFor(googleId, 'google_existing_record', DateTime(2025, 1, 3)),
    );

    await expectLater(
      service.adoptGuestWorkspace(
        sourceLocalAccountId: guestId,
        targetGoogleLocalAccountId: googleId,
        googleDisplayName: 'Amina Google',
      ),
      throwsA(isA<LocalBackupException>()),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: guestId))
          .map((record) => record.id),
      ['guest_must_survive'],
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: googleId))
          .map((record) => record.id),
      ['google_existing_record'],
    );
  });

  test('initial cloud backup marker belongs to the workspace that created it',
      () async {
    final store = AccountLocalStore(database: database);
    await database.markInitialCloudBackupPending();

    expect(await database.hasPendingInitialCloudBackup(), isTrue);

    const googleId = 'google:independent-workspace';
    await store.ensureAccountActive(googleId);
    expect(await database.hasPendingInitialCloudBackup(), isFalse);

    await store.activate('guest');
    expect(await database.hasPendingInitialCloudBackup(), isTrue);

    await store.activate(googleId);
    await database.clearPendingInitialCloudBackup(localAccountId: googleId);
    expect(await database.hasPendingInitialCloudBackup(), isFalse);

    await store.activate('guest');
    expect(await database.hasPendingInitialCloudBackup(), isTrue);
  });
}
