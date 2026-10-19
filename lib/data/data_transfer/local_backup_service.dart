import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../local/database/app_database.dart';

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
  LocalBackupService(this.database);

  final AppDatabase database;

  Future<String> exportJson({
    DateTime? exportedAt,
    String? localAccountId,
  }) async {
    return database.transaction(() async {
      final dbRevision = await database.readDbRevision();
      final users = await database.qazaRecordsDao.userIds();
      final records = <Map<String, dynamic>>[];
      for (final userId in users) {
        final rows = await database.qazaRecordsDao.getAll(userId: userId);
        records.addAll(rows.map((row) => row.toJson()));
      }
      records.sort(
        (a, b) => (a['id'] as String).compareTo(b['id'] as String),
      );

      final accountIdRows = await database.customSelect(
        'SELECT local_account_id FROM local_accounts ORDER BY local_account_id',
      ).get();
      final trackingEnabledByAccount = <String, bool>{};
      final trackingSetupDismissedByAccount = <String, bool>{};
      for (final row in accountIdRows) {
        final accountId = row.read<String>('local_account_id');
        trackingEnabledByAccount[accountId] =
            await database.isDailySalahTrackingEnabled(userId: accountId);
        trackingSetupDismissedByAccount[accountId] =
            await database.isDailySalahTrackingSetupDismissed(userId: accountId);
      }
      final activeSessionRows = await database.customSelect(
        'SELECT active_local_account_id FROM app_session_state ORDER BY id LIMIT 1',
      ).get();
      final activeAccountId = activeSessionRows.isEmpty
          ? null
          : activeSessionRows.first.read<String?>('active_local_account_id');
      final preferenceAccountId = localAccountId?.trim().isNotEmpty == true
          ? localAccountId!.trim()
          : activeAccountId ?? 'guest';

      final document = <String, dynamic>{
        'metadata': {
          'app_id': _appId,
          'backup_schema_version': _backupSchemaVersion,
          'database_schema_version': database.schemaVersion,
          'db_revision': dbRevision,
          'export_timestamp':
              (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        'data': {
          'qaza_records': records,
          'daily_salah_logs': await _selectMaps(
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
          'qaza_additions': await _selectMaps(
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
          'qaza_deletion_actions': await _selectMaps(
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
          'qaza_deletion_action_record_snapshots': await _selectMaps(
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
          'qaza_profile_plan_provenance': await _selectMaps(
            'SELECT record_id, user_id, plan_revision_id, plan_fingerprint '
            'FROM qaza_profile_plan_provenance ORDER BY record_id',
            ['record_id', 'user_id', 'plan_revision_id', 'plan_fingerprint'],
          ),
          'local_accounts': await _selectMaps(
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
          'app_session_state': await _selectMaps(
            'SELECT id, active_local_account_id FROM app_session_state ORDER BY id',
            ['id', 'active_local_account_id'],
            integerColumns: {'id'},
          ),
          'account_profiles': await _selectMaps(
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
          'account_plan_revisions': await _selectMaps(
            'SELECT local_account_id, revision_id, payload_json, created_at '
            'FROM account_plan_revisions ORDER BY local_account_id, revision_id',
            ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
            integerColumns: {'created_at'},
          ),
          'meta_store': {
            'is_onboarding_completed': await database.isOnboardingCompleted(),
            'daily_salah_tracking_enabled':
                await database.isDailySalahTrackingEnabled(
              userId: preferenceAccountId,
            ),
            'daily_salah_tracking_enabled_by_account':
                trackingEnabledByAccount,
            'daily_salah_tracking_setup_dismissed':
                await database.isDailySalahTrackingSetupDismissed(
              userId: preferenceAccountId,
            ),
            'daily_salah_tracking_setup_dismissed_by_account':
                trackingSetupDismissedByAccount,
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
      }

      return const JsonEncoder.withIndent('  ').convert(document);
    });
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

  Future<LocalBackupAnalysis> importJson(
    String jsonText, {
    String? targetLocalAccountId,
  }) async {
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
      );
    }

    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final backupRevision = metadata['db_revision'] as int;

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
      await _insertMaps(
        'app_session_state',
        ['id', 'active_local_account_id'],
        data['app_session_state'] as List<dynamic>,
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
    String targetLocalAccountId,
  ) {
    final target = targetLocalAccountId.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(targetLocalAccountId, 'targetLocalAccountId');
    }

    final remoteData = Map<String, dynamic>.from(remoteRoot['data'] as Map);
    final localData = Map<String, dynamic>.from(localRoot['data'] as Map);
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

    // Never silently attach a known, different Google workspace. Legacy
    // backups labelled "guest" can be adopted by the verified target account.
    if (sourceAccountId.startsWith('google:') && sourceAccountId != target) {
      throw const LocalBackupException(
        'This backup belongs to a different Google account. Local data was not changed.',
      );
    }

    // Before account-scoped backups, Qaza primary keys included the owning
    // workspace prefix. When adopting a legacy Guest backup into Google,
    // rewrite those IDs as well as every stored reference to them.
    final remapLegacyGuestRecordIds =
        sourceAccountId == UserProfile.localLedgerUserId &&
        target != UserProfile.localLedgerUserId;

    Object? remapQazaRecordId(Object? value) {
      if (!remapLegacyGuestRecordIds ||
          value is! String ||
          !value.startsWith('guest_')) {
        return value;
      }
      return '$target${value.substring(5)}';
    }

    Map<String, dynamic> remapRevisionPayload(Map<String, dynamic> row) {
      if (!remapLegacyGuestRecordIds || row['payload_json'] is! String) {
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
        if (remapLegacyGuestRecordIds) {
          switch (table) {
            case 'qaza_records':
              row['id'] = remapQazaRecordId(row['id']);
              break;
            case 'qaza_profile_plan_provenance':
            case 'qaza_deletion_action_record_snapshots':
              row['record_id'] = remapQazaRecordId(row['record_id']);
              break;
            case 'daily_salah_logs':
              row['tracker_created_qaza_id'] =
                  remapQazaRecordId(row['tracker_created_qaza_id']);
              row['linked_qaza_id'] = remapQazaRecordId(row['linked_qaza_id']);
              break;
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
        row['lifecycle_state'] = 'active';
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
        mergedMeta['daily_salah_tracking_setup_dismissed'] =
            remoteDismissed;
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
    // Schema 19 predates daily Salah tracking. Schema 20 has daily logs but
    // predates their explicit Qaza link and completion-sync columns. Both are
    // safe predecessors of schema 21 and are normalized below.
    final compatibleLegacySchema = database.schemaVersion == 21 &&
        (databaseSchema == 19 || databaseSchema == 20);
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
      if (map['lifecycle_state'] != 'active' &&
          map['lifecycle_state'] != 'archived' &&
          map['lifecycle_state'] != 'migrating') {
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
    List<dynamic> rawRows,
  ) async {
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
      await database.customInsert(
        'INSERT INTO "$table" ($quotedColumns) VALUES ($placeholders)',
        variables: values,
      );
    }
  }

  Future<void> _clearBusinessState() async {
    // Workspace-scoped tracking settings are restored from the backup payload.
    // Remove old values first so settings from workspaces absent in the backup
    // cannot survive a full import and affect a later account recreation.
    await database.customStatement(
      "DELETE FROM meta_store WHERE key IN ("
      "'daily_salah_tracking_enabled', "
      "'daily_salah_tracking_setup_dismissed') "
      "OR key LIKE 'daily_salah_tracking_enabled:%' "
      "OR key LIKE 'daily_salah_tracking_setup_dismissed:%'",
    );
    await database.customStatement('DELETE FROM daily_salah_logs');
    await database.customStatement(
      'DELETE FROM qaza_deletion_action_record_snapshots',
    );
    await database.customStatement('DELETE FROM qaza_deletion_actions');
    await database.customStatement('DELETE FROM qaza_profile_plan_provenance');
    await database.customStatement('DELETE FROM qaza_records');
    await database.customStatement('DELETE FROM qaza_additions');
    await database.customStatement('DELETE FROM account_plan_revisions');
    await database.customStatement('DELETE FROM account_profiles');
    await database.customStatement('DELETE FROM app_session_state');
    await database.customStatement('DELETE FROM local_accounts');
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
