import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/local_account.dart';
import '../local/database/app_database.dart';
import '../local/database/database_manager.dart';

const _appId = 'qaza_namaz_app';
const _backupSchemaVersion = 1;

class LocalBackupException implements Exception {
  const LocalBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalBackupAnalysis {
  const LocalBackupAnalysis({
    required this.dbRevision,
    required this.recordCount,
    required this.accountCount,
    required this.onboardingCompleted,
  });

  final int dbRevision;
  final int recordCount;
  final int accountCount;
  final bool onboardingCompleted;
}

class LocalBackupService {
  LocalBackupService(this.database, {DatabaseManager? databaseManager})
      : _databaseManager = databaseManager;

  final AppDatabase database;
  final DatabaseManager? _databaseManager;

  Future<String> exportJson({
    DateTime? exportedAt,
    String? localAccountId,
  }) async {
    final manager = _databaseManager;
    if (manager == null) {
      return _exportFromSource(
        database,
        exportedAt: exportedAt,
        localAccountId: localAccountId,
      );
    }
    final control = manager.controlDatabase;
    if (localAccountId != null) {
      final id = localAccountId.trim();
      if (id.isEmpty)
        throw ArgumentError.value(localAccountId, 'localAccountId');
      final workspace = await manager.databaseForWorkspace(id);
      final account = await _readLogicalAccount(control, id);
      return _exportFromSource(
        workspace,
        exportedAt: exportedAt,
        localAccountId: id,
        logicalAccount: account,
      );
    }

    final root =
        jsonDecode(await _exportFromSource(control, exportedAt: exportedAt));
    if (root is! Map<String, dynamic>) {
      throw const LocalBackupException('The local export document is invalid.');
    }
    final data = Map<String, dynamic>.from(root['data'] as Map);
    final separateRows = await control
        .customSelect(
          "SELECT local_account_id FROM local_accounts WHERE db_layout = 'separate' ORDER BY local_account_id",
        )
        .get();

    for (final registryRow in separateRows) {
      final id = registryRow.read<String>('local_account_id');
      final account = await _readLogicalAccount(control, id);
      final workspace = await manager.databaseForWorkspace(id);
      final scopedRoot = jsonDecode(await _exportFromSource(
        workspace,
        exportedAt: exportedAt,
        localAccountId: id,
        logicalAccount: account,
      )) as Map<String, dynamic>;
      final scopedData = Map<String, dynamic>.from(scopedRoot['data'] as Map);

      for (final key in const <String>[
        'qaza_records',
        'daily_salah_logs',
        'qaza_additions',
        'qaza_deletion_actions',
        'qaza_deletion_action_record_snapshots',
        'qaza_profile_plan_provenance',
        'account_profiles',
        'account_plan_revisions',
      ]) {
        (data[key] as List<dynamic>).addAll(scopedData[key] as List<dynamic>);
      }

      final rootMeta = Map<String, dynamic>.from(data['meta_store'] as Map);
      final scopedMeta =
          Map<String, dynamic>.from(scopedData['meta_store'] as Map);
      for (final key in const <String>[
        'daily_salah_tracking_enabled_by_account',
        'daily_salah_tracking_setup_dismissed_by_account',
        'workspace_display_names_by_account',
      ]) {
        final combined = Map<String, dynamic>.from(
          (rootMeta[key] as Map?) ?? const <String, dynamic>{},
        );
        final incoming = scopedMeta[key];
        if (incoming is Map) {
          for (final entry in incoming.entries) {
            if (entry.key is String)
              combined[entry.key as String] = entry.value;
          }
        }
        rootMeta[key] = combined;
      }
      data['meta_store'] = rootMeta;
    }

    for (final key in const <String>[
      'qaza_records',
      'qaza_additions',
      'qaza_deletion_actions',
      'account_profiles',
    ]) {
      (data[key] as List<dynamic>).sort((a, b) {
        final left = a as Map;
        final right = b as Map;
        final leftKey =
            (left['id'] ?? left['local_account_id'] ?? '').toString();
        final rightKey =
            (right['id'] ?? right['local_account_id'] ?? '').toString();
        return leftKey.compareTo(rightKey);
      });
    }
    (data['qaza_profile_plan_provenance'] as List<dynamic>).sort((a, b) =>
        ((a as Map)['record_id'] as String)
            .compareTo((b as Map)['record_id'] as String));
    (data['account_plan_revisions'] as List<dynamic>).sort((a, b) {
      final left = a as Map;
      final right = b as Map;
      return '${left['local_account_id']}:${left['revision_id']}'
          .compareTo('${right['local_account_id']}:${right['revision_id']}');
    });
    root['data'] = data;
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  Future<Map<String, dynamic>> _readLogicalAccount(
    AppDatabase control,
    String localAccountId,
  ) async {
    final rows = await control.customSelect(
      '''SELECT local_account_id, account_mode, lifecycle_state, created_at, updated_at
         FROM local_accounts WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable<String>(localAccountId)],
    ).get();
    if (rows.isEmpty) {
      throw LocalBackupException(
        'Workspace "$localAccountId" is not registered and cannot be exported.',
      );
    }
    final row = rows.single;
    return <String, dynamic>{
      'local_account_id': row.read<String>('local_account_id'),
      'account_mode': row.read<String>('account_mode'),
      'lifecycle_state': row.read<String>('lifecycle_state'),
      'created_at': row.read<int>('created_at'),
      'updated_at': row.read<int>('updated_at'),
    };
  }

  Future<String> _exportFromSource(
    AppDatabase source, {
    DateTime? exportedAt,
    String? localAccountId,
    Map<String, dynamic>? logicalAccount,
  }) async {
    Future<List<Map<String, dynamic>>> selectMapsFromSource(
      String sql,
      List<String> columns, {
      Set<String> integerColumns = const <String>{},
    }) async {
      final selectedRows = await source.customSelect(sql).get();
      return selectedRows
          .map((row) => <String, dynamic>{
                for (final column in columns)
                  column: _readValue(
                    row,
                    column,
                    integer: integerColumns.contains(column),
                  ),
              })
          .toList(growable: false);
    }

    return source.transaction(() async {
      final dbRevision = localAccountId == null
          ? await source.readDbRevision()
          : await source.readWorkspaceRevision(localAccountId);
      final users = await source.qazaRecordsDao.userIds();
      final records = <Map<String, dynamic>>[];
      for (final userId in users) {
        final rows = await source.qazaRecordsDao.getAll(userId: userId);
        records.addAll(rows.map((row) => row.toJson()));
      }
      records.sort(
        (a, b) => (a['id'] as String).compareTo(b['id'] as String),
      );

      final accountIds = source.isGoogleWorkspaceDatabase
          ? <String>[localAccountId ?? source.workspaceId!]
          : (await source
                  .customSelect(
                    'SELECT local_account_id FROM local_accounts ORDER BY local_account_id',
                  )
                  .get())
              .map((row) => row.read<String>('local_account_id'))
              .toList(growable: false);
      final trackingEnabledByAccount = <String, bool>{};
      final trackingSetupDismissedByAccount = <String, bool>{};
      final workspaceDisplayNames = <String, String>{};
      final workspaceNameRows = await source
          .customSelect(
            "SELECT key, value FROM meta_store "
            "WHERE key LIKE 'workspace_display_name:%'",
          )
          .get();
      const workspaceNamePrefix = 'workspace_display_name:';
      for (final row in workspaceNameRows) {
        final key = row.read<String>('key');
        final accountId = key.startsWith(workspaceNamePrefix)
            ? key.substring(workspaceNamePrefix.length)
            : '';
        final displayName = row.read<String>('value').trim();
        if (accountId.isNotEmpty && displayName.isNotEmpty) {
          workspaceDisplayNames[accountId] = displayName;
        }
      }
      for (final accountId in accountIds) {
        trackingEnabledByAccount[accountId] =
            await source.isDailySalahTrackingEnabled(userId: accountId);
        trackingSetupDismissedByAccount[accountId] =
            await source.isDailySalahTrackingSetupDismissed(userId: accountId);
      }
      final activeAccountId = source.isGoogleWorkspaceDatabase
          ? (localAccountId ?? source.workspaceId)
          : await (() async {
              final activeRows = await source
                  .customSelect(
                    'SELECT active_local_account_id FROM app_session_state ORDER BY id LIMIT 1',
                  )
                  .get();
              return activeRows.isEmpty
                  ? null
                  : activeRows.first.read<String?>('active_local_account_id');
            })();
      final preferenceAccountId = localAccountId?.trim().isNotEmpty == true
          ? localAccountId!.trim()
          : activeAccountId ?? 'guest';

      final document = <String, dynamic>{
        'metadata': {
          'app_id': _appId,
          'backup_schema_version': _backupSchemaVersion,
          'database_schema_version': source.schemaVersion,
          'db_revision': dbRevision,
          'export_timestamp':
              (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        'data': {
          'qaza_records': records,
          'daily_salah_logs': await selectMapsFromSource(
            'SELECT user_id, prayer_date, prayer_type, status, '
            'tracker_created_qaza_id, linked_qaza_id, completion_sync_id, '
            'updated_at FROM daily_salah_logs '
            'ORDER BY user_id, prayer_date, prayer_type',
            [
              'user_id',
              'prayer_date',
              'prayer_type',
              'status',
              'tracker_created_qaza_id',
              'linked_qaza_id',
              'completion_sync_id',
              'updated_at',
            ],
          ),
          'qaza_additions': await selectMapsFromSource(
            'SELECT id, user_id, mode, input_snapshot, revision, created_at, updated_at '
            'FROM qaza_additions ORDER BY id',
            [
              'id',
              'user_id',
              'mode',
              'input_snapshot',
              'revision',
              'created_at',
              'updated_at',
            ],
          ),
          'qaza_deletion_actions': await selectMapsFromSource(
            'SELECT id, user_id, addition_id, created_at, resolved_at, entity_version '
            'FROM qaza_deletion_actions ORDER BY id',
            [
              'id',
              'user_id',
              'addition_id',
              'created_at',
              'resolved_at',
              'entity_version',
            ],
          ),
          'qaza_deletion_action_record_snapshots': await selectMapsFromSource(
            'SELECT deletion_action_id, record_id, user_id, addition_id, prayer_type, '
            'original_date, status, completed_at, completion_id, created_at, '
            'updated_at, record_version '
            'FROM qaza_deletion_action_record_snapshots '
            'ORDER BY deletion_action_id, record_id',
            [
              'deletion_action_id',
              'record_id',
              'user_id',
              'addition_id',
              'prayer_type',
              'original_date',
              'status',
              'completed_at',
              'completion_id',
              'created_at',
              'updated_at',
              'record_version',
            ],
          ),
          'qaza_profile_plan_provenance': await selectMapsFromSource(
            'SELECT record_id, user_id, plan_revision_id, plan_fingerprint '
            'FROM qaza_profile_plan_provenance ORDER BY record_id',
            ['record_id', 'user_id', 'plan_revision_id', 'plan_fingerprint'],
          ),
          'local_accounts': source.isGoogleWorkspaceDatabase
              ? <Map<String, dynamic>>[
                  if (logicalAccount != null) logicalAccount,
                ]
              : await selectMapsFromSource(
                  'SELECT local_account_id, account_mode, lifecycle_state, created_at, updated_at '
                  'FROM local_accounts ORDER BY local_account_id',
                  [
                    'local_account_id',
                    'account_mode',
                    'lifecycle_state',
                    'created_at',
                    'updated_at',
                  ],
                  integerColumns: {'created_at', 'updated_at'},
                ),
          'app_session_state': source.isGoogleWorkspaceDatabase
              ? <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 1,
                    'active_local_account_id':
                        localAccountId ?? source.workspaceId,
                  },
                ]
              : await selectMapsFromSource(
                  'SELECT id, active_local_account_id FROM app_session_state ORDER BY id',
                  ['id', 'active_local_account_id'],
                  integerColumns: {'id'},
                ),
          'account_profiles': await selectMapsFromSource(
            'SELECT local_account_id, payload_json, entity_version, updated_at, '
            'writer_device_id, operation_id FROM account_profiles ORDER BY local_account_id',
            [
              'local_account_id',
              'payload_json',
              'entity_version',
              'updated_at',
              'writer_device_id',
              'operation_id',
            ],
            integerColumns: {'updated_at'},
          ),
          'account_plan_revisions': await selectMapsFromSource(
            'SELECT local_account_id, revision_id, payload_json, created_at '
            'FROM account_plan_revisions ORDER BY local_account_id, revision_id',
            ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
            integerColumns: {'created_at'},
          ),
          'meta_store': {
            'is_onboarding_completed': await source.isOnboardingCompleted(),
            'daily_salah_tracking_enabled':
                await source.isDailySalahTrackingEnabled(
              userId: preferenceAccountId,
            ),
            'daily_salah_tracking_enabled_by_account': trackingEnabledByAccount,
            'daily_salah_tracking_setup_dismissed':
                await source.isDailySalahTrackingSetupDismissed(
              userId: preferenceAccountId,
            ),
            'daily_salah_tracking_setup_dismissed_by_account':
                trackingSetupDismissedByAccount,
            'workspace_display_names_by_account': workspaceDisplayNames,
          },
        },
      };

      if (localAccountId != null) {
        final normalized = localAccountId.trim();
        if (normalized.isEmpty) {
          throw ArgumentError.value(localAccountId, 'localAccountId');
        }
        final data = document['data'] as Map<String, dynamic>;
        final accounts = data['local_accounts'] as List<dynamic>;
        if (!accounts.any(
          (row) => row is Map && row['local_account_id'] == normalized,
        )) {
          throw LocalBackupException(
            'The selected local workspace is not available for backup.',
          );
        }

        _filterOwnedRows(data, 'qaza_records', 'userId', normalized);
        _filterOwnedRows(data, 'daily_salah_logs', 'user_id', normalized);
        _filterOwnedRows(data, 'qaza_additions', 'user_id', normalized);
        _filterOwnedRows(data, 'qaza_deletion_actions', 'user_id', normalized);
        _filterOwnedRows(
          data,
          'qaza_deletion_action_record_snapshots',
          'user_id',
          normalized,
        );
        _filterOwnedRows(
          data,
          'qaza_profile_plan_provenance',
          'user_id',
          normalized,
        );
        _filterOwnedRows(
            data, 'local_accounts', 'local_account_id', normalized);
        _filterOwnedRows(
            data, 'account_profiles', 'local_account_id', normalized);
        _filterOwnedRows(
          data,
          'account_plan_revisions',
          'local_account_id',
          normalized,
        );

        // The remote snapshot describes this workspace, not the currently
        // foregrounded workspace on the device.
        data['app_session_state'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'active_local_account_id': normalized,
          },
        ];

        final profileRows = data['account_profiles'] as List<dynamic>;
        var profileOnboardingCompleted = false;
        if (profileRows.isNotEmpty) {
          final rawProfile = (profileRows.single as Map)['payload_json'];
          if (rawProfile is String) {
            try {
              final decodedProfile = jsonDecode(rawProfile);
              profileOnboardingCompleted = decodedProfile is Map &&
                  decodedProfile['onboardingCompleted'] == true;
            } catch (_) {
              profileOnboardingCompleted = false;
            }
          }
        }
        final meta = data['meta_store'] as Map<String, dynamic>;
        meta['is_onboarding_completed'] = profileOnboardingCompleted;
        for (final key in [
          'daily_salah_tracking_enabled_by_account',
          'daily_salah_tracking_setup_dismissed_by_account',
        ]) {
          final values = meta[key];
          if (values is Map) {
            meta[key] = <String, dynamic>{
              normalized: values[normalized] == true,
            };
          }
        }
        final displayNames = meta['workspace_display_names_by_account'];
        if (displayNames is Map) {
          final displayName = displayNames[normalized];
          meta['workspace_display_names_by_account'] =
              displayName is String && displayName.trim().isNotEmpty
                  ? <String, dynamic>{normalized: displayName.trim()}
                  : <String, dynamic>{};
        }
      }

      return const JsonEncoder.withIndent('  ').convert(document);
    });
  }

  /// Adopts a Guest workspace into a newly verified Google workspace.
  ///
  /// A validated, account-scoped snapshot is durably stored before ownership
  /// changes. Ownership reassignment and Guest archival are a single SQLite
  /// transaction. The snapshot lives in a dedicated table so it cannot replace
  /// a recovery snapshot already owned by cloud synchronization.
  Future<void> adoptGuestWorkspace({
    required String sourceLocalAccountId,
    required String targetGoogleLocalAccountId,
    required String googleDisplayName,
  }) async {
    final source = sourceLocalAccountId.trim();
    final suppliedTarget = targetGoogleLocalAccountId.trim();
    final target = suppliedTarget.startsWith('google:')
        ? googleLocalWorkspaceId(suppliedTarget.substring('google:'.length))
        : suppliedTarget;
    if (!isGuestLocalWorkspaceId(source) ||
        !target.startsWith('google_') ||
        source == target) {
      throw const LocalBackupException(
        'Only a Guest workspace can be adopted into a verified Google workspace.',
      );
    }

    // The operation ID is deterministic for this Guest/Google pair. A process
    // death can safely retry the same operation instead of creating a second
    // snapshot or adopting the same records twice.
    final operationId = 'guest-adoption:$source=>$target';
    final priorOperation = await database.customSelect(
      'SELECT phase FROM workspace_operation_journal '
      'WHERE operation_id = ? LIMIT 1',
      variables: [Variable(operationId)],
    ).get();
    if (priorOperation.isNotEmpty) {
      final phase = priorOperation.first.read<String>('phase');
      if (phase == 'committed' || phase == 'cleaned') {
        final states = await database.customSelect(
          '''SELECT local_account_id, lifecycle_state FROM local_accounts
             WHERE local_account_id IN (?, ?)''',
          variables: [Variable(source), Variable(target)],
        ).get();
        final statesById = <String, String>{
          for (final row in states)
            row.read<String>('local_account_id'):
                row.read<String>('lifecycle_state'),
        };
        if (statesById[source] == 'adopted_recovery' &&
            statesById[target] == 'active') {
          return;
        }
        throw const LocalBackupException(
          'A previous Guest adoption is recorded but workspace state differs. '
          'No automatic retry was attempted; keep both workspaces and contact support.',
        );
      }
      if (phase != 'prepared' && phase != 'snapshotted') {
        throw const LocalBackupException(
          'A Guest adoption needs recovery before it can continue. '
          'No workspace data was changed.',
        );
      }
    }

    const ownerTables = <(String, String)>[
      ('qaza_records', 'user_id'),
      ('daily_salah_logs', 'user_id'),
      ('qaza_additions', 'user_id'),
      ('qaza_deletion_actions', 'user_id'),
      ('qaza_deletion_action_record_snapshots', 'user_id'),
      ('qaza_profile_plan_provenance', 'user_id'),
      ('account_profiles', 'local_account_id'),
      ('account_plan_revisions', 'local_account_id'),
    ];

    Future<bool> workspaceHasData(String id) async {
      for (final (table, ownerColumn) in ownerTables) {
        final rows = await database.customSelect(
          'SELECT 1 FROM "$table" WHERE "$ownerColumn" = ? LIMIT 1',
          variables: [Variable(id)],
        ).get();
        if (rows.isNotEmpty) return true;
      }
      return false;
    }

    final sourceRows = await database.customSelect(
      'SELECT lifecycle_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable(source)],
    ).get();
    final targetRows = await database.customSelect(
      'SELECT lifecycle_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable(target)],
    ).get();
    if (sourceRows.isEmpty ||
        sourceRows.first.read<String>('lifecycle_state') != 'active') {
      throw const LocalBackupException(
        'The Guest workspace is not available for adoption.',
      );
    }
    if (targetRows.isEmpty ||
        targetRows.first.read<String>('lifecycle_state') != 'active') {
      throw const LocalBackupException(
        'The verified Google workspace is not available for adoption.',
      );
    }
    if (await workspaceHasData(target)) {
      throw const LocalBackupException(
        'This Google workspace already contains local data. The Guest workspace was left unchanged.',
      );
    }

    final expectedCounts = <String, int>{};
    for (final (table, ownerColumn) in ownerTables) {
      final countRows = await database.customSelect(
        'SELECT COUNT(*) AS row_count FROM "$table" WHERE "$ownerColumn" = ?',
        variables: [Variable(source)],
      ).get();
      expectedCounts[table] = countRows.single.read<int>('row_count');
    }

    var recoveryJson = await exportJson(localAccountId: source);
    await analyzeImport(recoveryJson);
    final operationNow = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT OR IGNORE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, created_at, updated_at)
         VALUES (?, 'guest_adoption', ?, ?, 'prepared', ?, ?)''',
      variables: [
        Variable(operationId),
        Variable(source),
        Variable(target),
        Variable(operationNow),
        Variable(operationNow),
      ],
    );
    await analyzeImport(recoveryJson);
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS local_account_adoption_snapshots (
        snapshot_id TEXT NOT NULL PRIMARY KEY,
        source_local_account_id TEXT NOT NULL,
        target_local_account_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    final snapshotId = operationId;
    final existingSnapshot = await database.customSelect(
      'SELECT payload_json FROM local_account_adoption_snapshots '
      'WHERE snapshot_id = ? LIMIT 1',
      variables: [Variable(snapshotId)],
    ).get();
    bool sameSnapshotContent(String first, String second) {
      try {
        final firstDecoded =
            Map<String, dynamic>.from(jsonDecode(first) as Map);
        final secondDecoded =
            Map<String, dynamic>.from(jsonDecode(second) as Map);
        for (final root in [firstDecoded, secondDecoded]) {
          final metadata = Map<String, dynamic>.from(root['metadata'] as Map);
          metadata.remove('export_timestamp');
          root['metadata'] = metadata;
        }
        return jsonEncode(firstDecoded) == jsonEncode(secondDecoded);
      } catch (_) {
        return false;
      }
    }

    if (existingSnapshot.isNotEmpty) {
      final savedSnapshot =
          existingSnapshot.single.read<String>('payload_json');
      if (!sameSnapshotContent(savedSnapshot, recoveryJson)) {
        throw const LocalBackupException(
          'A previous adoption snapshot differs from the current Guest data. '
          'The Guest workspace was left unchanged pending recovery.',
        );
      }
      // Preserve the exact persisted snapshot bytes for read-back verification.
      recoveryJson = savedSnapshot;
    }
    if (existingSnapshot.isEmpty) {
      await database.transaction(() async {
        await database.customInsert(
          '''INSERT INTO local_account_adoption_snapshots
             (snapshot_id, source_local_account_id, target_local_account_id,
              created_at, payload_json)
             VALUES (?, ?, ?, ?, ?)''',
          variables: [
            Variable(snapshotId),
            Variable(source),
            Variable(target),
            Variable(DateTime.now().toUtc().toIso8601String()),
            Variable(recoveryJson),
          ],
        );
      });
    }
    final verifiedSnapshot = await database.customSelect(
      'SELECT payload_json FROM local_account_adoption_snapshots '
      'WHERE snapshot_id = ? LIMIT 1',
      variables: [Variable(snapshotId)],
    ).get();
    if (verifiedSnapshot.isEmpty ||
        verifiedSnapshot.first.read<String>('payload_json') != recoveryJson) {
      throw const LocalBackupException(
        'A recovery snapshot could not be verified. The Guest workspace was not changed.',
      );
    }
    await database.customUpdate(
      '''UPDATE workspace_operation_journal
         SET phase = 'snapshotted', snapshot_id = ?, updated_at = ?,
             error_message = NULL
         WHERE operation_id = ? AND phase IN ('prepared', 'snapshotted')''',
      variables: [
        Variable(snapshotId),
        Variable(DateTime.now().microsecondsSinceEpoch),
        Variable(operationId),
      ],
    );

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final normalizedGoogleName = googleDisplayName.trim();
    await database.transactionWithRevision(() async {
      final latestSource = await database.customSelect(
        'SELECT lifecycle_state FROM local_accounts '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(source)],
      ).get();
      final latestTarget = await database.customSelect(
        'SELECT lifecycle_state FROM local_accounts '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(target)],
      ).get();
      if (latestSource.isEmpty ||
          latestSource.first.read<String>('lifecycle_state') != 'active' ||
          latestTarget.isEmpty ||
          latestTarget.first.read<String>('lifecycle_state') != 'active' ||
          await workspaceHasData(target)) {
        throw const LocalBackupException(
          'Workspace state changed during adoption. No Guest data was moved.',
        );
      }

      final sessionRows = await database
          .customSelect(
            'SELECT active_local_account_id FROM app_session_state '
            'WHERE id = 1 LIMIT 1',
          )
          .get();
      final activeId = sessionRows.isEmpty
          ? null
          : sessionRows.first.read<String?>('active_local_account_id');
      if (activeId != source && activeId != target) {
        throw const LocalBackupException(
          'The active workspace changed during adoption. Please retry.',
        );
      }

      // Plan revision payloads contain their owning user ID, so update that
      // embedded reference as well as the table's workspace key.
      final revisions = await database.customSelect(
        'SELECT revision_id, payload_json FROM account_plan_revisions '
        'WHERE local_account_id = ?',
        variables: [Variable(source)],
      ).get();
      for (final row in revisions) {
        final revisionId = row.read<String>('revision_id');
        final rawPayload = row.read<String>('payload_json');
        dynamic decoded;
        try {
          decoded = jsonDecode(rawPayload);
        } catch (_) {
          throw const LocalBackupException(
            'A saved plan revision could not be validated. Guest data was not moved.',
          );
        }
        if (decoded is! Map) {
          throw const LocalBackupException(
            'A saved plan revision has an invalid format. Guest data was not moved.',
          );
        }
        final payload = Map<String, dynamic>.from(decoded);
        if (payload['userId'] == source) payload['userId'] = target;
        if (payload['user_id'] == source) payload['user_id'] = target;
        await database.customUpdate(
          '''UPDATE account_plan_revisions SET payload_json = ?
             WHERE local_account_id = ? AND revision_id = ?''',
          variables: [
            Variable(jsonEncode(payload)),
            Variable(source),
            Variable(revisionId),
          ],
        );
      }

      for (final (table, ownerColumn) in ownerTables) {
        await database.customUpdate(
          'UPDATE "$table" SET "$ownerColumn" = ? WHERE "$ownerColumn" = ?',
          variables: [Variable(target), Variable(source)],
        );
      }
      await database.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'copied', updated_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(operationId)
        ],
      );

      // Verify row-count parity inside the same transaction as the ownership
      // move. Any mismatch throws and rolls the complete transfer back.
      for (final (table, ownerColumn) in ownerTables) {
        final sourceCountRows = await database.customSelect(
          'SELECT COUNT(*) AS row_count FROM "$table" WHERE "$ownerColumn" = ?',
          variables: [Variable(source)],
        ).get();
        final targetCountRows = await database.customSelect(
          'SELECT COUNT(*) AS row_count FROM "$table" WHERE "$ownerColumn" = ?',
          variables: [Variable(target)],
        ).get();
        final sourceCount = sourceCountRows.single.read<int>('row_count');
        final targetCount = targetCountRows.single.read<int>('row_count');
        if (sourceCount != 0 || targetCount != expectedCounts[table]) {
          throw LocalBackupException(
            'Adoption validation failed for $table. No workspace data was moved.',
          );
        }
      }
      await database.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'verified', updated_at = ?
           WHERE operation_id = ?''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(operationId)
        ],
      );

