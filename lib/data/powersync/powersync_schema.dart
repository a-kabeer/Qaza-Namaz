import 'package:powersync/powersync.dart';

/// PowerSync Client Schema matching the Supabase PostgreSQL replication publication.
/// Note: PowerSync automatically generates the primary key `id` column for each table.
const Schema qazaPowerSyncSchema = Schema([
  Table(
    'account_profiles',
    [
      Column.text('user_id'),
      Column.text('payload_json'),
      Column.integer('entity_version'),
      Column.text('writer_device_id'),
      Column.text('operation_id'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'account_plan_revisions',
    [
      Column.text('user_id'),
      Column.text('revision_id'),
      Column.text('payload_json'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user_revision', [
        IndexedColumn('user_id'),
        IndexedColumn('revision_id'),
      ]),
    ],
  ),
  Table(
    'qaza_additions',
    [
      Column.text('user_id'),
      Column.text('mode'),
      Column.text('input_snapshot'),
      Column.integer('revision'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_created', [
        IndexedColumn('user_id'),
        IndexedColumn.descending('created_at'),
      ]),
    ],
  ),
  Table(
    'qaza_records',
    [
      Column.text('user_id'),
      Column.text('prayer_type'),
      Column.text('original_date'),
      Column.text('status'),
      Column.text('completed_at'),
      Column.text('completion_id'),
      Column.text('addition_id'),
      Column.integer('record_version'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_date', [
        IndexedColumn('user_id'),
        IndexedColumn('original_date'),
      ]),
      Index('user_prayer_date', [
        IndexedColumn('user_id'),
        IndexedColumn('prayer_type'),
        IndexedColumn('original_date'),
      ]),
      Index('user_prayer_status_date', [
        IndexedColumn('user_id'),
        IndexedColumn('prayer_type'),
        IndexedColumn('status'),
        IndexedColumn('original_date'),
      ]),
      Index('user_status_completed', [
        IndexedColumn('user_id'),
        IndexedColumn('status'),
        IndexedColumn('completed_at'),
      ]),
      Index('user_addition_date', [
        IndexedColumn('user_id'),
        IndexedColumn('addition_id'),
        IndexedColumn('original_date'),
      ]),
      Index('user_addition_status', [
        IndexedColumn('user_id'),
        IndexedColumn('addition_id'),
        IndexedColumn('status'),
        IndexedColumn('record_version'),
      ]),
    ],
  ),
  Table(
    'daily_salah_logs',
    [
      Column.text('user_id'),
      Column.text('prayer_date'),
      Column.text('prayer_type'),
      Column.text('status'),
      Column.text('tracker_created_qaza_id'),
      Column.text('linked_qaza_id'),
      Column.text('completion_sync_id'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_date', [
        IndexedColumn('user_id'),
        IndexedColumn('prayer_date'),
      ]),
      Index('user_prayer_date', [
        IndexedColumn('user_id'),
        IndexedColumn('prayer_type'),
        IndexedColumn('prayer_date'),
      ]),
    ],
  ),
  Table(
    'qaza_deletion_actions',
    [
      Column.text('user_id'),
      Column.text('addition_id'),
      Column.text('created_at'),
      Column.text('resolved_at'),
      Column.integer('entity_version'),
    ],
    indexes: [
      Index('user_created', [
        IndexedColumn('user_id'),
        IndexedColumn.descending('created_at'),
      ]),
      Index('user_resolved_created', [
        IndexedColumn('user_id'),
        IndexedColumn('resolved_at'),
        IndexedColumn.descending('created_at'),
      ]),
    ],
  ),
  Table(
    'qaza_deletion_action_record_snapshots',
    [
      Column.text('deletion_action_id'),
      Column.text('record_id'),
      Column.text('user_id'),
      Column.text('addition_id'),
      Column.text('prayer_type'),
      Column.text('original_date'),
      Column.text('status'),
      Column.text('completed_at'),
      Column.text('completion_id'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.integer('record_version'),
    ],
    indexes: [
      Index('action_record', [
        IndexedColumn('deletion_action_id'),
        IndexedColumn('record_id'),
      ]),
    ],
  ),
  Table(
    'qaza_profile_plan_provenance',
    [
      Column.text('record_id'),
      Column.text('user_id'),
      Column.text('plan_revision_id'),
      Column.text('plan_fingerprint'),
    ],
    indexes: [
      Index('user_plan', [
        IndexedColumn('user_id'),
        IndexedColumn('plan_revision_id'),
        IndexedColumn('record_id'),
      ]),
    ],
  ),
  Table(
    'user_preferences',
    [
      Column.text('user_id'),
      Column.text('workspace_display_name'),
      Column.integer('daily_salah_tracking_enabled'),
      Column.integer('daily_salah_tracking_setup_dismissed'),
      Column.text('home_completion_mode'),
      Column.text('home_auto_sequence_prayer'),
      Column.text('home_selected_prayer'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('user_id', [IndexedColumn('user_id')]),
    ],
  ),
]);
