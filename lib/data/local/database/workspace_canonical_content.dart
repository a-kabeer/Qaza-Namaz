import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// The single canonical content definition for a workspace, unified in
/// Recovery Stage 4 (decision D-D(ii)) on the §7 scoped-export
/// canonicalisation.
///
/// The canonical form is the scoped-export data model of one workspace:
/// its eight owned tables (all columns, rows ordered by primary key), its
/// scoped `meta_store` keys, and its scoped recovery snapshot. It is
/// **mapping-invariant**: the owner ID itself is normalised to a token, so
/// a Guest source and its adopted Google target — whose rows differ only
/// by the documented Guest-to-Google identity mapping — hash identically.
///
/// Deliberate exclusions, per §7's counter rule:
/// - `workspace_revision:<id>` and the sync row's revision counters are
///   operational state maintained by triggers; they are verified
///   separately (migration compares the full sync row field-by-field),
///   never hashed.
/// - `workspace_sync_metadata` as a whole is operational sync state, not
///   ledger content; it is excluded from the hash and verified separately
///   where a flow copies it (migration).
/// - The `workspace_display_name:<id>` *value* is assigned by the adopting
///   identity (§4/§7 identity mapping), so only the key's presence is
///   hashed, never its value.
/// - The provisioning flag `initial_cloud_backup_pending:<id>` is not
///   workspace content: it is a cloud-upload operational state that
///   exists only for Google workspaces, so including it would make the
///   hash layout-dependent rather than content-dependent.
///
/// This replaces the retired `workspace-content-v1` (migration) and
/// `workspace-canonical-v1` (creation) forms; neither tag is produced
/// anywhere after Stage 4.
class WorkspaceCanonicalContent {
  WorkspaceCanonicalContent._();

  static const List<(String, String)> ownedTables = <(String, String)>[
    ('qaza_additions', 'user_id'),
    ('account_plan_revisions', 'local_account_id'),
    ('account_profiles', 'local_account_id'),
    ('qaza_records', 'user_id'),
    ('qaza_deletion_actions', 'user_id'),
    ('qaza_deletion_action_record_snapshots', 'user_id'),
    ('daily_salah_logs', 'user_id'),
    ('qaza_profile_plan_provenance', 'user_id'),
  ];

  static List<String> scopedMetadataKeys(String workspaceId) => <String>[
        'workspace_display_name:$workspaceId',
        'daily_salah_tracking_enabled:$workspaceId',
        'daily_salah_tracking_setup_dismissed:$workspaceId',
        'workspace_revision:$workspaceId',
      ];

  static Future<List<String>> _tableColumns(
    AppDatabase source,
    String table,
  ) async {
    final rows = await source.customSelect('PRAGMA table_info("$table")').get();
    return rows.map((row) => row.read<String>('name')).toList(growable: false);
  }

