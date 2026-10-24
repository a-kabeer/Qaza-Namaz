import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'database_encryption.dart';
import 'free_space.dart';
import 'workspace_canonical_content.dart';

part 'database_manager_migration.dart';

/// Outcome of one §5.2 startup migration run (Recovery Stage 4).
class StartupMigrationReport {
  const StartupMigrationReport({
    required this.migrated,
    required this.failed,
    required this.skippedMidOperation,
    required this.preCheckPassed,
    required this.safetyCopyEnsured,
  });

  /// Workspaces now committed on the separate layout.
  final List<String> migrated;

  /// Workspace ID → error, for workspaces that remain on the shared
  /// layout (fully operational there, per §5.2 step 7).
  final Map<String, String> failed;

  /// Workspaces skipped because an operation is in flight (§5.3).
  final List<String> skippedMidOperation;

  /// False when the §5.1 storage pre-check blocked the run before any
  /// file was modified.
  final bool preCheckPassed;

  /// True when the one-time §5.1 safety copy exists and was verified.
  final bool safetyCopyEnsured;
}

/// Owns foreground database handles and registry-based workspace resolution.
/// Control/session state is always read from [controlDatabase].
class DatabaseManager {
  DatabaseManager({
    AppDatabase? controlDatabase,
    Future<Directory> Function()? documentsDirectoryProvider,
    AppDatabase Function(
            {required String fileName, required String workspaceId})?
        googleDatabaseFactory,
    Future<int?> Function(Directory directory)? freeSpaceBytesProvider,
  })  : _controlDatabase = controlDatabase,
        _ownsControlDatabase = controlDatabase == null,
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _googleDatabaseFactory = googleDatabaseFactory ??
            (({required fileName, required workspaceId}) =>
                GoogleWorkspaceDatabase(
                  fileName: fileName,
                  workspaceId: workspaceId,
                )),
        _freeSpaceBytesProvider =
            freeSpaceBytesProvider ?? statvfsFreeSpaceBytes;

  AppDatabase? _controlDatabase;

  /// True when this manager created its control database (none was
  /// injected) and therefore owns its closure.
  final bool _ownsControlDatabase;
  final Map<String, AppDatabase> _workspaceDatabases = <String, AppDatabase>{};

  /// Registry-resolved workspaces whose authoritative handle is the
  /// control database (Guest workspaces and shared-layout Google
  /// workspaces under Shape A registry-true resolution, decision D-A).
  final Set<String> _controlResolvedWorkspaceIds = <String>{};
  final Map<String, Future<AppDatabase>> _openingWorkspaceDatabases =
      <String, Future<AppDatabase>>{};
  final Map<String, Future<AppDatabase>> _provisioningGoogleWorkspaces =
      <String, Future<AppDatabase>>{};
  final Future<Directory> Function() _documentsDirectoryProvider;
  final AppDatabase Function(
      {required String fileName,
      required String workspaceId}) _googleDatabaseFactory;
  final Future<int?> Function(Directory directory) _freeSpaceBytesProvider;
  Future<void>? _initializeFuture;
  Future<StartupMigrationReport>? _startupMigrationFuture;
  String? _activeWorkspaceId;

  // A manager is single-lifecycle: once close begins, reject new open/provision
  // requests, wait for operations already in flight, then close every handle
  // those operations may have created.
  bool _closing = false;
  bool _closed = false;
  bool _initializationInFlight = false;
  bool _startupMigrationInFlight = false;
  Future<void>? _closeFuture;

  /// Migration/reconciliation helper (database_manager_migration.dart),
  /// constructor-injected with this manager. Lazily created so it captures
  /// the fully constructed manager; entry points below delegate to it.
  late final _DatabaseManagerMigrationHelper _migrationHelper =
      _DatabaseManagerMigrationHelper(this);

  String? get activeWorkspaceId => _activeWorkspaceId;

  void setActiveWorkspace(String? localAccountId) {
    final id = localAccountId?.trim();
    if (id == null ||
        id.isEmpty ||
        id == 'guest' ||
        id.startsWith('guest_') ||
        id.startsWith('guest:')) {
      _activeWorkspaceId = null;
      return;
    }
    if (!_workspaceDatabases.containsKey(id) &&
        !_controlResolvedWorkspaceIds.contains(id)) {
      throw StateError(
          'Cannot publish a Google workspace before its database is validated.');
    }
    _activeWorkspaceId = id;
  }

