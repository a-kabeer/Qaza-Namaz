import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Owns foreground database handles and registry-based workspace resolution.
/// Control/session state is always read from [controlDatabase].
class DatabaseManager {
  DatabaseManager({
    AppDatabase? controlDatabase,
    Future<Directory> Function()? documentsDirectoryProvider,
    AppDatabase Function({required String fileName, required String workspaceId})?
        googleDatabaseFactory,
  })  : _controlDatabase = controlDatabase,
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _googleDatabaseFactory = googleDatabaseFactory ??
            (({required fileName, required workspaceId}) =>
                GoogleWorkspaceDatabase(
                  fileName: fileName,
                  workspaceId: workspaceId,
                ));

  AppDatabase? _controlDatabase;
  final Map<String, AppDatabase> _workspaceDatabases = <String, AppDatabase>{};
  final Future<Directory> Function() _documentsDirectoryProvider;
  final AppDatabase Function({required String fileName, required String workspaceId})
      _googleDatabaseFactory;
  Future<void>? _initializeFuture;
  String? _activeWorkspaceId;

  String? get activeWorkspaceId => _activeWorkspaceId;

  void setActiveWorkspace(String? localAccountId) {
    final id = localAccountId?.trim();
    if (id == null || id.isEmpty ||
        id == 'guest' || id.startsWith('guest_') || id.startsWith('guest:')) {
      _activeWorkspaceId = null;
      return;
    }
    if (!_workspaceDatabases.containsKey(id)) {
      throw StateError('Cannot publish a Google workspace before its database is validated.');
    }
    _activeWorkspaceId = id;
  }