      for (final setting in [
        'daily_salah_tracking_enabled',
        'daily_salah_tracking_setup_dismissed',
      ]) {
        final oldKey = '$setting:$source';
        final newKey = '$setting:$target';
        final values = await database.customSelect(
          'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
          variables: [Variable(oldKey)],
        ).get();
        if (values.isNotEmpty) {
          await database.customInsert(
            '''INSERT INTO meta_store (key, value) VALUES (?, ?)
               ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
            variables: [
              Variable(newKey),
              Variable(values.first.read<String>('value')),
            ],
          );
          await database.customStatement(
            'DELETE FROM meta_store WHERE key = ?',
            [oldKey],
          );
        }
      }

      if (normalizedGoogleName.isNotEmpty) {
        await database.customInsert(
          '''INSERT INTO meta_store (key, value)
             VALUES (?, ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
          variables: [
            Variable('workspace_display_name:$target'),
            Variable(normalizedGoogleName),
          ],
        );
      }
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'adopted_recovery', updated_at = ?
           WHERE local_account_id = ?''',
        variables: [Variable(timestamp), Variable(source)],
      );
      await database.customUpdate(
        '''UPDATE local_accounts
           SET lifecycle_state = 'active', updated_at = ?
           WHERE local_account_id = ?''',
        variables: [Variable(timestamp), Variable(target)],
      );
      await database.customUpdate(
        'UPDATE app_session_state SET active_local_account_id = ?, generation = generation + 1 WHERE id = 1',
        variables: [Variable(target)],
      );
      final profileRows = await database.customSelect(
        'SELECT payload_json FROM account_profiles '
        'WHERE local_account_id = ? LIMIT 1',
        variables: [Variable(target)],
      ).get();
      var onboardingCompleted = false;
      if (profileRows.isNotEmpty) {
        try {
          final payload = jsonDecode(
            profileRows.first.read<String>('payload_json'),
          );
          onboardingCompleted =
              payload is Map && payload['onboardingCompleted'] == true;
        } catch (_) {
          onboardingCompleted = false;
        }
      }
      await database.setOnboardingCompletedInTransaction(onboardingCompleted);
      await database.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'committed', updated_at = ?, error_message = NULL
           WHERE operation_id = ?''',
        variables: [
          Variable(DateTime.now().microsecondsSinceEpoch),
          Variable(operationId)
        ],
      );
      return true;
    }, mutationPredicate: (_) => true);
  }

  /// Records the first verified cloud upload for a completed Guest adoption.
  /// The recovery snapshot remains available for a further 30 days.
  Future<void> markGuestAdoptionBackupVerified(
    String targetGoogleLocalAccountId, {
    DateTime? verifiedAt,
  }) async {
    final target = targetGoogleLocalAccountId.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(
          targetGoogleLocalAccountId, 'targetGoogleLocalAccountId');
    }
    final timestamp = (verifiedAt ?? DateTime.now()).microsecondsSinceEpoch;
    await database.customUpdate(
      '''UPDATE workspace_operation_journal
         SET backup_verified_at = COALESCE(backup_verified_at, ?),
             updated_at = ?
         WHERE operation_type = 'guest_adoption'
           AND target_local_account_id = ?
           AND phase IN ('committed', 'cleaned')''',
      variables: [Variable(timestamp), Variable(timestamp), Variable(target)],
    );
    await purgeExpiredGuestAdoptionSnapshots(now: verifiedAt);
  }

  /// Removes an adoption snapshot only after a verified backup and the full
  /// 30-day recovery window have elapsed. The committed journal stays as an
  /// idempotency record, marked cleaned.
  Future<int> purgeExpiredGuestAdoptionSnapshots({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(days: 30))
        .microsecondsSinceEpoch;
    final rows = await database.customSelect(
      '''SELECT operation_id, snapshot_id
         FROM workspace_operation_journal
         WHERE operation_type = 'guest_adoption'
           AND phase = 'committed'
           AND backup_verified_at IS NOT NULL
           AND backup_verified_at <= ?''',
      variables: [Variable(cutoff)],
    ).get();
    var removed = 0;
    for (final row in rows) {
      final operationId = row.read<String>('operation_id');
      final snapshotId = row.read<String?>('snapshot_id');
      await database.transaction(() async {
        if (snapshotId != null) {
          await database.customStatement(
            'DELETE FROM local_account_adoption_snapshots WHERE snapshot_id = ?',
            [snapshotId],
          );
        }
        await database.customUpdate(
          '''UPDATE workspace_operation_journal
             SET phase = 'cleaned', updated_at = ?
             WHERE operation_id = ? AND phase = 'committed' ''',
          variables: [
            Variable((now ?? DateTime.now()).microsecondsSinceEpoch),
            Variable(operationId),
          ],
        );
      });
      removed++;
    }
    return removed;
  }

  /// Saves a validated remote workspace as a separate, non-active recovery
  /// copy. A deterministic identity makes retries idempotent.
  Future<String> saveCloudRecoveryCopyFromBackup({
    required String phase1BackupJson,
    required String googleAccountId,
    required String remoteBackupId,
    required String remoteVersion,
    String? googleDisplayName,
  }) async {
    final stableGoogleId = googleAccountId.trim();
    final backupId = remoteBackupId.trim();
    if (stableGoogleId.isEmpty || backupId.isEmpty) {
      throw ArgumentError(
          'Verified Google ID and remote backup ID are required.');
    }
    String token(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    final copyId = 'recovery_copy_${token(stableGoogleId)}_${token(backupId)}';
    final validated = _decodeAndValidate(phase1BackupJson);
    final remoteData = Map<String, dynamic>.from(validated['data'] as Map);
    final remoteSession =
        (remoteData['app_session_state'] as List<dynamic>?) ?? const [];
    final remoteAccounts =
        (remoteData['local_accounts'] as List<dynamic>?) ?? const [];
    String? sourceAccountId;
    if (remoteSession.isNotEmpty && remoteSession.first is Map) {
      final value = (remoteSession.first as Map)['active_local_account_id'];
      if (value is String && value.trim().isNotEmpty) {
        sourceAccountId = value;
      }
    }
    if (sourceAccountId == null &&
        remoteAccounts.length == 1 &&
        remoteAccounts.single is Map) {
      final value = (remoteAccounts.single as Map)['local_account_id'];
      if (value is String && value.trim().isNotEmpty) {
        sourceAccountId = value;
      }
    }
    if (sourceAccountId == null ||
        !(sourceAccountId.startsWith('google:') ||
            sourceAccountId.startsWith('google_')) ||
        sourceAccountId.substring(7) != stableGoogleId ||
        !remoteAccounts.any(
          (row) => row is Map && row['local_account_id'] == sourceAccountId,
        )) {
      throw const LocalBackupException(
        'The remote backup could not be tied to the verified Google identity.',
      );
    }

    final existing = await database.customSelect(
      'SELECT lifecycle_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable(copyId)],
    ).get();
    if (existing.isNotEmpty) {
      final marker = await database.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable('recovery_copy_source_backup:$copyId')],
      ).get();
      if (existing.single.read<String>('lifecycle_state') == 'recovery_copy' &&
          marker.isNotEmpty &&
          marker.single.read<String>('value') == backupId) {
        return copyId;
      }
      throw const LocalBackupException(
        'A recovery copy with this identity already exists but could not be verified. '
        'It was left unchanged to protect its data.',
      );
    }

    await importJson(
      phase1BackupJson,
      targetLocalAccountId: copyId,
      expectedGoogleAccountId: stableGoogleId,
      targetWorkspaceLifecycleState: 'recovery_copy',
    );

    final originalName = googleDisplayName?.trim();
    final displayName = originalName == null || originalName.isEmpty
        ? 'Recovery copy — Google account'
        : 'Recovery copy — $originalName';
    await database.customInsert(
      '''INSERT INTO meta_store (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable('workspace_display_name:$copyId'),
        Variable(displayName),
      ],
    );
    await database.customInsert(
      '''INSERT INTO meta_store (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable('recovery_copy_source_backup:$copyId'),
        Variable(backupId),
      ],
    );
    await database.writeWorkspaceSyncState(
      copyId,
      'needs_sign_in',
      localRevision: await database.readWorkspaceRevision(copyId),
      lastSyncedRemoteVersion: remoteVersion,
      conflictMarker: backupId,
      remoteAccountId: stableGoogleId,
    );
    final expectedRecords =
        ((remoteData['qaza_records'] as List<dynamic>?) ?? const <dynamic>[])
            .where((row) => row is Map && row['userId'] == sourceAccountId)
            .length;
    final actualRows = await database.customSelect(
      'SELECT COUNT(*) AS row_count FROM qaza_records WHERE user_id = ?',
      variables: [Variable(copyId)],
    ).get();
    if (actualRows.single.read<int>('row_count') != expectedRecords) {
      throw const LocalBackupException(
        'The recovery copy did not pass row-count verification. '
        'The copy was retained for inspection; the source data and cloud backup were not changed.',
      );
    }
    return copyId;
  }

  Future<LocalBackupAnalysis> analyzeImport(String jsonText) async {
    final decoded = _decodeAndValidate(jsonText);
    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final records = data['qaza_records'] as List<dynamic>;
    final accounts = data['local_accounts'] as List<dynamic>;
    final meta = data['meta_store'] as Map<String, dynamic>;
    return LocalBackupAnalysis(
      dbRevision: metadata['db_revision'] as int,
      recordCount: records.length,
      accountCount: accounts.length,
      onboardingCompleted: meta['is_onboarding_completed'] == true,
    );
  }

  Future<LocalBackupAnalysis> _importSeparateGoogleWorkspace(
    String jsonText,
    AppDatabase targetDatabase,
    String targetLocalAccountId, {
    String? expectedGoogleAccountId,
    String targetWorkspaceLifecycleState = 'active',
  }) async {
    final id = targetLocalAccountId.trim();
    if (id.isEmpty || !id.startsWith('google_')) {
      throw ArgumentError.value(targetLocalAccountId, 'targetLocalAccountId');
    }
    if (targetWorkspaceLifecycleState != 'active' &&
        targetWorkspaceLifecycleState != 'recovery_copy') {
      throw ArgumentError.value(
          targetWorkspaceLifecycleState, 'targetWorkspaceLifecycleState');
    }
    if (targetWorkspaceLifecycleState == 'recovery_copy' &&
        (expectedGoogleAccountId == null ||
            expectedGoogleAccountId.trim().isEmpty)) {
      throw const LocalBackupException(
        'A recovery copy requires a verified Google identity.',
      );
    }

    // Validate identity, schema and every owner field before touching the
    // workspace file. The current scoped snapshot supplies Keep Local rows.
    final remoteRoot = _decodeAndValidate(jsonText);
    final localText = await exportJson(localAccountId: id);
    final localRoot = _decodeAndValidate(localText);
    final mergedRoot = _mergeWorkspaceBackup(
      remoteRoot,
      localRoot,
      id,
      expectedGoogleAccountId: expectedGoogleAccountId,
      targetWorkspaceLifecycleState: targetWorkspaceLifecycleState,
    );
    final validated = _decodeAndValidate(jsonEncode(mergedRoot));
    final data = Map<String, dynamic>.from(validated['data'] as Map);
    final meta = Map<String, dynamic>.from(data['meta_store'] as Map);
    final expectedAccounts = data['local_accounts'] as List<dynamic>;
    if (expectedAccounts.length != 1 ||
        expectedAccounts.single is! Map ||
        (expectedAccounts.single as Map)['local_account_id'] != id) {
      throw const LocalBackupException(
        'The restore payload does not describe exactly the selected Google workspace.',
      );
    }

    final control = _databaseManager?.controlDatabase ?? database;
    final registryRows = await control.customSelect(
      'SELECT db_layout, db_file_name, db_migration_state FROM local_accounts '
      'WHERE local_account_id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (registryRows.isEmpty ||
        registryRows.single.read<String>('db_layout') != 'separate' ||
        registryRows.single.read<String>('db_migration_state') != 'committed') {
      throw const LocalBackupException(
        'The selected Google workspace is not registered as a committed separate database.',
      );
    }

    final payloadHash = sha256.convert(utf8.encode(jsonText)).toString();
    final operationId = 'workspace-restore:$id:$payloadHash';
    final now = DateTime.now().microsecondsSinceEpoch;
    await control.customInsert(
      '''INSERT OR REPLACE INTO workspace_operation_journal
         (operation_id, operation_type, source_local_account_id,
          target_local_account_id, phase, created_at, updated_at,
          snapshot_id, content_hash, error_message)
         VALUES (?, ?, ?, ?, 'prepared', ?, ?, ?, ?, NULL)''',
      variables: [
        Variable<String>(operationId),
        Variable<String>(
          targetWorkspaceLifecycleState == 'recovery_copy'
              ? 'keep_both_import'
              : 'workspace_restore',
        ),
        Variable<String>(id),
        Variable<String>(id),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(targetWorkspaceLifecycleState),
        Variable<String>(payloadHash),
      ],
    );

    var restoredOnboardingCompleted = false;
    final sessionBefore = await control
        .customSelect(
          'SELECT active_local_account_id, generation FROM app_session_state WHERE id = 1 LIMIT 1',
        )
        .get();
    final activeBefore = sessionBefore.isEmpty
        ? null
        : sessionBefore.single.read<String?>('active_local_account_id');
    final generationBefore = sessionBefore.isEmpty
        ? 1
        : sessionBefore.single.read<int>('generation');

    try {
      await targetDatabase.transaction(() async {
        await _clearBusinessState(
          targetDatabase: targetDatabase,
          includeControlTables: false,
        );

        for (final raw in data['qaza_records'] as List<dynamic>) {
          final record =
              QazaRecord.fromJson(Map<String, dynamic>.from(raw as Map));
          await targetDatabase.qazaRecordsDao
              .insertRecord(_recordCompanion(record));
        }
        await _insertMaps(
          'daily_salah_logs',
          [
            'user_id',
            'prayer_date',
            'prayer_type',
            'status',
            'tracker_created_qaza_id',
            'linked_qaza_id',
            'completion_sync_id',
            'updated_at',
          ],
          (data['daily_salah_logs'] as List<dynamic>?) ?? const <dynamic>[],
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'qaza_additions',
          [
            'id',
            'user_id',
            'mode',
            'input_snapshot',
            'revision',
            'created_at',
            'updated_at'
          ],
          data['qaza_additions'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'qaza_deletion_actions',
          [
            'id',
            'user_id',
            'addition_id',
            'created_at',
            'resolved_at',
            'entity_version'
          ],
          data['qaza_deletion_actions'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'qaza_deletion_action_record_snapshots',
          [
            'deletion_action_id',
            'record_id',
            'user_id',
            'addition_id',
            'prayer_type',
            'original_date',
            'status',
            'completed_at',
            'completion_id',
            'created_at',
            'updated_at',
            'record_version',
          ],
          data['qaza_deletion_action_record_snapshots'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'qaza_profile_plan_provenance',
          ['record_id', 'user_id', 'plan_revision_id', 'plan_fingerprint'],
          data['qaza_profile_plan_provenance'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'account_profiles',
          [
            'local_account_id',
            'payload_json',
            'entity_version',
            'updated_at',
            'writer_device_id',
            'operation_id',
          ],
          data['account_profiles'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );
        await _insertMaps(
          'account_plan_revisions',
          ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
          data['account_plan_revisions'] as List<dynamic>,
          targetDatabase: targetDatabase,
        );

        final workspaceNames = meta['workspace_display_names_by_account'];
        if (workspaceNames is Map && workspaceNames[id] is String) {
          final name = (workspaceNames[id] as String).trim();
          if (name.isNotEmpty) {
            await targetDatabase.customInsert(
              '''INSERT INTO meta_store (key, value) VALUES (?, ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
              variables: [
                Variable<String>('workspace_display_name:$id'),
                Variable<String>(name),
              ],
            );
          }
        }

        final enabledByAccount =
            meta['daily_salah_tracking_enabled_by_account'];
        final enabled = enabledByAccount is Map && enabledByAccount[id] is bool
            ? enabledByAccount[id] as bool
            : meta['daily_salah_tracking_enabled'] == true;
        await targetDatabase.setDailySalahTrackingEnabledInTransaction(
          enabled,
          userId: id,
        );

        final dismissedByAccount =
            meta['daily_salah_tracking_setup_dismissed_by_account'];
        final dismissed =
            dismissedByAccount is Map && dismissedByAccount[id] is bool
                ? dismissedByAccount[id] as bool
                : meta['daily_salah_tracking_setup_dismissed'] == true;
        await targetDatabase.setDailySalahTrackingSetupDismissedInTransaction(
          dismissed,
          userId: id,
        );

        final owner = await targetDatabase.readWorkspaceFileOwner();
        if (owner != id) {
          throw const LocalBackupException(
            'Workspace owner verification failed during restore.',
          );
        }
      });

      await control.customUpdate(
        '''UPDATE workspace_operation_journal
           SET phase = 'verified', updated_at = ?, error_message = NULL
           WHERE operation_id = ?''',
        variables: [
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );

      final profileRows = await targetDatabase.customSelect(
        'SELECT payload_json FROM account_profiles WHERE local_account_id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (profileRows.isNotEmpty) {
        try {
          final profile =
              jsonDecode(profileRows.single.read<String>('payload_json'));
          restoredOnboardingCompleted =
              profile is Map && profile['onboardingCompleted'] == true;
        } catch (_) {}
      }
      await control.transaction(() async {
        await control.customUpdate(
          'UPDATE local_accounts SET lifecycle_state = ?, updated_at = ? '
          'WHERE local_account_id = ?',
          variables: [
            Variable<String>(targetWorkspaceLifecycleState),
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(id),
          ],
        );
        final currentSession = await control
            .customSelect(
              'SELECT active_local_account_id, generation FROM app_session_state WHERE id = 1 LIMIT 1',
            )
            .get();
        final activeNow = currentSession.isEmpty
            ? null
            : currentSession.single.read<String?>('active_local_account_id');
        final generationNow = currentSession.isEmpty
            ? 1
            : currentSession.single.read<int>('generation');
        if (activeBefore == id &&
            activeNow == id &&
            generationBefore == generationNow) {
          await control.setOnboardingCompletedInTransaction(
            restoredOnboardingCompleted,
          );
        }
        await control.customUpdate(
          '''UPDATE workspace_operation_journal
             SET phase = 'committed', updated_at = ?, error_message = NULL
             WHERE operation_id = ?''',
          variables: [
            Variable<int>(DateTime.now().microsecondsSinceEpoch),
            Variable<String>(operationId),
          ],
        );
      });
    } catch (error) {
      // Keep the operation nonterminal and leave the recovery snapshot/file
      // intact. A later explicit retry can replay the same validated payload.
      await control.customUpdate(
        '''UPDATE workspace_operation_journal SET error_message = ?, updated_at = ?
           WHERE operation_id = ? AND phase != 'committed' ''',
        variables: [
          Variable<String>(error.toString()),
          Variable<int>(DateTime.now().microsecondsSinceEpoch),
          Variable<String>(operationId),
        ],
      );
      rethrow;
    }

    final restoredRevision = await targetDatabase.readWorkspaceRevision(id);
    return LocalBackupAnalysis(
      dbRevision: restoredRevision,
      recordCount: (data['qaza_records'] as List<dynamic>).length,
      accountCount: 1,
      onboardingCompleted: restoredOnboardingCompleted,
    );
  }

  Future<LocalBackupAnalysis> importJson(
    String jsonText, {
    String? targetLocalAccountId,
    String? expectedGoogleAccountId,
    String targetWorkspaceLifecycleState = 'active',
  }) async {
    final manager = _databaseManager;
    if (manager != null && targetLocalAccountId != null) {
      final target = await manager.databaseForWorkspace(targetLocalAccountId);
      if (target.isGoogleWorkspaceDatabase) {
        return _importSeparateGoogleWorkspace(
          jsonText,
          target,
          targetLocalAccountId,
          expectedGoogleAccountId: expectedGoogleAccountId,
          targetWorkspaceLifecycleState: targetWorkspaceLifecycleState,
        );
      }
    }
    if (targetWorkspaceLifecycleState != 'active' &&
        targetWorkspaceLifecycleState != 'recovery_copy') {
      throw ArgumentError.value(
        targetWorkspaceLifecycleState,
        'targetWorkspaceLifecycleState',
      );
    }
    if (targetWorkspaceLifecycleState == 'recovery_copy' &&
        (expectedGoogleAccountId == null ||
            expectedGoogleAccountId.trim().isEmpty ||
            targetLocalAccountId == null)) {
      throw const LocalBackupException(
        'A recovery copy requires a target workspace and verified Google identity.',
      );
    }
    final preservedWorkspaceRevisions = <String, String>{};
    if (targetLocalAccountId != null) {
      final rows = await database
          .customSelect(
            "SELECT key, value FROM meta_store WHERE key LIKE 'workspace_revision:%'",
          )
          .get();
      for (final row in rows) {
        preservedWorkspaceRevisions[row.read<String>('key')] =
            row.read<String>('value');
      }
    }
    var decoded = _decodeAndValidate(jsonText);
    if (targetLocalAccountId != null) {
      final localDocument = jsonDecode(await exportJson());
      if (localDocument is! Map) {
        throw const LocalBackupException(
          'The current local database could not be prepared for a safe restore.',
        );
      }
      final localDecoded = _decodeAndValidate(jsonEncode(localDocument));
      decoded = _mergeWorkspaceBackup(
        decoded,
        localDecoded,
        targetLocalAccountId,
        expectedGoogleAccountId: expectedGoogleAccountId,
        targetWorkspaceLifecycleState: targetWorkspaceLifecycleState,
      );
    }

    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final backupRevision = metadata['db_revision'] as int;
    final sessionGenerationBeforeImport =
        await database.readSessionGeneration();

    await database.transaction(() async {
      // Read and advance the authoritative local revision under the same
      // transaction that replaces the database contents.
      final currentRevision = await database.readDbRevision();
      final newRevision = (currentRevision > backupRevision
              ? currentRevision
              : backupRevision) +
          1;

      await _clearBusinessState();

      for (final raw in data['qaza_records'] as List<dynamic>) {
        final map = Map<String, dynamic>.from(raw as Map);
        final record = QazaRecord.fromJson(map);
        await database.qazaRecordsDao.insertRecord(_recordCompanion(record));
      }

      // Older backups omit the table; new backups preserve daily tracking
      // history independently from the canonical Qaza ledger.
      await _insertMaps(
        'daily_salah_logs',
        [
          'user_id',
          'prayer_date',
          'prayer_type',
          'status',
          'tracker_created_qaza_id',
          'linked_qaza_id',
          'completion_sync_id',
          'updated_at',
        ],
        (data['daily_salah_logs'] as List<dynamic>?) ?? const <dynamic>[],
      );

      await _insertMaps(
        'qaza_additions',
        [
          'id',
          'user_id',
          'mode',
          'input_snapshot',
          'revision',
          'created_at',
          'updated_at',
        ],
        data['qaza_additions'] as List<dynamic>,
      );
      await _insertMaps(
        'qaza_deletion_actions',
        [
          'id',
          'user_id',
          'addition_id',
          'created_at',
          'resolved_at',
          'entity_version',
        ],
        data['qaza_deletion_actions'] as List<dynamic>,
      );
      await _insertMaps(
        'qaza_deletion_action_record_snapshots',
        [
          'deletion_action_id',
          'record_id',
          'user_id',
          'addition_id',
          'prayer_type',
          'original_date',
          'status',
          'completed_at',
          'completion_id',
          'created_at',
          'updated_at',
          'record_version',
        ],
        data['qaza_deletion_action_record_snapshots'] as List<dynamic>,
      );
      await _insertMaps(
        'qaza_profile_plan_provenance',
        ['record_id', 'user_id', 'plan_revision_id', 'plan_fingerprint'],
        data['qaza_profile_plan_provenance'] as List<dynamic>,
      );
      await _insertMaps(
        'local_accounts',
        [
          'local_account_id',
          'account_mode',
          'lifecycle_state',
          'created_at',
          'updated_at',
        ],
        data['local_accounts'] as List<dynamic>,
      );
      final importedSessionRows =
          (data['app_session_state'] as List<dynamic>).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['generation'] = sessionGenerationBeforeImport + 1;
        return row;
      }).toList(growable: false);
      await _insertMaps(
        'app_session_state',
        ['id', 'active_local_account_id', 'generation'],
        importedSessionRows,
      );
      await _insertMaps(
        'account_profiles',
        [
          'local_account_id',
          'payload_json',
          'entity_version',
          'updated_at',
          'writer_device_id',
          'operation_id',
        ],
        data['account_profiles'] as List<dynamic>,
      );
      await _insertMaps(
        'account_plan_revisions',
        ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
        data['account_plan_revisions'] as List<dynamic>,
      );

      final meta = Map<String, dynamic>.from(data['meta_store'] as Map);
      final workspaceNames = meta['workspace_display_names_by_account'];
      if (workspaceNames is Map) {
        for (final entry in workspaceNames.entries) {
          if (entry.key is! String || entry.value is! String) continue;
          final accountId = (entry.key as String).trim();
          final displayName = (entry.value as String).trim();
          if (accountId.isEmpty || displayName.isEmpty) continue;
          await database.customInsert(
            '''INSERT INTO meta_store (key, value)
               VALUES (?, ?)
               ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
            variables: [
              Variable('workspace_display_name:$accountId'),
              Variable(displayName),
            ],
          );
        }
      }

      await database.setOnboardingCompletedInTransaction(
        meta['is_onboarding_completed'] == true,
      );

      final sessionRows =
          data['app_session_state'] as List<dynamic>? ?? const <dynamic>[];
      final activeUserId = sessionRows.isEmpty
          ? 'guest'
          : ((sessionRows.first as Map)['active_local_account_id'] as String? ??
              'guest');
      final enabledByAccount = meta['daily_salah_tracking_enabled_by_account'];
      if (enabledByAccount is Map) {
        for (final entry in enabledByAccount.entries) {
          if (entry.key is String && entry.value is bool) {
            await database.setDailySalahTrackingEnabledInTransaction(
              entry.value as bool,
              userId: entry.key as String,
            );
          }
        }
        if (!enabledByAccount.containsKey(activeUserId)) {
          await database.setDailySalahTrackingEnabledInTransaction(
            meta['daily_salah_tracking_enabled'] == true,
            userId: activeUserId,
          );
        }
      } else {
        await database.setDailySalahTrackingEnabledInTransaction(
          meta['daily_salah_tracking_enabled'] == true,
          userId: activeUserId,
        );
      }

      final dismissedByAccount =
          meta['daily_salah_tracking_setup_dismissed_by_account'];
      if (dismissedByAccount is Map) {
        for (final entry in dismissedByAccount.entries) {
          if (entry.key is String && entry.value is bool) {
            await database.setDailySalahTrackingSetupDismissedInTransaction(
              entry.value as bool,
              userId: entry.key as String,
            );
          }
        }
        if (!dismissedByAccount.containsKey(activeUserId)) {
          await database.setDailySalahTrackingSetupDismissedInTransaction(
            meta['daily_salah_tracking_setup_dismissed'] == true,
            userId: activeUserId,
          );
        }
      } else {
        await database.setDailySalahTrackingSetupDismissedInTransaction(
          meta['daily_salah_tracking_setup_dismissed'] == true,
          userId: activeUserId,
        );
      }
      // Import reconstructs the shared database from a merged payload.
      // Restore revisions for every untouched workspace; otherwise their
      // rows would appear dirty merely because the shared tables were rebuilt.
      if (targetLocalAccountId != null) {
        for (final entry in preservedWorkspaceRevisions.entries) {
          if (entry.key == 'workspace_revision:$targetLocalAccountId') {
            continue;
          }
          await database.customInsert(
            '''INSERT INTO meta_store (key, value) VALUES (?, ?)
               ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
            variables: [
              Variable(entry.key),
              Variable(entry.value),
            ],
          );
        }
      }
      await database.setDbRevisionInTransaction(newRevision);
    });

    final restoredRevision = await database.readDbRevision();
    final meta = data['meta_store'] as Map<String, dynamic>;
    return LocalBackupAnalysis(
      dbRevision: restoredRevision,
      recordCount: (data['qaza_records'] as List<dynamic>).length,
      accountCount: (data['local_accounts'] as List<dynamic>).length,
      onboardingCompleted: meta['is_onboarding_completed'] == true,
    );
  }

  void _filterOwnedRows(
    Map<String, dynamic> data,
    String table,
    String ownerColumn,
    String ownerId,
  ) {
    final rows = (data[table] as List<dynamic>?) ?? const <dynamic>[];
    data[table] = rows
        .where((raw) => raw is Map && raw[ownerColumn] == ownerId)
        .toList(growable: false);
  }

  Map<String, dynamic> _mergeWorkspaceBackup(
    Map<String, dynamic> remoteRoot,
    Map<String, dynamic> localRoot,
    String targetLocalAccountId, {
    String? expectedGoogleAccountId,
    String targetWorkspaceLifecycleState = 'active',
  }) {
    final suppliedTarget = targetLocalAccountId.trim();
    if (suppliedTarget.isEmpty) {
      throw ArgumentError.value(targetLocalAccountId, 'targetLocalAccountId');
    }

    final remoteData = Map<String, dynamic>.from(remoteRoot['data'] as Map);
    final localData = Map<String, dynamic>.from(localRoot['data'] as Map);

    // A Google workspace ID may be supplied in either its legacy
    // 'google:<id>' form or its canonical 'google_<id>' form. Every
    // comparison and row rewrite below matches against the ID exactly as
    // stored locally, so resolve the supplied form to the stored form
    // when the workspace already exists in the local document. A target
    // with no local workspace yet uses the canonical form, which is how
    // new workspaces are created.
    var target = suppliedTarget.startsWith('google:')
        ? googleLocalWorkspaceId(suppliedTarget.substring('google:'.length))
        : suppliedTarget;
    final equivalentTargets = <String>{suppliedTarget};
    if (suppliedTarget.startsWith('google:')) {
      equivalentTargets
          .add(googleLocalWorkspaceId(suppliedTarget.substring(7)));
    } else if (suppliedTarget.startsWith('google_')) {
      equivalentTargets.add('google:${suppliedTarget.substring(7)}');
    }
    if (equivalentTargets.length > 1) {
      final localAccounts =
          (localData['local_accounts'] as List<dynamic>?) ?? const [];
      for (final raw in localAccounts) {
        if (raw is! Map) continue;
        final storedId = raw['local_account_id'];
        if (storedId is String && equivalentTargets.contains(storedId)) {
          target = storedId;
          break;
        }
      }
    }
    final remoteSession =
        (remoteData['app_session_state'] as List<dynamic>?) ?? const [];
    final remoteAccounts =
        (remoteData['local_accounts'] as List<dynamic>?) ?? const [];
    String? sourceAccountId;
    if (remoteSession.isNotEmpty && remoteSession.first is Map) {
      final value = (remoteSession.first as Map)['active_local_account_id'];
      if (value is String && value.trim().isNotEmpty) {
        sourceAccountId = value;
      }
    }
    if (sourceAccountId == null &&
        remoteAccounts.length == 1 &&
        remoteAccounts.single is Map) {
      final value = (remoteAccounts.single as Map)['local_account_id'];
      if (value is String && value.trim().isNotEmpty) {
        sourceAccountId = value;
      }
    }
    if (sourceAccountId == null ||
        !remoteAccounts.any(
          (row) => row is Map && row['local_account_id'] == sourceAccountId,
        )) {
      throw const LocalBackupException(
        'The cloud backup does not identify a single workspace to restore.',
      );
    }

    String? googleIdentityFromWorkspaceId(String workspaceId) {
      if (workspaceId.startsWith('google:') ||
          workspaceId.startsWith('google_')) {
        return workspaceId.substring(7);
      }
      return null;
    }

    final sourceGoogleIdentity = googleIdentityFromWorkspaceId(sourceAccountId);
    final targetGoogleIdentity = googleIdentityFromWorkspaceId(target);
    if (expectedGoogleAccountId != null) {
      if (sourceGoogleIdentity != expectedGoogleAccountId.trim()) {
        throw const LocalBackupException(
          'This backup does not belong to the verified Google account. Local data was not changed.',
        );
      }
    } else if (sourceGoogleIdentity != null &&
        sourceGoogleIdentity != targetGoogleIdentity) {
      throw const LocalBackupException(
        'This backup belongs to a different Google account. Local data was not changed.',
      );
    }
    final remapRecoveryCopyIds =
        targetWorkspaceLifecycleState == 'recovery_copy';

    // Before account-scoped backups, Qaza primary keys included the owning
    // workspace prefix. When adopting a legacy Guest backup into Google,
    // rewrite those IDs as well as every stored reference to them.
    final sourceWorkspaceId = sourceAccountId!;
    final remapLegacyGuestRecordIds =
        isGuestLocalWorkspaceId(sourceWorkspaceId) &&
            !isGuestLocalWorkspaceId(target);

    Object? remapQazaRecordId(Object? value) {
      if (remapRecoveryCopyIds && value is String && value.isNotEmpty) {
        return '${target}_$value';
      }
      if (!remapLegacyGuestRecordIds || value is! String) {
        return value;
      }
      // Record IDs may be prefixed by the source workspace. Strip that exact
      // prefix so UUID-based Guest workspaces are adopted without cross-ID
      // collisions or rewriting unrelated IDs.
      final sourcePrefix = '${sourceWorkspaceId}_';
      if (!value.startsWith(sourcePrefix)) return value;
      return '$target${value.substring(sourceWorkspaceId.length)}';
    }

    Object? remapQazaAdditionId(Object? value) {
      if (remapRecoveryCopyIds && value is String && value.isNotEmpty) {
        return '${target}_$value';
      }
      if (!remapLegacyGuestRecordIds || value is! String || value.isEmpty) {
        return value;
      }
      return '${target}_$value';
    }

    Object? remapDeletionActionId(Object? value) {
      if (remapRecoveryCopyIds && value is String && value.isNotEmpty) {
        return '${target}_$value';
      }
      if (!remapLegacyGuestRecordIds || value is! String || value.isEmpty) {
        return value;
      }
      return '${target}_$value';
    }

    Map<String, dynamic> remapRevisionPayload(Map<String, dynamic> row) {
      if ((!remapLegacyGuestRecordIds && !remapRecoveryCopyIds) ||
          row['payload_json'] is! String) {
        return row;
      }
      try {
        final decoded = jsonDecode(row['payload_json'] as String);
        if (decoded is Map) {
          final payload = Map<String, dynamic>.from(decoded);
          if (payload['userId'] == sourceAccountId) {
            payload['userId'] = target;
          }
          if (payload['user_id'] == sourceAccountId) {
            payload['user_id'] = target;
          }
          row['payload_json'] = jsonEncode(payload);
        }
      } catch (_) {
        // Validation below will reject malformed revision payloads.
      }
      return row;
    }

    List<Map<String, dynamic>> remoteOwned(
      String table,
      String ownerColumn,
    ) {
      final rows = (remoteData[table] as List<dynamic>?) ?? const <dynamic>[];
      return rows
          .where((raw) => raw is Map && raw[ownerColumn] == sourceAccountId)
          .map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        row[ownerColumn] = target;
        if (remapLegacyGuestRecordIds || remapRecoveryCopyIds) {
          switch (table) {
            case 'qaza_records':
              row['id'] = remapQazaRecordId(row['id']);
              row['additionId'] = remapQazaAdditionId(row['additionId']);
              break;
            case 'qaza_additions':
              row['id'] = remapQazaAdditionId(row['id']);
              break;
            case 'qaza_deletion_actions':
              row['id'] = remapDeletionActionId(row['id']);
              row['addition_id'] = remapQazaAdditionId(row['addition_id']);
              break;
            case 'qaza_profile_plan_provenance':
              row['record_id'] = remapQazaRecordId(row['record_id']);
              break;
            case 'qaza_deletion_action_record_snapshots':
              row['record_id'] = remapQazaRecordId(row['record_id']);
              row['deletion_action_id'] =
                  remapDeletionActionId(row['deletion_action_id']);
              row['addition_id'] = remapQazaAdditionId(row['addition_id']);
              break;
            case 'daily_salah_logs':
              row['tracker_created_qaza_id'] =
                  remapQazaRecordId(row['tracker_created_qaza_id']);
              row['linked_qaza_id'] = remapQazaRecordId(row['linked_qaza_id']);
              break;
            case 'account_profiles':
            case 'account_plan_revisions':
              remapRevisionPayload(row);
              break;
          }
        }
        return row;
      }).toList(growable: false);
    }

    List<Map<String, dynamic>> localOthers(
      String table,
      String ownerColumn,
    ) {
      final rows = (localData[table] as List<dynamic>?) ?? const <dynamic>[];
      return rows
          .where((raw) => raw is Map && raw[ownerColumn] != target)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList(growable: false);
    }

    final mergedData = Map<String, dynamic>.from(localData);
    const userOwnedTables = <(String, String)>[
      ('qaza_records', 'userId'),
      ('daily_salah_logs', 'user_id'),
      ('qaza_additions', 'user_id'),
      ('qaza_deletion_actions', 'user_id'),
      ('qaza_deletion_action_record_snapshots', 'user_id'),
      ('qaza_profile_plan_provenance', 'user_id'),
    ];
    for (final (table, ownerColumn) in userOwnedTables) {
      mergedData[table] = <Map<String, dynamic>>[
        ...localOthers(table, ownerColumn),
        ...remoteOwned(table, ownerColumn),
      ];
    }

    mergedData['local_accounts'] = <Map<String, dynamic>>[
      ...localOthers('local_accounts', 'local_account_id'),
      ...remoteOwned('local_accounts', 'local_account_id').map((row) {
        row['account_mode'] = 'local';
        row['lifecycle_state'] = targetWorkspaceLifecycleState;
        return row;
      }),
    ];
    mergedData['account_profiles'] = <Map<String, dynamic>>[
      ...localOthers('account_profiles', 'local_account_id'),
      ...remoteOwned('account_profiles', 'local_account_id'),
    ];
    mergedData['account_plan_revisions'] = <Map<String, dynamic>>[
      ...localOthers('account_plan_revisions', 'local_account_id'),
      ...remoteOwned('account_plan_revisions', 'local_account_id'),
    ];

    // Keep the device's active session and global preferences unchanged. A
    // background sync must not redirect the foreground UI to another account.
    final localSession = (localData['app_session_state'] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    mergedData['app_session_state'] = localSession;

    // The import must not change which workspace is active, but its durable
    // onboarding flag must agree with the profile for that active workspace.
    // Otherwise restoring a completed Google profile into a fresh workspace
    // leaves the app routed through onboarding and causes a stale-screen flash.
    final activeLocalAccountId = localSession.isEmpty
        ? null
        : localSession.first['active_local_account_id'] as String?;
    var activeOnboardingCompleted = false;
    if (activeLocalAccountId != null) {
      final profiles = mergedData['account_profiles'] as List<dynamic>;
      for (final raw in profiles) {
        if (raw is! Map || raw['local_account_id'] != activeLocalAccountId) {
          continue;
        }
        final payload = raw['payload_json'];
        if (payload is String) {
          try {
            final decodedProfile = jsonDecode(payload);
            activeOnboardingCompleted = decodedProfile is Map &&
                decodedProfile['onboardingCompleted'] == true;
          } catch (_) {
            activeOnboardingCompleted = false;
          }
        }
        break;
      }
    }
    final mergedMeta =
        Map<String, dynamic>.from(localData['meta_store'] as Map);
    mergedMeta['is_onboarding_completed'] = activeOnboardingCompleted;

    final localNames = Map<String, dynamic>.from(
      mergedMeta['workspace_display_names_by_account'] as Map? ??
          const <String, dynamic>{},
    );
    final remoteNamesRaw = (remoteData['meta_store']
        as Map?)?['workspace_display_names_by_account'];
    final remoteNames = remoteNamesRaw is Map
        ? Map<String, dynamic>.from(remoteNamesRaw)
        : const <String, dynamic>{};
    if (sourceAccountId == target && target.startsWith('google:')) {
      final remoteName = remoteNames[target];
      if (remoteName is String && remoteName.trim().isNotEmpty) {
        localNames[target] = remoteName.trim();
      }
    }
    mergedMeta['workspace_display_names_by_account'] = localNames;

    // Tracking preferences belong to a workspace because the daily logs do.
    // Keep device preferences (prayer cache, Hijri offset, Home targeting)
    // unchanged, while adopting legacy scalar values for this target workspace.
    final remoteMeta = remoteData['meta_store'];
    if (activeLocalAccountId == target && remoteMeta is Map) {
      final remoteEnabledByAccount =
          remoteMeta['daily_salah_tracking_enabled_by_account'];
      final remoteEnabled = remoteEnabledByAccount is Map &&
              remoteEnabledByAccount[sourceAccountId] is bool
          ? remoteEnabledByAccount[sourceAccountId] as bool
          : remoteMeta['daily_salah_tracking_enabled'] is bool
              ? remoteMeta['daily_salah_tracking_enabled'] as bool
              : null;
      if (remoteEnabled != null) {
        mergedMeta['daily_salah_tracking_enabled'] = remoteEnabled;
        final enabledByAccount = Map<String, dynamic>.from(
          mergedMeta['daily_salah_tracking_enabled_by_account'] as Map? ??
              const <String, dynamic>{},
        );
        enabledByAccount[target] = remoteEnabled;
        mergedMeta['daily_salah_tracking_enabled_by_account'] =
            enabledByAccount;
      }

      final remoteDismissedByAccount =
          remoteMeta['daily_salah_tracking_setup_dismissed_by_account'];
      final remoteDismissed = remoteDismissedByAccount is Map &&
              remoteDismissedByAccount[sourceAccountId] is bool
          ? remoteDismissedByAccount[sourceAccountId] as bool
          : remoteMeta['daily_salah_tracking_setup_dismissed'] is bool
              ? remoteMeta['daily_salah_tracking_setup_dismissed'] as bool
              : null;
      if (remoteDismissed != null) {
        mergedMeta['daily_salah_tracking_setup_dismissed'] = remoteDismissed;
        final dismissedByAccount = Map<String, dynamic>.from(
          mergedMeta['daily_salah_tracking_setup_dismissed_by_account']
                  as Map? ??
              const <String, dynamic>{},
        );
        dismissedByAccount[target] = remoteDismissed;
        mergedMeta['daily_salah_tracking_setup_dismissed_by_account'] =
            dismissedByAccount;
      }
    }
    mergedData['meta_store'] = mergedMeta;

    final metadata = Map<String, dynamic>.from(remoteRoot['metadata'] as Map);
    final localMetadata =
        Map<String, dynamic>.from(localRoot['metadata'] as Map);
    final remoteRevision = metadata['db_revision'] as int;
    final localRevision = localMetadata['db_revision'] as int;
    metadata['db_revision'] =
        remoteRevision > localRevision ? remoteRevision : localRevision;

    final mergedRoot = <String, dynamic>{
      'metadata': metadata,
      'data': mergedData,
    };
    // Validate cross-table references before the transactional import clears
    // any rows. Any failure leaves the local database unchanged.
    return _decodeAndValidate(jsonEncode(mergedRoot));
  }

  Map<String, dynamic> _decodeAndValidate(String jsonText) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const LocalBackupException('The selected file is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const LocalBackupException('Backup root must be a JSON object.');
    }

    final root = Map<String, dynamic>.from(decoded);
    final metadata = root['metadata'];
    final data = root['data'];
    if (metadata is! Map || data is! Map) {
      throw const LocalBackupException(
        'Backup metadata or data section is missing.',
      );
    }

    final header = Map<String, dynamic>.from(metadata);
    if (header['app_id'] != _appId) {
      throw const LocalBackupException('This file is not a Qaza Namaz backup.');
    }

    final schema = header['backup_schema_version'];
    if (schema is! int || schema < 1) {
      throw const LocalBackupException('Backup schema version is invalid.');
    }
    if (schema > _backupSchemaVersion) {
      throw const LocalBackupException(
        'This backup was created by a newer app version. App update required.',
      );
    }
    if (schema < _backupSchemaVersion) {
      throw LocalBackupException(
        'Backup schema version $schema is not supported by this release.',
      );
    }

    final revision = header['db_revision'];
    if (revision is! int || revision < 1) {
      throw const LocalBackupException('Backup database revision is invalid.');
    }

    final databaseSchema = header['database_schema_version'];
    if (databaseSchema is! int || databaseSchema < 1) {
      throw const LocalBackupException(
        'Backup database schema version is invalid.',
      );
    }
    // Schemas 19–21 are supported predecessors of schema 22. Older
    // payloads are normalized below, including missing Daily Salah rows and
    // the link/completion-sync fields introduced after schema 20.
    // Schema 26 adds control-registry routing columns only. Schema-25 backup
    // payloads retain the same logical data shape and are safe to import.
    final compatibleLegacySchema =
        (databaseSchema >= 19 && databaseSchema <= 21) || databaseSchema == 25;
    if (databaseSchema > database.schemaVersion) {
      throw LocalBackupException(
        'This backup uses newer database schema $databaseSchema. '
        'Update Qaza Namaz to restore it '
        '(current schema: ${database.schemaVersion}).',
      );
    }
    if (databaseSchema != database.schemaVersion && !compatibleLegacySchema) {
      throw LocalBackupException(
        'Backup database schema $databaseSchema has no safe migration path '
        'in this release (current schema: ${database.schemaVersion}).',
      );
    }

    final timestamp = header['export_timestamp'];
    if (timestamp is! String || DateTime.tryParse(timestamp)?.isUtc != true) {
      throw const LocalBackupException(
        'Backup export timestamp must be a valid UTC timestamp.',
      );
    }

    final payload = Map<String, dynamic>.from(data);
    const requiredLists = [
      'qaza_records',
      'qaza_additions',
      'qaza_deletion_actions',
      'qaza_deletion_action_record_snapshots',
      'qaza_profile_plan_provenance',
      'local_accounts',
      'app_session_state',
      'account_profiles',
      'account_plan_revisions',
    ];

    for (final key in requiredLists) {
      final value = payload[key];
      if (value is! List<dynamic>) {
        throw LocalBackupException('Backup data section is missing "$key".');
      }
      for (var index = 0; index < value.length; index++) {
        if (value[index] is! Map) {
          throw LocalBackupException(
            'Backup data section "$key" row ${index + 1} is not an object.',
          );
        }
      }
    }

    String? requiredString(
      Map<dynamic, dynamic> row,
      String table,
      int index,
      String field, {
      bool nullable = false,
    }) {
      final value = row[field];
      if (value == null && nullable) return null;
      if (value is! String || value.trim().isEmpty) {
        throw LocalBackupException(
          'Backup table "$table" row ${index + 1} has an invalid $field.',
        );
      }
      return value;
    }

    int requiredInt(
      Map<dynamic, dynamic> row,
      String table,
      int index,
      String field,
    ) {
      final value = row[field];
      if (value is! int) {
        throw LocalBackupException(
          'Backup table "$table" row ${index + 1} has an invalid $field.',
        );
      }
      return value;
    }

    final rawDailySalahLogs = payload['daily_salah_logs'];
    if (databaseSchema >= 20 && rawDailySalahLogs is! List) {
      throw const LocalBackupException(
        'Backup data section is missing or invalid "daily_salah_logs".',
      );
    }
    if (rawDailySalahLogs != null && rawDailySalahLogs is! List) {
      throw const LocalBackupException(
        'Backup data section "daily_salah_logs" must be a list.',
      );
    }
    if (rawDailySalahLogs is List) {
      const validPrayerTypes = {
        'fajr',
        'zuhr',
        'asr',
        'maghrib',
        'isha',
        'witr',
      };
      const validStatuses = {'prayed', 'missed', 'unrecorded'};
      for (var index = 0; index < rawDailySalahLogs.length; index++) {
        final raw = rawDailySalahLogs[index];
        if (raw is! Map) {
          throw LocalBackupException(
            'Backup daily Salah row ${index + 1} is not an object.',
          );
        }
        requiredString(raw, 'daily_salah_logs', index, 'user_id');
        requiredString(raw, 'daily_salah_logs', index, 'prayer_date');
        requiredString(raw, 'daily_salah_logs', index, 'prayer_type');
        requiredString(raw, 'daily_salah_logs', index, 'status');
        requiredString(raw, 'daily_salah_logs', index, 'updated_at');
        if (!raw.containsKey('tracker_created_qaza_id')) {
          throw LocalBackupException(
            'Backup daily Salah row ${index + 1} is missing '
            '"tracker_created_qaza_id".',
          );
        }
        requiredString(
          raw,
          'daily_salah_logs',
          index,
          'tracker_created_qaza_id',
          nullable: true,
        );
        for (final field in ['linked_qaza_id', 'completion_sync_id']) {
          if (raw.containsKey(field)) {
            requiredString(
              raw,
              'daily_salah_logs',
              index,
              field,
              nullable: true,
            );
          }
        }
        if (!validPrayerTypes.contains(raw['prayer_type'])) {
          throw LocalBackupException(
            'Backup daily Salah row ${index + 1} has an invalid prayer_type.',
          );
        }
        if (!validStatuses.contains(raw['status'])) {
          throw LocalBackupException(
            'Backup daily Salah row ${index + 1} has an invalid status.',
          );
        }
        if (DateTime.tryParse(raw['prayer_date'] as String) == null ||
            DateTime.tryParse(raw['updated_at'] as String) == null) {
          throw LocalBackupException(
            'Backup daily Salah row ${index + 1} has an invalid date.',
          );
        }
      }
    }

    void validateRows(
      String table, {
      required List<String> strings,
      List<String> nullableStrings = const [],
      required List<String> ints,
    }) {
      final rows = payload[table] as List<dynamic>;
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index] as Map;
        for (final field in strings) {
          requiredString(row, table, index, field);
        }
        for (final field in nullableStrings) {
          requiredString(row, table, index, field, nullable: true);
        }
        for (final field in ints) {
          requiredInt(row, table, index, field);
        }
      }
    }

    validateRows(
      'qaza_additions',
      strings: [
        'id',
        'user_id',
        'mode',
        'input_snapshot',
        'created_at',
        'updated_at',
      ],
      ints: ['revision'],
    );
    validateRows(
      'qaza_deletion_actions',
      strings: ['id', 'user_id', 'addition_id', 'created_at'],
      nullableStrings: ['resolved_at'],
      ints: ['entity_version'],
    );
    validateRows(
      'qaza_deletion_action_record_snapshots',
      strings: [
        'deletion_action_id',
        'record_id',
        'user_id',
        'addition_id',
        'prayer_type',
        'original_date',
        'status',
        'created_at',
        'updated_at',
      ],
      nullableStrings: ['completed_at', 'completion_id'],
      ints: ['record_version'],
    );
    validateRows(
      'qaza_profile_plan_provenance',
      strings: [
        'record_id',
        'user_id',
        'plan_revision_id',
        'plan_fingerprint',
      ],
      ints: const [],
    );
    validateRows(
      'local_accounts',
      strings: ['local_account_id', 'account_mode', 'lifecycle_state'],
      ints: ['created_at', 'updated_at'],
    );
    validateRows(
      'app_session_state',
      strings: const [],
      nullableStrings: ['active_local_account_id'],
      ints: ['id'],
    );
    validateRows(
      'account_profiles',
      strings: [
        'local_account_id',
        'payload_json',
        'writer_device_id',
        'operation_id',
      ],
      ints: ['entity_version', 'updated_at'],
    );
    validateRows(
      'account_plan_revisions',
      strings: ['local_account_id', 'revision_id', 'payload_json'],
      ints: ['created_at'],
    );
    for (final row in payload['qaza_additions'] as List<dynamic>) {
      final map = row as Map;
      if ((map['revision'] as int) < 1) {
        throw const LocalBackupException(
          'Backup contains an invalid qaza_additions revision.',
        );
      }
      try {
        if (jsonDecode(map['input_snapshot'] as String) is! Map) {
          throw const LocalBackupException(
            'A Qaza addition input_snapshot must be a JSON object.',
          );
        }
      } catch (error) {
        if (error is LocalBackupException) rethrow;
        throw const LocalBackupException(
          'A Qaza addition input_snapshot is not valid JSON.',
        );
      }
    }
    for (final row in payload['qaza_deletion_actions'] as List<dynamic>) {
      if (((row as Map)['entity_version'] as int) < 1) {
        throw const LocalBackupException(
          'Backup contains an invalid qaza_deletion_actions entity_version.',
        );
      }
    }
    for (final row
        in payload['qaza_deletion_action_record_snapshots'] as List<dynamic>) {
      final map = row as Map;
      if ((map['record_version'] as int) < 1) {
        throw const LocalBackupException(
          'Backup contains an invalid deletion snapshot record_version.',
        );
      }
    }
    for (final row in payload['local_accounts'] as List<dynamic>) {
      final map = row as Map;
      if (map['account_mode'] != 'local') {
        throw const LocalBackupException(
          'Backup contains an invalid local account mode.',
        );
      }
      if (!const <String>{
        'active',
        'archived',
        'migrating',
        'draft',
        'adopting',
        'restoring',
        'adopted_recovery',
        'recovery_copy',
        'deleted_hold',
      }.contains(map['lifecycle_state'])) {
        throw const LocalBackupException(
          'Backup contains an invalid local account lifecycle state.',
        );
      }
    }

    final rawRecords = payload['qaza_records'] as List<dynamic>;
    final recordIds = <String>{};
    final recordKeys = <String>{};
    for (var index = 0; index < rawRecords.length; index++) {
      final raw = rawRecords[index] as Map;
      try {
        final record = QazaRecord.fromJson(Map<String, dynamic>.from(raw));
        if (!recordIds.add(record.id)) {
          throw LocalBackupException(
            'Duplicate Qaza record ID in backup: ${record.id}.',
          );
        }
        final key = '${record.userId}|${record.prayerType.name}|'
            '${record.originalDate.year.toString().padLeft(4, '0')}-'
            '${record.originalDate.month.toString().padLeft(2, '0')}-'
            '${record.originalDate.day.toString().padLeft(2, '0')}';
        if (!recordKeys.add(key)) {
          throw LocalBackupException(
            'Duplicate Qaza prayer/date combination in backup: $key.',
          );
        }
        if (record.recordVersion < 1) {
          throw LocalBackupException(
            'Qaza record ${record.id} has an invalid recordVersion.',
          );
        }
      } catch (error) {
        if (error is LocalBackupException) rethrow;
        throw LocalBackupException(
          'Backup contains an invalid Qaza record at row ${index + 1}: $error',
        );
      }
    }

    final accountRows = payload['local_accounts'] as List<dynamic>;
    final accountIds = <String>{};
    for (var index = 0; index < accountRows.length; index++) {
      final row = accountRows[index] as Map;
      final id = requiredString(
        row,
        'local_accounts',
        index,
        'local_account_id',
      )!;
      if (!accountIds.add(id)) {
        throw LocalBackupException(
          'Duplicate local_accounts local_account_id in backup: $id.',
        );
      }
    }

    final additionRows = payload['qaza_additions'] as List<dynamic>;
    final additionIds = <String>{};
    for (var index = 0; index < additionRows.length; index++) {
      final id = requiredString(
        additionRows[index] as Map,
        'qaza_additions',
        index,
        'id',
      )!;
      if (!additionIds.add(id)) {
        throw LocalBackupException(
            'Duplicate qaza_additions ID in backup: $id.');
      }
    }

    final actionRows = payload['qaza_deletion_actions'] as List<dynamic>;
    final actionIds = <String>{};
    for (var index = 0; index < actionRows.length; index++) {
      final row = actionRows[index] as Map;
      final id = requiredString(row, 'qaza_deletion_actions', index, 'id')!;
      if (!actionIds.add(id)) {
        throw LocalBackupException(
          'Duplicate qaza_deletion_actions ID in backup: $id.',
        );
      }
    }

    final provenanceRows =
        payload['qaza_profile_plan_provenance'] as List<dynamic>;
    final provenanceIds = <String>{};
    for (var index = 0; index < provenanceRows.length; index++) {
      final row = provenanceRows[index] as Map;
      final id = requiredString(
        row,
        'qaza_profile_plan_provenance',
        index,
        'record_id',
      )!;
      if (!provenanceIds.add(id)) {
        throw LocalBackupException(
          'Duplicate qaza_profile_plan_provenance record_id in backup: $id.',
        );
      }
    }

    final snapshotRows =
        payload['qaza_deletion_action_record_snapshots'] as List<dynamic>;
    final snapshotKeys = <String>{};
    for (var index = 0; index < snapshotRows.length; index++) {
      final row = snapshotRows[index] as Map;
      final actionId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'deletion_action_id',
      )!;
      final recordId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'record_id',
      )!;
      if (!snapshotKeys.add('$actionId|$recordId')) {
        throw LocalBackupException(
          'Duplicate deletion snapshot key in backup: $actionId|$recordId.',
        );
      }
    }

    final profileRows = payload['account_profiles'] as List<dynamic>;
    final profileIds = <String>{};
    for (var index = 0; index < profileRows.length; index++) {
      final id = requiredString(
        profileRows[index] as Map,
        'account_profiles',
        index,
        'local_account_id',
      )!;
      if (!profileIds.add(id)) {
        throw LocalBackupException(
          'Duplicate account_profiles local_account_id in backup: $id.',
        );
      }
    }

    final planRows = payload['account_plan_revisions'] as List<dynamic>;
    final planKeys = <String>{};
    for (var index = 0; index < planRows.length; index++) {
      final row = planRows[index] as Map;
      final localAccountId = requiredString(
        row,
        'account_plan_revisions',
        index,
        'local_account_id',
      )!;
      final revisionId = requiredString(
        row,
        'account_plan_revisions',
        index,
        'revision_id',
      )!;
      if (!planKeys.add('$localAccountId|$revisionId')) {
        throw LocalBackupException(
          'Duplicate account_plan_revisions key in backup: '
          '$localAccountId|$revisionId.',
        );
      }
    }

    for (final raw in rawRecords) {
      final record = QazaRecord.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      if (!accountIds.contains(record.userId)) {
        throw LocalBackupException(
          'Qaza record ${record.id} references an unknown local account.',
        );
      }
    }

    for (var index = 0; index < additionRows.length; index++) {
      final row = additionRows[index] as Map;
      final userId = requiredString(row, 'qaza_additions', index, 'user_id')!;
      if (!accountIds.contains(userId)) {
        throw LocalBackupException(
          'qaza_additions row ${index + 1} references an unknown local account.',
        );
      }
    }

    for (var index = 0; index < actionRows.length; index++) {
      final row = actionRows[index] as Map;
      final userId = requiredString(
        row,
        'qaza_deletion_actions',
        index,
        'user_id',
      )!;
      final additionId = requiredString(
        row,
        'qaza_deletion_actions',
        index,
        'addition_id',
      )!;
      if (!accountIds.contains(userId) || !additionIds.contains(additionId)) {
        throw LocalBackupException(
          'qaza_deletion_actions row ${index + 1} has an invalid account/addition reference.',
        );
      }
    }

    for (var index = 0; index < snapshotRows.length; index++) {
      final row = snapshotRows[index] as Map;
      final userId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'user_id',
      )!;
      final actionId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'deletion_action_id',
      )!;
      final recordId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'record_id',
      )!;
      final additionId = requiredString(
        row,
        'qaza_deletion_action_record_snapshots',
        index,
        'addition_id',
      )!;
      if (!accountIds.contains(userId) ||
          !actionIds.contains(actionId) ||
          !recordIds.contains(recordId) ||
          !additionIds.contains(additionId)) {
        throw LocalBackupException(
          'Deletion snapshot row ${index + 1} has an invalid account/action reference.',
        );
      }
    }

    for (var index = 0; index < provenanceRows.length; index++) {
      final row = provenanceRows[index] as Map;
      final userId = requiredString(
        row,
        'qaza_profile_plan_provenance',
        index,
        'user_id',
      )!;
      final recordId = requiredString(
        row,
        'qaza_profile_plan_provenance',
        index,
        'record_id',
      )!;
      final planRevisionId = requiredString(
        row,
        'qaza_profile_plan_provenance',
        index,
        'plan_revision_id',
      )!;
      final planKey = '$userId|$planRevisionId';
      if (!accountIds.contains(userId) ||
          !recordIds.contains(recordId) ||
          !planKeys.contains(planKey)) {
        throw LocalBackupException(
          'Qaza provenance row ${index + 1} references an unknown account/record.',
        );
      }
    }

    for (var index = 0; index < profileRows.length; index++) {
      final id = requiredString(
        profileRows[index] as Map,
        'account_profiles',
        index,
        'local_account_id',
      )!;
      if (!accountIds.contains(id)) {
        throw LocalBackupException(
          'account_profiles row ${index + 1} references an unknown local account.',
        );
      }
    }

    for (var index = 0; index < planRows.length; index++) {
      final id = requiredString(
        planRows[index] as Map,
        'account_plan_revisions',
        index,
        'local_account_id',
      )!;
      if (!accountIds.contains(id)) {
        throw LocalBackupException(
          'account_plan_revisions row ${index + 1} references an unknown local account.',
        );
      }
    }

    final sessionRows = payload['app_session_state'] as List<dynamic>;
    if (sessionRows.length != 1 || (sessionRows.single as Map)['id'] != 1) {
      throw const LocalBackupException(
        'Backup session state must contain exactly one row with id=1.',
      );
    }
    final activeAccountId =
        (sessionRows.single as Map)['active_local_account_id'];
    if (activeAccountId != null) {
      if (activeAccountId is! String || !accountIds.contains(activeAccountId)) {
        throw const LocalBackupException(
          'Backup session references an unknown active local account.',
        );
      }
    }

    final meta = payload['meta_store'];
    if (meta is! Map || meta['is_onboarding_completed'] is! bool) {
      throw const LocalBackupException(
        'Backup onboarding metadata is invalid.',
      );
    }

    // Normalize legacy daily Salah rows before either validation consumers
    // or import see them. Schema 20's migration copied the tracker-created
    // Qaza ID into linked_qaza_id and left completion_sync_id empty. Schema 21
    // backups produced before these fields were added to exports are handled
    // the same way when the fields are absent, while explicit nulls in new
    // exports remain meaningful.
    if (rawDailySalahLogs is List) {
      final migratedLogs = <Map<String, dynamic>>[];
      for (final raw in rawDailySalahLogs) {
        final log = Map<String, dynamic>.from(raw as Map);
        if (databaseSchema == 20 || !log.containsKey('linked_qaza_id')) {
          log['linked_qaza_id'] = log['tracker_created_qaza_id'];
        }
        log.putIfAbsent('completion_sync_id', () => null);
        migratedLogs.add(log);
      }
      payload['daily_salah_logs'] = migratedLogs;
    }
    root['data'] = payload;
    return root;
  }

  Future<List<Map<String, dynamic>>> _selectMaps(
    String sql,
    List<String> columns, {
    Set<String> integerColumns = const <String>{},
  }) async {
    final rows = await database.customSelect(sql).get();
    return rows.map((row) {
      return {
        for (final column in columns)
          column: _readValue(
            row,
            column,
            integer: integerColumns.contains(column),
          ),
      };
    }).toList(growable: false);
  }

  Object? _readValue(
    QueryRow row,
    String column, {
    bool integer = false,
  }) {
    if (integer) return row.read<int?>(column);
    return switch (column) {
      'id' ||
      'user_id' ||
      'mode' ||
      'input_snapshot' ||
      'created_at' ||
      'updated_at' ||
      'resolved_at' ||
      'addition_id' ||
      'deletion_action_id' ||
      'record_id' ||
      'prayer_type' ||
      'prayer_date' ||
      'status' ||
      'tracker_created_qaza_id' ||
      'linked_qaza_id' ||
      'completion_sync_id' ||
      'original_date' ||
      'completed_at' ||
      'completion_id' ||
      'plan_revision_id' ||
      'plan_fingerprint' ||
      'local_account_id' ||
      'account_mode' ||
      'lifecycle_state' ||
      'active_local_account_id' ||
      'payload_json' ||
      'writer_device_id' ||
      'operation_id' ||
      'revision_id' =>
        row.read<String?>(column),
      'revision' ||
      'entity_version' ||
      'record_version' =>
        row.read<int?>(column),
      _ => throw StateError('Unsupported backup column: $column'),
    };
  }

  Future<void> _insertMaps(
    String table,
    List<String> columns,
    List<dynamic> rawRows, {
    AppDatabase? targetDatabase,
  }) async {
    if (rawRows.isEmpty) return;
    final quotedColumns = columns.map((column) => '"$column"').join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    for (final raw in rawRows) {
      if (raw is! Map) {
        throw const LocalBackupException(
          'Backup contains an invalid table row.',
        );
      }
      final values = <Variable<Object>>[
        for (final column in columns) Variable(raw[column]),
      ];
      await (targetDatabase ?? database).customInsert(
        'INSERT INTO "$table" ($quotedColumns) VALUES ($placeholders)',
        variables: values,
      );
    }
  }

  Future<void> _clearBusinessState({
    AppDatabase? targetDatabase,
    bool includeControlTables = true,
  }) async {
    final target = targetDatabase ?? database;
    // Workspace-scoped tracking settings are restored from the backup payload.
    // Remove old values first so settings from workspaces absent in the backup
    // cannot survive a full import and affect a later account recreation.
    await target.customStatement(
      "DELETE FROM meta_store WHERE key IN ("
      "'daily_salah_tracking_enabled', "
      "'daily_salah_tracking_setup_dismissed') "
      "OR key GLOB 'daily_salah_tracking_enabled:*' "
      "OR key GLOB 'daily_salah_tracking_setup_dismissed:*' "
      "OR key GLOB 'workspace_display_name:*'",
    );
    await target.customStatement('DELETE FROM daily_salah_logs');
    await target.customStatement(
      'DELETE FROM qaza_deletion_action_record_snapshots',
    );
    await target.customStatement('DELETE FROM qaza_deletion_actions');
    await target.customStatement('DELETE FROM qaza_profile_plan_provenance');
    await target.customStatement('DELETE FROM qaza_records');
    await target.customStatement('DELETE FROM qaza_additions');
    await target.customStatement('DELETE FROM account_plan_revisions');
    await target.customStatement('DELETE FROM account_profiles');
    if (includeControlTables) {
      await target.customStatement('DELETE FROM app_session_state');
      await target.customStatement('DELETE FROM local_accounts');
    }
  }

  QazaRecordsCompanion _recordCompanion(QazaRecord record) =>
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
      );
}