  AppDatabase get controlDatabase {
    if (_closed) {
      throw StateError('DatabaseManager is closed.');
    }
    if (_closing && _controlDatabase == null) {
      throw StateError('DatabaseManager is closing.');
    }
    return _controlDatabase ??= AppDatabase.control();
  }

  void _throwIfClosing() {
    if (_closing || _closed) {
      throw StateError('DatabaseManager is closing or closed.');
    }
  }

  static String googleFileNameForWorkspaceId(String localAccountId) {
    final id = localAccountId.trim();
    if (!id.startsWith('google_') || id.length <= 'google_'.length) {
      throw ArgumentError.value(localAccountId, 'localAccountId',
          'Expected canonical google_<stable-id> workspace ID.');
    }
    final stableId = id.substring('google_'.length);
    final hash = sha256.convert(utf8.encode(stableId)).toString();
    return 'qaza_google_${hash.substring(0, 32)}.sqlite';
  }

  Future<void> initialize() {
    final pending = _initializeFuture;
    if (pending != null) return pending;
    _throwIfClosing();
    _initializationInFlight = true;
    final initialization = _initialize();
    final tracked = initialization.whenComplete(() {
      _initializationInFlight = false;
    });
    _initializeFuture = tracked;
    return tracked;
  }

  Future<void> _initialize() async {
    await controlDatabase.readDbRevision();
    await _reconcileWorkspaceCreationJournal();
  }

  /// The §5.2 startup migration run: migrates every resident
  /// shared-layout Google workspace before any workspace is exposed.
  /// Invoked from the app startup path (`main`'s database step) — never
  /// from activation (Shape A). Per-workspace failures never throw: the
  /// affected workspace remains fully operational on the shared layout
  /// and the failure is reported here (§5.2 step 7).
  Future<StartupMigrationReport> runStartupMigrations() {
    final pending = _startupMigrationFuture;
    if (pending != null) return pending;
    _throwIfClosing();
    _startupMigrationInFlight = true;
    final migration = _migrationHelper._runStartupMigrations();
    final tracked = migration.whenComplete(() {
      _startupMigrationInFlight = false;
    });
    _startupMigrationFuture = tracked;
    return tracked;
  }

  /// §4 staging file for a cross-file adoption into workspace [id]:
  /// a `VACUUM INTO` copy of the target's (empty) live file, so the
  /// staging database starts from the target's exact baseline state
  /// (owner marker, scoped metadata, sync row).
  Future<AppDatabase> createAdoptionStagingDatabase(String localAccountId) {
    return _migrationHelper._createAdoptionStagingDatabase(localAccountId);
  }

  /// Deletes an unpublished adoption staging file (retry/reset path).
  Future<void> discardAdoptionStagingDatabase(String localAccountId) {
    return _migrationHelper._discardAdoptionStagingDatabase(localAccountId);
  }

  /// §4 publish: swaps the verified adoption staging file into the
  /// target's final name without overwriting anything, reopens and
  /// re-verifies it, and restores the previous file if verification
  /// fails. The previous (empty) file is kept as
  /// `<final>.adoption-previous` until the adoption commits; call
  /// [discardAdoptionPreviousDatabase] after the commit.
  Future<AppDatabase> publishAdoptionStagingDatabase(
    String localAccountId, {
    required Future<void> Function(AppDatabase published) verify,
  }) {
    return _migrationHelper._publishAdoptionStagingDatabase(
      localAccountId,
      verify: verify,
    );
  }

  /// Deletes the retained pre-adoption file after a committed adoption.
  Future<void> discardAdoptionPreviousDatabase(String localAccountId) {
    return _migrationHelper._discardAdoptionPreviousDatabase(localAccountId);
  }

  /// Migration entry point used when a registered Google workspace still has
  /// shared-layout data; delegates to [_DatabaseManagerMigrationHelper].
  Future<AppDatabase> _migrateLegacyGoogleWorkspace(
    String id,
    String finalFileName,
  ) =>
      _migrationHelper._migrateLegacyGoogleWorkspace(id, finalFileName);

