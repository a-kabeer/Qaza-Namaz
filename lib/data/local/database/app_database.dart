import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'database_encryption.dart';
import 'qaza_records_dao.dart';
import 'tables/qaza_records.dart';

part 'app_database.g.dart';

enum AppDatabaseRole { controlGuest, googleWorkspace }

/// Application-local encrypted SQLite database.
@DriftDatabase(
  tables: [QazaRecords],
  daos: [QazaRecordsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Test seam retained for in-memory and explicitly supplied executors.
  AppDatabase([QueryExecutor? executor])
      : _role = AppDatabaseRole.controlGuest,
        _workspaceId = null,
        super(executor ?? _openEncryptedDatabase());

  /// Explicit production constructor for the control + Guest database.
  AppDatabase.control()
      : _role = AppDatabaseRole.controlGuest,
        _workspaceId = null,
        super(_openEncryptedDatabase());

  AppDatabase._workspace({
    required QueryExecutor executor,
    required String workspaceId,
  })  : _role = AppDatabaseRole.googleWorkspace,
        _workspaceId = workspaceId,
        super(executor);

  final AppDatabaseRole _role;
  final String? _workspaceId;

  bool get isGoogleWorkspaceDatabase =>
      _role == AppDatabaseRole.googleWorkspace;
  String? get workspaceId => _workspaceId;

  static QueryExecutor _openEncryptedDatabase({
    String fileName = 'qaza_namaz.sqlite',
    bool migrateLegacyPlaintext = true,
  }) {
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final databaseFile = File('${directory.path}/$fileName');
      final key = await DatabaseEncryptionKeyStore().readOrCreate();

      if (migrateLegacyPlaintext) {
        await PlaintextDatabaseMigrator.migrateIfNeeded(
          databaseFile: databaseFile,
          key: key,
        );
      }

      return NativeDatabase.createInBackground(
        databaseFile,
        setup: (rawDb) {
          final cipher = rawDb.select('PRAGMA cipher;');
          if (cipher.isEmpty) {
            throw StateError(
              'Encrypted SQLite support is unavailable in this build.',
            );
          }

          final escapedKey = key.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escapedKey';");

          // Force SQLite to validate the key before Drift starts issuing
          // application queries.
          rawDb.select('SELECT count(*) FROM sqlite_master;');
        },
      );
    });
  }

  /// Schema version 26 adds control-registry database-layout metadata.
  /// Backup payload schema remains v1; workspace data/JSON shapes are unchanged.
  @override
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _ensureQazaAdditionSchema();
          await _ensureQazaProfilePlanProvenanceSchema();
          await _ensurePerformanceIndexes();
          await _ensureAccountSchema();
          await _ensureMetaStoreSchema();
          await _ensureDailySalahTrackingSchema();
          await _ensureLocalRecoverySnapshotSchema();
          await _ensureWorkspaceRevisionSchema();
          await _ensureWorkspaceLifecycleSchema();
          if (isGoogleWorkspaceDatabase) {
            await _ensureWorkspaceOwnerGuardSchema();
            if (_workspaceId == null || _workspaceId!.isEmpty) {
              throw StateError(
                  'Google workspace database requires an owner ID.');
            }
          } else {
            await _ensureRegistryDatabaseRoutingSchema();
            await _ensureCloudSetupChoiceSchema();
            await _ensureWorkspaceOperationJournalColumns();
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (isGoogleWorkspaceDatabase) {
            // Google workspace files contain only workspace-owned state.
            // The control registry/session/journal are never installed here.
            await _ensureQazaAdditionSchema();
            await _ensureQazaProfilePlanProvenanceSchema();
            await _ensurePerformanceIndexes();
            await _ensureAccountSchema();
            await _ensureMetaStoreSchema();
            await _ensureDailySalahTrackingSchema();
            await _ensureLocalRecoverySnapshotSchema();
            await _ensureWorkspaceRevisionSchema();
            await _ensureWorkspaceLifecycleSchema();
            await _ensureWorkspaceOwnerGuardSchema();
            return;
          }
          if (from < 2) {
            await _ensurePerformanceIndexes();
          }
          if (from < 5) {
            await m.addColumn(qazaRecords, qazaRecords.completionId);
          }
          if (from < 6) {
            await _removeLegacyQazaHistorySchema();
          }
          if (from < 7) {
            await m.addColumn(qazaRecords, qazaRecords.additionId);
            await m.addColumn(qazaRecords, qazaRecords.recordVersion);
            await _ensureQazaAdditionSchema();
          }
          if (from < 8) {
            // Keep legacy completed rows visible in the permanent Completed
            // workspace even when older data lacks completedAt.
            await customStatement(
              "UPDATE qaza_records SET completed_at = updated_at "
              "WHERE status = 'completed' AND completed_at IS NULL",
            );
          }
          if (from < 9) {
            // The deletion-action table was introduced during the schema 7
            // migration. Check the actual table shape so an older upgrade
            // does not attempt to add the column twice.
            final columns = await customSelect(
              'PRAGMA table_info(qaza_deletion_actions)',
            ).get();
            final hasResolvedAt = columns.any(
              (row) => row.read<String>('name') == 'resolved_at',
            );
            if (!hasResolvedAt) {
              await customStatement(
                'ALTER TABLE qaza_deletion_actions ADD COLUMN resolved_at TEXT',
              );
            }
          }
          if (from < 10) {
            await _ensureQazaProfilePlanProvenanceSchema();
          }
          if (from < 12) {
            await _ensureDeletionActionVersionColumn();
          }
          if (from < 11) {
            await _ensureAccountSchema();
          }
          await _ensurePerformanceIndexes();
          if (from < 18) {
            await _ensureMetaStoreSchema();
          }
          if (from < 19) {
            await _ensureMetaStoreSchema();
            await _ensureCloudSetupChoiceSchema();
            await _ensureLocalRecoverySnapshotSchema();
          }
          if (from < 20) {
            await _ensureDailySalahTrackingSchema();
          }
          if (from < 21) {
            await _ensureDailySalahTrackingLinkSchema();
          }
          if (from < 22) {
            await _migrateDailySalahTrackingPreferencesToWorkspaceScope();
          }
          if (from < 23) {
            await _ensureWorkspaceRevisionSchema();
          }
          if (from < 24) {
            await _ensureWorkspaceLifecycleSchema();
          }
          if (from < 25) {
            await _ensureWorkspaceGenerationColumn();
          }
          if (from < 26) {
            await _ensureAccountSchema();
            await _ensureRegistryDatabaseRoutingSchema();
            await _ensureWorkspaceLifecycleSchema();
            await _ensureWorkspaceOperationJournalColumns();
          }
        },
      );

  Future<void> _ensureMetaStoreSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meta_store (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    if (isGoogleWorkspaceDatabase) {
      final id = _workspaceId;
      if (id == null || id.isEmpty) {
        throw StateError('Google workspace database requires an owner ID.');
      }
      await customInsert(
        'INSERT OR IGNORE INTO meta_store (key, value) VALUES (?, ?)',
        variables: [
          Variable<String>('workspace_revision:$id'),
          const Variable<String>('1'),
        ],
      );
      return;
    }
    await customStatement(
      "INSERT OR IGNORE INTO meta_store (key, value) VALUES "
      "('is_onboarding_completed', '0')",
    );
    // Drift's schemaVersion is the sole authoritative SQLite schema version.
    await customStatement(
        "DELETE FROM meta_store WHERE key = 'schema_version'");
    await customStatement(
      "INSERT OR IGNORE INTO meta_store (key, value) VALUES ('db_revision', '1')",
    );
  }

  Future<void> _ensureDailySalahTrackingSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS daily_salah_logs (
        user_id TEXT NOT NULL,
        prayer_date TEXT NOT NULL,
        prayer_type TEXT NOT NULL,
        status TEXT NOT NULL,
        tracker_created_qaza_id TEXT,
        linked_qaza_id TEXT,
        completion_sync_id TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, prayer_date, prayer_type),
        CHECK (prayer_type IN ('fajr', 'zuhr', 'asr', 'maghrib', 'isha', 'witr')),
        CHECK (status IN ('prayed', 'missed', 'unrecorded'))
      )
    ''');
    await _ensureDailySalahTrackingLinkSchema();
    await customStatement(
      'CREATE INDEX IF NOT EXISTS daily_salah_logs_user_date_idx '
      'ON daily_salah_logs (user_id, prayer_date)',
    );
  }

  Future<void> _ensureDailySalahTrackingLinkSchema() async {
    final columns =
        await customSelect('PRAGMA table_info(daily_salah_logs)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('linked_qaza_id')) {
      await customStatement(
        'ALTER TABLE daily_salah_logs ADD COLUMN linked_qaza_id TEXT',
      );
    }
    if (!names.contains('completion_sync_id')) {
      await customStatement(
        'ALTER TABLE daily_salah_logs ADD COLUMN completion_sync_id TEXT',
      );
    }

    // Preserve known associations for older tracker-created records.
    await customStatement(
      'UPDATE daily_salah_logs SET linked_qaza_id = tracker_created_qaza_id '
      'WHERE linked_qaza_id IS NULL AND tracker_created_qaza_id IS NOT NULL',
    );
  }

  String _workspacePreferenceKey(String name, String userId) {
    final normalized = userId.trim().isEmpty ? 'guest' : userId.trim();
    return '$name:$normalized';
  }

  /// Moves preferences from the former global keys to the workspace that was
  /// active during the schema upgrade. The legacy keys are removed so a new
  /// workspace cannot accidentally inherit another workspace's setting.
  Future<void> _migrateDailySalahTrackingPreferencesToWorkspaceScope() async {
    final sessionRows = await customSelect(
      'SELECT active_local_account_id FROM app_session_state ORDER BY id LIMIT 1',
    ).get();
    final rawUserId = sessionRows.isEmpty
        ? null
        : sessionRows.first.read<String?>('active_local_account_id');
    final userId = rawUserId == null || rawUserId.trim().isEmpty
        ? 'guest'
        : rawUserId.trim();

    for (final name in [
      'daily_salah_tracking_enabled',
      'daily_salah_tracking_setup_dismissed',
    ]) {
      final legacyRows = await customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable.withString(name)],
      ).get();
      if (legacyRows.isEmpty) continue;

      final scopedKey = _workspacePreferenceKey(name, userId);
      await customUpdate(
        'INSERT OR IGNORE INTO meta_store (key, value) VALUES (?, ?)',
        variables: [
          Variable.withString(scopedKey),
          Variable.withString(legacyRows.first.read<String>('value')),
        ],
      );
      await customUpdate(
        'DELETE FROM meta_store WHERE key = ?',
        variables: [Variable.withString(name)],
      );
    }
  }

  Future<bool> isDailySalahTrackingEnabled({String userId = 'guest'}) async {
    await _ensureMetaStoreSchema();
    final key = _workspacePreferenceKey('daily_salah_tracking_enabled', userId);
    final rows = await customSelect(
      'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
      variables: [Variable.withString(key)],
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<void> setDailySalahTrackingEnabled(
    bool enabled, {
    String userId = 'guest',
  }) async {
    await transactionWithRevision<bool>(
      () => setDailySalahTrackingEnabledInTransaction(
        enabled,
        userId: userId,
      ),
      mutationPredicate: (changed) => changed,
    );
  }

  /// Persists the feature toggle within an existing database transaction.
  /// Used by backup restore as well as the normal settings control.
  Future<bool> setDailySalahTrackingEnabledInTransaction(
    bool enabled, {
    String userId = 'guest',
  }) async {
    final current = await isDailySalahTrackingEnabled(userId: userId);
    if (current == enabled) return false;
    final key = _workspacePreferenceKey('daily_salah_tracking_enabled', userId);
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString(key),
        Variable(enabled ? '1' : '0'),
      ],
    );
    return true;
  }

  Future<bool> isDailySalahTrackingSetupDismissed({
    String userId = 'guest',
  }) async {
    await _ensureMetaStoreSchema();
    final key = _workspacePreferenceKey(
      'daily_salah_tracking_setup_dismissed',
      userId,
    );
    final rows = await customSelect(
      'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
      variables: [Variable.withString(key)],
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<void> setDailySalahTrackingSetupDismissed(
    bool dismissed, {
    String userId = 'guest',
  }) async {
    await transactionWithRevision<bool>(
      () => setDailySalahTrackingSetupDismissedInTransaction(
        dismissed,
        userId: userId,
      ),
      mutationPredicate: (changed) => changed,
    );
  }

  Future<bool> setDailySalahTrackingSetupDismissedInTransaction(
    bool dismissed, {
    String userId = 'guest',
  }) async {
    final current = await isDailySalahTrackingSetupDismissed(userId: userId);
    if (current == dismissed) return false;
    final key = _workspacePreferenceKey(
      'daily_salah_tracking_setup_dismissed',
      userId,
    );
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString(key),
        Variable(dismissed ? '1' : '0'),
      ],
    );
    return true;
  }

  Future<void> _ensureCloudSetupChoiceSchema() async {
    await customStatement(
      "INSERT OR IGNORE INTO meta_store (key, value) "
      "VALUES ('cloud_setup_choice_complete', '0')",
    );
  }

  Future<bool> isCloudSetupChoiceComplete() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store "
      "WHERE key = 'cloud_setup_choice_complete' LIMIT 1",
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<void> markCloudSetupChoiceComplete() async {
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('cloud_setup_choice_complete', '1')
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
    );
  }

  /// Marks that an explicit sign-out should return to account choice without
  /// altering first-run onboarding completion or local Qaza data.
  Future<bool> hasReturningAccountChoicePending() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store "
      "WHERE key = 'returning_account_choice_pending' LIMIT 1",
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<void> markReturningAccountChoicePending() async {
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('returning_account_choice_pending', '1')
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
    );
  }

  Future<void> clearReturningAccountChoicePending() async {
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('returning_account_choice_pending', '0')
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
    );
  }

  /// The guest connection prompt is persisted once shown, so it is not
  /// repeated after rebuilds or application restarts.
  Future<bool> hasShownGuestGooglePrompt() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store "
      "WHERE key = 'guest_google_prompt_shown' LIMIT 1",
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<void> markGuestGooglePromptShown() async {
    await customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('guest_google_prompt_shown', '1')
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
    );
  }

  /// Stores one encrypted, app-private recovery snapshot before a confirmed
  /// destructive restore. The table is excluded from normal export payloads.
  Future<void> _ensureLocalRecoverySnapshotSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_recovery_snapshots (
        snapshot_id TEXT NOT NULL PRIMARY KEY,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveLocalRecoverySnapshot(
    String payloadJson, {
    DateTime? createdAt,
  }) async {
    if (payloadJson.trim().isEmpty) {
      throw ArgumentError.value(payloadJson, 'payloadJson');
    }
    await transaction(() async {
      await _ensureLocalRecoverySnapshotSchema();
      await customStatement('DELETE FROM local_recovery_snapshots');
      await customInsert(
        'INSERT INTO local_recovery_snapshots '
        '(snapshot_id, created_at, payload_json) VALUES (?, ?, ?)',
        variables: [
          Variable('latest'),
          Variable((createdAt ?? DateTime.now()).toUtc().toIso8601String()),
          Variable(payloadJson),
        ],
      );
    });
  }

  Future<String?> readLocalRecoverySnapshot() async {
    await _ensureLocalRecoverySnapshotSchema();
    final rows = await customSelect(
      'SELECT payload_json FROM local_recovery_snapshots '
      "WHERE snapshot_id = 'latest' LIMIT 1",
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('payload_json');
  }

  Future<bool> hasLocalRecoverySnapshot() async {
    final rows = await customSelect(
      "SELECT 1 AS present FROM sqlite_master "
      "WHERE type = 'table' AND name = 'local_recovery_snapshots' LIMIT 1",
    ).get();
    if (rows.isEmpty) return false;
    final snapshots = await customSelect(
      'SELECT 1 AS present FROM local_recovery_snapshots LIMIT 1',
    ).get();
    return snapshots.isNotEmpty;
  }

  Future<void> clearLocalRecoverySnapshot() async {
    await _ensureLocalRecoverySnapshotSchema();
    await customStatement('DELETE FROM local_recovery_snapshots');
  }

  Future<bool> isOnboardingCompleted() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store WHERE key = 'is_onboarding_completed' LIMIT 1",
    ).get();
    return rows.isNotEmpty && rows.first.read<String>('value') == '1';
  }

  Future<int> readDbRevision() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store WHERE key = 'db_revision' LIMIT 1",
    ).get();
    if (rows.isEmpty) {
      throw StateError('The local database revision is missing.');
    }
    final revision = int.tryParse(rows.first.read<String>('value'));
    if (revision == null || revision < 1) {
      throw StateError('The local database revision is invalid.');
    }
    return revision;
  }

  /// Reads a monotonic revision for one workspace. Unrelated Guest/Google
  /// writes must not make this workspace look dirty or race its restore.
  Future<int> readWorkspaceRevision(String localAccountId) async {
    final accountId = localAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    final rows = await customSelect(
      'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
      variables: [Variable('workspace_revision:$accountId')],
    ).get();
    if (rows.isEmpty) return 1;
    final revision = int.tryParse(rows.first.read<String>('value'));
    if (revision == null || revision < 1) {
      throw StateError('The workspace revision is invalid.');
    }
    return revision;
  }

  /// Returns the active workspace ID used to scope the durable initial-upload
  /// marker. This keeps one Google account's pending upload from appearing
  /// while an unrelated Guest or Google workspace is active.
  Future<String?> _activeAccountForInitialBackup() async {
    final rows = await customSelect(
      'SELECT active_local_account_id FROM app_session_state '
      'WHERE id = 1 LIMIT 1',
    ).get();
    if (rows.isEmpty) return null;
    final id = rows.first.read<String?>('active_local_account_id')?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<String?> _pendingInitialBackupAccount() async {
    final rows = await customSelect(
      "SELECT value FROM meta_store "
      "WHERE key = 'initial_cloud_backup_pending_account_id' LIMIT 1",
    ).get();
    if (rows.isEmpty) return null;
    final id = rows.first.read<String>('value').trim();
    return id.isEmpty ? null : id;
  }

  /// Durable marker for an initial upload, scoped to a local workspace.
  /// A legacy marker without an owner is ambiguous, so it is not assigned to
  /// whichever account happens to be active after an upgrade.
  String _initialCloudBackupPendingKey(String accountId) =>
      'initial_cloud_backup_pending:${accountId.trim()}';

  Future<bool> hasPendingInitialCloudBackup({String? localAccountId}) async {
    final activeAccount = localAccountId?.trim().isNotEmpty == true
        ? localAccountId!.trim()
        : await _activeAccountForInitialBackup();
    if (activeAccount == null || activeAccount.isEmpty) return false;

    // New markers are independent per workspace. A late upload callback for
    // Google B must never clear or replace Google A's pending marker.
    final scopedRows = await customSelect(
      'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
      variables: [Variable(_initialCloudBackupPendingKey(activeAccount))],
    ).get();
    if (scopedRows.isNotEmpty) {
      return scopedRows.single.read<String>('value') == '1';
    }

    // Read legacy single-owner markers written by older app versions without
    // assigning an ambiguous marker to whichever workspace is active now.
    final legacyRows = await customSelect(
      "SELECT value FROM meta_store "
      "WHERE key = 'initial_cloud_backup_pending' LIMIT 1",
    ).get();
    if (legacyRows.isEmpty || legacyRows.single.read<String>('value') != '1') {
      return false;
    }
    return await _pendingInitialBackupAccount() == activeAccount;
  }

  Future<void> _refreshLegacyInitialCloudBackupMarker() async {
    final pendingRows = await customSelect(
      "SELECT key FROM meta_store "
      "WHERE key LIKE 'initial_cloud_backup_pending:%' AND value = '1' "
      "ORDER BY key",
    ).get();
    if (pendingRows.isEmpty) {
      await customInsert(
        '''INSERT INTO meta_store (key, value)
           VALUES ('initial_cloud_backup_pending', '0')
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      );
      await customStatement(
        "DELETE FROM meta_store "
        "WHERE key = 'initial_cloud_backup_pending_account_id'",
      );
      return;
    }

    await customInsert(
      '''INSERT INTO meta_store (key, value)
         VALUES ('initial_cloud_backup_pending', '1')
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
    );
    if (pendingRows.length == 1) {
      final key = pendingRows.single.read<String>('key');
      await customInsert(
        '''INSERT INTO meta_store (key, value)
           VALUES ('initial_cloud_backup_pending_account_id', ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        variables: [
          Variable(key.substring('initial_cloud_backup_pending:'.length))
        ],
      );
    } else {
      // More than one workspace can be pending; the legacy scalar marker
      // cannot represent that state, so deliberately leave it ownerless.
      await customStatement(
        "DELETE FROM meta_store "
        "WHERE key = 'initial_cloud_backup_pending_account_id'",
      );
    }
  }

  Future<void> markInitialCloudBackupPending({String? localAccountId}) async {
    final accountId = localAccountId?.trim().isNotEmpty == true
        ? localAccountId!.trim()
        : await _activeAccountForInitialBackup();
    if (accountId == null || accountId.isEmpty) {
      throw StateError(
        'Cannot mark an initial cloud backup without a selected workspace.',
      );
    }
    await transaction(() async {
      await customInsert(
        '''INSERT INTO meta_store (key, value) VALUES (?, '1')
           ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
        variables: [Variable(_initialCloudBackupPendingKey(accountId))],
      );
      await _refreshLegacyInitialCloudBackupMarker();
    });
  }

  Future<void> clearPendingInitialCloudBackup({String? localAccountId}) async {
    final accountId = localAccountId?.trim().isNotEmpty == true
        ? localAccountId!.trim()
        : await _activeAccountForInitialBackup();
    if (accountId == null || accountId.isEmpty) return;

    await transaction(() async {
      await customStatement(
        'DELETE FROM meta_store WHERE key = ?',
        [_initialCloudBackupPendingKey(accountId)],
      );

      // Clear a legacy owner marker only if it belongs to this workspace.
      if (await _pendingInitialBackupAccount() == accountId) {
        await customStatement(
          "DELETE FROM meta_store "
          "WHERE key = 'initial_cloud_backup_pending_account_id'",
        );
      }
      await _refreshLegacyInitialCloudBackupMarker();
    });
  }

  /// Returns true only when the database is still a genuinely fresh install.
  /// The local account/session bootstrap rows are expected and are excluded;
  /// any profile, Qaza ledger, plan-revision, or mutation data blocks an
  /// automatic destructive restore.
  Future<bool> isFreshInstallationForCloudRestore({
    String? localAccountId,
  }) async {
    return transaction(() async {
      if (localAccountId == null) {
        if (await isOnboardingCompleted() || await readDbRevision() != 1) {
          return false;
        }

        const businessTables = <String>[
          'qaza_records',
          'daily_salah_logs',
          'qaza_additions',
          'qaza_deletion_actions',
          'qaza_deletion_action_record_snapshots',
          'qaza_profile_plan_provenance',
          'account_profiles',
          'account_plan_revisions',
        ];
        for (final table in businessTables) {
          final row = await customSelect(
            'SELECT COUNT(*) AS row_count FROM $table',
          ).getSingle();
          if (row.read<int>('row_count') != 0) return false;
        }
        return true;
      }

      final normalized = localAccountId.trim();
      if (normalized.isEmpty) return false;

      // Account switching is allowed even when another workspace has data or
      // the global revision is greater than one. Only this workspace blocks
      // automatic restore.
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
        final row = await customSelect(
          'SELECT 1 FROM $table WHERE $ownerColumn = ? LIMIT 1',
          variables: [Variable(normalized)],
        ).get();
        if (row.isNotEmpty) return false;
      }
      return true;
    });
  }

  Future<void> setOnboardingCompletedInTransaction(bool completed) {
    return customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('is_onboarding_completed', ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [Variable(completed ? '1' : '0')],
    );
  }

  Future<void> setDbRevisionInTransaction(int revision) {
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision');
    }
    return customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES ('db_revision', ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [Variable(revision.toString())],
    );
  }

  Future<int> incrementDbRevisionInTransaction() async {
    await customUpdate(
      '''UPDATE meta_store
         SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT)
         WHERE key = 'db_revision' ''',
    );
    return readDbRevision();
  }

  /// Runs one logical local write transaction and advances db_revision once
  /// when the operation actually mutates local state.
  Future<T> transactionWithRevision<T>(
    Future<T> Function() action, {
    bool Function(T result)? mutationPredicate,
  }) async {
    return transaction(() async {
      final result = await action();
      final mutated = mutationPredicate?.call(result) ??
          switch (result) {
            bool value => value,
            int value => value > 0,
            Iterable<dynamic> value => value.isNotEmpty,
            _ => true,
          };
      if (mutated && !isGoogleWorkspaceDatabase) {
        // Google workspace files use their own trigger-maintained workspace_revision.
        // A global db_revision key exists only in the control/Guest database.
        await incrementDbRevisionInTransaction();
      }
      return result;
    });
  }

  Future<void> _ensureAccountSchema() async {
    if (!isGoogleWorkspaceDatabase) {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS local_accounts (
          local_account_id TEXT NOT NULL PRIMARY KEY,
          account_mode TEXT NOT NULL DEFAULT 'local',
          lifecycle_state TEXT NOT NULL DEFAULT 'active',
          db_file_name TEXT,
          db_layout TEXT NOT NULL DEFAULT 'shared',
          db_migration_state TEXT NOT NULL DEFAULT 'not_started',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS app_session_state (
          id INTEGER NOT NULL PRIMARY KEY,
          active_local_account_id TEXT,
          generation INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS device_metadata (
          id INTEGER NOT NULL PRIMARY KEY,
          device_instance_id TEXT NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE TABLE IF NOT EXISTS account_profiles (
        local_account_id TEXT NOT NULL PRIMARY KEY,
        payload_json TEXT NOT NULL,
        entity_version INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        writer_device_id TEXT NOT NULL,
        operation_id TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS account_plan_revisions (
        local_account_id TEXT NOT NULL,
        revision_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (local_account_id, revision_id)
      )
    ''');
  }

  Future<String?> readWorkspaceFileOwner() async {
    if (!isGoogleWorkspaceDatabase) {
      throw StateError('The control database has no Google workspace owner.');
    }
    final rows = await customSelect(
      "SELECT value FROM meta_store WHERE key = 'workspace_file_owner' LIMIT 1",
    ).get();
    return rows.isEmpty ? null : rows.single.read<String>('value');
  }

  Future<void> writeWorkspaceFileOwner(String localAccountId) async {
    if (!isGoogleWorkspaceDatabase || localAccountId != _workspaceId) {
      throw StateError(
          'Workspace owner marker does not match the database target.');
    }
    await customInsert(
      'INSERT INTO meta_store (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      variables: [
        const Variable<String>('workspace_file_owner'),
        Variable<String>(localAccountId),
      ],
    );
  }

  Future<void> _ensureWorkspaceOwnerGuardSchema() async {
    if (!isGoogleWorkspaceDatabase) return;
    final id = _workspaceId;
    if (id == null || id.isEmpty) {
      throw StateError('Google workspace database requires an owner ID.');
    }
    final ownerLiteral = "'${id.replaceAll("'", "''")}'";
    const ownerTables = <String, String>{
      'qaza_records': 'user_id',
      'daily_salah_logs': 'user_id',
      'qaza_additions': 'user_id',
      'qaza_deletion_actions': 'user_id',
      'qaza_deletion_action_record_snapshots': 'user_id',
      'qaza_profile_plan_provenance': 'user_id',
      'account_profiles': 'local_account_id',
      'account_plan_revisions': 'local_account_id',
      'workspace_sync_metadata': 'local_account_id',
    };
    for (final entry in ownerTables.entries) {
      final table = entry.key;
      final ownerColumn = entry.value;
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS workspace_owner_guard_${table}_insert
        BEFORE INSERT ON "$table"
        WHEN NEW."$ownerColumn" != $ownerLiteral
        BEGIN
          SELECT RAISE(ABORT, 'workspace owner mismatch');
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS workspace_owner_guard_${table}_update
        BEFORE UPDATE OF "$ownerColumn" ON "$table"
        WHEN NEW."$ownerColumn" != $ownerLiteral
        BEGIN
          SELECT RAISE(ABORT, 'workspace owner mismatch');
        END
      ''');
    }
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS workspace_meta_owner_guard_insert
      BEFORE INSERT ON meta_store
      WHEN NOT (
        NEW.key = 'workspace_file_owner'
        OR NEW.key = ('workspace_revision:' || $ownerLiteral)
        OR NEW.key = ('workspace_display_name:' || $ownerLiteral)
        OR NEW.key = ('daily_salah_tracking_enabled:' || $ownerLiteral)
        OR NEW.key = ('daily_salah_tracking_setup_dismissed:' || $ownerLiteral)
        OR NEW.key = ('initial_cloud_backup_pending:' || $ownerLiteral)
      )
      BEGIN
        SELECT RAISE(ABORT, 'workspace metadata key is not scoped to this owner');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS workspace_meta_owner_guard_update
      BEFORE UPDATE ON meta_store
      WHEN NOT (
        NEW.key = 'workspace_file_owner'
        OR NEW.key = ('workspace_revision:' || $ownerLiteral)
        OR NEW.key = ('workspace_display_name:' || $ownerLiteral)
        OR NEW.key = ('daily_salah_tracking_enabled:' || $ownerLiteral)
        OR NEW.key = ('daily_salah_tracking_setup_dismissed:' || $ownerLiteral)
        OR NEW.key = ('initial_cloud_backup_pending:' || $ownerLiteral)
      )
      BEGIN
        SELECT RAISE(ABORT, 'workspace metadata key is not scoped to this owner');
      END
    ''');
  }

  Future<void> _ensureWorkspaceOperationJournalColumns() async {
    final rows = await customSelect(
      'PRAGMA table_info(workspace_operation_journal)',
    ).get();
    final names = rows.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('staging_file')) {
      await customStatement(
        'ALTER TABLE workspace_operation_journal ADD COLUMN staging_file TEXT',
      );
    }
    if (!names.contains('final_file')) {
      await customStatement(
        'ALTER TABLE workspace_operation_journal ADD COLUMN final_file TEXT',
      );
    }
    if (!names.contains('content_hash')) {
      await customStatement(
        'ALTER TABLE workspace_operation_journal ADD COLUMN content_hash TEXT',
      );
    }
    // Recovery Stage 4 (design §5.1): the migration manifest carries
    // distinct source and target hashes, not one shared content hash.
    if (!names.contains('source_hash')) {
      await customStatement(
        'ALTER TABLE workspace_operation_journal ADD COLUMN source_hash TEXT',
      );
    }
    if (!names.contains('target_hash')) {
      await customStatement(
        'ALTER TABLE workspace_operation_journal ADD COLUMN target_hash TEXT',
      );
    }
  }

  /// Adds physical-database routing metadata to the control registry.
  /// Existing workspaces start on the shared layout; Phase 2 changes this only
  /// after a separate file has been validated and its publication is journalled.
  Future<void> _ensureRegistryDatabaseRoutingSchema() async {
    final columns = await customSelect(
      'PRAGMA table_info(local_accounts)',
    ).get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('db_file_name')) {
      await customStatement(
          'ALTER TABLE local_accounts ADD COLUMN db_file_name TEXT');
    }
    if (!names.contains('db_layout')) {
      await customStatement(
        "ALTER TABLE local_accounts ADD COLUMN db_layout TEXT NOT NULL DEFAULT 'shared'",
      );
    }
    if (!names.contains('db_migration_state')) {
      await customStatement(
        "ALTER TABLE local_accounts ADD COLUMN db_migration_state TEXT NOT NULL DEFAULT 'not_started'",
      );
    }

    final invalidRows = await customSelect(
      "SELECT local_account_id FROM local_accounts "
      "WHERE db_layout NOT IN ('shared', 'separate') OR db_layout IS NULL LIMIT 1",
    ).get();
    // Do not interpret an unrecognized layout as shared. A malformed layout is
    // an integrity error and must prevent any workspace from being routed.
    if (invalidRows.isNotEmpty) {
      throw StateError(
          'A local workspace has invalid database routing metadata.');
    }
  }

  /// Installs triggers that advance revisions only for the workspace touched
  /// by a row write. Existing workspaces start dirty so the first cloud
  /// connection cannot mistake an existing ledger for an empty install.
  /// Durable operation journal, workspace sync metadata, and undoable Guest
  /// deletion holds. These records remain local and are never restored from a
  /// remote workspace payload.
  Future<void> _ensureWorkspaceLifecycleSchema() async {
    if (!isGoogleWorkspaceDatabase) {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS workspace_operation_journal (
          operation_id TEXT NOT NULL PRIMARY KEY,
          operation_type TEXT NOT NULL,
          source_local_account_id TEXT NOT NULL,
          target_local_account_id TEXT NOT NULL,
          phase TEXT NOT NULL,
          snapshot_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          backup_verified_at INTEGER,
          error_message TEXT,
          staging_file TEXT,
          final_file TEXT,
          content_hash TEXT,
          source_hash TEXT,
          target_hash TEXT
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS local_workspace_deletion_holds (
          local_account_id TEXT NOT NULL PRIMARY KEY,
          requested_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL,
          prior_lifecycle_state TEXT NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE TABLE IF NOT EXISTS workspace_sync_metadata (
        local_account_id TEXT NOT NULL PRIMARY KEY,
        sync_state TEXT NOT NULL DEFAULT 'pending',
        local_revision INTEGER NOT NULL DEFAULT 1,
        last_synced_revision INTEGER,
        last_synced_local_hash TEXT,
        last_synced_remote_version TEXT,
        last_synced_remote_hash TEXT,
        last_checked_at TEXT,
        conflict_marker TEXT,
        remote_account_id TEXT
      )
    ''');
  }

  Future<String> readWorkspaceSyncState(String localAccountId) async {
    final accountId = localAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    final rows = await customSelect(
      'SELECT sync_state FROM workspace_sync_metadata '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable(accountId)],
    ).get();
    if (rows.isEmpty) return 'pending';
    return rows.first.read<String>('sync_state');
  }

  Future<void> writeWorkspaceSyncState(
    String localAccountId,
    String syncState, {
    int? localRevision,
    int? lastSyncedRevision,
    String? lastSyncedLocalHash,
    String? lastSyncedRemoteVersion,
    String? lastSyncedRemoteHash,
    String? lastCheckedAt,
    String? conflictMarker,
    String? remoteAccountId,
  }) async {
    const validStates = <String>{
      'clean',
      'pending',
      'cloud_unverified',
      'legacy_unverified',
      'conflict',
      'needs_sign_in',
    };
    final accountId = localAccountId.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(localAccountId, 'localAccountId');
    }
    if (!validStates.contains(syncState)) {
      throw ArgumentError.value(syncState, 'syncState');
    }
    await customInsert(
      '''INSERT INTO workspace_sync_metadata
         (local_account_id, sync_state, local_revision, last_synced_revision,
          last_synced_local_hash, last_synced_remote_version,
          last_synced_remote_hash, last_checked_at, conflict_marker,
          remote_account_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(local_account_id) DO UPDATE SET
           sync_state = excluded.sync_state,
           local_revision = COALESCE(excluded.local_revision, workspace_sync_metadata.local_revision),
           last_synced_revision = COALESCE(excluded.last_synced_revision, workspace_sync_metadata.last_synced_revision),
           last_synced_local_hash = COALESCE(excluded.last_synced_local_hash, workspace_sync_metadata.last_synced_local_hash),
           last_synced_remote_version = COALESCE(excluded.last_synced_remote_version, workspace_sync_metadata.last_synced_remote_version),
           last_synced_remote_hash = COALESCE(excluded.last_synced_remote_hash, workspace_sync_metadata.last_synced_remote_hash),
           last_checked_at = COALESCE(excluded.last_checked_at, workspace_sync_metadata.last_checked_at),
           conflict_marker = excluded.conflict_marker,
           remote_account_id = COALESCE(excluded.remote_account_id, workspace_sync_metadata.remote_account_id)''',
      variables: [
        Variable(accountId),
        Variable(syncState),
        Variable(localRevision ?? 1),
        Variable(lastSyncedRevision),
        Variable(lastSyncedLocalHash),
        Variable(lastSyncedRemoteVersion),
        Variable(lastSyncedRemoteHash),
        Variable(lastCheckedAt ?? DateTime.now().toUtc().toIso8601String()),
        Variable(conflictMarker),
        Variable(remoteAccountId),
      ],
    );
  }

  Future<bool> isWorkspaceCloudUploadBlocked(String localAccountId) async {
    final state = await readWorkspaceSyncState(localAccountId);
    return state == 'cloud_unverified' ||
        state == 'legacy_unverified' ||
        state == 'conflict' ||
        state == 'needs_sign_in';
  }

  Future<void> _ensureWorkspaceRevisionSchema() async {
    if (isGoogleWorkspaceDatabase) {
      final id = _workspaceId;
      if (id == null || id.isEmpty) {
        throw StateError('Google workspace database requires an owner ID.');
      }
      await customInsert(
        'INSERT OR IGNORE INTO meta_store (key, value) VALUES (?, ?)',
        variables: [
          Variable<String>('workspace_revision:$id'),
          const Variable<String>('1'),
        ],
      );
    } else {
      await customStatement('''
        INSERT OR IGNORE INTO meta_store (key, value)
        SELECT 'workspace_revision:' || local_account_id, '2'
        FROM local_accounts
      ''');
    }

    final ownerTables = <String, String>{
      if (!isGoogleWorkspaceDatabase) 'local_accounts': 'local_account_id',
      'qaza_records': 'user_id',
      'daily_salah_logs': 'user_id',
      'qaza_additions': 'user_id',
      'qaza_deletion_actions': 'user_id',
      'qaza_deletion_action_record_snapshots': 'user_id',
      'qaza_profile_plan_provenance': 'user_id',
      'account_profiles': 'local_account_id',
      'account_plan_revisions': 'local_account_id',
    };

    for (final entry in ownerTables.entries) {
      final table = entry.key;
      final owner = entry.value;
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS workspace_rev_${table}_insert
        AFTER INSERT ON $table
        BEGIN
          INSERT INTO meta_store (key, value)
          VALUES ('workspace_revision:' || NEW.$owner, '2')
          ON CONFLICT(key) DO UPDATE SET
            value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS workspace_rev_${table}_update
        AFTER UPDATE ON $table
        BEGIN
          INSERT INTO meta_store (key, value)
          VALUES ('workspace_revision:' || OLD.$owner, '2')
          ON CONFLICT(key) DO UPDATE SET
            value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
          INSERT INTO meta_store (key, value)
          VALUES ('workspace_revision:' || NEW.$owner, '2')
          ON CONFLICT(key) DO UPDATE SET
            value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS workspace_rev_${table}_delete
        AFTER DELETE ON $table
        BEGIN
          INSERT INTO meta_store (key, value)
          VALUES ('workspace_revision:' || OLD.$owner, '2')
          ON CONFLICT(key) DO UPDATE SET
            value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
        END
      ''');
    }

    // Workspace preferences and labels live in meta_store rather than owner
    // tables, so these keys also advance the corresponding workspace.
    const workspaceKeyPrefixes = <String>[
      'workspace_display_name:',
      'daily_salah_tracking_enabled:',
      'daily_salah_tracking_setup_dismissed:',
      'initial_cloud_backup_pending:',
    ];
    final when = workspaceKeyPrefixes
        .map((prefix) => "NEW.key GLOB '${prefix}*'")
        .join(' OR ');
    final oldWhen = workspaceKeyPrefixes
        .map((prefix) => "OLD.key GLOB '${prefix}*'")
        .join(' OR ');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS workspace_rev_meta_insert
      AFTER INSERT ON meta_store
      WHEN $when
      BEGIN
        INSERT INTO meta_store (key, value)
        VALUES (
          'workspace_revision:' || substr(NEW.key, instr(NEW.key, ':') + 1),
          '2'
        )
        ON CONFLICT(key) DO UPDATE SET
          value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS workspace_rev_meta_update
      AFTER UPDATE ON meta_store
      WHEN ($oldWhen) OR ($when)
      BEGIN
        INSERT INTO meta_store (key, value)
        VALUES (
          'workspace_revision:' || substr(OLD.key, instr(OLD.key, ':') + 1),
          '2'
        )
        ON CONFLICT(key) DO UPDATE SET
          value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
        INSERT INTO meta_store (key, value)
        VALUES (
          'workspace_revision:' || substr(NEW.key, instr(NEW.key, ':') + 1),
          '2'
        )
        ON CONFLICT(key) DO UPDATE SET
          value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS workspace_rev_meta_delete
      AFTER DELETE ON meta_store
      WHEN $oldWhen
      BEGIN
        INSERT INTO meta_store (key, value)
        VALUES (
          'workspace_revision:' || substr(OLD.key, instr(OLD.key, ':') + 1),
          '2'
        )
        ON CONFLICT(key) DO UPDATE SET
          value = CAST(CAST(value AS INTEGER) + 1 AS TEXT);
      END
    ''');
  }

  Future<void> _removeLegacyQazaHistorySchema() async {
    final statuses = await customSelect(
      'SELECT DISTINCT status FROM qaza_records',
    ).get();
    for (final row in statuses) {
      final status = row.read<String?>('status');
      if (status != 'pending' && status != 'completed' && status != 'deleted') {
        throw StateError(
          'Unsupported legacy Qaza status during migration: $status',
        );
      }
    }

    // Permanently remove the old Recently Deleted records. They have no
    // representation in the new ledger model.
    await customStatement(
      "DELETE FROM qaza_records WHERE status = 'deleted'",
    );

    // Rebuild the table so the obsolete operation_id column is physically
    // removed. This is deliberately not implemented as an ALTER-only change.
    await customStatement('''
      CREATE TABLE qaza_records_new (
        id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        prayer_type TEXT NOT NULL,
        original_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        completed_at INTEGER,
        completion_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (id),
        UNIQUE (user_id, prayer_type, original_date)
      )
    ''');
    await customStatement('''
      INSERT INTO qaza_records_new
        (id, user_id, prayer_type, original_date, status, completed_at,
         completion_id, created_at, updated_at)
      SELECT
        id, user_id, prayer_type, original_date, status, completed_at,
        completion_id, created_at, updated_at
      FROM qaza_records
    ''');
    await customStatement('DROP TABLE qaza_records');
    await customStatement(
      'ALTER TABLE qaza_records_new RENAME TO qaza_records',
    );
    await _ensurePerformanceIndexes();
  }

  Future<void> _ensureQazaAdditionSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_additions (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        input_snapshot TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_deletion_actions (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        addition_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        entity_version INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_deletion_action_record_snapshots (
        deletion_action_id TEXT NOT NULL,
        record_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        addition_id TEXT NOT NULL,
        prayer_type TEXT NOT NULL,
        original_date TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        completion_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        record_version INTEGER NOT NULL,
        PRIMARY KEY (deletion_action_id, record_id)
      )
    ''');
  }

  Future<void> _ensureQazaProfilePlanProvenanceSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS qaza_profile_plan_provenance (
        record_id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_revision_id TEXT NOT NULL,
        plan_fingerprint TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureDeletionActionVersionColumn() async {
    final columns = await customSelect(
      'PRAGMA table_info(qaza_deletion_actions)',
    ).get();
    final exists = columns.any(
      (row) => row.read<String>('name') == 'entity_version',
    );
    if (!exists) {
      await customStatement(
        'ALTER TABLE qaza_deletion_actions '
        'ADD COLUMN entity_version INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _ensureWorkspaceGenerationColumn() async {
    final columns =
        await customSelect('PRAGMA table_info(app_session_state)').get();
    if (columns.isEmpty) {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS app_session_state (
          id INTEGER NOT NULL PRIMARY KEY,
          active_local_account_id TEXT,
          generation INTEGER NOT NULL DEFAULT 1
        )
      ''');
      return;
    }
    if (!columns.any((row) => row.read<String>('name') == 'generation')) {
      await customStatement(
        'ALTER TABLE app_session_state ADD COLUMN generation INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<int> readSessionGeneration() async {
    final rows = await customSelect(
      'SELECT generation FROM app_session_state WHERE id = 1 LIMIT 1',
    ).get();
    if (rows.isEmpty) return 1;
    final value = rows.single.read<int>('generation');
    return value < 1 ? 1 : value;
  }

  Future<String?> readActiveLocalAccountId() async {
    final rows = await customSelect(
      'SELECT active_local_account_id FROM app_session_state WHERE id = 1 LIMIT 1',
    ).get();
    if (rows.isEmpty) return null;
    final id = rows.single.read<String?>('active_local_account_id')?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<bool> isCurrentWorkspaceGeneration({
    required String localAccountId,
    required int generation,
  }) async {
    return await readActiveLocalAccountId() == localAccountId &&
        await readSessionGeneration() == generation;
  }

  Future<void> _ensurePerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_date_idx '
      'ON qaza_records (user_id, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_prayer_date_idx '
      'ON qaza_records (user_id, prayer_type, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_prayer_status_date_idx '
      'ON qaza_records '
      '(user_id, prayer_type, status, original_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_status_completed_idx '
      'ON qaza_records (user_id, status, completed_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_status_completed_id_idx '
      'ON qaza_records (user_id, status, completed_at, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_addition_date_idx '
      'ON qaza_records (user_id, addition_id, original_date, id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_records_user_addition_status_idx '
      'ON qaza_records (user_id, addition_id, status, record_version)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_profile_plan_provenance_user_idx '
      'ON qaza_profile_plan_provenance (user_id, plan_revision_id, record_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_additions_user_created_idx '
      'ON qaza_additions (user_id, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_actions_user_created_idx '
      'ON qaza_deletion_actions (user_id, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_actions_user_resolved_created_idx '
      'ON qaza_deletion_actions '
      '(user_id, resolved_at, created_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS qaza_deletion_snapshots_action_idx '
      'ON qaza_deletion_action_record_snapshots (deletion_action_id, record_id)',
    );
  }
}

/// Encrypted database containing exactly one verified Google workspace.
/// It reuses the existing Drift table and DAO declarations but its role-aware
/// schema setup deliberately excludes registry, session, device and journal state.
class GoogleWorkspaceDatabase extends AppDatabase {
  GoogleWorkspaceDatabase({
    required String fileName,
    required String workspaceId,
  }) : super._workspace(
          executor: AppDatabase._openEncryptedDatabase(
            fileName: fileName,
            migrateLegacyPlaintext: false,
          ),
          workspaceId: workspaceId,
        );

  GoogleWorkspaceDatabase.forTesting({
    required QueryExecutor executor,
    required String workspaceId,
  }) : super._workspace(executor: executor, workspaceId: workspaceId);
}
