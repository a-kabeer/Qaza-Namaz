part of 'database_manager.dart';

const List<(String, String)> _workspaceOwnedTables = <(String, String)>[
  ('qaza_additions', 'user_id'),
  ('account_plan_revisions', 'local_account_id'),
  ('account_profiles', 'local_account_id'),
  ('qaza_records', 'user_id'),
  ('qaza_deletion_actions', 'user_id'),
  ('qaza_deletion_action_record_snapshots', 'user_id'),
  ('daily_salah_logs', 'user_id'),
  ('qaza_profile_plan_provenance', 'user_id'),
];

List<String> _workspaceMetadataKeys(String id) => <String>[
      'workspace_display_name:$id',
      'daily_salah_tracking_enabled:$id',
      'daily_salah_tracking_setup_dismissed:$id',
      'workspace_revision:$id',
      'initial_cloud_backup_pending:$id',
    ];

/// Migration and startup-reconciliation routines for legacy shared-layout
/// Google workspaces.
///
/// These routines were originally an extension on [DatabaseManager], then a
/// `mixin _DatabaseManagerMigration on DatabaseManager` applied to
/// [DatabaseManager] itself — which created recursive interface inheritance
/// and 42 analyzer errors. They now live in this helper with an explicit,
/// constructor-injected [DatabaseManager] dependency, and [DatabaseManager]
/// delegates its migration entry points here (Recovery Plan Stage 1).
class _DatabaseManagerMigrationHelper {
  _DatabaseManagerMigrationHelper(this._manager);

  /// The manager that owns the control database, the workspace handle cache,
  /// and the directory/factory hooks these routines operate through.
  final DatabaseManager _manager;
  Future<Map<String, String>> _readWorkspaceMetadata(
    AppDatabase source,
    String id,
  ) async {
    final keys = _workspaceMetadataKeys(id);
    final rows = await source
        .customSelect(
          'SELECT key, value FROM meta_store WHERE key IN (?, ?, ?, ?, ?) ORDER BY key',
          variables: keys.map((key) => Variable<String>(key)).toList(),
        )
        .get();
    final values = <String, String>{
      for (final row in rows)
        row.read<String>('key'): row.read<String>('value'),
    };
    values.putIfAbsent('workspace_revision:$id', () => '2');
    return values;
  }

  Future<Map<String, dynamic>?> _readScopedRecoverySnapshot(
    AppDatabase source,
    String id,
  ) {
    // R-15 (Recovery Stage 4): selection is scoped to this workspace —
    // the newest snapshot *for this workspace*, not the newest overall.
    return WorkspaceCanonicalContent.scopedRecoverySnapshot(source, id);
  }

  Future<List<String>> _tableColumns(AppDatabase source, String table) async {
    final rows = await source.customSelect('PRAGMA table_info("$table")').get();
    return rows.map((row) => row.read<String>('name')).toList(growable: false);
  }

  Future<List<String>> _tablePrimaryKeyColumns(
    AppDatabase source,
    String table,
  ) async {
    final rows = await source.customSelect('PRAGMA table_info("$table")').get();
    final keyed = <(int, String)>[];
    for (final row in rows) {
      final ordinal = row.read<int>('pk');
      if (ordinal > 0) keyed.add((ordinal, row.read<String>('name')));
    }
    keyed.sort((a, b) => a.$1.compareTo(b.$1));
    return keyed.map((entry) => entry.$2).toList(growable: false);
  }

