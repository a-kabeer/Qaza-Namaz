/// Definition of the PowerSync schema matching the Qaza Namaz PostgreSQL schema.
///
/// Every PowerSync table requires an `id` column as its single primary key.
/// All timestamp and date fields are stored in UTC ISO-8601 strings.
enum PowerSyncColumnType { text, integer, real }

class PowerSyncColumnDefinition {
  const PowerSyncColumnDefinition(this.name, this.type);
  final String name;
  final PowerSyncColumnType type;
}

class PowerSyncTableDefinition {
  const PowerSyncTableDefinition({
    required this.name,
    required this.columns,
    this.indexes = const [],
  });

  final String name;
  final List<PowerSyncColumnDefinition> columns;
  final List<String> indexes;
}

class QazaPowerSyncSchema {
  QazaPowerSyncSchema._();

  static const PowerSyncTableDefinition accountProfiles =
      PowerSyncTableDefinition(
    name: 'account_profiles',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('payload_json', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('entity_version', PowerSyncColumnType.integer),
      PowerSyncColumnDefinition('writer_device_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('operation_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
    ],
  );

  static const PowerSyncTableDefinition accountPlanRevisions =
      PowerSyncTableDefinition(
    name: 'account_plan_revisions',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('revision_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('payload_json', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
    ],
  );

  static const PowerSyncTableDefinition qazaAdditions =
      PowerSyncTableDefinition(
    name: 'qaza_additions',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('mode', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('input_snapshot', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('revision', PowerSyncColumnType.integer),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
    ],
  );

  static const PowerSyncTableDefinition qazaRecords = PowerSyncTableDefinition(
    name: 'qaza_records',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('prayer_type', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('original_date', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('status', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('completed_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('completion_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('addition_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('record_version', PowerSyncColumnType.integer),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
    ],
    indexes: ['user_id', 'prayer_type', 'status'],
  );

  static const PowerSyncTableDefinition dailySalahLogs =
      PowerSyncTableDefinition(
    name: 'daily_salah_logs',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('prayer_date', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('prayer_type', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('status', PowerSyncColumnType.text),
      PowerSyncColumnDefinition(
          'tracker_created_qaza_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('linked_qaza_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('completion_sync_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
    ],
    indexes: ['user_id', 'prayer_date'],
  );

  static const PowerSyncTableDefinition qazaDeletionActions =
      PowerSyncTableDefinition(
    name: 'qaza_deletion_actions',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('addition_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('resolved_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('entity_version', PowerSyncColumnType.integer),
    ],
  );

  static const PowerSyncTableDefinition qazaDeletionActionRecordSnapshots =
      PowerSyncTableDefinition(
    name: 'qaza_deletion_action_record_snapshots',
    columns: [
      PowerSyncColumnDefinition(
          'deletion_action_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('record_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('addition_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('prayer_type', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('original_date', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('status', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('completed_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('completion_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('created_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('record_version', PowerSyncColumnType.integer),
    ],
  );

  static const PowerSyncTableDefinition qazaProfilePlanProvenance =
      PowerSyncTableDefinition(
    name: 'qaza_profile_plan_provenance',
    columns: [
      PowerSyncColumnDefinition('record_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('plan_revision_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('plan_fingerprint', PowerSyncColumnType.text),
    ],
  );

  static const PowerSyncTableDefinition userPreferences =
      PowerSyncTableDefinition(
    name: 'user_preferences',
    columns: [
      PowerSyncColumnDefinition('user_id', PowerSyncColumnType.text),
      PowerSyncColumnDefinition(
          'workspace_display_name', PowerSyncColumnType.text),
      PowerSyncColumnDefinition(
          'daily_salah_tracking_enabled', PowerSyncColumnType.integer),
      PowerSyncColumnDefinition(
          'daily_salah_tracking_setup_dismissed', PowerSyncColumnType.integer),
      PowerSyncColumnDefinition(
          'home_completion_mode', PowerSyncColumnType.text),
      PowerSyncColumnDefinition(
          'home_auto_sequence_prayer', PowerSyncColumnType.text),
      PowerSyncColumnDefinition(
          'home_selected_prayer', PowerSyncColumnType.text),
      PowerSyncColumnDefinition('updated_at', PowerSyncColumnType.text),
    ],
  );

  static const List<PowerSyncTableDefinition> allTables = [
    accountProfiles,
    accountPlanRevisions,
    qazaAdditions,
    qazaRecords,
    dailySalahLogs,
    qazaDeletionActions,
    qazaDeletionActionRecordSnapshots,
    qazaProfilePlanProvenance,
    userPreferences,
  ];
}
