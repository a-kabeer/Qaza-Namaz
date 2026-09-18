import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_record.dart';
import '../local/database/app_database.dart';

/// One-time migration from the legacy SharedPreferences cache to Drift/SQLite.
///
/// SharedPreferences remains available only to this upgrade path. It is not a
/// runtime local-store implementation after the migration boundary.
class SharedPreferencesToDriftMigrator {
  SharedPreferencesToDriftMigrator({
    required AppDatabase database,
    required SharedPreferences preferences,
    this.storageKey = legacyStorageKey,
  })  : _database = database,
        _preferences = preferences;

  static const int migrationVersion = 1;
  static const String legacyStorageKey = 'qaza_offline_cache_v1';
  static const String migrationKey = 'qaza_drift_migration_v1_complete';
  static const String migrationVersionKey = '${migrationKey}_version';

  final AppDatabase _database;
  final SharedPreferences _preferences;
  final String storageKey;

  Future<void> _migrationLock = Future<void>.value();

  /// Serializes concurrent callers in the same application process.
  Future<MigrationResult> migrate() {
    final result = _migrationLock.then((_) => _migrateOnce());
    _migrationLock = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<MigrationResult> _migrateOnce() async {
    final marker = _preferences.getBool(migrationKey) == true;
    final storedVersion = _preferences.getInt(migrationVersionKey);
    if (marker) {
      if (storedVersion != migrationVersion) {
        throw StateError(
          'Unsupported Qaza migration marker version: '
          '${storedVersion ?? 'missing'} (expected $migrationVersion).',
        );
      }
      return const MigrationResult(alreadyComplete: true);
    }

    if (storedVersion != null && storedVersion > migrationVersion) {
      throw StateError(
        'Qaza migration is newer than this app: version $storedVersion.',
      );
    }

    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      await _markComplete();
      return const MigrationResult();
    }

    final snapshot = _decode(raw);
    final normalized = <String, List<QazaRecord>>{};
    var sourceCount = 0;
    for (final entry in snapshot.recordsByUser.entries) {
      sourceCount += entry.value.length;
      normalized[entry.key] = _normalizeRecords(entry.key, entry.value);
    }

    final expectedCount = normalized.values.fold<int>(
      0,
      (sum, records) => sum + records.length,
    );

    await _database.transaction(() async {
      for (final entry in normalized.entries) {
        for (final record in entry.value) {
          final existing = await _database.qazaRecordsDao.findById(
            userId: entry.key,
            id: record.id,
          );
          if (existing == null) {
            await _database.qazaRecordsDao.insertRecord(_toCompanion(record));
          } else if (!_sameRecord(existing, record)) {
            throw StateError(
              'Migration conflict for Qaza record ${record.id} belonging to '
              'user ${entry.key}.',
            );
          }
        }
      }
    });

    var targetCount = 0;
    for (final entry in normalized.entries) {
      final count = await _database.qazaRecordsDao.count(userId: entry.key);
      if (count < entry.value.length) {
        throw StateError(
          'Qaza migration verification failed for user ${entry.key}: '
          'expected at least ${entry.value.length} records but found $count.',
        );
      }
      targetCount += count;
    }

    if (targetCount < expectedCount) {
      throw StateError(
        'Qaza migration verification failed: expected at least '
        '$expectedCount normalized records but found $targetCount.',
      );
    }

    await _markComplete();
    return MigrationResult(
      sourceRecordCount: sourceCount,
      migratedRecordCount: expectedCount,
      duplicateRecordCount: sourceCount - expectedCount,
    );
  }

  Future<void> _markComplete() async {
    final versionWritten =
        await _preferences.setInt(migrationVersionKey, migrationVersion);
    if (!versionWritten) {
      throw StateError('Could not persist Qaza migration version marker.');
    }
    final markerWritten = await _preferences.setBool(migrationKey, true);
    if (!markerWritten) {
      throw StateError('Could not persist Qaza migration completion marker.');
    }
  }