  AppDatabase get controlDatabase =>
      _controlDatabase ??= AppDatabase.control();

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

  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    await controlDatabase.readDbRevision();
    await _reconcileWorkspaceCreationJournal();
  }

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
    final database = _workspaceDatabases[id];
    if (database == null) {
      throw StateError(
        'The active Google workspace has not been opened and validated.',
      );
    }
    return database;
  }

  Future<AppDatabase> databaseForWorkspace(String localAccountId) async {
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
      throw StateError(
        'This Google workspace has the legacy shared development layout. '
        'Its data was preserved; it needs an explicit development conversion or reset.',
      );
    }
    if (layout != 'separate') {
      throw StateError('The Google workspace database layout is invalid.');
    }
    final fileName = row.read<String?>('db_file_name');
    if (row.read<String>('db_migration_state') != 'committed' ||
        fileName == null ||
        fileName != googleFileNameForWorkspaceId(id) ||
        !RegExp(r'^qaza_google_[0-9a-f]{32}\.sqlite$').hasMatch(fileName)) {
      throw StateError('Google workspace registry filename/state failed validation.');
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
    final workspace = _googleDatabaseFactory(fileName: fileName, workspaceId: id);
    try {
      if (await workspace.readWorkspaceFileOwner() != id) {
        throw StateError('Google workspace file owner does not match the registry.');
      }
      final integrity = await workspace.customSelect('PRAGMA integrity_check').get();
      if (integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok') {
        throw StateError('Google workspace database integrity check failed.');
      }
      _workspaceDatabases[id] = workspace;
      return workspace;
    } catch (_) {
      await workspace.close();
      rethrow;
    }
  }

  /// Creates a new separate Google workspace only when called by a flow that
  /// has already verified the Google identity. Existing shared workspace data
  /// is preserved and is never silently discarded.
  Future<AppDatabase> ensureGoogleWorkspace(String localAccountId) async {
    final id = localAccountId.trim();
    final fileName = googleFileNameForWorkspaceId(id);
    await initialize();
    final rows = await controlDatabase.customSelect(
      'SELECT db_file_name, db_layout, db_migration_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (rows.isNotEmpty && rows.single.read<String>('db_layout') == 'separate') {
      return databaseForWorkspace(id);
    }
    if (rows.isNotEmpty && await _hasSharedWorkspaceData(id)) {
      throw StateError(
        'Existing Google workspace data is still in the shared development database. '
        'The data was preserved; an explicit conversion or reset is required.',
      );
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    if (rows.isEmpty) {
      await controlDatabase.customInsert(
        '''INSERT INTO local_accounts
           (local_account_id, account_mode, lifecycle_state, db_file_name,
            db_layout, db_migration_state, created_at, updated_at)
           VALUES (?, 'local', 'active', NULL, 'shared', 'not_started', ?, ?)''',
        variables: [Variable<String>(id), Variable<int>(now), Variable<int>(now)],
      );
    }

    final directory = await _documentsDirectoryProvider();
    final finalFile = File('${directory.path}/$fileName');
    final stagingName = '$fileName.staging';
    final stagingFile = File('${directory.path}/$stagingName');
    if (await finalFile.exists()) {
      throw StateError('An unregistered Google file already exists; it will not be overwritten.');
    }
    if (await stagingFile.exists()) {
      throw StateError('An interrupted staging file requires recovery; it will not be overwritten.');
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
        Variable<String>(operationId), Variable<String>(id), Variable<String>(id),
        Variable<int>(createdAt), Variable<int>(createdAt),
        Variable<String>(stagingName), Variable<String>(fileName),
      ],
    );

    final scopedKeys = await controlDatabase.customSelect(
      'SELECT key, value FROM meta_store WHERE key IN (?, ?, ?, ?, ?)',
      variables: [
        Variable<String>('workspace_display_name:$id'),
        Variable<String>('daily_salah_tracking_enabled:$id'),
        Variable<String>('daily_salah_tracking_setup_dismissed:$id'),
        Variable<String>('workspace_revision:$id'),
        Variable<String>('initial_cloud_backup_pending:$id'),
      ],
    ).get();
    AppDatabase? staging;
    try {
      staging = _googleDatabaseFactory(fileName: stagingName, workspaceId: id);
      await staging.customSelect('SELECT count(*) AS count FROM qaza_records').get();
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
      final integrity = await staging.customSelect('PRAGMA integrity_check').get();
      if (integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok' ||
          await staging.readWorkspaceFileOwner() != id) {
        throw StateError('Staging Google workspace failed verification.');
      }
      final canonical = jsonEncode(<Object?>[
        'workspace-canonical-v1',
        id,
        for (final row in scopedKeys)
          <String>[row.read<String>('key'), row.read<String>('value')],
      ]);
      final hash = sha256.convert(utf8.encode(canonical)).toString();
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

      final published = _googleDatabaseFactory(fileName: fileName, workspaceId: id);
      try {
        final owner = await published.readWorkspaceFileOwner();
        final check = await published.customSelect('PRAGMA integrity_check').get();
        if (owner != id ||
            check.isEmpty ||
            check.first.read<String>('integrity_check') != 'ok') {
          throw StateError('Published Google workspace failed verification.');
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
        await controlDatabase.customDelete(
          'DELETE FROM meta_store WHERE key IN (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('workspace_display_name:$id'),
            Variable<String>('daily_salah_tracking_enabled:$id'),
            Variable<String>('daily_salah_tracking_setup_dismissed:$id'),
            Variable<String>('workspace_revision:$id'),
            Variable<String>('initial_cloud_backup_pending:$id'),
          ],
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

  Future<bool> _hasSharedWorkspaceData(String id) async {
    const queries = <String>[
      'SELECT 1 FROM qaza_records WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM daily_salah_logs WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_additions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_actions WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_deletion_action_record_snapshots WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM qaza_profile_plan_provenance WHERE user_id = ? LIMIT 1',
      'SELECT 1 FROM account_profiles WHERE local_account_id = ? LIMIT 1',
      'SELECT 1 FROM account_plan_revisions WHERE local_account_id = ? LIMIT 1',
      'SELECT 1 FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1',
    ];
    for (final query in queries) {
      final found = await controlDatabase.customSelect(query,
        variables: [Variable<String>(id)]).get();
      if (found.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _reconcileWorkspaceCreationJournal() async {
    final rows = await controlDatabase.customSelect(
      "SELECT operation_id, target_local_account_id, phase, staging_file, final_file "
      "FROM workspace_operation_journal WHERE operation_type = 'google_workspace_create' "
      "AND phase != 'committed' ORDER BY created_at",
    ).get();
    for (final row in rows) {
      final operationId = row.read<String>('operation_id');
      final id = row.read<String>('target_local_account_id');
      final phase = row.read<String>('phase');
      final stagingName = row.read<String?>('staging_file');
      final finalName = row.read<String?>('final_file');
      final dir = await _documentsDirectoryProvider();
      if (phase != 'finalizing' || stagingName == null || finalName == null) {
        if (stagingName != null) {
          final staging = File('${dir.path}/$stagingName');
          if (await staging.exists()) {
            final quarantine = File('${staging.path}.quarantine');
            if (!await quarantine.exists()) await staging.rename(quarantine.path);
          }
        }
        await controlDatabase.customUpdate(
          "UPDATE workspace_operation_journal SET phase = 'failed', error_message = 'Interrupted before finalization; staging quarantined', updated_at = ? WHERE operation_id = ?",
          variables: [Variable<int>(DateTime.now().microsecondsSinceEpoch), Variable<String>(operationId)],
        );
        continue;
      }
      final finalFile = File('${dir.path}/$finalName');
      final stagingFile = File('${dir.path}/$stagingName');
      if (!await finalFile.exists() && await stagingFile.exists()) {
        await stagingFile.rename(finalFile.path);
      }
      if (!await finalFile.exists()) {
        throw StateError('Finalizing Google workspace creation is missing final and staging files.');
      }
      final published = _googleDatabaseFactory(fileName: finalName, workspaceId: id);
      try {
        if (await published.readWorkspaceFileOwner() != id) {
          throw StateError('Finalizing workspace owner marker does not match.');
        }
        final integrity = await published.customSelect('PRAGMA integrity_check').get();
        if (integrity.isEmpty || integrity.first.read<String>('integrity_check') != 'ok') {
          throw StateError('Finalizing workspace integrity check failed.');
        }
      } finally {
        await published.close();
      }
      await controlDatabase.transaction(() async {
        await controlDatabase.customUpdate(
          "UPDATE local_accounts SET db_file_name = ?, db_layout = 'separate', db_migration_state = 'committed', updated_at = ? WHERE local_account_id = ?",
          variables: [Variable<String>(finalName), Variable<int>(DateTime.now().microsecondsSinceEpoch), Variable<String>(id)],
        );
        await controlDatabase.customUpdate(
          "UPDATE workspace_operation_journal SET phase = 'committed', updated_at = ? WHERE operation_id = ?",
          variables: [Variable<int>(DateTime.now().microsecondsSinceEpoch), Variable<String>(operationId)],
        );
      });
    }
  }

  Future<void> close() async {
    final handles = <AppDatabase>{
      if (_controlDatabase != null) _controlDatabase!,
      ..._workspaceDatabases.values,
    };
    _controlDatabase = null;
    _workspaceDatabases.clear();
    _activeWorkspaceId = null;
    for (final database in handles) {
      await database.close();
    }
  }
}
