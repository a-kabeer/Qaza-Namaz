import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import 'database/app_database.dart';

/// Migrates legacy local workspace identifiers without ever merging histories.
class WorkspaceIdentityMigrator {
  WorkspaceIdentityMigrator(this.database);

  final AppDatabase database;

  Future<void> migrate() async {
    await database.transaction(_migrateInsideTransaction);
  }

  Future<void> _migrateInsideTransaction() async {
    final rows = await database
        .customSelect(
          'SELECT local_account_id FROM local_accounts ORDER BY local_account_id',
        )
        .get();
    final existing =
        rows.map((row) => row.read<String>('local_account_id')).toSet();
    final remap = <String, String>{};

    for (final id in existing) {
      if (id == 'guest') {
        remap[id] = _newGuestId(existing, remap.values);
      } else if (id.startsWith('guest:')) {
        final suffix = id.substring('guest:'.length);
        final uuidPattern = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        );
        final canonical = 'guest_$suffix';
        remap[id] = uuidPattern.hasMatch(suffix) &&
                !existing.contains(canonical) &&
                !remap.values.contains(canonical)
            ? canonical
            : _newGuestId(existing, remap.values);
      } else if (id.startsWith('google:')) {
        final stableId = id.substring('google:'.length);
        if (stableId.isEmpty) {
          await _markLegacyWorkspaceUnverified(id);
          continue;
        }
        final canonical = 'google_$stableId';
        if (existing.contains(canonical) || remap.values.contains(canonical)) {
          throw StateError(
            'Workspace migration found both "$id" and "$canonical". '
            'No records were merged or deleted. Keep a copy of the local database and resolve the duplicate workspace before retrying.',
          );
        }
        remap[id] = canonical;
      }
    }

