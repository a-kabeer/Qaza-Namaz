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
    final dbRevision = await database.readDbRevision();
    final users = await database.qazaRecordsDao.userIds();
    final records = <Map<String, dynamic>>[];
    for (final userId in users) {
      final rows = await database.qazaRecordsDao.getAll(userId: userId);
      records.addAll(rows.map((row) => row.toJson()));
    }

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
        ),
        'account_plan_revisions': await _selectMaps(
          'SELECT local_account_id, revision_id, payload_json, created_at '
          'FROM account_plan_revisions ORDER BY local_account_id, revision_id',
          ['local_account_id', 'revision_id', 'payload_json', 'created_at'],
        ),
        'meta_store': {
          'is_onboarding_completed':
              await database.isOnboardingCompleted(),
        },
      },
    };

    return const JsonEncoder.withIndent('  ').convert(document);
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
      final newRevision =
          (currentRevision > backupRevision ? currentRevision : backupRevision) + 1;

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
    if (schema is! int) {
      throw const LocalBackupException('Backup schema version is invalid.');
    }
    if (schema > _backupSchemaVersion) {
      throw const LocalBackupException(
        'This backup was created by a newer app version. App update required.',
      );
    }

    // Version 1 is the first portable backup format. Keeping this switch
    // explicit provides the migration boundary for future schema versions.
    if (schema < _backupSchemaVersion) {
      throw LocalBackupException(
        'Backup schema version $schema is not supported by this release.',
      );
    }

    final revision = header['db_revision'];
    if (revision is! int || revision < 1) {
      throw const LocalBackupException('Backup database revision is invalid.');
    }
    final timestamp = header['export_timestamp'];
    if (timestamp is! String || DateTime.tryParse(timestamp) == null) {
      throw const LocalBackupException('Backup export timestamp is invalid.');
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
      if (payload[key] is! List<dynamic>) {
        throw LocalBackupException('Backup data section is missing "$key".');
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
    List<String> columns,
  ) async {
    final rows = await database.customSelect(sql).get();
    return rows.map((row) {
      return {
        for (final column in columns) column: _readValue(row, column),
      };
    }).toList(growable: false);
  }

  Object? _readValue(QueryRow row, String column) {
    return switch (column) {
      'id' || 'user_id' || 'mode' || 'input_snapshot' || 'created_at' ||
      'updated_at' || 'resolved_at' || 'addition_id' || 'deletion_action_id' ||
      'record_id' || 'prayer_type' || 'original_date' ||
      'completed_at' || 'completion_id' || 'plan_revision_id' ||
      'plan_fingerprint' || 'local_account_id' || 'account_mode' ||
      'lifecycle_state' || 'active_local_account_id' || 'payload_json' ||
      'writer_device_id' || 'operation_id' =>
        row.read<String?>(column),
      'revision' || 'entity_version' || 'record_version' =>
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
