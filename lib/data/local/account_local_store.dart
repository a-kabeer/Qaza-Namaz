
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/conflict_resolver.dart';
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

  Future<String> migrationState() async {
    final rows = await database.customSelect(
      'SELECT migration_state FROM app_session_state WHERE id = 1',
    ).get();
    return rows.isEmpty
        ? 'none'
        : rows.first.read<String>('migration_state');
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

    if (guest == null ||
        !guest.isGuest ||
        guest.lifecycleState == AccountLifecycleState.archived) {
      final freshGuestId =
          guest == null ? UserProfile.localLedgerUserId : _randomId('guest');
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

  Future<bool> hasAnyAccountData(String localAccountId) async {
    const queries = [
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_additions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_actions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_action_record_snapshots WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM account_profiles WHERE local_account_id = ? LIMIT 1',
      'SELECT 1 FROM account_plan_revisions WHERE local_account_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_record_tombstones WHERE local_account_id = ? LIMIT 1',
    ];
    for (final query in queries) {
      final rows = await database.customSelect(
        query,
        variables: [Variable(localAccountId)],
      ).get();
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<VersionedEntity> _localEntityStamp(
    String localAccountId,
    String entityType,
    String entityId, {
    required int fallbackVersion,
    required DateTime fallbackUpdatedAt,
  }) async {
    final rows = await database.customSelect(
      '''SELECT entity_version, updated_at, writer_device_id, operation_id
         FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = ? AND entity_id = ?
         LIMIT 1''',
      variables: [
        Variable(localAccountId),
        Variable(entityType),
        Variable(entityId),
      ],
    ).get();
    if (rows.isEmpty) {
      return VersionedEntity(
        entityVersion: fallbackVersion,
        updatedAt: fallbackUpdatedAt,
        writerDeviceId: '',
        operationId: 'legacy_' + entityId,
        entityId: entityId,
      );
    }
    final row = rows.first;
    return VersionedEntity(
      entityVersion: row.read<int>('entity_version'),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
      writerDeviceId: row.read<String>('writer_device_id'),
      operationId: row.read<String>('operation_id'),
      entityId: entityId,
    );
  }

  VersionedEntity _rowEntityStamp({
    required String entityId,
    required int version,
    required DateTime updatedAt,
    String writerDeviceId = '',
    String operationId = '',
  }) {
    return VersionedEntity(
      entityVersion: version,
      updatedAt: updatedAt,
      writerDeviceId: writerDeviceId,
      operationId: operationId.isEmpty ? 'legacy_' + entityId : operationId,
      entityId: entityId,
    );
  }

  String _mergeBusinessKey(
    String prayerType,
    DateTime date,
  ) =>
      prayerType +
      '|' +
      date.year.toString() +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');

  Future<void> mergeGuestIntoGooglePartition({
    required String guestLocalAccountId,
    required String googleLocalAccountId,
  }) async {
    if (guestLocalAccountId == googleLocalAccountId) return;

    final guest = await getAccount(guestLocalAccountId);
    final google = await getAccount(googleLocalAccountId);
    if (guest == null || google == null || !google.isGoogle) {
      throw StateError('Guest/Google migration partitions are unavailable.');
    }

    await database.transaction(() async {
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'migrating',
               cloud_backup_enabled = 1,
               updated_at = ?
           WHERE local_account_id = ?''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(googleLocalAccountId),
        ],
      );

      // ---------- Profile ----------
      final guestProfileRows = await database.customSelect(
        '''SELECT payload_json, entity_version, updated_at,
                  writer_device_id, operation_id
           FROM account_profiles
           WHERE local_account_id = ? LIMIT 1''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      final googleProfileRows = await database.customSelect(
        '''SELECT payload_json, entity_version, updated_at,
                  writer_device_id, operation_id
           FROM account_profiles
           WHERE local_account_id = ? LIMIT 1''',
        variables: [Variable(googleLocalAccountId)],
      ).get();

      if (guestProfileRows.isNotEmpty) {
        final guestProfile = guestProfileRows.first;
        final guestStamp = VersionedEntity(
          entityVersion: guestProfile.read<int>('entity_version'),
          updatedAt: DateTime.fromMicrosecondsSinceEpoch(
            guestProfile.read<int>('updated_at'),
          ),
          writerDeviceId: guestProfile.read<String>('writer_device_id'),
          operationId: guestProfile.read<String>('operation_id'),
          entityId: 'profile',
        );
        final keepGuest = googleProfileRows.isEmpty
            ? true
            : ConflictResolver().compare(
                  guestStamp,
                  VersionedEntity(
                    entityVersion:
                        googleProfileRows.first.read<int>('entity_version'),
                    updatedAt: DateTime.fromMicrosecondsSinceEpoch(
                      googleProfileRows.first.read<int>('updated_at'),
                    ),
                    writerDeviceId:
                        googleProfileRows.first.read<String>('writer_device_id'),
                    operationId:
                        googleProfileRows.first.read<String>('operation_id'),
                    entityId: 'profile',
                  ),
                ) > 0;
        if (keepGuest) {
          await database.customInsert(
            '''INSERT INTO account_profiles
               (local_account_id, payload_json, entity_version, updated_at,
                writer_device_id, operation_id)
               VALUES (?, ?, ?, ?, ?, ?)
               ON CONFLICT(local_account_id) DO UPDATE SET
                 payload_json = excluded.payload_json,
                 entity_version = excluded.entity_version,
                 updated_at = excluded.updated_at,
                 writer_device_id = excluded.writer_device_id,
                 operation_id = excluded.operation_id''',
            variables: [
              Variable(googleLocalAccountId),
              Variable(guestProfile.read<String>('payload_json')),
              Variable(guestProfile.read<int>('entity_version')),
              Variable(guestProfile.read<int>('updated_at')),
              Variable(guestProfile.read<String>('writer_device_id')),
              Variable(guestProfile.read<String>('operation_id')),
            ],
          );
          await database.customInsert(
            '''INSERT OR REPLACE INTO entity_metadata
               (local_account_id, entity_type, entity_id, entity_version,
                updated_at, writer_device_id, operation_id)
               VALUES (?, 'profile', 'profile', ?, ?, ?, ?)''',
            variables: [
              Variable(googleLocalAccountId),
              Variable(guestProfile.read<int>('entity_version')),
              Variable(guestProfile.read<int>('updated_at')),
              Variable(guestProfile.read<String>('writer_device_id')),
              Variable(guestProfile.read<String>('operation_id')),
            ],
          );
        }
      }

      // ---------- Qaza records ----------
      final guestRecords =
          await database.qazaRecordsDao.getAll(userId: guestLocalAccountId);
      final googleRecords =
          await database.qazaRecordsDao.getAll(userId: googleLocalAccountId);
      final googleById = <String, QazaRecord>{
        for (final record in googleRecords) record.id: record,
      };
      final googleByKey = <String, QazaRecord>{
        for (final record in googleRecords)
          _mergeBusinessKey(record.prayerType.name, record.originalDate):
              record,
      };
      final canonical = <String, QazaRecord>{...googleById};
      final guestWinningIds = <String>{};
      final targetLoserIds = <String>{};

      for (final guestRecord in guestRecords) {
        final sameId = googleById[guestRecord.id];
        if (sameId != null) {
          final guestStamp = await _localEntityStamp(
            guestLocalAccountId,
            'qazaRecord',
            guestRecord.id,
            fallbackVersion: guestRecord.recordVersion,
            fallbackUpdatedAt: guestRecord.updatedAt,
          );
          final googleStamp = await _localEntityStamp(
            googleLocalAccountId,
            'qazaRecord',
            sameId.id,
            fallbackVersion: sameId.recordVersion,
            fallbackUpdatedAt: sameId.updatedAt,
          );
          if (ConflictResolver().compare(guestStamp, googleStamp) > 0) {
            canonical[guestRecord.id] = guestRecord;
            guestWinningIds.add(guestRecord.id);
          }
          continue;
        }

        final key = _mergeBusinessKey(
          guestRecord.prayerType.name,
          guestRecord.originalDate,
        );
        final collision = googleByKey[key];
        if (collision == null) {
          canonical[guestRecord.id] = guestRecord;
          guestWinningIds.add(guestRecord.id);
          googleByKey[key] = guestRecord;
          continue;
        }

        final guestStamp = await _localEntityStamp(
          guestLocalAccountId,
          'qazaRecord',
          guestRecord.id,
          fallbackVersion: guestRecord.recordVersion,
          fallbackUpdatedAt: guestRecord.updatedAt,
        );
        final googleStamp = await _localEntityStamp(
          googleLocalAccountId,
          'qazaRecord',
          collision.id,
          fallbackVersion: collision.recordVersion,
          fallbackUpdatedAt: collision.updatedAt,
        );
        if (ConflictResolver().compare(guestStamp, googleStamp) > 0) {
          canonical.remove(collision.id);
          targetLoserIds.add(collision.id);
          canonical[guestRecord.id] = guestRecord;
          guestWinningIds.add(guestRecord.id);
          googleByKey[key] = guestRecord;
        }
      }

      for (final id in targetLoserIds) {
        await database.qazaRecordsDao.deleteById(
          userId: googleLocalAccountId,
          id: id,
        );
        await database.customUpdate(
          'DELETE FROM qaza_profile_plan_provenance '
          'WHERE user_id = ? AND record_id = ?',
          variables: [
            Variable(googleLocalAccountId),
            Variable(id),
          ],
        );
      }

      if (guestWinningIds.isNotEmpty) {
        final guestRows = guestWinningIds
            .map((id) => canonical[id])
            .whereType<QazaRecord>()
            .toList(growable: false);
        for (final record in guestRows) {
          await database.customInsert(
            '''INSERT INTO qaza_records
               (id, user_id, prayer_type, original_date, status, completed_at,
                completion_id, addition_id, record_version, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                 user_id = excluded.user_id,
                 prayer_type = excluded.prayer_type,
                 original_date = excluded.original_date,
                 status = excluded.status,
                 completed_at = excluded.completed_at,
                 completion_id = excluded.completion_id,
                 addition_id = excluded.addition_id,
                 record_version = excluded.record_version,
                 created_at = excluded.created_at,
                 updated_at = excluded.updated_at''',
            variables: [
              Variable(record.id),
              Variable(googleLocalAccountId),
              Variable(record.prayerType.name),
              Variable(record.originalDate),
              Variable(record.status.name),
              Variable(record.completedAt),
              Variable(record.completionId),
              Variable(record.additionId),
              Variable(record.recordVersion),
              Variable(record.createdAt),
              Variable(record.updatedAt),
            ],
          );
        }
      }

      // Remove target records that lost a same-business-key conflict or were
      // otherwise excluded by the canonical set.
      final canonicalIds = canonical.keys.toSet();
      for (final record in googleRecords) {
        if (!canonicalIds.contains(record.id) &&
            !targetLoserIds.contains(record.id)) {
          await database.qazaRecordsDao.deleteById(
            userId: googleLocalAccountId,
            id: record.id,
          );
          await database.customUpdate(
            'DELETE FROM qaza_profile_plan_provenance '
            'WHERE user_id = ? AND record_id = ?',
            variables: [
              Variable(googleLocalAccountId),
              Variable(record.id),
            ],
          );
        }
      }

      // ---------- Plan provenance ----------
      for (final id in guestWinningIds) {
        final rows = await database.customSelect(
          '''SELECT plan_revision_id, plan_fingerprint
             FROM qaza_profile_plan_provenance
             WHERE user_id = ? AND record_id = ? LIMIT 1''',
          variables: [
            Variable(guestLocalAccountId),
            Variable(id),
          ],
        ).get();
        if (rows.isEmpty) continue;
        await database.customInsert(
          '''INSERT OR REPLACE INTO qaza_profile_plan_provenance
             (record_id, user_id, plan_revision_id, plan_fingerprint)
             VALUES (?, ?, ?, ?)''',
          variables: [
            Variable(id),
            Variable(googleLocalAccountId),
            Variable(rows.first.read<String>('plan_revision_id')),
            Variable(rows.first.read<String>('plan_fingerprint')),
          ],
        );
      }

      // ---------- Additions ----------
      final guestAdditions = await database.customSelect(
        '''SELECT id, mode, input_snapshot, revision, created_at, updated_at
           FROM qaza_additions WHERE user_id = ?''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      final googleAdditionIds = (await database.customSelect(
        'SELECT id FROM qaza_additions WHERE user_id = ?',
        variables: [Variable(googleLocalAccountId)],
      ).get()).map((row) => row.read<String>('id')).toSet();

      for (final row in guestAdditions) {
        final id = row.read<String>('id');
        if (!googleAdditionIds.contains(id)) {
          await database.customInsert(
            '''INSERT INTO qaza_additions
               (id, user_id, mode, input_snapshot, revision, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            variables: [
              Variable(id),
              Variable(googleLocalAccountId),
              Variable(row.read<String>('mode')),
              Variable(row.read<String>('input_snapshot')),
              Variable(row.read<int>('revision')),
              Variable(row.read<String>('created_at')),
              Variable(row.read<String>('updated_at')),
            ],
          );
          continue;
        }

        final googleRow = (await database.customSelect(
          '''SELECT mode, input_snapshot, revision, updated_at
             FROM qaza_additions
             WHERE user_id = ? AND id = ? LIMIT 1''',
          variables: [Variable(googleLocalAccountId), Variable(id)],
        ).get()).first;
        final guestStamp = await _localEntityStamp(
          guestLocalAccountId,
          'qazaAddition',
          id,
          fallbackVersion: row.read<int>('revision'),
          fallbackUpdatedAt: DateTime.parse(row.read<String>('updated_at')),
        );
        final googleStamp = await _localEntityStamp(
          googleLocalAccountId,
          'qazaAddition',
          id,
          fallbackVersion: googleRow.read<int>('revision'),
          fallbackUpdatedAt:
              DateTime.parse(googleRow.read<String>('updated_at')),
        );
        if (ConflictResolver().compare(guestStamp, googleStamp) > 0) {
          await database.customUpdate(
            '''UPDATE qaza_additions
               SET mode = ?, input_snapshot = ?, revision = ?,
                   created_at = ?, updated_at = ?
               WHERE user_id = ? AND id = ?''',
            variables: [
              Variable(row.read<String>('mode')),
              Variable(row.read<String>('input_snapshot')),
              Variable(row.read<int>('revision')),
              Variable(row.read<String>('created_at')),
              Variable(row.read<String>('updated_at')),
              Variable(googleLocalAccountId),
              Variable(id),
            ],
          );
        }
      }

      // ---------- Deletion actions ----------
      final guestActions = await database.customSelect(
        '''SELECT id, addition_id, created_at, resolved_at, entity_version
           FROM qaza_deletion_actions WHERE user_id = ?''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      for (final row in guestActions) {
        final id = row.read<String>('id');
        final googleRows = await database.customSelect(
          '''SELECT id, addition_id, created_at, resolved_at, entity_version
             FROM qaza_deletion_actions
             WHERE user_id = ? AND id = ? LIMIT 1''',
          variables: [Variable(googleLocalAccountId), Variable(id)],
        ).get();
        if (googleRows.isEmpty) {
          await database.customInsert(
            '''INSERT INTO qaza_deletion_actions
               (id, user_id, addition_id, created_at, resolved_at, entity_version)
               VALUES (?, ?, ?, ?, ?, ?)''',
            variables: [
              Variable(id),
              Variable(googleLocalAccountId),
              Variable(row.read<String>('addition_id')),
              Variable(row.read<String>('created_at')),
              Variable(row.read<String?>('resolved_at')),
              Variable(row.read<int>('entity_version')),
            ],
          );
        } else {
          final googleRow = googleRows.first;
          final guestUpdated =
              DateTime.parse(row.read<String?>('resolved_at') ??
                  row.read<String>('created_at'));
          final googleUpdated =
              DateTime.parse(googleRow.read<String?>('resolved_at') ??
                  googleRow.read<String>('created_at'));
          final guestStamp = await _localEntityStamp(
            guestLocalAccountId,
            'deletionAction',
            id,
            fallbackVersion: row.read<int>('entity_version'),
            fallbackUpdatedAt: guestUpdated,
          );
          final googleStamp = await _localEntityStamp(
            googleLocalAccountId,
            'deletionAction',
            id,
            fallbackVersion: googleRow.read<int>('entity_version'),
            fallbackUpdatedAt: googleUpdated,
          );
          if (ConflictResolver().compare(guestStamp, googleStamp) > 0) {
            await database.customUpdate(
              '''UPDATE qaza_deletion_actions
                 SET addition_id = ?, created_at = ?, resolved_at = ?,
                     entity_version = ?
                 WHERE user_id = ? AND id = ?''',
              variables: [
                Variable(row.read<String>('addition_id')),
                Variable(row.read<String>('created_at')),
                Variable(row.read<String?>('resolved_at')),
                Variable(row.read<int>('entity_version')),
                Variable(googleLocalAccountId),
                Variable(id),
              ],
            );
          }
        }
      }

      // ---------- Immutable deletion snapshots ----------
      final guestSnapshots = await database.customSelect(
        '''SELECT deletion_action_id, record_id, user_id, addition_id,
                  prayer_type, original_date, status, completed_at,
                  completion_id, created_at, updated_at, record_version
           FROM qaza_deletion_action_record_snapshots
           WHERE user_id = ?''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      for (final row in guestSnapshots) {
        final existing = await database.customSelect(
          '''SELECT prayer_type, original_date, status, completed_at,
                    completion_id, created_at, updated_at, record_version
             FROM qaza_deletion_action_record_snapshots
             WHERE user_id = ? AND deletion_action_id = ? AND record_id = ?
             LIMIT 1''',
          variables: [
            Variable(googleLocalAccountId),
            Variable(row.read<String>('deletion_action_id')),
            Variable(row.read<String>('record_id')),
          ],
        ).get();
        if (existing.isEmpty) {
          await database.customInsert(
            '''INSERT INTO qaza_deletion_action_record_snapshots
               (deletion_action_id, record_id, user_id, addition_id,
                prayer_type, original_date, status, completed_at,
                completion_id, created_at, updated_at, record_version)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            variables: [
              Variable(row.read<String>('deletion_action_id')),
              Variable(row.read<String>('record_id')),
              Variable(googleLocalAccountId),
              Variable(row.read<String>('addition_id')),
              Variable(row.read<String>('prayer_type')),
              Variable(row.read<String>('original_date')),
              Variable(row.read<String?>('status')),
              Variable(row.read<String?>('completed_at')),
              Variable(row.read<String?>('completion_id')),
              Variable(row.read<String>('created_at')),
              Variable(row.read<String>('updated_at')),
              Variable(row.read<int>('record_version')),
            ],
          );
        } else {
          final same = existing.first.read<String>('prayer_type') ==
                  row.read<String>('prayer_type') &&
              existing.first.read<String>('original_date') ==
                  row.read<String>('original_date') &&
              existing.first.read<String?>('status') ==
                  row.read<String?>('status') &&
              existing.first.read<String?>('completed_at') ==
                  row.read<String?>('completed_at') &&
              existing.first.read<String?>('completion_id') ==
                  row.read<String?>('completion_id') &&
              existing.first.read<String>('created_at') ==
                  row.read<String>('created_at') &&
              existing.first.read<String>('updated_at') ==
                  row.read<String>('updated_at') &&
              existing.first.read<int>('record_version') ==
                  row.read<int>('record_version');
          if (!same) {
            throw StateError(
              'Immutable deletion snapshot conflict: ' +
                  row.read<String>('deletion_action_id') +
                  '/' +
                  row.read<String>('record_id'),
            );
          }
        }
      }

      // ---------- Immutable plan revisions ----------
      final guestRevisions = await database.customSelect(
        '''SELECT revision_id, payload_json, created_at
           FROM account_plan_revisions
           WHERE local_account_id = ?''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      for (final row in guestRevisions) {
        final id = row.read<String>('revision_id');
        final existing = await database.customSelect(
          '''SELECT payload_json FROM account_plan_revisions
             WHERE local_account_id = ? AND revision_id = ? LIMIT 1''',
          variables: [
            Variable(googleLocalAccountId),
            Variable(id),
          ],
        ).get();
        if (existing.isEmpty) {
          await database.customInsert(
            '''INSERT INTO account_plan_revisions
               (local_account_id, revision_id, payload_json, created_at)
               VALUES (?, ?, ?, ?)''',
            variables: [
              Variable(googleLocalAccountId),
              Variable(id),
              Variable(row.read<String>('payload_json')),
              Variable(row.read<int>('created_at')),
            ],
          );
        } else if (existing.first.read<String>('payload_json') !=
            row.read<String>('payload_json')) {
          throw StateError('Immutable QazaPlanRevision conflict: ' + id);
        }
      }

      // ---------- Tombstones ----------
      final guestTombstones = await database.customSelect(
        '''SELECT record_id, record_version, deleted_at, writer_device_id,
                  operation_id, cloud_generation
           FROM qaza_record_tombstones
           WHERE local_account_id = ?''',
        variables: [Variable(guestLocalAccountId)],
      ).get();
      for (final row in guestTombstones) {
        final id = row.read<String>('record_id');
        final googleRows = await database.customSelect(
          '''SELECT record_version, deleted_at, writer_device_id,
                    operation_id, cloud_generation
             FROM qaza_record_tombstones
             WHERE local_account_id = ? AND record_id = ? LIMIT 1''',
          variables: [Variable(googleLocalAccountId), Variable(id)],
        ).get();
        if (googleRows.isEmpty) {
          await database.customInsert(
            '''INSERT INTO qaza_record_tombstones
               (local_account_id, record_id, record_version, deleted_at,
                writer_device_id, operation_id, cloud_generation)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            variables: [
              Variable(googleLocalAccountId),
              Variable(id),
              Variable(row.read<int>('record_version')),
              Variable(row.read<int>('deleted_at')),
              Variable(row.read<String>('writer_device_id')),
              Variable(row.read<String>('operation_id')),
              Variable(google.cloudGeneration),
            ],
          );
        } else {
          final current = googleRows.first;
          final guestStamp = _rowEntityStamp(
            entityId: id,
            version: row.read<int>('record_version'),
            updatedAt: DateTime.fromMicrosecondsSinceEpoch(
              row.read<int>('deleted_at'),
            ),
            writerDeviceId: row.read<String>('writer_device_id'),
            operationId: row.read<String>('operation_id'),
          );
          final googleStamp = _rowEntityStamp(
            entityId: id,
            version: current.read<int>('record_version'),
            updatedAt: DateTime.fromMicrosecondsSinceEpoch(
              current.read<int>('deleted_at'),
            ),
            writerDeviceId: current.read<String>('writer_device_id'),
            operationId: current.read<String>('operation_id'),
          );
          if (ConflictResolver().compare(guestStamp, googleStamp) > 0) {
            await database.customUpdate(
              '''UPDATE qaza_record_tombstones
                 SET record_version = ?, deleted_at = ?, writer_device_id = ?,
                     operation_id = ?, cloud_generation = ?
                 WHERE local_account_id = ? AND record_id = ?''',
              variables: [
                Variable(row.read<int>('record_version')),
                Variable(row.read<int>('deleted_at')),
                Variable(row.read<String>('writer_device_id')),
                Variable(row.read<String>('operation_id')),
                Variable(google.cloudGeneration),
                Variable(googleLocalAccountId),
                Variable(id),
              ],
            );
          }
        }
      }

      // A winning tombstone removes only records that are not newer than it.
      final mergedTombstones = await database.customSelect(
        '''SELECT record_id, record_version
           FROM qaza_record_tombstones
           WHERE local_account_id = ?''',
        variables: [Variable(googleLocalAccountId)],
      ).get();
      for (final row in mergedTombstones) {
        final id = row.read<String>('record_id');
        final version = row.read<int>('record_version');
        final records = await database.customSelect(
          '''SELECT record_version FROM qaza_records
             WHERE user_id = ? AND id = ? LIMIT 1''',
          variables: [Variable(googleLocalAccountId), Variable(id)],
        ).get();
        if (records.isNotEmpty && version >= records.first.read<int>('record_version')) {
          await database.qazaRecordsDao.deleteById(
            userId: googleLocalAccountId,
            id: id,
          );
        }
      }

      // Qaza-record/addition/deletion metadata is maintained by the
      // corresponding database triggers during the merge. Profile metadata is
      // copied only when the Guest profile actually won the profile conflict.
    });
  }

  Future<String?> migratingGoogleAccount() async {
    final rows = await database.customSelect(
      '''SELECT local_account_id, account_mode, firebase_uid, google_email,
                lifecycle_state, cloud_backup_enabled, cloud_generation,
                created_at, updated_at
         FROM local_accounts
         WHERE account_mode = 'google' AND lifecycle_state = 'migrating'
         ORDER BY updated_at DESC
         LIMIT 1''',
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('local_account_id');
  }

  Future<String> cloneGuestToGoogle({
    required String firebaseUid,
    required String? email,
  }) async {
    final existing = await findGoogleByUid(firebaseUid);
    final guest = await getAccount(UserProfile.localLedgerUserId);
    if (guest == null) {
      if (existing != null) return existing.localAccountId;
      return createGooglePartition(firebaseUid: firebaseUid, email: email);
    }

    // Prefer converting the existing Guest partition in place. Qaza record IDs
    // are globally unique in SQLite, so copying records into a second local
    // partition necessarily changes identity. Reusing the Guest partition
    // preserves every record/addition/tombstone ID exactly.
    if (existing == null) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.transaction(() async {
        await database.customUpdate(
          '''UPDATE local_accounts
             SET account_mode = 'google',
                 firebase_uid = ?,
                 google_email = ?,
                 lifecycle_state = 'migrating',
                 cloud_backup_enabled = 1,
                 cloud_generation = 1,
                 updated_at = ?
             WHERE local_account_id = ?''',
          variables: [
            Variable(firebaseUid),
            Variable(email),
            Variable(now),
            Variable(guest.localAccountId),
          ],
        );
        await database.customUpdate(
          '''UPDATE app_session_state
             SET active_local_account_id = ?,
                 initial_choice_required = 0,
                 migration_state = 'targetPartitionPrepared'
             WHERE id = 1''',
          variables: [Variable(guest.localAccountId)],
        );
      });
      return guest.localAccountId;
    }

    if (existing.localAccountId == guest.localAccountId) {
      return existing.localAccountId;
    }

    // An empty historical Google partition can safely be removed and replaced
    // by the existing Guest partition. This is still identity-preserving.
    if (!await hasAnyAccountData(existing.localAccountId)) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.transaction(() async {
        await database.customUpdate(
          'DELETE FROM local_accounts WHERE local_account_id = ?',
          variables: [Variable(existing.localAccountId)],
        );
        await database.customUpdate(
          '''UPDATE local_accounts
             SET account_mode = 'google',
                 firebase_uid = ?,
                 google_email = ?,
                 lifecycle_state = 'migrating',
                 cloud_backup_enabled = 1,
                 cloud_generation = ?,
                 updated_at = ?
             WHERE local_account_id = ?''',
          variables: [
            Variable(firebaseUid),
            Variable(email),
            Variable(guest.cloudGeneration),
            Variable(now),
            Variable(guest.localAccountId),
          ],
        );
        await database.customUpdate(
          '''UPDATE app_session_state
             SET active_local_account_id = ?,
                 initial_choice_required = 0,
                 migration_state = 'targetPartitionPrepared'
             WHERE id = 1''',
          variables: [Variable(guest.localAccountId)],
        );
      });
      return guest.localAccountId;
    }

    await createMigrationSnapshot(existing.localAccountId);
    await mergeGuestIntoGooglePartition(
      guestLocalAccountId: guest.localAccountId,
      googleLocalAccountId: existing.localAccountId,
    );
    return existing.localAccountId;
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

  Future<void> unarchiveAccount(String localAccountId) async {
    await database.customUpdate(
      '''UPDATE local_accounts
         SET lifecycle_state = 'active', updated_at = ?
         WHERE local_account_id = ?''',
      variables: [
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(localAccountId),
      ],
    );
    await activate(localAccountId);
  }

  Future<void> deleteLocalAccount(String localAccountId) async {
    if (localAccountId == UserProfile.localLedgerUserId) {
      throw StateError('The base Guest partition cannot be removed.');
    }
    await database.transaction(() async {
      await database.customUpdate(
        'DELETE FROM qaza_records WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM qaza_profile_plan_provenance WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM qaza_additions WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM qaza_deletion_actions WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM qaza_deletion_action_record_snapshots WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM account_plan_revisions WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM entity_metadata WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM qaza_record_tombstones WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM sync_outbox WHERE user_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.customUpdate(
        'DELETE FROM local_accounts WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
    });
  }

  Future<String?> migrationSnapshotId() async {
    final rows = await database.customSelect(
      'SELECT migration_snapshot_id FROM app_session_state WHERE id = 1',
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String?>('migration_snapshot_id');
  }

  Future<String> createMigrationSnapshot(String localAccountId) async {
    final accountRows = await database.customSelect(
      '''SELECT local_account_id, account_mode, firebase_uid, google_email,
                lifecycle_state, cloud_backup_enabled, cloud_generation,
                created_at, updated_at
         FROM local_accounts WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (accountRows.isEmpty) {
      throw StateError('Migration snapshot account does not exist.');
    }

    Future<List<Map<String, dynamic>>> queryMaps(
      String sql,
      List<String> columns,
    ) async {
      final rows = await database.customSelect(
        sql,
        variables: [Variable(localAccountId)],
      ).get();
      return rows
          .map((row) => <String, dynamic>{
                for (final column in columns) column: row.data[column],
              })
          .toList(growable: false);
    }

    final account = accountRows.first;
    final migrationId = _randomId('migration');
    final snapshot = <String, dynamic>{
      'local_accounts': [
        {
          'local_account_id': account.read<String>('local_account_id'),
          'account_mode': account.read<String>('account_mode'),
          'firebase_uid': account.read<String?>('firebase_uid'),
          'google_email': account.read<String?>('google_email'),
          'lifecycle_state': account.read<String>('lifecycle_state'),
          'cloud_backup_enabled': account.read<int>('cloud_backup_enabled'),
          'cloud_generation': account.read<int>('cloud_generation'),
          'created_at': account.read<int>('created_at'),
          'updated_at': account.read<int>('updated_at'),
        },
      ],
      'account_profiles': await queryMaps(
        '''SELECT local_account_id, payload_json, entity_version, updated_at,
                  writer_device_id, operation_id
           FROM account_profiles WHERE local_account_id = ?''',
        ['local_account_id', 'payload_json', 'entity_version', 'updated_at',
          'writer_device_id', 'operation_id'],
      ),
      'qaza_records': await queryMaps(
        '''SELECT id, user_id, prayer_type, original_date, status, completed_at,
                  completion_id, addition_id, record_version, created_at, updated_at
           FROM qaza_records WHERE user_id = ?''',
        ['id', 'user_id', 'prayer_type', 'original_date', 'status', 'completed_at',
          'completion_id', 'addition_id', 'record_version', 'created_at', 'updated_at'],
      ),
      'qaza_additions': await queryMaps(
        '''SELECT id, user_id, mode, input_snapshot, revision, created_at, updated_at
           FROM qaza_additions WHERE user_id = ?''',
        ['id', 'user_id', 'mode', 'input_snapshot', 'revision', 'created_at', 'updated_at'],
      ),
      'qaza_deletion_actions': await queryMaps(
        '''SELECT id, user_id, addition_id, created_at, resolved_at, entity_version
           FROM qaza_deletion_actions WHERE user_id = ?''',
        ['id', 'user_id', 'addition_id', 'created_at', 'resolved_at', 'entity_version'],
      ),
      'qaza_deletion_action_record_snapshots': await queryMaps(
        '''SELECT deletion_action_id, record_id, user_id, addition_id,
                  prayer_type, original_date, status, completed_at,
                  completion_id, created_at, updated_at, record_version
           FROM qaza_deletion_action_record_snapshots WHERE user_id = ?''',
        ['deletion_action_id', 'record_id', 'user_id', 'addition_id', 'prayer_type',
          'original_date', 'status', 'completed_at', 'completion_id', 'created_at',
          'updated_at', 'record_version'],
      ),
      'account_plan_revisions': await queryMaps(
        '''SELECT local_account_id, revision_id, payload_json, created_at
           FROM account_plan_revisions WHERE local_account_id = ?''',
        ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
      ),
      'entity_metadata': await queryMaps(
        '''SELECT local_account_id, entity_type, entity_id, entity_version,
                  updated_at, writer_device_id, operation_id
           FROM entity_metadata WHERE local_account_id = ?''',
        ['local_account_id', 'entity_type', 'entity_id', 'entity_version',
          'updated_at', 'writer_device_id', 'operation_id'],
      ),
      'qaza_record_tombstones': await queryMaps(
        '''SELECT local_account_id, record_id, record_version, deleted_at,
                  writer_device_id, operation_id, cloud_generation
           FROM qaza_record_tombstones WHERE local_account_id = ?''',
        ['local_account_id', 'record_id', 'record_version', 'deleted_at',
          'writer_device_id', 'operation_id', 'cloud_generation'],
      ),
      'qaza_profile_plan_provenance': await queryMaps(
        '''SELECT record_id, user_id, plan_revision_id, plan_fingerprint
           FROM qaza_profile_plan_provenance WHERE user_id = ?''',
        ['record_id', 'user_id', 'plan_revision_id', 'plan_fingerprint'],
      ),
      'sync_outbox': await queryMaps(
        '''SELECT id, user_id, type, queued_at, firebase_uid, cloud_generation,
                  entity_type, operation, payload_json, next_attempt_at, attempts,
                  worker_id, lease_until, writer_device_id
           FROM sync_outbox WHERE user_id = ?''',
        ['id', 'user_id', 'type', 'queued_at', 'firebase_uid', 'cloud_generation',
          'entity_type', 'operation', 'payload_json', 'next_attempt_at', 'attempts',
          'worker_id', 'lease_until', 'writer_device_id'],
      ),
    };

    await database.transaction(() async {
      await database.customInsert(
        '''INSERT INTO account_migration_snapshots
           (migration_id, local_account_id, snapshot_json, created_at)
           VALUES (?, ?, ?, ?)''',
        variables: [
          Variable(migrationId),
          Variable(localAccountId),
          Variable(jsonEncode(snapshot)),
          Variable(DateTime.now().microsecondsSinceEpoch),
        ],
      );
      await database.customUpdate(
        '''UPDATE app_session_state
           SET migration_snapshot_id = ?, migration_state = 'localStateSnapshotSecured'
           WHERE id = 1''',
        variables: [Variable(migrationId)],
      );
    });
    return migrationId;
  }

  Future<void> completeMigration() async {
    await database.transaction(() async {
      final id = await migrationSnapshotId();
      if (id != null) {
        await database.customUpdate(
          'DELETE FROM account_migration_snapshots WHERE migration_id = ?',
          variables: [Variable(id)],
        );
      }
      await database.customUpdate(
        '''UPDATE app_session_state
           SET migration_snapshot_id = NULL, migration_state = 'completed'
           WHERE id = 1''',
      );
    });
  }

  Future<void> clearMigrationSnapshot() async {
    final id = await migrationSnapshotId();
    if (id == null) return;
    await database.transaction(() async {
      await database.customUpdate(
        'DELETE FROM account_migration_snapshots WHERE migration_id = ?',
        variables: [Variable(id)],
      );
      await database.customUpdate(
        'UPDATE app_session_state SET migration_snapshot_id = NULL WHERE id = 1',
      );
    });
  }

  Future<void> restoreMigrationSnapshotIfPresent() async {
    final id = await migrationSnapshotId();
    if (id == null) return;
    final rows = await database.customSelect(
      '''SELECT local_account_id, snapshot_json
         FROM account_migration_snapshots WHERE migration_id = ? LIMIT 1''',
      variables: [Variable(id)],
    ).get();
    if (rows.isEmpty) return;
    final snapshot = Map<String, dynamic>.from(
      jsonDecode(rows.first.read<String>('snapshot_json')) as Map,
    );
    final accounts = (snapshot['local_accounts'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (accounts.isEmpty) throw StateError('Migration snapshot is empty.');
    final targetId = accounts.first['local_account_id'] as String;

    Future<void> deleteRows(String table, String column) async {
      await database.customUpdate(
        'DELETE FROM $table WHERE $column = ?',
        variables: [Variable(targetId)],
      );
    }
    Future<void> insertRows(String table, List<dynamic> rawRows) async {
      for (final rawRow in rawRows) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final columns = row.keys.toList(growable: false);
        if (columns.isEmpty) continue;
        final placeholders = List.filled(columns.length, '?').join(', ');
        await database.customInsert(
          'INSERT OR REPLACE INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
          variables: columns.map((column) => Variable(row[column])).toList(),
        );
      }
    }

    await database.transaction(() async {
      await deleteRows('qaza_profile_plan_provenance', 'user_id');
      await deleteRows('qaza_deletion_action_record_snapshots', 'user_id');
      await deleteRows('qaza_deletion_actions', 'user_id');
      await deleteRows('qaza_additions', 'user_id');
      await deleteRows('qaza_records', 'user_id');
      await deleteRows('account_plan_revisions', 'local_account_id');
      await deleteRows('entity_metadata', 'local_account_id');
      await deleteRows('qaza_record_tombstones', 'local_account_id');
      await deleteRows('sync_outbox', 'user_id');
      await database.customUpdate(
        'DELETE FROM local_accounts WHERE local_account_id = ?',
        variables: [Variable(targetId)],
      );
      for (final entry in snapshot.entries) {
        if (entry.key == 'local_accounts') continue;
        final value = entry.value;
        if (value is List) await insertRows(entry.key, value);
      }
      await insertRows('local_accounts', accounts);
      await database.customUpdate(
        'DELETE FROM account_migration_snapshots WHERE migration_id = ?',
        variables: [Variable(id)],
      );
      await database.customUpdate(
        'UPDATE app_session_state SET migration_snapshot_id = NULL WHERE id = 1',
      );
    });
  }
  Future<void> rollbackGoogleMigration(String localAccountId) async {
    await database.transaction(() async {
      await database.customUpdate(
        '''UPDATE local_accounts
           SET account_mode = 'guest',
               firebase_uid = NULL,
               google_email = NULL,
               lifecycle_state = 'active',
               cloud_backup_enabled = 0,
               cloud_generation = 1,
               updated_at = ?
           WHERE local_account_id = ?''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(localAccountId),
        ],
      );
      await database.customUpdate(
        '''UPDATE app_session_state
           SET active_local_account_id = ?,
               migration_state = 'failed'
           WHERE id = 1''',
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
    await database.customUpdate(
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

  Future<void> clearBackupOperations(String localAccountId) async {
    final rows = await database.customSelect(
      '''SELECT cloud_generation FROM local_accounts
         WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (rows.isEmpty) return;
    await removeAllOutboxForGeneration(
      localAccountId: localAccountId,
      generation: rows.first.read<int>('cloud_generation'),
    );
  }

  Future<void> removeOutboxOperation({
    required String localAccountId,
    required String operationId,
    required String workerId,
  }) async {
    await database.customUpdate(
      '''DELETE FROM sync_outbox
         WHERE user_id = ? AND id = ? AND worker_id = ?''',
      variables: [
        Variable(localAccountId),
        Variable(operationId),
        Variable(workerId),
      ],
    );
  }

  Future<void> removeAllOutboxForGeneration({
    required String localAccountId,
    required int generation,
  }) async {
    await database.customUpdate(
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
    required String workerId,
    required int attempts,
    required String error,
    required int nextAttemptMicros,
  }) async {
    await database.customUpdate(
      '''UPDATE sync_outbox
         SET attempts = ?, last_error = ?, next_attempt_at = ?,
             worker_id = NULL, lease_until = NULL
         WHERE user_id = ? AND id = ? AND worker_id = ?''',
      variables: [
        Variable(attempts),
        Variable(error),
        Variable(nextAttemptMicros),
        Variable(localAccountId),
        Variable(operationId),
        Variable(workerId),
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