  /// Startup reconciliation entry point for interrupted legacy migrations;
  /// delegates to [_DatabaseManagerMigrationHelper].
  Future<void> _reconcileLegacyGoogleWorkspaceMigration(QueryRow row) =>
      _migrationHelper._reconcileLegacyGoogleWorkspaceMigration(row);

  /// Current provider handle. Google workspaces must already have been resolved
  /// during account activation; a missing handle never falls back to Guest.
  AppDatabase databaseForActiveWorkspace(String? localAccountId) {
    final id = localAccountId?.trim();
    if (id == null ||
        id.isEmpty ||
        id == 'guest' ||
        id.startsWith('guest_') ||
        id.startsWith('guest:')) {
      return controlDatabase;
    }
    if (_controlResolvedWorkspaceIds.contains(id)) return controlDatabase;
    final database = _workspaceDatabases[id];
    if (database == null) {
      throw StateError(
        'The active Google workspace has not been opened and validated.',
      );
    }
    return database;
  }

  Future<AppDatabase> databaseForWorkspace(String localAccountId) {
    _throwIfClosing();
    final id = localAccountId.trim();
    final pending = _openingWorkspaceDatabases[id];
    if (pending != null) return pending;
    final future = _openDatabaseForWorkspace(id);
    _openingWorkspaceDatabases[id] = future;
    return future.whenComplete(() {
      if (identical(_openingWorkspaceDatabases[id], future)) {
        _openingWorkspaceDatabases.remove(id);
      }
    });
  }

