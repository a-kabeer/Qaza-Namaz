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

extension _DatabaseManagerMigration on DatabaseManager {
  Future<Map<String, String>> _readWorkspaceMetadata(
    AppDatabase source,
    String id,
  ) async {
    final keys = _workspaceMetadataKeys(id);
    final rows = await source.customSelect(
      'SELECT key, value FROM meta_store WHERE key IN (?, ?, ?, ?, ?) ORDER BY key',
      variables: keys.map((key) => Variable<String>(key)).toList(),
    ).get();
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
  ) async {
    final table = await source.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'local_recovery_snapshots' LIMIT 1",
    ).get();
    if (table.isEmpty) return null;
    final rows = await source.customSelect(
      'SELECT snapshot_id, created_at, payload_json FROM local_recovery_snapshots '
      'ORDER BY created_at DESC LIMIT 1',
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    final payload = row.read<String>('payload_json');
    try {
      final root = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      final data = Map<String, dynamic>.from(root['data'] as Map);
      final accounts = data['local_accounts'] as List<dynamic>;
      final sessions = data['app_session_state'] as List<dynamic>;
      if (accounts.length != 1 ||
          accounts.single is! Map ||
          (accounts.single as Map)['local_account_id'] != id ||
          sessions.length != 1 ||
          sessions.single is! Map ||
          (sessions.single as Map)['active_local_account_id'] != id) {
        return null;
      }
      return <String, dynamic>{
        'snapshot_id': row.read<String>('snapshot_id'),
        'created_at': row.read<String>('created_at'),
        'payload_json': payload,
      };
    } catch (_) {
      // An ambiguous recovery snapshot remains in the control database.
      return null;
    }
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
    final placeholders = List<String>.filled(sourceColumns.length, '?').join(', ');
    for (final row in rows) {
      final values = <Variable<Object>>[
        for (final column in sourceColumns)
          Variable<Object>(row.read<Object?>(column)),
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
  ) async {
    if (source.isGoogleWorkspaceDatabase &&
        await source.readWorkspaceFileOwner() != id) {
      throw StateError(
        'Cannot hash a Google workspace database owned by another ID.',
      );
    }

    final tablePayload = <Object?>[];
    for (final (table, ownerColumn) in _workspaceOwnedTables) {
      final columns = await _tableColumns(source, table);
      if (columns.isEmpty || !columns.contains(ownerColumn)) {
        throw StateError(
          'Workspace table $table is missing owner column $ownerColumn.',
        );
      }
      final primaryKeys = await _tablePrimaryKeyColumns(source, table);
      final orderBy = (primaryKeys.isEmpty ? columns : primaryKeys)
          .map((column) => '"$column"')
          .join(', ');
      final quotedColumns = columns.map((column) => '"$column"').join(', ');
      final rows = await source.customSelect(
        'SELECT $quotedColumns FROM "$table" WHERE "$ownerColumn" = ? ORDER BY $orderBy',
        variables: [Variable<String>(id)],
      ).get();
      tablePayload.add(<Object?>[
        table,
        columns,
        for (final row in rows)
          <Object?>[for (final column in columns) row.read<Object?>(column)],
      ]);
    }

    final metadata = await _readWorkspaceMetadata(source, id);
    final syncRows = await source.customSelect(
      '''SELECT local_account_id, sync_state, local_revision, last_synced_revision,
                last_synced_local_hash, last_synced_remote_version,
                last_synced_remote_hash, last_checked_at, conflict_marker,
                remote_account_id
         FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable<String>(id)],
    ).get();
    final sync = syncRows.isEmpty
        ? <Object?>[id, 'pending', 1, null, null, null, null, null, null, null]
        : <Object?>[
            syncRows.single.read<String>('local_account_id'),
            syncRows.single.read<String>('sync_state'),
            syncRows.single.read<int>('local_revision'),
            syncRows.single.read<int?>('last_synced_revision'),
            syncRows.single.read<String?>('last_synced_local_hash'),
            syncRows.single.read<String?>('last_synced_remote_version'),
            syncRows.single.read<String?>('last_synced_remote_hash'),
            syncRows.single.read<String?>('last_checked_at'),
            syncRows.single.read<String?>('conflict_marker'),
            syncRows.single.read<String?>('remote_account_id'),
          ];
    final snapshot = await _readScopedRecoverySnapshot(source, id);
    final canonical = jsonEncode(<Object?>[
      'workspace-content-v1',
      id,
      metadata.entries
          // Revision counters are operational state, not content identity.
          // Row-copy triggers naturally advance them in the destination file.
          .where((entry) => entry.key != 'workspace_revision:$id')
          .map((entry) => <String>[entry.key, entry.value])
          .toList(growable: false),
      tablePayload,
      sync,
      if (snapshot != null)
        <Object?>[
          snapshot['snapshot_id'],
          snapshot['created_at'],
          snapshot['payload_json'],
        ],
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Future<void> _commitLegacyGoogleWorkspaceMigration({
    required String localAccountId,
    required String fileName,
    required String operationId,
    required String expectedHash,
    String? recoverySnapshotId,
    required AppDatabase verifiedWorkspace,
  }) async {
    final id = localAccountId;
    await controlDatabase.transactionWithRevision<bool>(() async {
      final current = await controlDatabase.customSelect(
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
      final sourceHash = await _canonicalWorkspaceContentHash(controlDatabase, id);
      final targetHash = await _canonicalWorkspaceContentHash(verifiedWorkspace, id);
      if (sourceHash != expectedHash || targetHash != expectedHash) {
        throw StateError(
          'Workspace content changed during migration verification. '
          'The shared source rows have been preserved.',
        );
      }

      for (final (table, ownerColumn) in _workspaceOwnedTables) {
        await controlDatabase.customUpdate(
          'DELETE FROM "$table" WHERE "$ownerColumn" = ?',
          variables: [Variable<String>(id)],
        );
      }
      await controlDatabase.customUpdate(
        'DELETE FROM workspace_sync_metadata WHERE local_account_id = ?',
        variables: [Variable<String>(id)],
      );
      await controlDatabase.customUpdate(
        'DELETE FROM meta_store WHERE key IN (?, ?, ?, ?, ?)',
        variables: _workspaceMetadataKeys(id)
            .map((key) => Variable<String>(key))
            .toList(),
      );
      if (recoverySnapshotId != null) {
        await controlDatabase.customUpdate(
          'DELETE FROM local_recovery_snapshots WHERE snapshot_id = ?',
          variables: [Variable<String>(recoverySnapshotId)],
        );
      }
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
        '''UPDATE workspace_operation_journal
           SET phase = 'committed', updated_at = ?, error_message = NULL
           WHERE operation_id = ?''',
        variables: [
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
    final directory = await _documentsDirectoryProvider();
    final finalFile = File('${directory.path}/$finalFileName');
    final stagingName = '$finalFileName.migration-staging';
    final stagingFile = File('${directory.path}/$stagingName');
    final operationId = 'google-workspace-migration:$id';
    final existingJournal = await controlDatabase.customSelect(
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
    final currentSnapshot = await _readScopedRecoverySnapshot(controlDatabase, id);
    await controlDatabase.customInsert(
      '''INSERT OR REPLACE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id, target_local_account_id,
          phase, snapshot_id, created_at, updated_at, staging_file, final_file,
          content_hash, error_message)
         VALUES (?, 'google_workspace_migration', ?, ?, 'prepared', ?, ?, ?, ?, ?, NULL, NULL)''',
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

    AppDatabase? staging;
    try {
      staging = _googleDatabaseFactory(
        fileName: stagingName,
        workspaceId: id,
      );
      await staging.customSelect('SELECT COUNT(*) AS row_count FROM qaza_records').get();

      for (final (table, ownerColumn) in _workspaceOwnedTables) {
        await _copyOwnedTableRows(
          source: controlDatabase,
          target: staging,
          table: table,
          ownerColumn: ownerColumn,
          ownerId: id,
        );
      }

      final syncRows = await controlDatabase.customSelect(
        'SELECT 1 FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (syncRows.isNotEmpty) {
        await _copyOwnedTableRows(
          source: controlDatabase,
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

      final metadata = await _readWorkspaceMetadata(controlDatabase, id);
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

      final sourceHash = await _canonicalWorkspaceContentHash(controlDatabase, id);
      final stagingHash = await _canonicalWorkspaceContentHash(staging, id);
      final integrity = await staging.customSelect('PRAGMA integrity_check').get();
      if (sourceHash != stagingHash ||
          integrity.isEmpty ||
          integrity.first.read<String>('integrity_check') != 'ok' ||
          await staging.readWorkspaceFileOwner() != id) {
        throw StateError(
          'Legacy Google workspace staging verification failed. '
          'The shared source rows have been preserved.',
        );
      }

      await controlDatabase.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'finalizing', content_hash = ?, updated_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable<String>(stagingHash),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      await staging.close();
      staging = null;
      await stagingFile.rename(finalFile.path);

      final published =
          _googleDatabaseFactory(fileName: finalFileName, workspaceId: id);
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
          recoverySnapshotId: currentSnapshot?['snapshot_id'] as String?,
          verifiedWorkspace: published,
        );
        _workspaceDatabases[id] = published;
        return published;
      } catch (_) {
        await published.close();
        rethrow;
      }
    } catch (error) {
      if (staging != null) await staging.close();
      final journalRows = await controlDatabase.customSelect(
        'SELECT phase FROM workspace_operation_journal WHERE operation_id = ? LIMIT 1',
        variables: [Variable<String>(operationId)],
      ).get();
      final phase = journalRows.isEmpty
          ? null
          : journalRows.single.read<String>('phase');
      if (phase != 'finalizing') {
        if (await stagingFile.exists()) {
          final quarantine = File('${stagingFile.path}.quarantine');
          if (!await quarantine.exists()) {
            await stagingFile.rename(quarantine.path);
          }
        }
        await controlDatabase.customUpdate(
          '''UPDATE workspace_operation_journal
             SET phase = 'failed', error_message = ?, updated_at = ?
             WHERE operation_id = ? AND phase != 'committed' ''',
          variables: [
            Variable<String>(error.toString()),
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId),
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
    final recoverySnapshotId = journalRow.read<String?>('snapshot_id');
    final directory = await _documentsDirectoryProvider();

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
      await controlDatabase.customUpdate(
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
      return;
    }

    final expectedFileName = googleFileNameForWorkspaceId(id);
    if (finalName != expectedFileName ||
        stagingName != '$expectedFileName.migration-staging' ||
        expectedHash == null) {
      throw StateError('Legacy workspace migration journal failed filename/hash validation.');
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
    final published = _googleDatabaseFactory(
      fileName: finalName,
      workspaceId: id,
    );
    try {
      final owner = await published.readWorkspaceFileOwner();
      final integrity = await published.customSelect('PRAGMA integrity_check').get();
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
        recoverySnapshotId: recoverySnapshotId,
        verifiedWorkspace: published,
      );
    } finally {
      await published.close();
    }
  }
}
