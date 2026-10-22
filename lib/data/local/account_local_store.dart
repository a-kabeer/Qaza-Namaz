import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import 'database/app_database.dart';
import 'database/database_manager.dart';
import 'workspace_identity_migrator.dart';

class AccountLocalStore {
  AccountLocalStore({
    required this.database,
    DatabaseManager? databaseManager,
  }) : _databaseManager =
            databaseManager ?? DatabaseManager(controlDatabase: database);

  /// Always the control + Guest handle. Registry/session/device changes live here.
  final AppDatabase database;
  final DatabaseManager _databaseManager;

  Future<AppDatabase> _workspaceDatabase(String localAccountId) =>
      _databaseManager.databaseForWorkspace(localAccountId);

  Future<void> ensureInitialized() async {
    await _ensureDeviceId();
    await _ensureLocalAccount();
    await _reconcileOnboardingCommitJournals();
    final persisted = await activeAccount();
    final activeId = persisted?.localAccountId;
    if (activeId != null && activeId.startsWith('google_')) {
      await _databaseManager.ensureGoogleWorkspace(activeId);
    }
    _databaseManager.setActiveWorkspace(activeId);
    final profile = activeId == null ? null : await loadProfile(activeId);
    await database.transaction(() async {
      await database.setOnboardingCompletedInTransaction(
        profile?.onboardingCompleted == true,
      );
    });
  }