    for (final entry in remap.entries) {
      await _moveWorkspace(entry.key, entry.value);
    }
  }

  String _newGuestId(Set<String> existing, Iterable<String> planned) {
    var id = 'guest_${_uuidV4()}';
    while (existing.contains(id) || planned.contains(id)) {
      id = 'guest_${_uuidV4()}';
    }
    return id;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _moveWorkspace(String oldId, String newId) async {
    final revisions = await database.customSelect(
      'SELECT revision_id, payload_json FROM account_plan_revisions WHERE local_account_id = ?',
      variables: [Variable(oldId)],
    ).get();
    for (final row in revisions) {
      final decoded = jsonDecode(row.read<String>('payload_json'));
      if (decoded is! Map) {
        throw StateError(
          'Cannot safely migrate plan revision for workspace "$oldId": invalid JSON payload.',
        );
      }
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['userId'] == oldId) payload['userId'] = newId;
      if (payload['user_id'] == oldId) payload['user_id'] = newId;
      await database.customUpdate(
        'UPDATE account_plan_revisions SET payload_json = ? WHERE local_account_id = ? AND revision_id = ?',
        variables: [
          Variable(jsonEncode(payload)),
          Variable(oldId),
          Variable(row.read<String>('revision_id')),
        ],
      );
    }

    const owners = <(String, String)>[
      ('qaza_records', 'user_id'),
      ('daily_salah_logs', 'user_id'),
      ('qaza_additions', 'user_id'),
      ('qaza_deletion_actions', 'user_id'),
      ('qaza_deletion_action_record_snapshots', 'user_id'),
      ('qaza_profile_plan_provenance', 'user_id'),
      ('account_profiles', 'local_account_id'),
      ('account_plan_revisions', 'local_account_id'),
    ];
    for (final (table, ownerColumn) in owners) {
      await database.customUpdate(
        'UPDATE "$table" SET "$ownerColumn" = ? WHERE "$ownerColumn" = ?',
        variables: [Variable(newId), Variable(oldId)],
      );
    }

    await database.customUpdate(
      'UPDATE app_session_state SET active_local_account_id = ?, generation = generation + 1 WHERE active_local_account_id = ?',
      variables: [Variable(newId), Variable(oldId)],
    );
    await database.customUpdate(
      'UPDATE workspace_sync_metadata SET local_account_id = ? WHERE local_account_id = ?',
      variables: [Variable(newId), Variable(oldId)],
    );
    await database.customUpdate(
      'UPDATE local_workspace_deletion_holds SET local_account_id = ? WHERE local_account_id = ?',
      variables: [Variable(newId), Variable(oldId)],
    );

    await _moveJournalReferences(oldId, newId);
    await _moveWorkspaceMeta(oldId, newId);

    final oldOwner = await database
        .customSelect(
          "SELECT value FROM meta_store WHERE key = 'initial_cloud_backup_pending_account_id' LIMIT 1",
        )
        .get();
    if (oldOwner.isNotEmpty && oldOwner.single.read<String>('value') == oldId) {
      await database.customUpdate(
        "UPDATE meta_store SET value = ? WHERE key = 'initial_cloud_backup_pending_account_id'",
        variables: [Variable(newId)],
      );
    }

    await database.customUpdate(
      'UPDATE local_accounts SET local_account_id = ? WHERE local_account_id = ?',
      variables: [Variable(newId), Variable(oldId)],
    );

    if (oldId == 'guest') {
      final displayNameRows = await database.customSelect(
        'SELECT 1 FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable('workspace_display_name:$newId')],
      ).get();
      if (displayNameRows.isEmpty) {
        await database.customInsert(
          'INSERT INTO meta_store (key, value) VALUES (?, ?)',
          variables: [
            Variable('workspace_display_name:$newId'),
            Variable('Guest')
          ],
        );
      }
    }
  }

  Future<void> _moveJournalReferences(String oldId, String newId) async {
    final journalRows = await database.customSelect(
      'SELECT operation_id, operation_type, source_local_account_id, target_local_account_id, snapshot_id FROM workspace_operation_journal WHERE source_local_account_id = ? OR target_local_account_id = ?',
      variables: [Variable(oldId), Variable(oldId)],
    ).get();

    for (final journal in journalRows) {
      final oldOperationId = journal.read<String>('operation_id');
      final type = journal.read<String>('operation_type');
      final sourceId = journal.read<String>('source_local_account_id');
      final targetId = journal.read<String>('target_local_account_id');
      final nextSource = sourceId == oldId ? newId : sourceId;
      final nextTarget = targetId == oldId ? newId : targetId;
      final oldSnapshotId = journal.read<String?>('snapshot_id');
      final nextOperationId = type == 'guest_adoption'
          ? 'guest-adoption:$nextSource=>$nextTarget'
          : oldOperationId;
      final nextSnapshotId =
          oldSnapshotId == oldOperationId ? nextOperationId : oldSnapshotId;

      if (nextOperationId != oldOperationId) {
        final collision = await database.customSelect(
          'SELECT 1 FROM workspace_operation_journal WHERE operation_id = ? LIMIT 1',
          variables: [Variable(nextOperationId)],
        ).get();
        if (collision.isNotEmpty) {
          throw StateError(
            'Workspace migration found duplicate recovery-journal IDs. No local data was merged or deleted.',
          );
        }
      }
      await database.customUpdate(
        'UPDATE workspace_operation_journal SET operation_id = ?, source_local_account_id = ?, target_local_account_id = ?, snapshot_id = ? WHERE operation_id = ?',
        variables: [
          Variable(nextOperationId),
          Variable(nextSource),
          Variable(nextTarget),
          Variable(nextSnapshotId),
          Variable(oldOperationId),
        ],
      );

      final snapshotTable = await database
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'local_account_adoption_snapshots' LIMIT 1",
          )
          .get();
      if (snapshotTable.isNotEmpty && oldSnapshotId != null) {
        await database.customUpdate(
          'UPDATE local_account_adoption_snapshots SET snapshot_id = ?, source_local_account_id = ?, target_local_account_id = ? WHERE snapshot_id = ?',
          variables: [
            Variable(nextSnapshotId),
            Variable(nextSource),
            Variable(nextTarget),
            Variable(oldSnapshotId),
          ],
        );
      }
    }
  }

  Future<void> _moveWorkspaceMeta(String oldId, String newId) async {
    for (final prefix in [
      'workspace_display_name:',
      'workspace_revision:',
      'daily_salah_tracking_enabled:',
      'daily_salah_tracking_setup_dismissed:',
      'initial_cloud_backup_pending:',
    ]) {
      final oldKey = '$prefix$oldId';
      final newKey = '$prefix$newId';
      final oldRows = await database.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable(oldKey)],
      ).get();
      if (oldRows.isEmpty) continue;
      final oldValue = oldRows.single.read<String>('value');
      final nextRows = await database.customSelect(
        'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
        variables: [Variable(newKey)],
      ).get();

      if (nextRows.isEmpty) {
        await database.customInsert(
          'INSERT INTO meta_store (key, value) VALUES (?, ?)',
          variables: [Variable(newKey), Variable(oldValue)],
        );
      } else if (prefix == 'workspace_revision:') {
        final oldRevision = int.tryParse(oldValue) ?? 1;
        final nextRevision =
            int.tryParse(nextRows.single.read<String>('value')) ?? 1;
        await database.customUpdate(
          'UPDATE meta_store SET value = ? WHERE key = ?',
          variables: [
            Variable((oldRevision > nextRevision ? oldRevision : nextRevision)
                .toString()),
            Variable(newKey),
          ],
        );
      } else if (nextRows.single.read<String>('value') != oldValue) {
        throw StateError(
          'Workspace migration found conflicting metadata for "$oldId". No data was merged or deleted.',
        );
      }
      await database.customStatement(
        'DELETE FROM meta_store WHERE key = ?',
        [Variable(oldKey)],
      );
    }
  }

  Future<void> _markLegacyWorkspaceUnverified(String localAccountId) async {
    await database.customInsert(
      '''INSERT INTO workspace_sync_metadata
         (local_account_id, sync_state, local_revision, last_checked_at)
         VALUES (?, 'legacy_unverified', 1, ?)
         ON CONFLICT(local_account_id) DO UPDATE SET sync_state = 'legacy_unverified' ''',
      variables: [
        Variable(localAccountId),
        Variable(DateTime.now().toUtc().toIso8601String()),
      ],
    );
  }
}