  List<QazaRecord> _normalizeRecords(String userId, List<QazaRecord> records) {
    final byKey = <String, QazaRecord>{};
    for (final input in records) {
      if (input.userId != userId) {
        throw StateError(
          'Qaza migration found a user-isolation mismatch for record '
          '${input.id}.',
        );
      }

      // Qaza dates are calendar dates, not instants. Canonicalize legacy
      // timezone-aware values before deduplication and persistence so the
      // same missed calendar date cannot become two SQLite rows.
      final record = input.copyWith(
        originalDate: QazaDate.normalize(input.originalDate),
      );
      final key = '${record.userId}|${record.prayerType.name}|'
          '${QazaDate.key(record.originalDate)}';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = record;
        continue;
      }
      if (existing.status == QazaStatus.completed &&
          record.status != QazaStatus.completed) {
        continue;
      }
      if (record.status == QazaStatus.completed &&
          existing.status != QazaStatus.completed) {
        byKey[key] = record.copyWith(
          completedAt: record.completedAt ?? existing.completedAt,
          createdAt: existing.createdAt.isBefore(record.createdAt)
              ? existing.createdAt
              : record.createdAt,
          updatedAt: existing.updatedAt.isAfter(record.updatedAt)
              ? existing.updatedAt
              : record.updatedAt,
        );
        continue;
      }
      if (existing.status == QazaStatus.completed &&
          record.status == QazaStatus.completed) {
        final earliest = existing.completedAt == null
            ? record.completedAt
            : record.completedAt == null
                ? existing.completedAt
                : (existing.completedAt!.isBefore(record.completedAt!)
                    ? existing.completedAt
                    : record.completedAt);
        byKey[key] = existing.copyWith(
          completedAt: earliest,
          createdAt: existing.createdAt.isBefore(record.createdAt)
              ? existing.createdAt
              : record.createdAt,
          updatedAt: existing.updatedAt.isAfter(record.updatedAt)
              ? existing.updatedAt
              : record.updatedAt,
        );
      }
    }
    return byKey.values.toList(growable: false);
  }

  OfflineSnapshot _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root value must be a JSON object.');
      }
      final rawUsers = decoded['recordsByUser'];
      if (rawUsers == null) {
        return const OfflineSnapshot(recordsByUser: {});
      }
      if (rawUsers is! Map<String, dynamic>) {
        throw const FormatException('recordsByUser must be a JSON object.');
      }

      final recordsByUser = <String, List<QazaRecord>>{};
      for (final entry in rawUsers.entries) {
        if (entry.key.trim().isEmpty) {
          throw const FormatException('A user ID cannot be empty.');
        }
        if (entry.value is! List<dynamic>) {
          throw FormatException(
            'recordsByUser.${entry.key} must be a JSON array.',
          );
        }
        recordsByUser[entry.key] = (entry.value as List<dynamic>).map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'A Qaza record must be a JSON object.',
            );
          }
          return QazaRecord.fromJson(item);
        }).toList(growable: false);
      }
      return OfflineSnapshot(recordsByUser: recordsByUser);
    } catch (error) {
      throw StateError('Cannot safely migrate Qaza cache: $error');
    }
  }

  QazaRecordsCompanion _toCompanion(QazaRecord record) =>
      QazaRecordsCompanion.insert(
        id: record.id,
        userId: record.userId,
        prayerType: record.prayerType.name,
        originalDate: record.originalDate,
        status: record.status.name,
        completedAt: record.completedAt == null
            ? const Value.absent()
            : Value(record.completedAt),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );

  bool _sameRecord(dynamic row, QazaRecord record) =>
      row.userId == record.userId &&
      row.prayerType == record.prayerType.name &&
      row.originalDate == record.originalDate &&
      row.status == record.status.name &&
      row.completedAt == record.completedAt &&
      row.createdAt == record.createdAt &&
      row.updatedAt == record.updatedAt;
}

class OfflineSnapshot {
  const OfflineSnapshot({required this.recordsByUser});
  final Map<String, List<QazaRecord>> recordsByUser;
}

class MigrationResult {
  const MigrationResult({
    this.sourceRecordCount = 0,
    this.migratedRecordCount = 0,
    this.duplicateRecordCount = 0,
    this.alreadyComplete = false,
  });
  final int sourceRecordCount;
  final int migratedRecordCount;
  final int duplicateRecordCount;
  final bool alreadyComplete;
}