  Future<AppDatabase> _openDatabaseForWorkspace(String localAccountId) async {
    final id = localAccountId.trim();
    if (id.isEmpty) throw ArgumentError.value(localAccountId, 'localAccountId');
    if (!id.startsWith('google_')) {
      final row = await controlDatabase.customSelect(
        'SELECT 1 FROM local_accounts WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (row.isEmpty) {
        throw StateError('The requested local workspace is not registered.');
      }
      _controlResolvedWorkspaceIds.add(id);
      return controlDatabase;
    }

    await initialize();
    final rows = await controlDatabase.customSelect(
      'SELECT db_file_name, db_layout, db_migration_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (rows.isEmpty) {
      throw StateError('The requested Google workspace is not registered.');
    }
    final row = rows.single;
    final layout = row.read<String>('db_layout');
    if (layout == 'shared') {
      // Shape A (decision D-A): registry-true resolution. A shared-layout
      // Google workspace's authoritative database is the control file;
      // it remains fully operational there until the §5.2 startup
      // migration moves it. There is no "development conversion or
      // reset" — that text had no basis in design v2.2.
      _controlResolvedWorkspaceIds.add(id);
      return controlDatabase;
    }
    if (layout != 'separate') {
      throw StateError('The Google workspace database layout is invalid.');
    }
    final fileName = row.read<String?>('db_file_name');
    if (row.read<String>('db_migration_state') != 'committed' ||
        fileName == null ||
        fileName != googleFileNameForWorkspaceId(id) ||
        !RegExp(r'^qaza_google_[0-9a-f]{32}\.sqlite$').hasMatch(fileName)) {
      throw StateError(
          'Google workspace registry filename/state failed validation.');
    }
    final cached = _workspaceDatabases[id];
    if (cached != null) return cached;
    final directory = await _documentsDirectoryProvider();
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) {
      throw StateError(
        'The registered Google workspace database is missing. No empty replacement was created.',
      );
    }
    final workspace =
        _googleDatabaseFactory(fileName: fileName, workspaceId: id);
    try {
      if (await workspace.readWorkspaceFileOwner() != id) {
        throw StateError(
            'Google workspace file owner does not match the registry.');
      }
      final integrity =
          await workspace.customSelect('PRAGMA integrity_check').get();
      if (integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok') {
        throw StateError('Google workspace database integrity check failed.');
      }
      _workspaceDatabases[id] = workspace;
      return workspace;
    } on StateError {
      await workspace.close();
      rethrow;
    } catch (error) {
      // §6 (Recovery Stage 4): a separate file that cannot be opened or
      // validated — corrupt, wrong key, schema-incompatible — blocks
      // access to THIS workspace with an account-specific, recoverable
      // StateError. It never falls back to another database and never
      // leaks a raw storage exception as the error surface.
      await workspace.close();
      throw StateError(
        'The separate database for this Google workspace could not be '
        'opened or validated. Access to this workspace is blocked; '
        'other workspaces are unaffected. ($error)',
      );
    }
  }

  /// Creates a new separate Google workspace only when called by a flow that
  /// has already verified the Google identity. Existing shared workspace data
  /// is preserved and is never silently discarded.
  Future<AppDatabase> ensureGoogleWorkspace(String localAccountId) {
    _throwIfClosing();
    final id = localAccountId.trim();
    final pending = _provisioningGoogleWorkspaces[id];
    if (pending != null) return pending;
    final future = _ensureGoogleWorkspace(id);
    _provisioningGoogleWorkspaces[id] = future;
    return future.whenComplete(() {
      if (identical(_provisioningGoogleWorkspaces[id], future)) {
        _provisioningGoogleWorkspaces.remove(id);
      }
    });
  }

  Future<AppDatabase> _ensureGoogleWorkspace(String localAccountId) async {
    final id = localAccountId.trim();
    await initialize();
    final rows = await controlDatabase.customSelect(
      'SELECT db_file_name, db_layout, db_migration_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (rows.isNotEmpty) {
      final layout = rows.single.read<String>('db_layout');
      if (layout == 'separate') {
        return databaseForWorkspace(id);
      }
      if (layout == 'shared') {
        // Shape A (decision D-A): activating an existing shared-layout
        // workspace is a control-database operation. It must not
        // provision a file and must not migrate on activation —
        // provisioning belongs to the verified sign-in creation flow
        // (the no-row path below) and migration to the §5.2 startup
        // run ([runStartupMigrations]).
        _controlResolvedWorkspaceIds.add(id);
        return controlDatabase;
      }
      throw StateError('The Google workspace database layout is invalid.');
    }
    final fileName = googleFileNameForWorkspaceId(id);

    final now = DateTime.now().microsecondsSinceEpoch;
    if (rows.isEmpty) {
      await controlDatabase.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state, db_file_name,
            db_layout, db_migration_state, created_at, updated_at)
           VALUES (?, 'local', 'active', NULL, 'shared', 'not_started', ?, ?)''',
        variables: [
          Variable<String>(id),
          Variable<int>(now),
          Variable<int>(now)
        ],
      );
    }

    final directory = await _documentsDirectoryProvider();
    final finalFile = File('${directory.path}/$fileName');
    final stagingName = '$fileName.staging';
    final stagingFile = File('${directory.path}/$stagingName');
    if (await finalFile.exists()) {
      throw StateError(
          'An unregistered Google file already exists; it will not be overwritten.');
    }
    if (await stagingFile.exists()) {
      throw StateError(
          'An interrupted staging file requires recovery; it will not be overwritten.');
    }

    final operationId = 'google-workspace-create:$id';
    final createdAt = DateTime.now().microsecondsSinceEpoch;
    await controlDatabase.customInsert(
      '''INSERT OR REPLACE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, created_at, updated_at,
          staging_file, final_file, content_hash, error_message)
         VALUES (?, 'google_workspace_create', ?, ?, 'prepared', ?, ?, ?, ?, NULL, NULL)''',
      variables: [
        Variable<String>(operationId),
        Variable<String>(id),
        Variable<String>(id),
        Variable<int>(createdAt),
        Variable<int>(createdAt),
        Variable<String>(stagingName),
        Variable<String>(fileName),
      ],
    );

    final scopedKeys = await controlDatabase.customSelect(
      'SELECT key, value FROM meta_store WHERE key IN (?, ?, ?, ?, ?) ORDER BY key',
      variables: [
        Variable<String>('workspace_display_name:$id'),
        Variable<String>('daily_salah_tracking_enabled:$id'),
        Variable<String>('daily_salah_tracking_setup_dismissed:$id'),
        Variable<String>('workspace_revision:$id'),
        Variable<String>('initial_cloud_backup_pending:$id'),
      ],
    ).get();
    final syncRows = await controlDatabase.customSelect(
      '''SELECT local_account_id, sync_state, local_revision, last_synced_revision,
                last_synced_local_hash, last_synced_remote_version,
                last_synced_remote_hash, last_checked_at, conflict_marker,
                remote_account_id
         FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable<String>(id)],
    ).get();
    AppDatabase? staging;
    try {
      staging = _googleDatabaseFactory(fileName: stagingName, workspaceId: id);
      await staging
          .customSelect('SELECT count(*) AS count FROM qaza_records')
          .get();
      await staging.writeWorkspaceFileOwner(id);
      for (final row in scopedKeys) {
        await staging.customInsert(
          'INSERT OR REPLACE INTO meta_store (key, value) VALUES (?, ?)',
          variables: [
            Variable<String>(row.read<String>('key')),
            Variable<String>(row.read<String>('value')),
          ],
        );
      }
      if (syncRows.isNotEmpty) {
        final sync = syncRows.single;
        await staging.customInsert(
          '''INSERT INTO workspace_sync_metadata
             (local_account_id, sync_state, local_revision, last_synced_revision,
              last_synced_local_hash, last_synced_remote_version,
              last_synced_remote_hash, last_checked_at, conflict_marker,
              remote_account_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable<String>(sync.read<String>('local_account_id')),
            Variable<String>(sync.read<String>('sync_state')),
            Variable<int>(sync.read<int>('local_revision')),
            Variable<int>(sync.read<int?>('last_synced_revision')),
            Variable<String>(sync.read<String?>('last_synced_local_hash')),
            Variable<String>(sync.read<String?>('last_synced_remote_version')),
            Variable<String>(sync.read<String?>('last_synced_remote_hash')),
            Variable<String>(sync.read<String?>('last_checked_at')),
            Variable<String>(sync.read<String?>('conflict_marker')),
            Variable<String>(sync.read<String?>('remote_account_id')),
          ],
        );
      } else {
        await staging.customInsert(
          '''INSERT INTO workspace_sync_metadata
             (local_account_id, sync_state, local_revision)
             VALUES (?, 'pending', 1)''',
          variables: [Variable<String>(id)],
        );
      }
      final integrity =
          await staging.customSelect('PRAGMA integrity_check').get();
      if (integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok' ||
          await staging.readWorkspaceFileOwner() != id) {
        throw StateError('Staging Google workspace failed verification.');
      }
      final hash = await _canonicalWorkspaceCreationHash(staging, id);
      await controlDatabase.customUpdate(
        "UPDATE workspace_operation_journal SET phase = 'finalizing', content_hash = ?, updated_at = ? WHERE operation_id = ?",
        variables: [
          Variable<String>(hash),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      await staging.close();
      staging = null;
      await stagingFile.rename(finalFile.path);

      final published =
          _googleDatabaseFactory(fileName: fileName, workspaceId: id);
      try {
        final owner = await published.readWorkspaceFileOwner();
        final check =
            await published.customSelect('PRAGMA integrity_check').get();
        if (owner != id ||
            check.isEmpty ||
            check.first.read<String>('integrity_check') != 'ok') {
          throw StateError('Published Google workspace failed verification.');
        }
        final publishedHash =
            await _canonicalWorkspaceCreationHash(published, id);
        if (publishedHash != hash) {
          throw StateError(
              'Published Google workspace content hash does not match staging.');
        }
      } catch (_) {
        await published.close();
        rethrow;
      }

      await controlDatabase.transaction(() async {
        await controlDatabase.customUpdate(
          '''UPDATE local_accounts SET db_file_name = ?, db_layout = 'separate',
             db_migration_state = 'committed', updated_at = ?
             WHERE local_account_id = ?''',
          variables: [
            Variable<String>(fileName),
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(id),
          ],
        );
        await controlDatabase.customUpdate(
          "UPDATE workspace_operation_journal SET phase = 'committed', updated_at = ? WHERE operation_id = ?",
          variables: [
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId),
          ],
        );
        await controlDatabase.customUpdate(
          'DELETE FROM meta_store WHERE key IN (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('workspace_display_name:$id'),
            Variable<String>('daily_salah_tracking_enabled:$id'),
            Variable<String>('daily_salah_tracking_setup_dismissed:$id'),
            Variable<String>('workspace_revision:$id'),
            Variable<String>('initial_cloud_backup_pending:$id'),
          ],
        );
        await controlDatabase.customUpdate(
          'DELETE FROM workspace_sync_metadata WHERE local_account_id = ?',
          variables: [Variable<String>(id)],
        );
      });
      _workspaceDatabases[id] = published;
      return published;
    } catch (error) {
      if (staging != null) await staging.close();
      // If publication is already finalizing, leave the journal untouched so
      // the next startup can reconcile it instead of marking a published file failed.
      await controlDatabase.customUpdate(
        "UPDATE workspace_operation_journal SET phase = 'failed', error_message = ?, updated_at = ? WHERE operation_id = ? AND phase != 'finalizing'",
        variables: [
          Variable<String>(error.toString()),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      rethrow;
    }
  }

  Future<void> _reconcileWorkspaceCreationJournal() async {
    final rows = await controlDatabase
        .customSelect(
          "SELECT operation_id, operation_type, target_local_account_id, phase, snapshot_id, staging_file, final_file, content_hash "
          "FROM workspace_operation_journal "
          "WHERE operation_type IN ('google_workspace_create', 'google_workspace_migration') "
          "AND phase != 'committed' ORDER BY created_at",
        )
        .get();
    for (final row in rows) {
      if (row.read<String>('operation_type') == 'google_workspace_migration') {
        await _reconcileLegacyGoogleWorkspaceMigration(row);
        continue;
      }
      final operationId = row.read<String>('operation_id');
      final id = row.read<String>('target_local_account_id');
      final phase = row.read<String>('phase');
      final stagingName = row.read<String?>('staging_file');
      final finalName = row.read<String?>('final_file');
      final expectedHash = row.read<String?>('content_hash');
      final dir = await _documentsDirectoryProvider();
      if (phase != 'finalizing' || stagingName == null || finalName == null) {
        if (stagingName != null) {
          final staging = File('${dir.path}/$stagingName');
          if (await staging.exists()) {
            final quarantine = File('${staging.path}.quarantine');
            if (!await quarantine.exists())
              await staging.rename(quarantine.path);
          }
        }
        await controlDatabase.customUpdate(
          "UPDATE workspace_operation_journal SET phase = 'failed', error_message = 'Interrupted before finalization; staging quarantined', updated_at = ? WHERE operation_id = ?",
          variables: [
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId)
          ],
        );
        continue;
      }
      final finalFile = File('${dir.path}/$finalName');
      final stagingFile = File('${dir.path}/$stagingName');
      if (!await finalFile.exists() && await stagingFile.exists()) {
        await stagingFile.rename(finalFile.path);
      }
      if (!await finalFile.exists()) {
        throw StateError(
            'Finalizing Google workspace creation is missing final and staging files.');
      }
      final published =
          _googleDatabaseFactory(fileName: finalName, workspaceId: id);
      try {
        if (await published.readWorkspaceFileOwner() != id) {
          throw StateError('Finalizing workspace owner marker does not match.');
        }
        final integrity =
            await published.customSelect('PRAGMA integrity_check').get();
        if (integrity.isEmpty ||
            integrity.first.read<String>('integrity_check') != 'ok') {
          throw StateError('Finalizing workspace integrity check failed.');
        }
        final actualHash = await _canonicalWorkspaceCreationHash(published, id);
        if (expectedHash == null || expectedHash != actualHash) {
          throw StateError(
              'Finalizing workspace content hash does not match the journal.');
        }
      } finally {
        await published.close();
      }
      await controlDatabase.transaction(() async {
        await controlDatabase.customUpdate(
          "UPDATE local_accounts SET db_file_name = ?, db_layout = 'separate', db_migration_state = 'committed', updated_at = ? WHERE local_account_id = ?",
          variables: [
            Variable<String>(finalName),
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(id)
          ],
        );
        await controlDatabase.customUpdate(
          "UPDATE workspace_operation_journal SET phase = 'committed', updated_at = ? WHERE operation_id = ?",
          variables: [
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId)
          ],
        );
        await controlDatabase.customUpdate(
          'DELETE FROM meta_store WHERE key IN (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('workspace_display_name:$id'),
            Variable<String>('daily_salah_tracking_enabled:$id'),
            Variable<String>('daily_salah_tracking_setup_dismissed:$id'),
            Variable<String>('workspace_revision:$id'),
            Variable<String>('initial_cloud_backup_pending:$id'),
          ],
        );
        await controlDatabase.customUpdate(
          'DELETE FROM workspace_sync_metadata WHERE local_account_id = ?',
          variables: [Variable<String>(id)],
        );
      });
    }
  }

  Future<String> _canonicalWorkspaceCreationHash(
    AppDatabase workspace,
    String id,
  ) async {
    final owner = await workspace.readWorkspaceFileOwner();
    if (owner != id) {
      throw StateError(
          'Cannot hash a Google workspace with an invalid owner marker.');
    }
    // A fresh workspace must not contain any owned rows yet.
    final counts = await WorkspaceCanonicalContent.rowCounts(workspace, id);
    for (final entry in counts.entries) {
      if (entry.value != 0) {
        throw StateError(
            'Fresh workspace unexpectedly contains ${entry.value} rows in ${entry.key}.');
      }
    }
    final syncRows = await workspace.customSelect(
      'SELECT COUNT(*) AS row_count FROM workspace_sync_metadata '
      'WHERE local_account_id = ?',
      variables: [Variable<String>(id)],
    ).get();
    if (syncRows.single.read<int>('row_count') != 1) {
      throw StateError(
          'A Google workspace must have exactly one sync metadata row.');
    }
    // Unified canonical hash (decision D-D(ii)): the §7 scoped-export
    // canonicalisation, shared with migration, adoption, and export.
    // The retired 'workspace-canonical-v1' form is no longer produced.
    return WorkspaceCanonicalContent.hash(workspace, id);
  }

  Future<void> close() => _closeFuture ??= _closeAndReleaseHandles();

  Future<void> _closeAndReleaseHandles() async {
    // Set the gate before the first await. New workspace-open/provision
    // requests are rejected from this point, while operations already
    // registered in the in-flight maps may finish and publish their handles.
    _closing = true;
    await _awaitInFlightOperations();

    // A control database injected by the caller stays caller-owned: this
    // manager closes only the workspace handles it opened and a control
    // database it created itself.
    final handles = <AppDatabase>{
      if (_controlDatabase != null && _ownsControlDatabase) _controlDatabase!,
      ..._workspaceDatabases.values,
    };
    _closed = true;
    _controlDatabase = null;
    _workspaceDatabases.clear();
    _openingWorkspaceDatabases.clear();
    _provisioningGoogleWorkspaces.clear();
    _activeWorkspaceId = null;
    for (final database in handles) {
      await database.close();
    }
  }

  Future<void> _awaitInFlightOperations() async {
    // Closing must not take its handle snapshot while an async open, create,
    // initialization, or startup migration can still add a database to the
    // manager. Drain until all registered operations and completion callbacks
    // have settled. Failed operations still need to settle before handles are
    // released; their original callers continue to receive their errors.
    while (true) {
      final pending = <Future<void>>[];
      final initialization = _initializeFuture;
      if (_initializationInFlight && initialization != null) {
        pending.add(_settleOperation(initialization));
      }
      final migration = _startupMigrationFuture;
      if (_startupMigrationInFlight && migration != null) {
        pending.add(_settleOperation(migration));
      }
      pending.addAll(
        _openingWorkspaceDatabases.values.map(
          (future) => _settleOperation(future),
        ),
      );
      pending.addAll(
        _provisioningGoogleWorkspaces.values.map(
          (future) => _settleOperation(future),
        ),
      );
      if (pending.isEmpty) return;
      await Future.wait(pending);
    }
  }

  Future<void> _settleOperation<T>(Future<T> operation) async {
    try {
      await operation;
    } catch (_) {
      // Failure is returned to the operation's caller; shutdown still has to
      // wait for all in-flight work before collecting database handles.
    }
  }
}
