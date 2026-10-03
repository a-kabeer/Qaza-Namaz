
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/user_profile.dart';
import 'database/app_database.dart';

class AccountLocalStore {
  AccountLocalStore({required this.database});

  final AppDatabase database;

  Future<void> ensureInitialized({
    required bool hasLegacyProfile,
    required bool hasLegacyQaza,
    UserProfile? legacyProfile,
  }) async {
    await _ensureDeviceId();
    final legacy = legacyProfile ?? await _readLegacyProfile();
    await _ensureGuestAccount(
      hasLegacyProfile: hasLegacyProfile || legacy != null,
      hasLegacyQaza: hasLegacyQaza,
      legacyProfile: legacy,
    );
    await _migrateLegacyPlanRevisions();
  }

  Future<UserProfile?> _readLegacyProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(UserProfile.storageKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UserProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _migrateLegacyPlanRevisions() async {
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'qaza_plan_revision_v1_guest_';
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final revision = QazaPlanRevision.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        await savePlanRevision(UserProfile.localLedgerUserId, revision);
      } catch (_) {
        // Preserve the legacy key; a malformed historical revision must not
        // block the rest of account initialization.
      }
    }
  }

  Future<bool> hasAnyQaza(String localAccountId) async {
    final rows = await database.customSelect(
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      variables: [Variable(localAccountId)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<String> deviceInstanceId() async {
    final rows = await database.customSelect(
      'SELECT device_instance_id FROM device_metadata WHERE id = 1 LIMIT 1',
    ).get();
    if (rows.isNotEmpty) return rows.first.read<String>('device_instance_id');

    final id = _randomId('device');
    await database.customInsert(
      'INSERT INTO device_metadata (id, device_instance_id) VALUES (1, ?)',
      variables: [Variable(id)],
    );
    return id;
  }

  Future<void> _ensureDeviceId() => deviceInstanceId().then((_) {});

  Future<LocalAccount?> getAccount(String localAccountId) async {
    final rows = await database.customSelect(
      '''SELECT local_account_id, account_mode, firebase_uid, google_email,
                lifecycle_state, cloud_backup_enabled, cloud_generation,
                created_at, updated_at
         FROM local_accounts
         WHERE local_account_id = ?
         LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    return rows.isEmpty ? null : _mapAccount(rows.first);
  }

  Future<LocalAccount?> findGoogleByUid(String uid) async {
    final rows = await database.customSelect(
      '''SELECT local_account_id, account_mode, firebase_uid, google_email,
                lifecycle_state, cloud_backup_enabled, cloud_generation,
                created_at, updated_at
         FROM local_accounts
         WHERE firebase_uid = ? AND account_mode = 'google'
           AND lifecycle_state <> 'archived'
         LIMIT 1''',
      variables: [Variable(uid)],
    ).get();
    return rows.isEmpty ? null : _mapAccount(rows.first);
  }

  Future<LocalAccount?> activeAccount() async {
    final rows = await database.customSelect(
      '''SELECT a.local_account_id, a.account_mode, a.firebase_uid,
                a.google_email, a.lifecycle_state, a.cloud_backup_enabled,
                a.cloud_generation, a.created_at, a.updated_at
         FROM app_session_state s
         LEFT JOIN local_accounts a
           ON a.local_account_id = s.active_local_account_id
         WHERE s.id = 1
         LIMIT 1''',
    ).get();
    if (rows.isEmpty || rows.first.read<String?>('local_account_id') == null) {
      return null;
    }
    return _mapAccount(rows.first);
  }

  Future<bool> initialChoiceRequired() async {
    final rows = await database.customSelect(
      'SELECT initial_choice_required FROM app_session_state WHERE id = 1',
    ).get();
    return rows.isNotEmpty && rows.first.read<int>('initial_choice_required') != 0;
  }

  Future<String?> activeLocalAccountId() async {
    final rows = await database.customSelect(
      'SELECT active_local_account_id FROM app_session_state WHERE id = 1',
    ).get();
    return rows.isEmpty
        ? null
        : rows.first.read<String?>('active_local_account_id');
  }

  Future<void> setInitialChoiceRequired(bool required) async {
    await database.customUpdate(
      'UPDATE app_session_state SET initial_choice_required = ? WHERE id = 1',
      variables: [Variable(required ? 1 : 0)],
    );
  }

  Future<void> setMigrationState(String value) async {
    await database.customUpdate(
      'UPDATE app_session_state SET migration_state = ? WHERE id = 1',
      variables: [Variable(value)],
    );
  }

  Future<void> setRestoreState(String value) async {
    await database.customUpdate(
      'UPDATE app_session_state SET restore_state = ? WHERE id = 1',
      variables: [Variable(value)],
    );
  }

  Future<void> activate(String localAccountId) async {
    final account = await getAccount(localAccountId);
    if (account == null) throw StateError('Local account not found: $localAccountId');
    if (account.lifecycleState == AccountLifecycleState.archived) {
      throw StateError('Archived local account cannot become active.');
    }
    await database.customUpdate(
      '''UPDATE app_session_state
         SET active_local_account_id = ?, initial_choice_required = 0
         WHERE id = 1''',
      variables: [Variable(localAccountId)],
    );
  }

  Future<String> ensureGuestActive() async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final guest = await getAccount(UserProfile.localLedgerUserId);
    if (guest == null) {
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, firebase_uid, google_email,
            lifecycle_state, cloud_backup_enabled, cloud_generation,
            created_at, updated_at)
           VALUES ('guest', 'guest', NULL, NULL, 'active', 0, 1, ?, ?)''',
        variables: [Variable(now), Variable(now)],
      );
      await activate(UserProfile.localLedgerUserId);
      return UserProfile.localLedgerUserId;
    }
    if (guest.lifecycleState == AccountLifecycleState.archived) {
      final freshGuestId = _randomId('guest');
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, firebase_uid, google_email,
            lifecycle_state, cloud_backup_enabled, cloud_generation,
            created_at, updated_at)
           VALUES (?, 'guest', NULL, NULL, 'active', 0, 1, ?, ?)''',
        variables: [Variable(freshGuestId), Variable(now), Variable(now)],
      );
      await activate(freshGuestId);
      return freshGuestId;
    }
    await activate(guest.localAccountId);
    return guest.localAccountId;
  }

  Future<String> createGooglePartition({
    required String firebaseUid,
    required String? email,
  }) async {
    final existing = await findGoogleByUid(firebaseUid);
    if (existing != null) return existing.localAccountId;

    final id = _randomId('google');
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, firebase_uid, google_email,
          lifecycle_state, cloud_backup_enabled, cloud_generation,
          created_at, updated_at)
         VALUES (?, 'google', ?, ?, 'active', 1, 1, ?, ?)''',
      variables: [
        Variable(id),
        Variable(firebaseUid),
        Variable(email),
        Variable(now),
        Variable(now),
      ],
    );
    return id;
  }

  Future<String> cloneGuestToGoogle({
    required String firebaseUid,
    required String? email,
  }) async {
    final existing = await findGoogleByUid(firebaseUid);
    if (existing != null) return existing.localAccountId;

    final guest = await getAccount(UserProfile.localLedgerUserId);
    if (guest == null) {
      return createGooglePartition(firebaseUid: firebaseUid, email: email);
    }

    final target = _randomId('google');
    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();

    await database.transaction(() async {
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, firebase_uid, google_email,
            lifecycle_state, cloud_backup_enabled, cloud_generation,
            created_at, updated_at)
           VALUES (?, 'google', ?, ?, 'migrating', 1, 1, ?, ?)''',
        variables: [
          Variable(target),
          Variable(firebaseUid),
          Variable(email),
          Variable(now),
          Variable(now),
        ],
      );

      await database.customUpdate(
        '''INSERT INTO qaza_records
           (id, user_id, prayer_type, original_date, status, completed_at,
            completion_id, addition_id, record_version, created_at, updated_at)
           SELECT id, ?, prayer_type, original_date, status, completed_at,
                  completion_id, addition_id, record_version, created_at, updated_at
           FROM qaza_records WHERE user_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''INSERT INTO qaza_profile_plan_provenance
           (record_id, user_id, plan_revision_id, plan_fingerprint)
           SELECT record_id, ?, plan_revision_id, plan_fingerprint
           FROM qaza_profile_plan_provenance WHERE user_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''INSERT INTO qaza_additions
           (id, user_id, mode, input_snapshot, revision, created_at, updated_at)
           SELECT id, ?, mode, input_snapshot, revision, created_at, updated_at
           FROM qaza_additions WHERE user_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''INSERT INTO qaza_deletion_actions
           (id, user_id, addition_id, created_at, resolved_at)
           SELECT id, ?, addition_id, created_at, resolved_at
           FROM qaza_deletion_actions WHERE user_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''INSERT INTO qaza_deletion_action_record_snapshots
           (deletion_action_id, record_id, user_id, addition_id,
            prayer_type, original_date, status, completed_at, completion_id,
            created_at, updated_at, record_version)
           SELECT deletion_action_id, record_id, ?, addition_id, prayer_type,
                  original_date, status, completed_at, completion_id, created_at,
                  updated_at, record_version
           FROM qaza_deletion_action_record_snapshots WHERE user_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''INSERT INTO account_profiles
           (local_account_id, payload_json, entity_version, updated_at,
            writer_device_id, operation_id)
           SELECT ?, payload_json, entity_version, updated_at, ?, operation_id
           FROM account_profiles WHERE local_account_id = ?''',
        variables: [
          Variable(target),
          Variable(device),
          Variable(guest.localAccountId),
        ],
      );
      await database.customUpdate(
        '''INSERT INTO account_plan_revisions
           (local_account_id, revision_id, payload_json, created_at)
           SELECT ?, revision_id, payload_json, created_at
           FROM account_plan_revisions WHERE local_account_id = ?''',
        variables: [Variable(target), Variable(guest.localAccountId)],
      );
      await database.customUpdate(
        '''UPDATE app_session_state
           SET active_local_account_id = ?,
               initial_choice_required = 0,
               migration_state = 'target_ready'
           WHERE id = 1''',
        variables: [Variable(guest.localAccountId)],
      );
    });
    return target;
  }

  Future<void> finalizeGuestMigration({
    required String guestLocalAccountId,
    required String googleLocalAccountId,
  }) async {
    await database.transaction(() async {
      final guest = await getAccount(guestLocalAccountId);
      final google = await getAccount(googleLocalAccountId);
      if (guest == null || google == null) {
        throw StateError('Migration partitions are missing.');
      }
      if (!google.isGoogle) {
        throw StateError('Migration target is not a Google account.');
      }
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'archived', updated_at = ?
           WHERE local_account_id = ?''',
        variables: [Variable(now), Variable(guestLocalAccountId)],
      );
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'active', updated_at = ?
           WHERE local_account_id = ?''',
        variables: [Variable(now), Variable(googleLocalAccountId)],
      );
      await database.customUpdate(
        '''UPDATE app_session_state
           SET active_local_account_id = ?, migration_state = 'completed'
           WHERE id = 1''',
        variables: [Variable(googleLocalAccountId)],
      );
    });
  }

  Future<void> deleteLocalAccount(String localAccountId) async {
    if (localAccountId == UserProfile.localLedgerUserId) {
      throw StateError('The base Guest partition cannot be removed.');
    }
    await database.transaction(() async {
      await database.customDelete(
        'DELETE FROM qaza_records WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM qaza_profile_plan_provenance WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM qaza_additions WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM qaza_deletion_actions WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM qaza_deletion_action_record_snapshots WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM account_plan_revisions WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM entity_metadata WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM qaza_record_tombstones WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM sync_outbox WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customDelete(
        'DELETE FROM local_accounts WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
    });
  }

  Future<void> updateGoogleAccount({
    required String localAccountId,
    required String uid,
    required String? email,
    required bool backupEnabled,
    required int generation,
  }) async {
    await database.customUpdate(
      '''UPDATE local_accounts
         SET account_mode = 'google',
             firebase_uid = ?,
             google_email = ?,
             lifecycle_state = 'active',
             cloud_backup_enabled = ?,
             cloud_generation = ?,
             updated_at = ?
         WHERE local_account_id = ?''',
      variables: [
        Variable(uid),
        Variable(email),
        Variable(backupEnabled ? 1 : 0),
        Variable(generation),
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(localAccountId),
      ],
    );
  }

  Future<void> setBackupEnabled(String localAccountId, bool enabled) async {
    await database.customUpdate(
      '''UPDATE local_accounts
         SET cloud_backup_enabled = ?, updated_at = ?
         WHERE local_account_id = ?''',
      variables: [
        Variable(enabled ? 1 : 0),
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(localAccountId),
      ],
    );
  }

  Future<void> setCloudGeneration(String localAccountId, int generation) async {
    await database.customUpdate(
      '''UPDATE local_accounts
         SET cloud_generation = ?, updated_at = ?
         WHERE local_account_id = ?''',
      variables: [
        Variable(generation),
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(localAccountId),
      ],
    );
  }

  Future<UserProfile?> loadProfile(String localAccountId) async {
    final rows = await database.customSelect(
      '''SELECT payload_json FROM account_profiles
         WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first.read<String>('payload_json'));
      if (decoded is! Map) return null;
      return UserProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(String localAccountId, UserProfile profile) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();
    final opId = _randomId('op');
    await database.transaction(() async {
      await database.customUpdate(
        '''INSERT INTO account_profiles
           (local_account_id, payload_json, entity_version, updated_at,
            writer_device_id, operation_id)
           VALUES (?, ?, 1, ?, ?, ?)
           ON CONFLICT(local_account_id) DO UPDATE SET
             payload_json = excluded.payload_json,
             entity_version = account_profiles.entity_version + 1,
             updated_at = excluded.updated_at,
             writer_device_id = excluded.writer_device_id,
             operation_id = excluded.operation_id''',
        variables: [
          Variable(localAccountId),
          Variable(jsonEncode(profile.toJson())),
          Variable(now),
          Variable(device),
          Variable(opId),
        ],
      );
      await _enqueueSnapshotInsideTransaction(localAccountId, now, device);
    });
  }

  Future<void> clearProfile(String localAccountId) async {
    await database.customDelete(
      'DELETE FROM account_profiles WHERE local_account_id = ?',
      variables: [Variable(localAccountId)],
    );
  }

  Future<List<QazaPlanRevision>> loadPlanRevisions(
    String localAccountId,
  ) async {
    final rows = await database.customSelect(
      '''SELECT payload_json FROM account_plan_revisions
         WHERE local_account_id = ?
         ORDER BY created_at DESC''',
      variables: [Variable(localAccountId)],
    ).get();
    final result = <QazaPlanRevision>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.read<String>('payload_json'));
        if (decoded is Map) {
          result.add(
            QazaPlanRevision.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {}
    }
    return result;
  }

  Future<void> savePlanRevision(
    String localAccountId,
    QazaPlanRevision revision,
  ) async {
    final payload = jsonEncode(revision.toJson());
    final existing = await database.customSelect(
      '''SELECT payload_json FROM account_plan_revisions
         WHERE local_account_id = ? AND revision_id = ? LIMIT 1''',
      variables: [
        Variable(localAccountId),
        Variable(revision.revisionId),
      ],
    ).get();
    if (existing.isNotEmpty) {
      if (existing.first.read<String>('payload_json') != payload) {
        throw StateError('Immutable QazaPlanRevision conflict.');
      }
      return;
    }
    await database.transaction(() async {
      await database.customInsert(
        '''INSERT INTO account_plan_revisions
           (local_account_id, revision_id, payload_json, created_at)
           VALUES (?, ?, ?, ?)''',
        variables: [
          Variable(localAccountId),
          Variable(revision.revisionId),
          Variable(payload),
          Variable(revision.createdAt.microsecondsSinceEpoch),
        ],
      );
      await _enqueueSnapshotInsideTransaction(
        localAccountId,
        DateTime.now().microsecondsSinceEpoch,
        await deviceInstanceId(),
      );
    });
  }

  Future<List<Map<String, Object?>>> loadModernOutboxBatch({
    required String localAccountId,
    required int nowMicros,
    int limit = 20,
  }) async {
    final rows = await database.customSelect(
      '''SELECT id, user_id, firebase_uid, cloud_generation,
                entity_type, operation, payload_json, queued_at,
                next_attempt_at, attempts, last_error
         FROM sync_outbox
         WHERE user_id = ?
           AND type = 'account_snapshot'
           AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
           AND (lease_until IS NULL OR lease_until <= ?)
         ORDER BY queued_at ASC, id ASC
         LIMIT ?''',
      variables: [
        Variable(localAccountId),
        Variable(nowMicros),
        Variable(nowMicros),
        Variable(limit),
      ],
    ).get();
    return [
      for (final row in rows)
        {
          'id': row.read<String>('id'),
          'user_id': row.read<String>('user_id'),
          'firebase_uid': row.read<String?>('firebase_uid'),
          'cloud_generation': row.read<int?>('cloud_generation'),
          'entity_type': row.read<String?>('entity_type'),
          'operation': row.read<String?>('operation'),
          'payload_json': row.read<String?>('payload_json'),
          'queued_at': row.read<int>('queued_at'),
          'next_attempt_at': row.read<int?>('next_attempt_at'),
          'attempts': row.read<int>('attempts'),
          'last_error': row.read<String?>('last_error'),
        },
    ];
  }

  Future<bool> claimOutbox({
    required String localAccountId,
    required String operationId,
    required String workerId,
    required int leaseUntilMicros,
  }) async {
    final changed = await database.customUpdate(
      '''UPDATE sync_outbox
         SET worker_id = ?, lease_until = ?
         WHERE user_id = ? AND id = ?
           AND type = 'account_snapshot'
           AND (lease_until IS NULL OR lease_until <= ?)''',
      variables: [
        Variable(workerId),
        Variable(leaseUntilMicros),
        Variable(localAccountId),
        Variable(operationId),
        Variable(DateTime.now().microsecondsSinceEpoch),
      ],
    );
    return changed > 0;
  }

  Future<void> removeOutboxOperation({
    required String localAccountId,
    required String operationId,
  }) async {
    await database.customDelete(
      'DELETE FROM sync_outbox WHERE user_id = ? AND id = ?',
      variables: [Variable(localAccountId), Variable(operationId)],
    );
  }

  Future<void> removeAllOutboxForGeneration({
    required String localAccountId,
    required int generation,
  }) async {
    await database.customDelete(
      '''DELETE FROM sync_outbox
         WHERE user_id = ? AND
               type = 'account_snapshot' AND
               cloud_generation <> ?''',
      variables: [Variable(localAccountId), Variable(generation)],
    );
  }

  Future<void> markOutboxRetry({
    required String localAccountId,
    required String operationId,
    required int attempts,
    required String error,
    required int nextAttemptMicros,
  }) async {
    await database.customUpdate(
      '''UPDATE sync_outbox
         SET attempts = ?, last_error = ?, next_attempt_at = ?,
             worker_id = NULL, lease_until = NULL
         WHERE user_id = ? AND id = ?''',
      variables: [
        Variable(attempts),
        Variable(error),
        Variable(nextAttemptMicros),
        Variable(localAccountId),
        Variable(operationId),
      ],
    );
  }

  Future<void> enqueueSnapshot(String localAccountId) async {
    final rows = await database.customSelect(
      '''SELECT firebase_uid, cloud_generation, cloud_backup_enabled
         FROM local_accounts WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (rows.isEmpty) return;
    final enabled = rows.first.read<int>('cloud_backup_enabled') != 0;
    final uid = rows.first.read<String?>('firebase_uid');
    if (!enabled || uid == null || uid.isEmpty) return;

    final device = await deviceInstanceId();
    final now = DateTime.now().microsecondsSinceEpoch;
    final id = _randomId('snapshot');
    await database.customInsert(
      '''INSERT INTO sync_outbox
         (id, user_id, type, queued_at, firebase_uid, cloud_generation,
          entity_type, operation, next_attempt_at, attempts, worker_id,
          lease_until, writer_device_id)
         VALUES (?, ?, 'account_snapshot', ?, ?, ?, 'account', 'snapshot',
                 ?, 0, NULL, NULL, ?)''',
      variables: [
        Variable(id),
        Variable(localAccountId),
        Variable(now),
        Variable(uid),
        Variable(rows.first.read<int>('cloud_generation')),
        Variable(now),
        Variable(device),
      ],
    );
  }

  Future<void> _enqueueSnapshotInsideTransaction(
    String localAccountId,
    int nowMicros,
    String writerDeviceId,
  ) async {
    final rows = await database.customSelect(
      '''SELECT firebase_uid, cloud_generation, cloud_backup_enabled
         FROM local_accounts WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (rows.isEmpty || rows.first.read<int>('cloud_backup_enabled') == 0) {
      return;
    }
    final uid = rows.first.read<String?>('firebase_uid');
    if (uid == null || uid.isEmpty) return;
    await database.customInsert(
      '''INSERT INTO sync_outbox
         (id, user_id, type, queued_at, firebase_uid, cloud_generation,
          entity_type, operation, next_attempt_at, attempts, worker_id,
          lease_until, writer_device_id)
         VALUES (?, ?, 'account_snapshot', ?, ?, ?, 'account', 'snapshot',
                 ?, 0, NULL, NULL, ?)''',
      variables: [
        Variable(_randomId('snapshot')),
        Variable(localAccountId),
        Variable(nowMicros),
        Variable(uid),
        Variable(rows.first.read<int>('cloud_generation')),
        Variable(nowMicros),
        Variable(writerDeviceId),
      ],
    );
  }

  Future<void> _ensureGuestAccount({
    required bool hasLegacyProfile,
    required bool hasLegacyQaza,
    UserProfile? legacyProfile,
  }) async {
    final rows = await database.customSelect(
      'SELECT local_account_id FROM local_accounts WHERE local_account_id = ?',
      variables: [Variable(UserProfile.localLedgerUserId)],
    ).get();
    if (rows.isEmpty) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, firebase_uid, google_email,
            lifecycle_state, cloud_backup_enabled, cloud_generation,
            created_at, updated_at)
           VALUES ('guest', 'guest', NULL, NULL, 'active', 0, 1, ?, ?)''',
        variables: [Variable(now), Variable(now)],
      );
    }

    final sessionRows = await database.customSelect(
      'SELECT id FROM app_session_state WHERE id = 1',
    ).get();
    if (sessionRows.isEmpty) {
      final initialChoiceRequired = !hasLegacyProfile && !hasLegacyQaza;
      await database.customInsert(
        '''INSERT INTO app_session_state
           (id, active_local_account_id, initial_choice_required,
            migration_state, restore_state)
           VALUES (1, ?, ?, 'none', 'none')''',
        variables: [
          Variable(
            initialChoiceRequired ? null : UserProfile.localLedgerUserId,
          ),
          Variable(initialChoiceRequired ? 1 : 0),
        ],
      );
    }

    if (legacyProfile != null) {
      final existing = await loadProfile(UserProfile.localLedgerUserId);
      if (existing == null) {
        await database.customInsert(
          '''INSERT OR IGNORE INTO account_profiles
             (local_account_id, payload_json, entity_version, updated_at,
              writer_device_id, operation_id)
             VALUES (?, ?, 1, ?, ?, ?)''',
          variables: [
            Variable(UserProfile.localLedgerUserId),
            Variable(jsonEncode(legacyProfile.toJson())),
            Variable(DateTime.now().microsecondsSinceEpoch),
            Variable(await deviceInstanceId()),
            Variable(_randomId('migrate')),
          ],
        );
      }
    }
  }

  LocalAccount _mapAccount(QueryRow row) {
    return LocalAccount(
      localAccountId: row.read<String>('local_account_id'),
      accountMode: AccountMode.values.byName(row.read<String>('account_mode')),
      firebaseUid: row.read<String?>('firebase_uid'),
      googleEmail: row.read<String?>('google_email'),
      lifecycleState:
          AccountLifecycleState.values.byName(row.read<String>('lifecycle_state')),
      cloudBackupEnabled: row.read<int>('cloud_backup_enabled') != 0,
      cloudGeneration: row.read<int>('cloud_generation'),
      createdAt:
          DateTime.fromMicrosecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt:
          DateTime.fromMicrosecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }

  String _randomId(String prefix) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return prefix + '_' + hex;
  }

  String jsonEncode(Object value) => json.encode(value);
}