  Future<int> _copyOwnedTableRows({
    required AppDatabase source,
    required AppDatabase target,
    required String table,
    required String ownerColumn,
    required String ownerId,
  }) async {
    final sourceColumns = await _tableColumns(source, table);
    final targetColumns = await _tableColumns(target, table);
    if (sourceColumns.isEmpty ||
        sourceColumns.toSet().length != sourceColumns.length) {
      throw StateError(
        'Cannot read a valid schema for legacy workspace table $table.',
      );
    }
    if (sourceColumns.toSet().difference(targetColumns.toSet()).isNotEmpty ||
        targetColumns.toSet().difference(sourceColumns.toSet()).isNotEmpty) {
      throw StateError(
        'Legacy workspace table $table has a schema that does not match staging. '
        'The source rows were preserved.',
      );
    }
    if (!sourceColumns.contains(ownerColumn)) {
      throw StateError(
        'Workspace owner column $ownerColumn is missing from $table.',
      );
    }
    final primaryKeys = await _tablePrimaryKeyColumns(source, table);
    final orderBy = (primaryKeys.isEmpty ? sourceColumns : primaryKeys)
        .map((column) => '"$column"')
        .join(', ');
    final quotedColumns = sourceColumns.map((column) => '"$column"').join(', ');
    final rows = await source.customSelect(
      'SELECT $quotedColumns FROM "$table" WHERE "$ownerColumn" = ? ORDER BY $orderBy',
      variables: [Variable<String>(ownerId)],
    ).get();
    final placeholders =
        List<String>.filled(sourceColumns.length, '?').join(', ');
    for (final row in rows) {
      final values = <Variable<Object>>[
        for (final column in sourceColumns) Variable<Object>(row.data[column]),
      ];
      await target.customInsert(
        'INSERT INTO "$table" ($quotedColumns) VALUES ($placeholders)',
        variables: values,
      );
    }
    return rows.length;
  }

  Future<String> _canonicalWorkspaceContentHash(
    AppDatabase source,
    String id,
  ) {
    // Unified canonical hash (decision D-D(ii), Recovery Stage 4): the
    // §7 scoped-export canonicalisation in WorkspaceCanonicalContent.
    // The retired 'workspace-content-v1' form is no longer produced.
    return WorkspaceCanonicalContent.hash(source, id);
  }

