import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import 'database/app_database.dart';

class AccountLocalStore {
  AccountLocalStore({required this.database});

  final AppDatabase database;

  Future<void> ensureInitialized() async {
    await _ensureDeviceId();
    await _ensureLocalAccount();
  }

  Future<bool> hasAnyQaza(String localAccountId) async {
    final rows = await database.customSelect(
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      variables: [Variable(localAccountId)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<String> deviceInstanceId() async {
    final rows = await database
        .customSelect(
          'SELECT device_instance_id FROM device_metadata WHERE id = 1 LIMIT 1',
        )
        .get();
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
      '''SELECT local_account_id, account_mode, lifecycle_state,
                created_at, updated_at
         FROM local_accounts
         WHERE local_account_id = ?
         LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    return rows.isEmpty ? null : _mapAccount(rows.first);
  }

  Future<LocalAccount?> activeAccount() async {
    final rows = await database.customSelect(
      '''SELECT a.local_account_id, a.account_mode, a.lifecycle_state,
                a.created_at, a.updated_at
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

  Future<void> activate(String localAccountId) async {
    final account = await getAccount(localAccountId);
    if (account == null) {
      throw StateError('Local account not found: $localAccountId');
    }
    if (account.lifecycleState == AccountLifecycleState.archived) {
      throw StateError('Archived local account cannot become active.');
    }

    await database.customUpdate(
      '''UPDATE app_session_state
         SET active_local_account_id = ?
         WHERE id = 1''',
      variables: [Variable(localAccountId)],
    );
  }

  Future<String> ensureLocalAccountActive() async {
    final account = await getAccount(UserProfile.localLedgerUserId);
    if (account == null) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state,
            created_at, updated_at)
           VALUES (?, 'local', 'active', ?, ?)''',
        variables: [
          Variable(UserProfile.localLedgerUserId),
          Variable(now),
          Variable(now),
        ],
      );
    }

    await activate(UserProfile.localLedgerUserId);
    return UserProfile.localLedgerUserId;
  }

  Future<bool> hasAnyAccountData(String localAccountId) async {
    const queries = [
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_additions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_actions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_action_record_snapshots WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM account_profiles WHERE local_account_id = ? LIMIT 1',
      'SELECT 1 FROM account_plan_revisions WHERE local_account_id = ? LIMIT 1',
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
      await _writeProfileRowInsideTransaction(
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
    });
  }

  /// Persists a draft locally.
  Future<void> saveProfileLocalOnly(
    String localAccountId,
    UserProfile profile,
  ) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();
    final opId = _randomId('op');
    await database.transaction(() async {
      await _writeProfileRowInsideTransaction(
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
    });
  }

  Future<void> _writeProfileRowInsideTransaction({
    required String localAccountId,
    required UserProfile profile,
    required int nowMicros,
    required String writerDeviceId,
    required String operationId,
  }) {
    return database.customUpdate(
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
        Variable(nowMicros),
        Variable(writerDeviceId),
        Variable(operationId),
      ],
    );
  }

  /// Atomically commits profile, initial plan revision, Qaza records,
  /// provenance.
  Future<void> commitOnboarding({
    required String localAccountId,
    required UserProfile profile,
    required QazaPlanRevision revision,
    required List<QazaRecord> records,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (localAccountId.isEmpty) {
      throw StateError('Onboarding requires a local account ID.');
    }
    if (revision.userId != localAccountId) {
      throw StateError('Onboarding revision is for a different local account.');
    }
    for (final record in records) {
      if (record.userId != localAccountId) {
        throw StateError('Onboarding Qaza record is for a different account.');
      }
      if (record.profilePlanRevisionId != revision.revisionId ||
          record.profilePlanFingerprint != revision.planFingerprint) {
        throw StateError('Onboarding Qaza record has invalid plan provenance.');
      }
    }

    await database.transaction(() async {
      final activeRows = await database.customSelect(
        '''SELECT active_local_account_id
           FROM app_session_state
           WHERE id = 1
           LIMIT 1''',
      ).get();
      final activeId = activeRows.isEmpty
          ? null
          : activeRows.first.read<String?>('active_local_account_id');
      if (activeId != localAccountId) {
        throw StateError('Onboarding account is not the active local account.');
      }

      final accountRows = await database.customSelect(
        '''SELECT lifecycle_state
           FROM local_accounts
           WHERE local_account_id = ?
           LIMIT 1''',
        variables: [Variable(localAccountId)],
      ).get();
      if (accountRows.isEmpty) {
        throw StateError('Local onboarding account does not exist.');
      }
      final lifecycle = accountRows.first.read<String>('lifecycle_state');
      if (lifecycle == 'archived' || lifecycle == 'migrating') {
        throw StateError('Local onboarding account is not active.');
      }
      final now = DateTime.now().microsecondsSinceEpoch;
      final device = await deviceInstanceId();
      await _writeProfileRowInsideTransaction(
        localAccountId: localAccountId,
        profile: profile.copyWith(onboardingCompleted: true),
        nowMicros: now,
        writerDeviceId: device,
        operationId: _randomId('onboarding_profile'),
      );

      final revisionPayload = jsonEncode(revision.toJson());
      final existingRevision = await database.customSelect(
        '''SELECT payload_json
           FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ?
           LIMIT 1''',
        variables: [
          Variable(localAccountId),
          Variable(revision.revisionId),
        ],
      ).get();
      if (existingRevision.isNotEmpty) {
        if (existingRevision.first.read<String>('payload_json') !=
            revisionPayload) {
          throw StateError('Immutable onboarding plan revision conflict.');
        }
      } else {
        await database.customInsert(
          '''INSERT INTO account_plan_revisions
             (local_account_id, revision_id, payload_json, created_at)
             VALUES (?, ?, ?, ?)''',
          variables: [
            Variable(localAccountId),
            Variable(revision.revisionId),
            Variable(revisionPayload),
            Variable(revision.createdAt.microsecondsSinceEpoch),
          ],
        );
      }

      var insertedTotal = 0;
      for (var start = 0; start < records.length; start += 500) {
        final end = start + 500 < records.length ? start + 500 : records.length;
        final chunk = records.sublist(start, end);
        if (chunk.isNotEmpty) {
          final ids =
              await database.qazaRecordsDao.insertRecordsReturningInsertedIds(
            [
              for (final record in chunk)
                QazaRecordsCompanion.insert(
                  id: record.id,
                  userId: record.userId,
                  prayerType: record.prayerType.name,
                  originalDate: record.originalDate,
                  status: record.status.name,
                  completedAt: record.completedAt == null
                      ? const Value.absent()
                      : Value(record.completedAt),
                  completionId: record.completionId == null
                      ? const Value.absent()
                      : Value(record.completionId),
                  additionId: record.additionId == null
                      ? const Value.absent()
                      : Value(record.additionId),
                  recordVersion: Value(record.recordVersion),
                  createdAt: record.createdAt,
                  updatedAt: record.updatedAt,
                ),
            ],
          );
          insertedTotal += ids.length;
          await _upsertProfilePlanProvenance(
            chunk.where((record) => ids.contains(record.id)),
          );
        }
        onProgress?.call(end, records.length);
      }

      if (insertedTotal != records.length) {
        throw StateError(
          'Onboarding Qaza dataset is incomplete: inserted '
          '${insertedTotal} of ${records.length} records.',
        );
      }
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
    });
  }

  Future<void> _upsertProfilePlanProvenance(
    Iterable<QazaRecord> records,
  ) async {
    final eligible = records
        .where(
          (record) =>
              record.profilePlanRevisionId != null &&
              record.profilePlanFingerprint != null,
        )
        .toList(growable: false);
    for (final record in eligible) {
      await database.customInsert(
        '''INSERT INTO qaza_profile_plan_provenance
           (record_id, user_id, plan_revision_id, plan_fingerprint)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(record_id) DO UPDATE SET
             user_id = excluded.user_id,
             plan_revision_id = excluded.plan_revision_id,
             plan_fingerprint = excluded.plan_fingerprint''',
        variables: [
          Variable(record.id),
          Variable(record.userId),
          Variable(record.profilePlanRevisionId!),
          Variable(record.profilePlanFingerprint!),
        ],
      );
    }
  }

  Future<void> _ensureLocalAccount() async {
    final rows = await database.customSelect(
      'SELECT local_account_id FROM local_accounts WHERE local_account_id = ?',
      variables: [Variable(UserProfile.localLedgerUserId)],
    ).get();

    if (rows.isEmpty) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state,
            created_at, updated_at)
           VALUES (?, 'local', 'active', ?, ?)''',
        variables: [
          Variable(UserProfile.localLedgerUserId),
          Variable(now),
          Variable(now),
        ],
      );
    }

    final sessionRows = await database.customSelect(
      'SELECT id FROM app_session_state WHERE id = 1',
    ).get();

    if (sessionRows.isEmpty) {
      await database.customInsert(
        '''INSERT INTO app_session_state
           (id, active_local_account_id)
           VALUES (1, ?)''',
        variables: [Variable(UserProfile.localLedgerUserId)],
      );
    } else {
      await database.customUpdate(
        '''UPDATE app_session_state
           SET active_local_account_id = ?
           WHERE id = 1
             AND active_local_account_id IS NULL''',
        variables: [Variable(UserProfile.localLedgerUserId)],
      );
    }
  }

  LocalAccount _mapAccount(QueryRow row) {
    return LocalAccount(
      localAccountId: row.read<String>('local_account_id'),
      accountMode: AccountMode.local,
      lifecycleState: AccountLifecycleState.values
          .byName(row.read<String>('lifecycle_state')),
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

