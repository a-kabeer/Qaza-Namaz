import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/qaza_record.dart';
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

  Future<String> exportJson({DateTime? exportedAt}) async {
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

      final document = <String, dynamic>{
        'metadata': {
          'app_id': _appId,
          'backup_schema_version': _backupSchemaVersion,
          'database_schema_version': database.schemaVersion,
          'db_revision': dbRevision,
          'export_timestamp':
              (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
        },
        'data': {
          'qaza_records': records,
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
          },
        },
      };

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

  Future<LocalBackupAnalysis> importJson(String jsonText) async {
    final decoded = _decodeAndValidate(jsonText);
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
    if (databaseSchema != database.schemaVersion) {
      throw LocalBackupException(
        'Backup database schema $databaseSchema is not supported by this release '
        '(current schema: ${database.schemaVersion}).',
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
        throw LocalBackupException('Duplicate qaza_additions ID in backup: $id.');
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
      if (!accountIds.contains(userId) || !actionIds.contains(actionId)) {
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
      if (!accountIds.contains(userId) || !recordIds.contains(recordId)) {
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
      if (activeAccountId is! String ||
          !accountIds.contains(activeAccountId)) {
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
      'operation_id' =>
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