  Future<void> _commitLegacyGoogleWorkspaceMigration({
    required String localAccountId,
    required String fileName,
    required String operationId,
    required String expectedHash,
    required AppDatabase verifiedWorkspace,
  }) async {
    final id = localAccountId;
    await _manager.controlDatabase.transactionWithRevision<bool>(() async {
      final current = await _manager.controlDatabase.customSelect(
        'SELECT db_file_name, db_layout, db_migration_state FROM local_accounts '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (current.isEmpty) {
        throw StateError(
          'Legacy Google workspace registry row disappeared during migration.',
        );
      }
      final layout = current.single.read<String>('db_layout');
      if (layout == 'separate') {
        if (current.single.read<String?>('db_file_name') != fileName ||
            current.single.read<String>('db_migration_state') != 'committed') {
          throw StateError(
            'Google workspace registry changed unexpectedly during migration.',
          );
        }
        return false;
      }
      if (layout != 'shared') {
        throw StateError(
          'Legacy Google workspace has an unrecognized database layout.',
        );
      }

      // Verify both copies under the control transaction immediately before
      // cutover. Any concurrent change aborts and preserves the source rows.
      final sourceHash =
          await _canonicalWorkspaceContentHash(_manager.controlDatabase, id);
      final targetHash =
          await _canonicalWorkspaceContentHash(verifiedWorkspace, id);
      if (sourceHash != expectedHash || targetHash != expectedHash) {
        throw StateError(
          'Workspace content changed during migration verification. '
          'The shared source rows have been preserved.',
        );
      }
      // §7 counter rule: revision/sync counters are excluded from the
      // canonical hash and verified separately — here, field-by-field
      // equality of the copied sync row (when the source has one).
      final sourceSync = await WorkspaceCanonicalContent.syncRowValues(
        _manager.controlDatabase,
        id,
      );
      if (sourceSync != null) {
        final targetSync = await WorkspaceCanonicalContent.syncRowValues(
          verifiedWorkspace,
          id,
        );
        if (targetSync == null ||
            jsonEncode(targetSync) != jsonEncode(sourceSync)) {
          throw StateError(
            'Workspace sync metadata changed during migration verification. '
            'The shared source rows have been preserved.',
          );
        }
      }

      // §5.4 retention (decision D-C): the commit does NOT delete the
      // shared source rows. They stay in the control database, marked
      // superseded by the registry's db_layout = 'separate' — the
      // registry decides which copy is authoritative, and the retained
      // rows are never read again. Physical deletion is the separately
      // gated Stage 6 cleanup, not part of migration.
      await _manager.controlDatabase.customUpdate(
        '''UPDATE local_accounts SET db_file_name = ?, db_layout = 'separate',
           db_migration_state = 'committed', updated_at = ?
           WHERE local_account_id = ?''',
        variables: [
          Variable<String>(fileName),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(id),
        ],
      );
      await _manager.controlDatabase.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'committed', source_hash = ?, target_hash = ?,
               updated_at = ?, error_message = NULL
           WHERE operation_id = ?''',
        variables: [
          Variable<String>(sourceHash),
          Variable<String>(targetHash),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      return true;
    });
  }

  Future<AppDatabase> _migrateLegacyGoogleWorkspace(
    String id,
    String finalFileName,
  ) async {
    // §5.3 state rules (decision D-C): never migrate mid-operation.
    final lifecycleRows = await _manager.controlDatabase.customSelect(
      'SELECT lifecycle_state FROM local_accounts WHERE local_account_id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (lifecycleRows.isNotEmpty) {
      final lifecycle = lifecycleRows.single.read<String>('lifecycle_state');
      if (lifecycle == 'adopting' || lifecycle == 'restoring') {
        throw StateError(
          'Migration waits while this workspace is $lifecycle; '
          'it will run at a later startup.',
        );
      }
    }
    final directory = await _manager._documentsDirectoryProvider();
    final finalFile = File('${directory.path}/$finalFileName');
    final stagingName = '$finalFileName.migration-staging';
    final stagingFile = File('${directory.path}/$stagingName');
    final operationId = 'google-workspace-migration:$id';
    final existingJournal = await _manager.controlDatabase.customSelect(
      'SELECT phase FROM workspace_operation_journal WHERE operation_id = ? LIMIT 1',
      variables: [Variable<String>(operationId)],
    ).get();
    if (existingJournal.isNotEmpty &&
        existingJournal.single.read<String>('phase') == 'finalizing') {
      throw StateError(
        'A legacy workspace migration is awaiting startup recovery. '
        'The shared source data has been preserved.',
      );
    }
    if (await finalFile.exists()) {
      throw StateError(
        'An unregistered Google workspace file already exists; it will not be overwritten.',
      );
    }
    if (await stagingFile.exists()) {
      throw StateError(
        'An interrupted migration staging file exists; it will not be overwritten.',
      );
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final currentSnapshot =
        await _readScopedRecoverySnapshot(_manager.controlDatabase, id);
    await _manager.controlDatabase.customInsert(
      '''INSERT OR REPLACE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id, target_local_account_id,
          phase, snapshot_id, created_at, updated_at, staging_file, final_file,
          content_hash, source_hash, target_hash, error_message)
         VALUES (?, 'google_workspace_migration', ?, ?, 'copying', ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL)''',
      variables: [
        Variable<String>(operationId),
        Variable<String>(id),
        Variable<String>(id),
        Variable<String>(currentSnapshot?['snapshot_id'] as String?),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(stagingName),
        Variable<String>(finalFileName),
      ],
    );
    // §5.1 manifest states: the registry mirrors the journal phase.
    await _manager.controlDatabase.customUpdate(
      "UPDATE local_accounts SET db_migration_state = 'copying', updated_at = ? "
      'WHERE local_account_id = ?',
      variables: [
        Variable<int>(now),
        Variable<String>(id),
      ],
    );

    AppDatabase? staging;
    try {
      staging = _manager._googleDatabaseFactory(
        fileName: stagingName,
        workspaceId: id,
      );
      await staging
          .customSelect('SELECT COUNT(*) AS row_count FROM qaza_records')
          .get();

      for (final (table, ownerColumn) in _workspaceOwnedTables) {
        await _copyOwnedTableRows(
          source: _manager.controlDatabase,
          target: staging,
          table: table,
          ownerColumn: ownerColumn,
          ownerId: id,
        );
      }

      final syncRows = await _manager.controlDatabase.customSelect(
        'SELECT 1 FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (syncRows.isNotEmpty) {
        await _copyOwnedTableRows(
          source: _manager.controlDatabase,
          target: staging,
          table: 'workspace_sync_metadata',
          ownerColumn: 'local_account_id',
          ownerId: id,
        );
      } else {
        await staging.customInsert(
          '''INSERT INTO workspace_sync_metadata
             (local_account_id, sync_state, local_revision)
             VALUES (?, 'pending', 1)''',
          variables: [Variable<String>(id)],
        );
      }

      if (currentSnapshot != null) {
        await staging.customInsert(
          'INSERT INTO local_recovery_snapshots (snapshot_id, created_at, payload_json) '
          'VALUES (?, ?, ?)',
          variables: [
            Variable<String>(currentSnapshot['snapshot_id'] as String),
            Variable<String>(currentSnapshot['created_at'] as String),
            Variable<String>(currentSnapshot['payload_json'] as String),
          ],
        );
      }

      final metadata =
          await _readWorkspaceMetadata(_manager.controlDatabase, id);
      for (final entry in metadata.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))) {
        await staging.customInsert(
          '''INSERT INTO meta_store (key, value) VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
          variables: [
            Variable<String>(entry.key),
            Variable<String>(entry.value),
          ],
        );
      }
      await staging.writeWorkspaceFileOwner(id);

      final sourceHash =
          await _canonicalWorkspaceContentHash(_manager.controlDatabase, id);
      final stagingHash = await _canonicalWorkspaceContentHash(staging, id);
      final integrity =
          await staging.customSelect('PRAGMA integrity_check').get();
      if (sourceHash != stagingHash ||
          integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok' ||
          await staging.readWorkspaceFileOwner() != id) {
        throw StateError(
          'Legacy Google workspace staging verification failed. '
          'The shared source rows have been preserved.',
        );
      }

      // §5.1: the manifest records the verifying state with the
      // distinct source and target hashes before finalization.
      await _manager.controlDatabase.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'verifying', source_hash = ?, target_hash = ?,
               content_hash = ?, updated_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable<String>(sourceHash),
          Variable<String>(stagingHash),
          Variable<String>(stagingHash),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      await _manager.controlDatabase.customUpdate(
        "UPDATE local_accounts SET db_migration_state = 'verifying', updated_at = ? "
        'WHERE local_account_id = ?',
        variables: [
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(id),
        ],
      );
      await _manager.controlDatabase.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'finalizing', content_hash = ?, updated_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable<String>(stagingHash),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      await _manager.controlDatabase.customUpdate(
        "UPDATE local_accounts SET db_migration_state = 'finalizing', updated_at = ? "
        'WHERE local_account_id = ?',
        variables: [
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(id),
        ],
      );
      await staging.close();
      staging = null;
      await stagingFile.rename(finalFile.path);

      final published = _manager._googleDatabaseFactory(
          fileName: finalFileName, workspaceId: id);
      try {
        final owner = await published.readWorkspaceFileOwner();
        final publishedIntegrity =
            await published.customSelect('PRAGMA integrity_check').get();
        final publishedHash =
            await _canonicalWorkspaceContentHash(published, id);
        if (owner != id ||
            publishedIntegrity.isEmpty ||
            publishedIntegrity.first.read<String>('integrity_check') != 'ok' ||
            publishedHash != stagingHash) {
          throw StateError(
            'Published legacy Google workspace failed verification. '
            'The original shared source rows remain intact.',
          );
        }
        await _commitLegacyGoogleWorkspaceMigration(
          localAccountId: id,
          fileName: finalFileName,
          operationId: operationId,
          expectedHash: stagingHash,
          verifiedWorkspace: published,
        );
        _manager._workspaceDatabases[id] = published;
        return published;
      } catch (_) {
        await published.close();
        rethrow;
      }
    } catch (error) {
      if (staging != null) await staging.close();
      final journalRows = await _manager.controlDatabase.customSelect(
        'SELECT phase FROM workspace_operation_journal WHERE operation_id = ? LIMIT 1',
        variables: [Variable<String>(operationId)],
      ).get();
      final phase =
          journalRows.isEmpty ? null : journalRows.single.read<String>('phase');
      if (phase != 'finalizing') {
        if (await stagingFile.exists()) {
          final quarantine = File('${stagingFile.path}.quarantine');
          if (!await quarantine.exists()) {
            await stagingFile.rename(quarantine.path);
          }
        }
        await _manager.controlDatabase.customUpdate(
          '''UPDATE workspace_operation_journal
             SET phase = 'failed', error_message = ?, updated_at = ?
             WHERE operation_id = ? AND phase != 'committed' ''',
          variables: [
            Variable<String>(error.toString()),
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId),
          ],
        );
        await _manager.controlDatabase.customUpdate(
          "UPDATE local_accounts SET db_migration_state = 'failed', updated_at = ? "
          "WHERE local_account_id = ? AND db_layout = 'shared'",
          variables: [
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(id),
          ],
        );
      }
      rethrow;
    }
  }

  Future<void> _reconcileLegacyGoogleWorkspaceMigration(
    QueryRow journalRow,
  ) async {
    final operationId = journalRow.read<String>('operation_id');
    final id = journalRow.read<String>('target_local_account_id');
    final phase = journalRow.read<String>('phase');
    final stagingName = journalRow.read<String?>('staging_file');
    final finalName = journalRow.read<String?>('final_file');
    final expectedHash = journalRow.read<String?>('content_hash');
    final directory = await _manager._documentsDirectoryProvider();

    if (phase != 'finalizing' || stagingName == null || finalName == null) {
      if (stagingName != null) {
        final staging = File('${directory.path}/$stagingName');
        if (await staging.exists()) {
          final quarantine = File('${staging.path}.quarantine');
          if (!await quarantine.exists()) {
            await staging.rename(quarantine.path);
          }
        }
      }
      await _manager.controlDatabase.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'failed',
               error_message = 'Interrupted before finalization; migration staging quarantined',
               updated_at = ?
           WHERE operation_id = ? AND phase != 'committed' ''',
        variables: [
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      await _manager.controlDatabase.customUpdate(
        "UPDATE local_accounts SET db_migration_state = 'failed', updated_at = ? "
        "WHERE local_account_id = ? AND db_layout = 'shared'",
        variables: [
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(id),
        ],
      );
      return;
    }

    final expectedFileName = DatabaseManager.googleFileNameForWorkspaceId(id);
    if (finalName != expectedFileName ||
        stagingName != '$expectedFileName.migration-staging' ||
        expectedHash == null) {
      throw StateError(
          'Legacy workspace migration journal failed filename/hash validation.');
    }
    final finalFile = File('${directory.path}/$finalName');
    final stagingFile = File('${directory.path}/$stagingName');
    if (!await finalFile.exists() && await stagingFile.exists()) {
      await stagingFile.rename(finalFile.path);
    }
    if (!await finalFile.exists()) {
      throw StateError(
        'Finalizing migration is missing both published and staging files. '
        'The shared source rows were preserved.',
      );
    }
    final published = _manager._googleDatabaseFactory(
      fileName: finalName,
      workspaceId: id,
    );
    try {
      final owner = await published.readWorkspaceFileOwner();
      final integrity =
          await published.customSelect('PRAGMA integrity_check').get();
      final fileHash = await _canonicalWorkspaceContentHash(published, id);
      if (owner != id ||
          integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok' ||
          fileHash != expectedHash) {
        throw StateError(
          'Finalizing migration file failed owner, integrity, or content-hash verification. '
          'The shared source rows were preserved.',
        );
      }
      await _commitLegacyGoogleWorkspaceMigration(
        localAccountId: id,
        fileName: finalName,
        operationId: operationId,
        expectedHash: expectedHash,
        verifiedWorkspace: published,
      );
    } finally {
      await published.close();
    }
  }

  // ---------------------------------------------------------------------
  // Recovery Stage 4: §5.1 safety copy + storage pre-check, §5.2 startup
  // run, §6 quarantine scan, §4 adoption staging publish.
  // ---------------------------------------------------------------------

  static const String safetyCopyFileName =
      'qaza_namaz.sqlite.migration-safety-copy';

  /// §5.2 startup run. See [DatabaseManager.runStartupMigrations].
  Future<StartupMigrationReport> _runStartupMigrations() async {
    await _manager.initialize();
    final rows = await _manager.controlDatabase
        .customSelect(
          "SELECT local_account_id, lifecycle_state FROM local_accounts "
          "WHERE db_layout = 'shared' "
          "AND substr(local_account_id, 1, 7) = 'google_' "
          'ORDER BY local_account_id',
        )
        .get();
    final migrated = <String>[];
    final failed = <String, String>{};
    final skipped = <String>[];
    final eligible = <String>[];
    for (final row in rows) {
      final id = row.read<String>('local_account_id');
      final lifecycle = row.read<String>('lifecycle_state');
      // §5.3: a workspace mid-adoption or mid-restore is never migrated.
      if (lifecycle == 'adopting' || lifecycle == 'restoring') {
        skipped.add(id);
        continue;
      }
      // §5.3/§6: a workspace with a non-terminal operation in flight is
      // left exactly as it is for this run.
      final inFlight = await _manager.controlDatabase.customSelect(
        'SELECT 1 FROM workspace_operation_journal '
        'WHERE (source_local_account_id = ? OR target_local_account_id = ?) '
        "AND phase NOT IN ('committed', 'failed', 'cleaned') LIMIT 1",
        variables: [Variable<String>(id), Variable<String>(id)],
      ).get();
      if (inFlight.isNotEmpty) {
        skipped.add(id);
        continue;
      }
      eligible.add(id);
    }
    if (eligible.isEmpty) {
      return StartupMigrationReport(
        migrated: migrated,
        failed: failed,
        skippedMidOperation: skipped,
        preCheckPassed: true,
        safetyCopyEnsured: false,
      );
    }

    final directory = await _manager._documentsDirectoryProvider();
    // §5.1 storage pre-check: required space is the safety copy (≈ the
    // control size) + the largest workspace's staging and final files +
    // margin; a blanket 3× the control size satisfies the computed
    // requirement for any single-workspace staging/final pair. The check
    // runs before any file is modified; when free space cannot be
    // determined the run proceeds (nothing is fabricated) and the
    // per-workspace copy will fail safe on its own.
    final controlSize = await _controlDatabaseSizeBytes();
    final requiredBytes = controlSize * 3;
    final freeBytes = await _manager._freeSpaceBytesProvider(directory);
    if (freeBytes != null && freeBytes < requiredBytes) {
      for (final id in eligible) {
        failed[id] = 'Insufficient storage for the migration pre-check: '
            'required $requiredBytes bytes, available $freeBytes bytes. '
            'No file was modified.';
      }
      return StartupMigrationReport(
        migrated: migrated,
        failed: failed,
        skippedMidOperation: skipped,
        preCheckPassed: false,
        safetyCopyEnsured: false,
      );
    }

    // §5.1 safety copy: created ONCE before the first migration of the
    // run (and of the database's lifetime), never refreshed afterwards.
    bool safetyOk;
    try {
      safetyOk = await _ensureSafetyCopy(directory);
    } catch (error) {
      safetyOk = false;
      for (final id in eligible) {
        failed[id] = 'Safety copy could not be created or verified: $error';
      }
    }
    if (!safetyOk) {
      return StartupMigrationReport(
        migrated: migrated,
        failed: failed,
        skippedMidOperation: skipped,
        preCheckPassed: true,
        safetyCopyEnsured: false,
      );
    }

    // §6: unrecognized Google files are quarantined, never exposed as
    // empty workspaces and never deleted.
    await _quarantineUnrecognizedGoogleFiles(directory);

    for (final id in eligible) {
      try {
        await _migrateLegacyGoogleWorkspace(
          id,
          DatabaseManager.googleFileNameForWorkspaceId(id),
        );
        _manager._controlResolvedWorkspaceIds.remove(id);
        migrated.add(id);
      } catch (error) {
        // §5.2 step 7: the workspace remains fully operational on the
        // shared layout; the failure is recorded, not hidden.
        failed[id] = error.toString();
      }
    }
    return StartupMigrationReport(
      migrated: migrated,
      failed: failed,
      skippedMidOperation: skipped,
      preCheckPassed: true,
      safetyCopyEnsured: true,
    );
  }

  Future<int> _controlDatabaseSizeBytes() async {
    final pageCountRows =
        await _manager.controlDatabase.customSelect('PRAGMA page_count').get();
    final pageSizeRows =
        await _manager.controlDatabase.customSelect('PRAGMA page_size').get();
    final pageCount = pageCountRows.single.read<int>('page_count');
    final pageSize = pageSizeRows.single.read<int>('page_size');
    return pageCount * pageSize;
  }

  Future<bool> _ensureSafetyCopy(Directory directory) async {
    final copyFile = File('${directory.path}/$safetyCopyFileName');
    if (await copyFile.exists()) {
      // The pristine pre-migration copy is never refreshed or
      // overwritten (§5.1); it is only re-verified.
      return _verifySafetyCopy(copyFile);
    }
    final escapedPath = copyFile.path.replaceAll("'", "''");
    await _manager.controlDatabase
        .customStatement("VACUUM INTO '$escapedPath'");
    return _verifySafetyCopy(copyFile);
  }

  Future<bool> _verifySafetyCopy(File copyFile) async {
    if (!await copyFile.exists()) return false;
    final handle = await copyFile.open();
    final header = await handle.read(16);
    await handle.close();
    final isPlainSqlite = header.length >= 15 &&
        String.fromCharCodes(header.sublist(0, 15)) == 'SQLite format 3';
    if (isPlainSqlite) {
      final copy = AppDatabase(NativeDatabase(copyFile));
      try {
        final integrity =
            await copy.customSelect('PRAGMA integrity_check').get();
        return integrity.isNotEmpty &&
            integrity.first.read<String>('integrity_check') == 'ok';
      } catch (_) {
        return false;
      } finally {
        await copy.close();
      }
    }
    // Encrypted copy: verify under the real SQLCipher key.
    try {
      return await DatabaseSafetyCopy.verifyEncrypted(copyFile);
    } catch (_) {
      return false;
    }
  }

  Future<void> _quarantineUnrecognizedGoogleFiles(Directory directory) async {
    // A file is recognized when its name is the deterministic S3 name
    // of ANY registered Google workspace (db_file_name is NULL for a
    // shared workspace until its migration commits, so the column alone
    // cannot be the recognition test) or is recorded as a db_file_name.
    final registered = await _manager.controlDatabase
        .customSelect(
          'SELECT local_account_id, db_file_name FROM local_accounts',
        )
        .get();
    final knownNames = <String>{};
    for (final row in registered) {
      final id = row.read<String>('local_account_id');
      if (id.startsWith('google_')) {
        knownNames.add(DatabaseManager.googleFileNameForWorkspaceId(id));
      }
      final fileName = row.read<String?>('db_file_name');
      if (fileName != null) knownNames.add(fileName);
    }
    final pattern = RegExp(r'^qaza_google_[0-9a-f]{32}\.sqlite$');
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!pattern.hasMatch(name) || knownNames.contains(name)) continue;
      final quarantine = File('${entity.path}.quarantine');
      if (!await quarantine.exists()) {
        await entity.rename(quarantine.path);
      }
    }
  }

  String _adoptionStagingName(String id) =>
      '${DatabaseManager.googleFileNameForWorkspaceId(id)}.adoption-staging';

  String _adoptionPreviousName(String id) =>
      '${DatabaseManager.googleFileNameForWorkspaceId(id)}.adoption-previous';

  Future<AppDatabase> _createAdoptionStagingDatabase(String id) async {
    await _manager.initialize();
    final live = await _manager.databaseForWorkspace(id);
    if (!live.isGoogleWorkspaceDatabase) {
      throw StateError(
        'Cross-file adoption requires a separate Google workspace target.',
      );
    }
    final directory = await _manager._documentsDirectoryProvider();
    final stagingName = _adoptionStagingName(id);
    final stagingFile = File('${directory.path}/$stagingName');
    if (await stagingFile.exists()) {
      throw StateError(
        'An adoption staging file already exists; it will not be overwritten.',
      );
    }
    final escapedPath = stagingFile.path.replaceAll("'", "''");
    await live.customStatement("VACUUM INTO '$escapedPath'");
    final staging = _manager._googleDatabaseFactory(
      fileName: stagingName,
      workspaceId: id,
    );
    try {
      if (await staging.readWorkspaceFileOwner() != id) {
        throw StateError('Adoption staging file has an invalid owner marker.');
      }
      return staging;
    } catch (_) {
      await staging.close();
      rethrow;
    }
  }

  Future<void> _discardAdoptionStagingDatabase(String id) async {
    final directory = await _manager._documentsDirectoryProvider();
    final stagingFile = File('${directory.path}/${_adoptionStagingName(id)}');
    if (await stagingFile.exists()) await stagingFile.delete();
  }

  Future<AppDatabase> _publishAdoptionStagingDatabase(
    String id, {
    required Future<void> Function(AppDatabase published) verify,
  }) async {
    final directory = await _manager._documentsDirectoryProvider();
    final finalName = DatabaseManager.googleFileNameForWorkspaceId(id);
    final finalFile = File('${directory.path}/$finalName');
    final stagingFile = File('${directory.path}/${_adoptionStagingName(id)}');
    final previousFile = File('${directory.path}/${_adoptionPreviousName(id)}');
    if (!await stagingFile.exists()) {
      throw StateError('The adoption staging file is missing.');
    }
    if (await previousFile.exists()) {
      throw StateError(
        'A retained pre-adoption file requires recovery before publishing.',
      );
    }
    final cached = _manager._workspaceDatabases.remove(id);
    if (cached != null) await cached.close();
    var movedFinalAside = false;
    try {
      if (await finalFile.exists()) {
        await finalFile.rename(previousFile.path);
        movedFinalAside = true;
      }
      await stagingFile.rename(finalFile.path);
    } catch (_) {
      if (movedFinalAside &&
          !await finalFile.exists() &&
          await previousFile.exists()) {
        await previousFile.rename(finalFile.path);
      }
      rethrow;
    }
    final published = _manager._googleDatabaseFactory(
      fileName: finalName,
      workspaceId: id,
    );
    try {
      if (await published.readWorkspaceFileOwner() != id) {
        throw StateError('Published adoption file has an invalid owner.');
      }
      final integrity =
          await published.customSelect('PRAGMA integrity_check').get();
      if (integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok') {
        throw StateError('Published adoption file failed integrity check.');
      }
      await verify(published);
    } catch (_) {
      await published.close();
      // Never leave an unverified file live: quarantine it and restore
      // the previous file untouched.
      final quarantine = File('${finalFile.path}.quarantine');
      if (await finalFile.exists() && !await quarantine.exists()) {
        await finalFile.rename(quarantine.path);
      }
      if (movedFinalAside &&
          await previousFile.exists() &&
          !await finalFile.exists()) {
        await previousFile.rename(finalFile.path);
      }
      rethrow;
    }
    _manager._workspaceDatabases[id] = published;
    return published;
  }

  Future<void> _discardAdoptionPreviousDatabase(String id) async {
    final directory = await _manager._documentsDirectoryProvider();
    final previousFile = File('${directory.path}/${_adoptionPreviousName(id)}');
    if (await previousFile.exists()) await previousFile.delete();
  }
}