  Future<bool> hasAnyQaza(String localAccountId) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final rows = await workspace.customSelect(
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
                a.created_at, a.updated_at, a.db_layout,
                (SELECT value FROM meta_store
                 WHERE key = 'workspace_display_name:' || a.local_account_id
                 LIMIT 1) AS display_name
         FROM local_accounts a
         WHERE a.local_account_id = ?
         LIMIT 1''',
      variables: [Variable(localAccountId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    var displayName = row.read<String?>('display_name');
    if (row.read<String?>('db_layout') == 'separate') {
      final workspace = await _workspaceDatabase(localAccountId);
      final names = await workspace.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable('workspace_display_name:$localAccountId')],
      ).get();
      displayName = names.isEmpty ? null : names.single.read<String>('value');
    }
    return _mapAccount(row, displayName: displayName);
  }

  Future<LocalAccount?> activeAccount() async {
    final rows = await database
        .customSelect(
          'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
        )
        .get();
    if (rows.isEmpty) return null;
    final id = rows.single.read<String?>('active_local_account_id');
    if (id == null || id.trim().isEmpty) return null;
    return getAccount(id);
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

    // Verified Google workspaces must resolve their own file before the active
    // session is published. Legacy shared data is preserved and fails closed.
    if (localAccountId.startsWith('google_')) {
      await _databaseManager.ensureGoogleWorkspace(localAccountId);
    }
    // The onboarding flag is global metadata, so it follows the selected profile.
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
    _databaseManager.setActiveWorkspace(localAccountId);
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

  /// Finds the most recently updated Guest draft that holds no user data or
  /// entered values, if one exists.
  ///
  /// A draft counts as empty when nothing was ever saved into it: no profile
  /// row, no Qaza or daily Salah records, no plan data, and not even a saved
  /// workspace name. Any of those is user data, so such a draft is a real
  /// saved Guest and is never reused.
  Future<String?> findReusableEmptyGuestDraft() async {
    final rows = await database.customSelect(
      '''SELECT local_account_id FROM local_accounts
         WHERE lifecycle_state = 'draft'
           AND (local_account_id = 'guest'
                OR local_account_id GLOB 'guest:*'
                OR local_account_id GLOB 'guest_*')
         ORDER BY updated_at DESC, local_account_id ASC''',
    ).get();
    for (final row in rows) {
      final id = row.read<String>('local_account_id');
      if (await loadWorkspaceDisplayName(id) != null) continue;
      if (await hasAnyAccountData(id)) continue;
      return id;
    }
    return null;
  }

  /// Opens the Guest workspace a "Start Fresh" action should use.
  ///
  /// An existing empty draft is resumed instead of creating another
  /// workspace, so repeated cancelled onboarding attempts do not pile up
  /// empty drafts. A draft holding any user data is left untouched and a
  /// new draft is created, exactly as Start Fresh behaved before.
  Future<String> startFreshGuestWorkspace() async {
    final reusable = await findReusableEmptyGuestDraft();
    if (reusable != null) {
      await activate(reusable);
      return reusable;
    }
    return createGuestWorkspace(draft: true);
  }

  /// Counts the records a workspace owns, so the delete confirmation can
  /// show what will be lost: the profile plus these two record counts.
  Future<GuestWorkspaceRecordCounts> countWorkspaceRecords(
    String localAccountId,
  ) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final qazaRows = await workspace.customSelect(
      'SELECT COUNT(*) AS total FROM qaza_records WHERE user_id = ?',
      variables: [Variable(localAccountId)],
    ).get();
    final salahRows = await workspace.customSelect(
      'SELECT COUNT(*) AS total FROM daily_salah_logs WHERE user_id = ?',
      variables: [Variable(localAccountId)],
    ).get();
    return GuestWorkspaceRecordCounts(
      qazaRecords: qazaRows.first.read<int>('total'),
      dailySalahRecords: salahRows.first.read<int>('total'),
    );
  }

  Future<String?> loadWorkspaceDisplayName(String localAccountId) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final rows = await workspace.customSelect(
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
    final workspace = await _workspaceDatabase(localAccountId);
    await workspace.transactionWithRevision(() async {
      final rows = await workspace.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable(key)],
      ).get();
      final current = rows.isEmpty ? null : rows.first.read<String>('value');
      if ((current ?? '') == normalized) return false;
      if (normalized.isEmpty) {
        await workspace.customStatement(
          'DELETE FROM meta_store WHERE key = ?',
          [key],
        );
      } else {
        await workspace.customInsert(
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
  ///
  /// A draft is listed only when it holds data (Scenario 18): an empty
  /// draft — no saved name and no profile, records, logs, or plan data,
  /// the same emptiness test [findReusableEmptyGuestDraft] uses — stays
  /// hidden from the chooser and management lists, so abandoned onboarding
  /// attempts do not pile up as visible workspaces. Hiding it here does
  /// not affect resumability: startup resume follows the persisted
  /// session, and Start Fresh finds the hidden draft directly.
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
      if (account.displayName?.trim().isNotEmpty == true ||
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
    final workspace = await _workspaceDatabase(localAccountId);
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
      final rows = await workspace.customSelect(
        query,
        variables: [Variable(localAccountId)],
      ).get();
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<UserProfile?> loadProfile(String localAccountId) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final rows = await workspace.customSelect(
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
    final workspace = await _workspaceDatabase(localAccountId);
    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();
    final opId = _randomId('op');
    final beforeGeneration = await database.readSessionGeneration();
    final changed = await workspace.transactionWithRevision<bool>(() async {
      final existingRows = await workspace.customSelect(
        'SELECT payload_json FROM account_profiles WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(localAccountId)],
      ).get();
      UserProfile? existing;
      if (existingRows.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(existingRows.single.read<String>('payload_json'));
          if (decoded is Map) {
            existing = UserProfile.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      if (existing != null &&
          jsonEncode(existing.toJson()) == jsonEncode(profile.toJson())) {
        return false;
      }
      await _writeProfileRowInsideTransaction(
        targetDatabase: workspace,
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
      if (identical(workspace, database)) {
        await database.setOnboardingCompletedInTransaction(
          profile.onboardingCompleted,
        );
      }
      return true;
    });
    if (!identical(workspace, database) &&
        changed &&
        await database.isCurrentWorkspaceGeneration(
          localAccountId: localAccountId,
          generation: beforeGeneration,
        )) {
      await database.transaction(() async {
        await database.setOnboardingCompletedInTransaction(
          profile.onboardingCompleted,
        );
      });
    }
  }

  /// Persists a draft locally.
  Future<void> saveProfileLocalOnly(
    String localAccountId,
    UserProfile profile,
  ) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();
    final opId = _randomId('op');
    final beforeGeneration = await database.readSessionGeneration();
    await workspace.transactionWithRevision(() async {
      await _writeProfileRowInsideTransaction(
        targetDatabase: workspace,
        localAccountId: localAccountId,
        profile: profile,
        nowMicros: now,
        writerDeviceId: device,
        operationId: opId,
      );
      if (identical(workspace, database)) {
        await database.setOnboardingCompletedInTransaction(
          profile.onboardingCompleted,
        );
      }
    });
    if (!identical(workspace, database) &&
        await database.isCurrentWorkspaceGeneration(
          localAccountId: localAccountId,
          generation: beforeGeneration,
        )) {
      await database.transaction(() async {
        await database.setOnboardingCompletedInTransaction(
          profile.onboardingCompleted,
        );
      });
    }
  }

  Future<void> _writeProfileRowInsideTransaction({
    required AppDatabase targetDatabase,
    required String localAccountId,
    required UserProfile profile,
    required int nowMicros,
    required String writerDeviceId,
    required String operationId,
  }) {
    return targetDatabase.customUpdate(
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
    final id = localAccountId.trim();
    if (id.isEmpty) {
      throw StateError('Onboarding requires a local account ID.');
    }
    if (revision.userId != id) {
      throw StateError('Onboarding revision is for a different local account.');
    }
    for (final record in records) {
      if (record.userId != id) {
        throw StateError('Onboarding Qaza record is for a different account.');
      }
      if (record.profilePlanRevisionId != revision.revisionId ||
          record.profilePlanFingerprint != revision.planFingerprint) {
        throw StateError('Onboarding Qaza record has invalid plan provenance.');
      }
    }

    final workspace = await _workspaceDatabase(id);
    final sessionRows = await database
        .customSelect(
          'SELECT active_local_account_id, generation FROM app_session_state WHERE id = 1 LIMIT 1',
        )
        .get();
    final activeId = sessionRows.isEmpty
        ? null
        : sessionRows.single.read<String?>('active_local_account_id');
    if (activeId != id) {
      throw StateError('Onboarding account is not the active local account.');
    }
    final sessionGeneration =
        sessionRows.isEmpty ? 1 : sessionRows.single.read<int>('generation');

    final accountRows = await database.customSelect(
      'SELECT lifecycle_state FROM local_accounts WHERE local_account_id = ? LIMIT 1',
      variables: [Variable(id)],
    ).get();
    if (accountRows.isEmpty) {
      throw StateError('Local onboarding account does not exist.');
    }
    final lifecycle = accountRows.single.read<String>('lifecycle_state');
    if (lifecycle != 'active' && lifecycle != 'draft') {
      throw StateError('Local onboarding account is not active.');
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final device = await deviceInstanceId();
    final operationId = 'onboarding-commit:$id:${revision.revisionId}';

    // Guest remains in one database, preserving its existing atomic transaction.
    if (identical(workspace, database)) {
      await database.transactionWithRevision(() async {
        await _writeOnboardingWorkspaceData(
          targetDatabase: database,
          localAccountId: id,
          profile: profile,
          revision: revision,
          records: records,
          nowMicros: now,
          writerDeviceId: device,
          operationId: operationId,
          onProgress: onProgress,
        );
        await database.setOnboardingCompletedInTransaction(true);
        await database.customUpdate(
          '''UPDATE local_accounts SET lifecycle_state = 'active', updated_at = ?
             WHERE local_account_id = ? AND lifecycle_state = 'draft' ''',
          variables: [Variable(now), Variable(id)],
        );
      });
      return;
    }

    // Google workspaces span two files. A durable control-side journal lets a
    // restart finish registry promotion after the workspace transaction commits.
    await database.customInsert(
      '''INSERT OR IGNORE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, created_at, updated_at, snapshot_id)
         VALUES (?, 'onboarding_commit', ?, ?, 'prepared', ?, ?, ?)''',
      variables: [
        Variable(operationId),
        Variable(id),
        Variable(id),
        Variable(now),
        Variable(now),
        Variable(revision.revisionId),
      ],
    );
    await database.customUpdate(
      '''UPDATE workspace_operation_journal
         SET phase = 'prepared', error_message = NULL, updated_at = ?
         WHERE operation_id = ? AND phase != 'committed' ''',
      variables: [
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(operationId)
      ],
    );

    try {
      await workspace.transactionWithRevision(() async {
        await _writeOnboardingWorkspaceData(
          targetDatabase: workspace,
          localAccountId: id,
          profile: profile,
          revision: revision,
          records: records,
          nowMicros: now,
          writerDeviceId: device,
          operationId: operationId,
          onProgress: onProgress,
        );
      });
      await database.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'verified', updated_at = ?
           WHERE operation_id = ? AND phase != 'committed' ''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(operationId),
        ],
      );
      await _reconcileOnboardingCommitJournals(
        onlyOperationId: operationId,
        expectedSessionGeneration: sessionGeneration,
      );
    } catch (error) {
      await database.customUpdate(
        '''UPDATE workspace_operation_journal
           SET error_message = ?, updated_at = ?
           WHERE operation_id = ? AND phase != 'committed' ''',
        variables: [
          Variable(error.toString()),
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(operationId),
        ],
      );
      rethrow;
    }
  }

  Future<void> _writeOnboardingWorkspaceData({
    required AppDatabase targetDatabase,
    required String localAccountId,
    required UserProfile profile,
    required QazaPlanRevision revision,
    required List<QazaRecord> records,
    required int nowMicros,
    required String writerDeviceId,
    required String operationId,
    void Function(int processed, int total)? onProgress,
  }) async {
    await _writeProfileRowInsideTransaction(
      targetDatabase: targetDatabase,
      localAccountId: localAccountId,
      profile: profile.copyWith(onboardingCompleted: true),
      nowMicros: nowMicros,
      writerDeviceId: writerDeviceId,
      operationId: '${operationId}_profile',
    );

    final revisionPayload = jsonEncode(revision.toJson());
    final existingRevision = await targetDatabase.customSelect(
      '''SELECT payload_json FROM account_plan_revisions
         WHERE local_account_id = ? AND revision_id = ? LIMIT 1''',
      variables: [Variable(localAccountId), Variable(revision.revisionId)],
    ).get();
    if (existingRevision.isNotEmpty) {
      if (existingRevision.single.read<String>('payload_json') !=
          revisionPayload) {
        throw StateError('Immutable onboarding plan revision conflict.');
      }
    } else {
      await targetDatabase.customInsert(
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

    for (var start = 0; start < records.length; start += 500) {
      final end = start + 500 < records.length ? start + 500 : records.length;
      final chunk = records.sublist(start, end);
      if (chunk.isNotEmpty) {
        await targetDatabase.qazaRecordsDao.insertRecordsReturningInsertedIds(
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
        // On a retry after process death, verify existing rows match exactly.
        // Any conflicting payload aborts without overwriting the existing data.
        final persistedRows = await targetDatabase.qazaRecordsDao.getRowsByIds(
          userId: localAccountId,
          ids: chunk.map((record) => record.id).toList(growable: false),
        );
        final persistedById = {
          for (final row in persistedRows) row.id: row,
        };
        for (final record in chunk) {
          final row = persistedById[record.id];
          if (row == null ||
              row.userId != localAccountId ||
              row.prayerType != record.prayerType.name ||
              row.originalDate != record.originalDate ||
              row.status != record.status.name ||
              row.completedAt != record.completedAt ||
              row.completionId != record.completionId ||
              row.additionId != record.additionId ||
              row.recordVersion != record.recordVersion ||
              row.createdAt != record.createdAt ||
              row.updatedAt != record.updatedAt) {
            throw StateError(
              'Onboarding Qaza row verification failed for record ${record.id}.',
            );
          }
        }
        await _upsertProfilePlanProvenance(targetDatabase, chunk);
      }
      onProgress?.call(end, records.length);
    }
  }

  Future<void> _reconcileOnboardingCommitJournals({
    String? onlyOperationId,
    int? expectedSessionGeneration,
  }) async {
    final rows = await database.customSelect(
      '''SELECT operation_id, target_local_account_id, phase
         FROM workspace_operation_journal
         WHERE operation_type = 'onboarding_commit' AND phase = 'verified'
         ${onlyOperationId == null ? '' : 'AND operation_id = ?'}
         ORDER BY created_at''',
      variables:
          onlyOperationId == null ? const [] : [Variable(onlyOperationId)],
    ).get();
    for (final row in rows) {
      final operationId = row.read<String>('operation_id');
      final id = row.read<String>('target_local_account_id');
      final workspace = await _workspaceDatabase(id);
      final profileRows = await workspace.customSelect(
        'SELECT payload_json FROM account_profiles WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(id)],
      ).get();
      if (profileRows.isEmpty) {
        throw StateError(
            'Verified onboarding journal has no workspace profile.');
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(profileRows.single.read<String>('payload_json'));
      } catch (_) {
        throw StateError('Verified onboarding profile is invalid JSON.');
      }
      if (decoded is! Map || decoded['onboardingCompleted'] != true) {
        throw StateError(
            'Verified onboarding profile is not marked completed.');
      }

      await database.transaction(() async {
        final sessionRows = await database
            .customSelect(
              'SELECT active_local_account_id, generation FROM app_session_state WHERE id = 1 LIMIT 1',
            )
            .get();
        final activeId = sessionRows.isEmpty
            ? null
            : sessionRows.single.read<String?>('active_local_account_id');
        final generation = sessionRows.isEmpty
            ? 1
            : sessionRows.single.read<int>('generation');
        await database.customUpdate(
          '''UPDATE local_accounts SET lifecycle_state = 'active', updated_at = ?
             WHERE local_account_id = ? AND lifecycle_state = 'draft' ''',
          variables: [
            Variable(DateTime.now().microsecondsSinceEpoch),
            Variable(id)
          ],
        );
        if (activeId == id &&
            (expectedSessionGeneration == null ||
                expectedSessionGeneration == generation)) {
          await database.setOnboardingCompletedInTransaction(true);
        }
        await database.customUpdate(
          '''UPDATE workspace_operation_journal
             SET phase = 'committed', error_message = NULL, updated_at = ?
             WHERE operation_id = ?''',
          variables: [
            Variable(DateTime.now().microsecondsSinceEpoch),
            Variable(operationId),
          ],
        );
      });
    }
  }

  Future<void> clearProfile(String localAccountId) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final beforeGeneration = await database.readSessionGeneration();
    final changed = await workspace.transactionWithRevision<bool>(() async {
      final rows = await workspace.customSelect(
        'SELECT 1 FROM account_profiles WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(localAccountId)],
      ).get();
      if (rows.isEmpty) return false;
      await workspace.customUpdate(
        'DELETE FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable(localAccountId)],
      );
      if (identical(workspace, database)) {
        await database.setOnboardingCompletedInTransaction(false);
      }
      return true;
    });
    if (!identical(workspace, database) &&
        changed &&
        await database.isCurrentWorkspaceGeneration(
          localAccountId: localAccountId,
          generation: beforeGeneration,
        )) {
      await database.transaction(() async {
        await database.setOnboardingCompletedInTransaction(false);
      });
    }
  }

  Future<List<QazaPlanRevision>> loadPlanRevisions(
    String localAccountId,
  ) async {
    final workspace = await _workspaceDatabase(localAccountId);
    final rows = await workspace.customSelect(
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
    final workspace = await _workspaceDatabase(localAccountId);
    final payload = jsonEncode(revision.toJson());
    final existing = await workspace.customSelect(
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
    await workspace.transactionWithRevision(() async {
      await workspace.customInsert(
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
    AppDatabase targetDatabase,
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
      await targetDatabase.customInsert(
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

  LocalAccount _mapAccount(QueryRow row, {String? displayName}) {
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
      displayName: displayName ?? row.read<String?>('display_name'),
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
