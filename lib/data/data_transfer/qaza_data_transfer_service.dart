import 'dart:convert';

import '../../core/constants/app_metadata.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';

class QazaImportAnalysis {
  const QazaImportAnalysis({
    required this.userId,
    required this.records,
    required this.newRecords,
    required this.pendingCompletions,
    required this.alreadyPresentCount,
  });

  final String userId;
  final List<QazaRecord> records;
  final List<QazaRecord> newRecords;
  final List<QazaRecord> pendingCompletions;
  final int alreadyPresentCount;

  int get totalCount => records.length;
  int get newCount => newRecords.length;
  int get completionCount => pendingCompletions.length;
  int get unchangedCount => totalCount - newCount - completionCount;
}

class QazaImportResult {
  const QazaImportResult({
    required this.importedCount,
    required this.addedCount,
    required this.completedCount,
    required this.unchangedCount,
  });

  final int importedCount;
  final int addedCount;
  final int completedCount;
  final int unchangedCount;
}

class QazaDataTransferException implements Exception {
  const QazaDataTransferException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QazaDataTransferService {
  QazaDataTransferService(this._repository);

  final QazaRepository _repository;

  Future<String> exportJson({
    required String userId,
    required String appVersion,
    DateTime? exportedAt,
  }) async {
    if (userId.isEmpty) {
      throw const QazaDataTransferException('A signed-in user is required.');
    }

    final records = await _repository.getRecords(userId: userId);
    final document = <String, dynamic>{
      'schemaVersion': qazaExportSchemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'appVersion': appVersion,
      'records': records.map((record) => record.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Future<QazaImportAnalysis> analyzeImport({
    required String jsonText,
    required String userId,
  }) async {
    if (userId.isEmpty) {
      throw const QazaDataTransferException('A signed-in user is required.');
    }

    final imported = _parseAndValidate(jsonText, userId);
    return _buildAnalysis(imported, userId);
  }

  Future<QazaImportResult> applyImport(QazaImportAnalysis analysis) async {
    final fresh = await _buildAnalysis(analysis.records, analysis.userId);

    if (fresh.newRecords.isNotEmpty) {
      await _repository.addRecords(fresh.newRecords);
    }

    for (final record in fresh.pendingCompletions) {
      final completedAt = record.completedAt;
      if (completedAt == null) continue;
      await _repository.completeRecord(
        userId: fresh.userId,
        recordId: record.id,
        completedAt: completedAt,
      );
    }

    return QazaImportResult(
      importedCount: fresh.totalCount,
      addedCount: fresh.newCount,
      completedCount: fresh.completionCount,
      unchangedCount: fresh.unchangedCount,
    );
  }

  Future<QazaImportAnalysis> _buildAnalysis(
    List<QazaRecord> imported,
    String userId,
  ) async {
    final existing = await _repository.getRecords(userId: userId);
    final byKey = {
      for (final record in existing) _combinationKey(record): record,
    };

    final newRecords = <QazaRecord>[];
    final pendingCompletions = <QazaRecord>[];
    var alreadyPresent = 0;

    for (final record in imported) {
      final existingRecord = byKey[_combinationKey(record)];
      if (existingRecord == null) {
        newRecords.add(record);
        byKey[_combinationKey(record)] = record;
        continue;
      }

      alreadyPresent++;
      if (existingRecord.status == QazaStatus.pending &&
          record.status == QazaStatus.completed) {
        pendingCompletions.add(record);
      }
    }

    return QazaImportAnalysis(
      userId: userId,
      records: List<QazaRecord>.unmodifiable(imported),
      newRecords: List<QazaRecord>.unmodifiable(newRecords),
      pendingCompletions: List<QazaRecord>.unmodifiable(pendingCompletions),
      alreadyPresentCount: alreadyPresent,
    );
  }

  List<QazaRecord> _parseAndValidate(String jsonText, String userId) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const QazaDataTransferException('The selected file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const QazaDataTransferException('The export root must be a JSON object.');
    }
    if (decoded['schemaVersion'] != qazaExportSchemaVersion) {
      throw QazaDataTransferException(
        'Unsupported export schema version: ${decoded['schemaVersion']}.',
      );
    }
    if (decoded['exportedAt'] is! String ||
        _tryParseDate(decoded['exportedAt'] as String) == null) {
      throw const QazaDataTransferException('The export timestamp is invalid.');
    }
    if (decoded['appVersion'] is! String ||
        (decoded['appVersion'] as String).trim().isEmpty) {
      throw const QazaDataTransferException('The app version is missing or invalid.');
    }

    final rawRecords = decoded['records'];
    if (rawRecords is! List<dynamic>) {
      throw const QazaDataTransferException('The records field must be a JSON array.');
    }

    final records = <QazaRecord>[];
    final ids = <String>{};
    final combinationKeys = <String>{};

    for (var index = 0; index < rawRecords.length; index++) {
      final raw = rawRecords[index];
      if (raw is! Map<String, dynamic>) {
        throw QazaDataTransferException('Record ${index + 1} is not an object.');
      }

      final record = _decodeRecord(raw, userId, index + 1);
      if (!ids.add(record.id)) {
        throw QazaDataTransferException(
          'Duplicate record ID in import: ${record.id}.',
        );
      }
      final key = _combinationKey(record);
      if (!combinationKeys.add(key)) {
        throw QazaDataTransferException(
          'Duplicate prayer/date combination in import: $key.',
        );
      }
      records.add(record);
    }

    return records;
  }

  QazaRecord _decodeRecord(
    Map<String, dynamic> raw,
    String currentUserId,
    int position,
  ) {
    String requiredString(String field) {
      final value = raw[field];
      if (value is! String || value.trim().isEmpty) {
        throw QazaDataTransferException(
          'Record $position has an invalid $field.',
        );
      }
      return value;
    }

    requiredString('id');
    requiredString('userId');
    final prayerName = requiredString('prayerType');
    final statusName = requiredString('status');
    final originalDate = _parseRequiredDate(raw['originalDate'], 'originalDate', position);
    final createdAt = _parseRequiredDate(raw['createdAt'], 'createdAt', position);
    final updatedAt = _parseRequiredDate(raw['updatedAt'], 'updatedAt', position);

    PrayerType? prayerType;
    for (final candidate in PrayerType.values) {
      if (candidate.name == prayerName) {
        prayerType = candidate;
        break;
      }
    }
    if (prayerType == null) {
      throw QazaDataTransferException(
        'Record $position has an unknown prayer type: $prayerName.',
      );
    }

    QazaStatus? status;
    for (final candidate in QazaStatus.values) {
      if (candidate.name == statusName) {
        status = candidate;
        break;
      }
    }
    if (status == null) {
      throw QazaDataTransferException(
        'Record $position has an unknown status: $statusName.',
      );
    }

    final rawCompletedAt = raw['completedAt'];
    final completedAt = rawCompletedAt == null
        ? null
        : _parseRequiredDate(rawCompletedAt, 'completedAt', position);

    if (status == QazaStatus.pending && completedAt != null) {
      throw QazaDataTransferException(
        'Record $position is pending but contains completedAt.',
      );
    }
    if (status == QazaStatus.completed && completedAt == null) {
      throw QazaDataTransferException(
        'Record $position is completed but has no completedAt.',
      );
    }
    if (originalDate.year < 1900 || originalDate.year > 2200) {
      throw QazaDataTransferException(
        'Record $position has an out-of-range originalDate.',
      );
    }

    final dateOnly = DateTime(
      originalDate.year,
      originalDate.month,
      originalDate.day,
    );
    final stableId = '${currentUserId}_${prayerType.name}_'
        '${dateOnly.year.toString().padLeft(4, '0')}-'
        '${dateOnly.month.toString().padLeft(2, '0')}-'
        '${dateOnly.day.toString().padLeft(2, '0')}';

    return QazaRecord(
      id: stableId,
      userId: currentUserId,
      prayerType: prayerType,
      originalDate: dateOnly,
      status: status,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  DateTime _parseRequiredDate(Object? value, String field, int position) {
    if (value is! String) {
      throw QazaDataTransferException('Record $position has an invalid $field.');
    }
    final parsed = _tryParseDate(value);
    if (parsed == null) {
      throw QazaDataTransferException('Record $position has an invalid $field.');
    }
    return parsed;
  }

  DateTime? _tryParseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _combinationKey(QazaRecord record) =>
      '${record.userId}|${record.prayerType.name}|'
      '${record.originalDate.year.toString().padLeft(4, '0')}-'
      '${record.originalDate.month.toString().padLeft(2, '0')}-'
      '${record.originalDate.day.toString().padLeft(2, '0')}';
}