  static Future<List<String>> _tablePrimaryKeyColumns(
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

  static Object? _normalizeValue(Object? value, {required bool isOwner}) {
    if (isOwner) return '<workspace>';
    if (value is Uint8List)
      return <String, String>{'blob': base64Encode(value)};
    if (value is List<int>)
      return <String, String>{'blob': base64Encode(value)};
    return value;
  }

  /// Returns the scoped recovery snapshot that belongs to [workspaceId]:
  /// the newest snapshot whose payload validates for this workspace.
  ///
  /// (Recovery R-15: the previous selection inspected only the single
  /// newest snapshot overall and silently dropped this workspace's
  /// snapshot whenever a newer snapshot belonged to another workspace.)
  static Future<Map<String, dynamic>?> scopedRecoverySnapshot(
    AppDatabase source,
    String workspaceId,
  ) async {
    final table = await source
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'local_recovery_snapshots' LIMIT 1",
        )
        .get();
    if (table.isEmpty) return null;
    final rows = await source
        .customSelect(
          'SELECT snapshot_id, created_at, payload_json '
          'FROM local_recovery_snapshots ORDER BY created_at DESC',
        )
        .get();
    for (final row in rows) {
      final payload = row.read<String>('payload_json');
      try {
        final root = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        final data = Map<String, dynamic>.from(root['data'] as Map);
        final accounts = data['local_accounts'] as List<dynamic>;
        final sessions = data['app_session_state'] as List<dynamic>;
        if (accounts.length != 1 ||
            accounts.single is! Map ||
            (accounts.single as Map)['local_account_id'] != workspaceId ||
            sessions.length != 1 ||
            sessions.single is! Map ||
            (sessions.single as Map)['active_local_account_id'] !=
                workspaceId) {
          continue;
        }
        return <String, dynamic>{
          'snapshot_id': row.read<String>('snapshot_id'),
          'created_at': row.read<String>('created_at'),
          'payload_json': payload,
        };
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<Map<String, int>> rowCounts(
    AppDatabase source,
    String workspaceId,
  ) async {
    final counts = <String, int>{};
    for (final (table, ownerColumn) in ownedTables) {
      final rows = await source.customSelect(
        'SELECT COUNT(*) AS row_count FROM "$table" WHERE "$ownerColumn" = ?',
        variables: [Variable<String>(workspaceId)],
      ).get();
      counts[table] = rows.single.read<int>('row_count');
    }
    return counts;
  }

  /// The full sync-metadata row for [workspaceId], for the separate
  /// field-by-field verification §7 requires for copied operational state.
  static Future<List<Object?>?> syncRowValues(
    AppDatabase source,
    String workspaceId,
  ) async {
    final rows = await source.customSelect(
      '''SELECT local_account_id, sync_state, local_revision, last_synced_revision,
                last_synced_local_hash, last_synced_remote_version,
                last_synced_remote_hash, last_checked_at, conflict_marker,
                remote_account_id
         FROM workspace_sync_metadata WHERE local_account_id = ? LIMIT 1''',
      variables: [Variable<String>(workspaceId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return <Object?>[
      row.read<String>('local_account_id'),
      row.read<String>('sync_state'),
      row.read<int>('local_revision'),
      row.read<int?>('last_synced_revision'),
      row.read<String?>('last_synced_local_hash'),
      row.read<String?>('last_synced_remote_version'),
      row.read<String?>('last_synced_remote_hash'),
      row.read<String?>('last_checked_at'),
      row.read<String?>('conflict_marker'),
      row.read<String?>('remote_account_id'),
    ];
  }

  static Future<String> hash(AppDatabase source, String workspaceId) async {
    if (source.isGoogleWorkspaceDatabase &&
        await source.readWorkspaceFileOwner() != workspaceId) {
      throw StateError(
        'Cannot hash a Google workspace database owned by another ID.',
      );
    }

    final tablePayload = await _ownedTablesPayload(source, workspaceId);

    final metadataKeys = scopedMetadataKeys(workspaceId)
        .where((key) => key != 'workspace_revision:$workspaceId')
        .toList(growable: false);
    final metadataRows = await source
        .customSelect(
          'SELECT key, value FROM meta_store '
          'WHERE key IN (${List<String>.filled(metadataKeys.length, '?').join(', ')}) '
          'ORDER BY key',
          variables: metadataKeys.map((key) => Variable<String>(key)).toList(),
        )
        .get();
    final metadataPayload = <Object?>[
      for (final row in metadataRows)
        <Object?>[
          (row.read<String>('key')).replaceAll(':$workspaceId', ':<workspace>'),
          row.read<String>('key') == 'workspace_display_name:$workspaceId'
              ? '<workspace-display-name>'
              : row.read<String>('value'),
        ],
    ];

    final snapshot = await scopedRecoverySnapshot(source, workspaceId);

    final canonical = jsonEncode(<Object?>[
      'workspace-scoped-export-v1',
      tablePayload,
      metadataPayload,
      if (snapshot != null)
        <Object?>[
          'recovery_snapshot',
          snapshot['snapshot_id'],
          snapshot['created_at'],
          (snapshot['payload_json'] as String)
              .replaceAll(workspaceId, '<workspace>'),
        ],
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Future<List<Object?>> _ownedTablesPayload(
    AppDatabase source,
    String workspaceId,
  ) async {
    final tablePayload = <Object?>[];
    for (final (table, ownerColumn) in ownedTables) {
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
        'SELECT $quotedColumns FROM "$table" '
        'WHERE "$ownerColumn" = ? ORDER BY $orderBy',
        variables: [Variable<String>(workspaceId)],
      ).get();
      tablePayload.add(<Object?>[
        table,
        columns,
        for (final row in rows)
          <Object?>[
            for (final column in columns)
              _normalizeValue(
                row.data[column],
                isOwner: column == ownerColumn,
              ),
          ],
      ]);
    }
    return tablePayload;
  }

  /// The payload-bearing part of the same canonicalisation: the owned
  /// tables only, without scoped metadata or the recovery snapshot.
  /// Cross-file adoption verification compares this hash between the
  /// Guest source and the Google target (decision D-D(ii)): scoped
  /// metadata in the target is provisioning state (its content settings
  /// are verified directly by the adoption flow), and a recovery
  /// snapshot's payload is bound to its source workspace by
  /// construction, so neither can ever be equal across an adoption
  /// boundary.
  static Future<String> ownedContentHash(
    AppDatabase source,
    String workspaceId,
  ) async {
    final tablePayload = await _ownedTablesPayload(source, workspaceId);
    final canonical = jsonEncode(<Object?>[
      'workspace-owned-content-v1',
      tablePayload,
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
