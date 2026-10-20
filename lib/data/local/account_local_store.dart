import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import 'database/app_database.dart';
import 'workspace_identity_migrator.dart';

class AccountLocalStore {
  AccountLocalStore({required this.database});

  final AppDatabase database;

  Future<void> ensureInitialized() async {
    await _ensureDeviceId();
    await _ensureLocalAccount();
    final persisted = await activeAccount();
    final activeId = persisted?.localAccountId;
    final profile = activeId == null ? null : await loadProfile(activeId);
    await database.transaction(() async {
      await database.setOnboardingCompletedInTransaction(
        profile?.onboardingCompleted == true,
      );
    });
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
      '''SELECT a.local_account_id, a.account_mode, a.lifecycle_state,
                a.created_at, a.updated_at,
                (SELECT value FROM meta_store
                 WHERE key = 'workspace_display_name:' || a.local_account_id
                 LIMIT 1) AS display_name
         FROM local_accounts a
         WHERE a.local_account_id = ?
         LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    return rows.isEmpty ? null : _mapAccount(rows.first);
  }

  Future<LocalAccount?> activeAccount() async {
    final rows = await database.customSelect(
      '''SELECT a.local_account_id, a.account_mode, a.lifecycle_state,
                a.created_at, a.updated_at,
                (SELECT value FROM meta_store
                 WHERE key = 'workspace_display_name:' || a.local_account_id
                 LIMIT 1) AS display_name
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
    if (account.lifecycleState == AccountLifecycleState.archived ||
        account.lifecycleState == AccountLifecycleState.deletedHold ||
        account.lifecycleState == AccountLifecycleState.adoptedRecovery ||
        account.lifecycleState == AccountLifecycleState.recoveryCopy) {
      throw StateError('This local workspace cannot become active.');
    }

    // The onboarding flag is global metadata, so it must follow the active
    // workspace rather than retaining the previous user's value.
    final profile = await loadProfile(localAccountId);
    await database.transaction(() async {
      final sessionRows = await database
          .customSelect(
            'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
          )
          .get();
      if (sessionRows.isEmpty) {
        await database.customInsert(
          '''INSERT INTO app_session_state
             (id, active_local_account_id, generation) VALUES (1, ?, 1)''',
          variables: [Variable(localAccountId)],
        );
      } else {
        final currentId =
            sessionRows.single.read<String?>('active_local_account_id');
        if (currentId != localAccountId) {
          await database.customUpdate(
            '''UPDATE app_session_state
               SET active_local_account_id = ?, generation = generation + 1
               WHERE id = 1''',
            variables: [Variable(localAccountId)],
          );
        }
      }
      await database.setOnboardingCompletedInTransaction(
        profile?.onboardingCompleted == true,
      );
    });
  }

  /// Creates a separate local workspace when it does not exist, then activates
  /// it. Existing records are never deleted or copied during account switching.
  Future<String> ensureAccountActive(String localAccountId) async {
    final normalized = localAccountId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }

    final account = await getAccount(normalized);
    if (account == null) {
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state,
            created_at, updated_at)
           VALUES (?, 'local', 'active', ?, ?)''',
        variables: [
          Variable(normalized),
          Variable(now),
          Variable(now),
        ],
      );
    }

    await activate(normalized);
    return normalized;
  }

  /// Keeps the last persisted workspace selected across process restarts.
  /// The legacy Guest workspace remains the fallback for older installations.
  Future<String> ensureLocalAccountActive() async {
    final persisted = await activeAccount();
    if (persisted != null &&
        (persisted.lifecycleState == AccountLifecycleState.active ||
            persisted.lifecycleState == AccountLifecycleState.draft)) {
      await activate(persisted.localAccountId);
      return persisted.localAccountId;
    }

    // A migration or an interrupted older sign-out can leave the legacy Guest
    // session pointing at an archived workspace. Recover into a fresh local
    // workspace instead of trying to reactivate the archived row.
    final legacyGuest = await getAccount(UserProfile.localLedgerUserId);
    if (legacyGuest?.lifecycleState == AccountLifecycleState.archived ||
        legacyGuest?.lifecycleState == AccountLifecycleState.deletedHold) {
      return createGuestWorkspace();
    }
    return ensureAccountActive(UserProfile.localLedgerUserId);
  }

  /// Creates a distinct Guest workspace. New Guest sessions never reuse the
  /// legacy fixed workspace that may contain years of existing Qaza records.
  Future<String> createGuestWorkspace({
    String? displayName,
    bool draft = false,
  }) async {
    final id = 'guest_${Uuid().v4()}';
    final now = DateTime.now().microsecondsSinceEpoch;
    final normalizedName = displayName?.trim();
    final lifecycleState = draft ? 'draft' : 'active';
    await database.transactionWithRevision(() async {
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state,
            created_at, updated_at)
           VALUES (?, 'local', ?, ?, ?)''',
        variables: [
          Variable(id),
          Variable(lifecycleState),
          Variable(now),
          Variable(now),
        ],
      );
      if (normalizedName != null && normalizedName.isNotEmpty) {
        await database.customInsert(
          '''INSERT INTO meta_store (key, value)
             VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
          variables: [
            Variable('workspace_display_name:$id'),
            Variable(normalizedName),
          ],
        );
      }
      return true;
    });
    await activate(id);
    return id;
  }

  Future<String?> loadWorkspaceDisplayName(String localAccountId) async {
    final rows = await database.customSelect(
      'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
      variables: [Variable('workspace_display_name:$localAccountId')],
    ).get();
    if (rows.isEmpty) return null;
    final value = rows.first.read<String>('value').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> saveWorkspaceDisplayName(
    String localAccountId,
    String displayName,
  ) async {
    final account = await getAccount(localAccountId);
    if (account == null ||
        account.lifecycleState == AccountLifecycleState.archived) {
      throw StateError('The selected local workspace is not available.');
    }
    final normalized = displayName.trim();
    final key = 'workspace_display_name:$localAccountId';
    await database.transactionWithRevision(() async {
      final rows = await database.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable(key)],
      ).get();
      final current = rows.isEmpty ? null : rows.first.read<String>('value');
      if ((current ?? '') == normalized) return false;
      if (normalized.isEmpty) {
        await database.customStatement(
          'DELETE FROM meta_store WHERE key = ?',
          [key],
        );
      } else {
        await database.customInsert(
          '''INSERT INTO meta_store (key, value)
             VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
          variables: [Variable(key), Variable(normalized)],
        );
      }
      return true;
    });
  }

  /// Lists non-archived Guest workspaces that have a saved name or data.
  /// Empty rows left behind by cancelled flows are intentionally hidden.
  Future<List<LocalAccount>> listGuestWorkspaces() async {
    final rows = await database.customSelect(
      '''SELECT a.local_account_id, a.account_mode, a.lifecycle_state,
                a.created_at, a.updated_at,
                (SELECT value FROM meta_store
                 WHERE key = 'workspace_display_name:' || a.local_account_id
                 LIMIT 1) AS display_name
         FROM local_accounts a
         WHERE (a.local_account_id = 'guest'
                OR a.local_account_id GLOB 'guest:*'
                OR a.local_account_id GLOB 'guest_*')
           AND a.lifecycle_state IN ('active', 'draft')
         ORDER BY a.created_at DESC''',
    ).get();
    final result = <LocalAccount>[];
    for (final row in rows) {
      final account = _mapAccount(row);
      if (account.lifecycleState == AccountLifecycleState.draft ||
          account.displayName?.trim().isNotEmpty == true ||
          await hasAnyAccountData(account.localAccountId)) {
        result.add(account);
      }
    }
    return result;
  }

  /// Places a non-active Guest workspace into a seven-day deletion hold.
  /// Records stay in SQLite until the hold expires and purge safety checks pass.
  Future<DateTime> scheduleGuestWorkspaceDeletion(
    String localAccountId, {
    DateTime? requestedAt,
  }) async {
    final id = localAccountId.trim();
    if (!isGuestLocalWorkspaceId(id)) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    final account = await getAccount(id);
    if (account == null ||
        (account.lifecycleState != AccountLifecycleState.active &&
            account.lifecycleState != AccountLifecycleState.draft)) {
      throw StateError('This Guest workspace is not available for deletion.');
    }
    final now = requestedAt ?? DateTime.now();
    final requestedMicros = now.microsecondsSinceEpoch;
    final expires = now.add(const Duration(days: 7));
    final expiresMicros = expires.microsecondsSinceEpoch;

    await database.transaction(() async {
      final sessionRows = await database
          .customSelect(
            'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
          )
          .get();
      final activeId = sessionRows.isEmpty
          ? null
          : sessionRows.single.read<String?>('active_local_account_id');
      if (activeId == id) {
        throw StateError(
          'Switch to another workspace before deleting this Guest workspace.',
        );
      }
      if (await database.hasPendingInitialCloudBackup(localAccountId: id)) {
        throw StateError(
          'This workspace has a backup waiting to finish. Keep it until the backup is resolved.',
        );
      }
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'deleted_hold', updated_at = ?
           WHERE local_account_id = ?
             AND lifecycle_state IN ('active', 'draft') ''',
        variables: [Variable(requestedMicros), Variable(id)],
      );
      await database.customInsert(
        '''INSERT INTO local_workspace_deletion_holds
           (local_account_id, requested_at, expires_at, prior_lifecycle_state)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(local_account_id) DO UPDATE SET
             requested_at = excluded.requested_at,
             expires_at = excluded.expires_at,
             prior_lifecycle_state = excluded.prior_lifecycle_state''',
        variables: [
          Variable(id),
          Variable(requestedMicros),
          Variable(expiresMicros),
          Variable(account.lifecycleState.name),
        ],
      );
    });
    return expires;
  }

  Future<bool> undoGuestWorkspaceDeletion(String localAccountId) async {
    final id = localAccountId.trim();
    if (!isGuestLocalWorkspaceId(id)) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    return database.transaction(() async {
      final rows = await database.customSelect(
        'SELECT prior_lifecycle_state FROM local_workspace_deletion_holds '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(id)],
      ).get();
      if (rows.isEmpty) return false;
      final account = await database.customSelect(
        'SELECT lifecycle_state FROM local_accounts WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(id)],
      ).get();
      if (account.isEmpty ||
          account.single.read<String>('lifecycle_state') != 'deleted_hold') {
        throw StateError(
          'The Guest workspace has changed state and cannot be restored automatically.',
        );
      }
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = ?, updated_at = ?
           WHERE local_account_id = ?''',
        variables: [
          Variable(rows.single.read<String>('prior_lifecycle_state')),
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(id),
        ],
      );
      await database.customStatement(
        'DELETE FROM local_workspace_deletion_holds WHERE local_account_id = ?',
        [id],
      );
      return true;
    });
  }

  Future<List<LocalWorkspaceDeletionHold>>
      listGuestWorkspaceDeletionHolds() async {
    final rows = await database.customSelect(
      '''SELECT h.local_account_id, h.requested_at, h.expires_at,
                (SELECT value FROM meta_store
                 WHERE key = 'workspace_display_name:' || h.local_account_id
                 LIMIT 1) AS display_name
         FROM local_workspace_deletion_holds h
         ORDER BY h.expires_at ASC''',
    ).get();
    return rows.map((row) {
      final rawName = row.read<String?>('display_name')?.trim();
      return LocalWorkspaceDeletionHold(
        localAccountId: row.read<String>('local_account_id'),
        requestedAt: DateTime.fromMicrosecondsSinceEpoch(
          row.read<int>('requested_at'),
        ),
        expiresAt: DateTime.fromMicrosecondsSinceEpoch(
          row.read<int>('expires_at'),
        ),
        displayName: rawName == null || rawName.isEmpty ? null : rawName,
      );
    }).toList(growable: false);
  }

  /// Permanently removes only Guest workspaces whose seven-day hold expired.
  /// Active workspaces and workspaces with a pending backup are never purged.
  Future<int> purgeExpiredGuestWorkspaceDeletions({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).microsecondsSinceEpoch;
    final holds = await database.customSelect(
      '''SELECT local_account_id FROM local_workspace_deletion_holds
         WHERE expires_at <= ? ORDER BY expires_at ASC''',
      variables: [Variable(cutoff)],
    ).get();
    var purged = 0;
    for (final hold in holds) {
      final id = hold.read<String>('local_account_id');
      if (!isGuestLocalWorkspaceId(id) ||
          await database.hasPendingInitialCloudBackup(localAccountId: id)) {
        continue;
      }
      final removed = await database.transaction(() async {
        final sessionRows = await database
            .customSelect(
              'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
            )
            .get();
        final activeId = sessionRows.isEmpty
            ? null
            : sessionRows.single.read<String?>('active_local_account_id');
        if (activeId == id) return false;
        final accountRows = await database.customSelect(
          'SELECT lifecycle_state FROM local_accounts WHERE local_account_id = ? LIMIT 1',
          variables: [Variable(id)],
        ).get();
        if (accountRows.isEmpty ||
            accountRows.single.read<String>('lifecycle_state') !=
                'deleted_hold') {
          return false;
        }
        const ownedTables = <(String, String)>[
          ('qaza_records', 'user_id'),
          ('daily_salah_logs', 'user_id'),
          ('qaza_additions', 'user_id'),
          ('qaza_deletion_actions', 'user_id'),
          ('qaza_deletion_action_record_snapshots', 'user_id'),
          ('qaza_profile_plan_provenance', 'user_id'),
          ('account_profiles', 'local_account_id'),
          ('account_plan_revisions', 'local_account_id'),
        ];
        for (final (table, ownerColumn) in ownedTables) {
          await database.customStatement(
            'DELETE FROM "$table" WHERE "$ownerColumn" = ?',
            [id],
          );
        }
        await database.customStatement(
          '''DELETE FROM meta_store
             WHERE key IN (?, ?, ?, ?)''',
          [
            'workspace_display_name:$id',
            'daily_salah_tracking_enabled:$id',
            'daily_salah_tracking_setup_dismissed:$id',
            'workspace_revision:$id',
          ],
        );
        await database.customStatement(
          'DELETE FROM workspace_sync_metadata WHERE local_account_id = ?',
          [id],
        );
        await database.customStatement(
          'DELETE FROM local_workspace_deletion_holds WHERE local_account_id = ?',
          [id],
        );
        await database.customStatement(
          'DELETE FROM local_accounts WHERE local_account_id = ?',
          [id],
        );
        return true;
      });
      if (removed) purged++;
    }
    return purged;
  }

  Future<bool> hasAnyAccountData(String localAccountId) async {
    const queries = [
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM daily_salah_logs WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_additions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_actions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_action_record_snapshots WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_profile_plan_provenance WHERE user_id = ? LIMIT 1',
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
    await database.transactionWithRevision(() async {
      final existing = await loadProfile(localAccountId);
      final onboardingCompleted = await database.isOnboardingCompleted();
      if (existing != null &&
          jsonEncode(existing.toJson()) == jsonEncode(profile.toJson()) &&
          onboardingCompleted == profile.onboardingCompleted) {
        return false;
      }
      await _writeProfileRowInsideTransaction(
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
      await database.setOnboardingCompletedInTransaction(
        profile.onboardingCompleted,
      );
      return true;
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
    await database.transactionWithRevision(() async {
      await _writeProfileRowInsideTransaction(
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
      await database.setOnboardingCompletedInTransaction(
        profile.onboardingCompleted,
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

    await database.transactionWithRevision(() async {
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
      if (lifecycle != 'active' && lifecycle != 'draft') {
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
      await database.setOnboardingCompletedInTransaction(true);

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
          '$insertedTotal of ${records.length} records.',
        );
      }
      // Promote a draft only as part of the transaction that commits the
      // final profile, plan revision, and all planned Qaza rows.
      await database.customUpdate(
        '''UPDATE local_accounts SET lifecycle_state = 'active', updated_at = ?
           WHERE local_account_id = ? AND lifecycle_state = 'draft' ''',
        variables: [Variable(now), Variable(localAccountId)],
      );
    });
  }

  Future<void> clearProfile(String localAccountId) async {
    await database.transactionWithRevision(() async {
      final rows = await database.customSelect(
        'SELECT 1 FROM account_profiles WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(localAccountId)],
      ).get();
      final wasOnboardingCompleted = await database.isOnboardingCompleted();
      if (rows.isEmpty && !wasOnboardingCompleted) return false;
      await database.customUpdate(
        'DELETE FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      await database.setOnboardingCompletedInTransaction(false);
      return true;
    });
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
    await database.transactionWithRevision(() async {
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
    await WorkspaceIdentityMigrator(database).migrate();

    Future<String> insertGuestWorkspace() async {
      final id = 'guest_${Uuid().v4()}';
      final now = DateTime.now().microsecondsSinceEpoch;
      await database.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
           VALUES (?, 'local', 'active', ?, ?)''',
        variables: [Variable(id), Variable(now), Variable(now)],
      );
      return id;
    }

    final existingRows = await database
        .customSelect(
          'SELECT local_account_id FROM local_accounts LIMIT 1',
        )
        .get();
    if (existingRows.isEmpty) await insertGuestWorkspace();

    final sessions = await database
        .customSelect(
          'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
        )
        .get();
    final currentId = sessions.isEmpty
        ? null
        : sessions.single.read<String?>('active_local_account_id');
    final currentRows = currentId == null
        ? <dynamic>[]
        : await database.customSelect(
            'SELECT lifecycle_state FROM local_accounts WHERE local_account_id = ? LIMIT 1',
            variables: [Variable(currentId)],
          ).get();
    final currentState = currentRows.isEmpty
        ? null
        : currentRows.single.read<String>('lifecycle_state');
    if (currentState == 'active' || currentState == 'draft') return;

    final candidates = await database.customSelect(
      '''SELECT local_account_id FROM local_accounts
         WHERE lifecycle_state IN ('active', 'draft')
         ORDER BY CASE lifecycle_state WHEN 'active' THEN 0 ELSE 1 END,
                  updated_at DESC, local_account_id ASC LIMIT 1''',
    ).get();
    final nextId = candidates.isNotEmpty
        ? candidates.single.read<String>('local_account_id')
        : await insertGuestWorkspace();
    await database.transaction(() async {
      if (sessions.isEmpty) {
        await database.customInsert(
          '''INSERT INTO app_session_state (id, active_local_account_id, generation)
             VALUES (1, ?, 1)''',
          variables: [Variable(nextId)],
        );
      } else {
        await database.customUpdate(
          '''UPDATE app_session_state SET active_local_account_id = ?,
             generation = generation + 1 WHERE id = 1''',
          variables: [Variable(nextId)],
        );
      }
    });
  }

  LocalAccount _mapAccount(QueryRow row) {
    return LocalAccount(
      localAccountId: row.read<String>('local_account_id'),
      accountMode: AccountMode.local,
      lifecycleState: _parseLifecycleState(
        row.read<String>('lifecycle_state'),
      ),
      createdAt:
          DateTime.fromMicrosecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt:
          DateTime.fromMicrosecondsSinceEpoch(row.read<int>('updated_at')),
      displayName: row.read<String?>('display_name'),
    );
  }

  AccountLifecycleState _parseLifecycleState(String value) => switch (value) {
        'active' => AccountLifecycleState.active,
        'archived' => AccountLifecycleState.archived,
        'draft' => AccountLifecycleState.draft,
        'adopting' => AccountLifecycleState.adopting,
        'restoring' => AccountLifecycleState.restoring,
        'adopted_recovery' => AccountLifecycleState.adoptedRecovery,
        'recovery_copy' => AccountLifecycleState.recoveryCopy,
        'deleted_hold' => AccountLifecycleState.deletedHold,
        _ => throw FormatException('Unknown local workspace state: $value'),
      };

  String _randomId(String prefix) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${prefix}_$hex';
  }

  String jsonEncode(Object value) => json.encode(value);
}
