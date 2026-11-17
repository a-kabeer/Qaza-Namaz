import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/database/app_database.dart';
import '../local/database/database_encryption.dart';
import '../local/database/database_manager.dart';

enum LegacyMigrationStatus {
  noLegacyDb,
  alreadyMigrated,
  migrated,
  emptyLegacyDb,
  failed,
}

class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.status,
    required this.recordsMigrated,
    this.profilesMigrated = 0,
    this.dailyLogsMigrated = 0,
    this.details,
  });

  final LegacyMigrationStatus status;
  final int recordsMigrated;
  final int profilesMigrated;
  final int dailyLogsMigrated;
  final String? details;
}

/// Safely and idempotently migrates legacy encrypted Drift SQLite database
/// records into the unified encrypted PowerSync local database.
///
/// Guarantees:
/// 1. Non-destructive: Read-only on legacy databases; source files are NEVER deleted.
/// 2. Idempotent & Resumable: Uses insertOrIgnore / replace logic with post-verification.
///    If interrupted, the completion marker is not written and the migration resumes cleanly.
/// 3. Workspace-scoped: Guest and Google accounts migrate independently to their own databases.
class LegacyDriftToPowerSyncMigrator {
  const LegacyDriftToPowerSyncMigrator({
    this.documentsDirectoryProvider,
    this.keyStore,
  });

  final Future<Directory> Function()? documentsDirectoryProvider;
  final DatabaseEncryptionKeyStore? keyStore;

  static const String migrationMarkerKey = 'legacy_drift_migration_completed';

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.now().toUtc();
    if (raw is int) {
      if (raw < 100000000000) {
        // Unix epoch in seconds (Drift standard SQLite representation)
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      } else {
        // Unix epoch in milliseconds
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
    }
    return DateTime.parse(raw.toString()).toUtc();
  }

  static DateTime? _parseNullableTimestamp(dynamic raw) {
    if (raw == null) return null;
    return _parseTimestamp(raw);
  }

  Future<LegacyMigrationResult> migrateIfNeeded({
    required String workspaceId,
    required AppDatabase targetPowerSyncDb,
    String? customLegacyFilePath,
    Future<Directory> Function()? documentsDirectoryProvider,
    String? legacyEncryptionKey,
  }) async {
    // 1. Check if already migrated
    final markerRows = await targetPowerSyncDb.customSelect(
      "SELECT value FROM meta_store WHERE key = ? LIMIT 1",
      variables: [const Variable<String>(migrationMarkerKey)],
    ).get();

    if (markerRows.isNotEmpty) {
      return const LegacyMigrationResult(
        status: LegacyMigrationStatus.alreadyMigrated,
        recordsMigrated: 0,
        details: 'Already migrated',
      );
    }

    // 2. Resolve legacy database file path
    final dirProvider =
        documentsDirectoryProvider ?? this.documentsDirectoryProvider;
    final legacyFile = customLegacyFilePath != null
        ? File(customLegacyFilePath)
        : await _resolveLegacyFile(workspaceId, dirProvider);

    if (!legacyFile.existsSync()) {
      await _recordMigrationMarker(
        targetPowerSyncDb,
        'no_legacy_database_found',
      );
      return const LegacyMigrationResult(
        status: LegacyMigrationStatus.noLegacyDb,
        recordsMigrated: 0,
        details: 'No legacy database file found',
      );
    }

    // 3. Open legacy database with its encryption key
    String? encryptionKey = legacyEncryptionKey;
    if (encryptionKey == null) {
      try {
        final effectiveKeyStore = keyStore ?? DatabaseEncryptionKeyStore();
        encryptionKey = workspaceId.startsWith('google_')
            ? await effectiveKeyStore.readOrCreateForWorkspace(workspaceId)
            : await effectiveKeyStore.readOrCreate();
      } catch (_) {
        return const LegacyMigrationResult(
          status: LegacyMigrationStatus.failed,
          recordsMigrated: 0,
          details: 'Could not resolve encryption key for legacy database',
        );
      }
    }

    final effectiveKey = encryptionKey;
    final legacyDb = AppDatabase(
      NativeDatabase.createInBackground(
        legacyFile,
        setup: (rawDb) {
          final escapedKey = effectiveKey.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escapedKey';");
          rawDb.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );

    try {
      // 4. Check if legacy database contains records
      final legacyQazaCountRows = await legacyDb.customSelect(
        "SELECT count(*) as c FROM sqlite_master WHERE type = 'table' AND name = 'qaza_records'",
      ).get();

      if (legacyQazaCountRows.isEmpty ||
          legacyQazaCountRows.first.read<int>('c') == 0) {
        await _recordMigrationMarker(targetPowerSyncDb, 'legacy_empty_schema');
        return const LegacyMigrationResult(
          status: LegacyMigrationStatus.emptyLegacyDb,
          recordsMigrated: 0,
        );
      }

      final legacyQazaRows = await legacyDb.customSelect(
        "SELECT * FROM qaza_records",
      ).get();

      // Check account_profiles
      final hasProfilesTable = await _tableExists(legacyDb, 'account_profiles');
      final legacyProfileRows = hasProfilesTable
          ? await legacyDb.customSelect("SELECT * FROM account_profiles").get()
          : <QueryRow>[];

      // Check daily_salah_logs
      final hasDailyTable = await _tableExists(legacyDb, 'daily_salah_logs');
      final legacyDailyRows = hasDailyTable
          ? await legacyDb.customSelect("SELECT * FROM daily_salah_logs").get()
          : <QueryRow>[];

      // Check meta_store
      final hasMetaTable = await _tableExists(legacyDb, 'meta_store');
      final legacyMetaRows = hasMetaTable
          ? await legacyDb.customSelect("SELECT * FROM meta_store").get()
          : <QueryRow>[];

      // Check qaza_additions
      final hasAdditionsTable = await _tableExists(legacyDb, 'qaza_additions');
      final legacyAdditionRows = hasAdditionsTable
          ? await legacyDb.customSelect("SELECT * FROM qaza_additions").get()
          : <QueryRow>[];

      if (legacyQazaRows.isEmpty &&
          legacyProfileRows.isEmpty &&
          legacyDailyRows.isEmpty) {
        await _recordMigrationMarker(targetPowerSyncDb, 'legacy_db_empty');
        return const LegacyMigrationResult(
          status: LegacyMigrationStatus.emptyLegacyDb,
          recordsMigrated: 0,
        );
      }

      // 5. Migrate data into target PowerSync database
      // A. Migrate account_profiles
      var profilesMigrated = 0;
      for (final row in legacyProfileRows) {
        final id = row.read<String>('id');
        final email = row.readNullable<String>('email');
        final displayName = row.readNullable<String>('display_name');
        final gender = row.readNullable<String>('gender');
        final calculationMethod =
            row.readNullable<String>('calculation_method');
        final madhab = row.readNullable<String>('madhab');
        final dailyTarget = row.readNullable<int>('daily_target');
        final birthDate = row.readNullable<String>('birth_date');
        final maturityDate = row.readNullable<String>('maturity_date');
        final createdAt = row.readNullable<String>('created_at');
        final updatedAt = row.readNullable<String>('updated_at');

        await targetPowerSyncDb.customInsert(
          '''INSERT OR IGNORE INTO account_profiles
             (id, email, display_name, gender, calculation_method, madhab,
              daily_target, birth_date, maturity_date, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable.withString(id),
            Variable(email),
            Variable(displayName),
            Variable(gender),
            Variable(calculationMethod),
            Variable(madhab),
            Variable(dailyTarget),
            Variable(birthDate),
            Variable(maturityDate),
            Variable(createdAt),
            Variable(updatedAt),
          ],
        );
        profilesMigrated++;
      }

      // B. Migrate qaza_additions
      for (final row in legacyAdditionRows) {
        final id = row.read<String>('id');
        final userId = row.read<String>('user_id');
        final prayerType = row.read<String>('prayer_type');
        final count = row.read<int>('count');
        final notes = row.readNullable<String>('notes');
        final addedAt = row.readNullable<String>('added_at');

        await targetPowerSyncDb.customInsert(
          '''INSERT OR IGNORE INTO qaza_additions
             (id, user_id, prayer_type, count, notes, added_at)
             VALUES (?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable.withString(id),
            Variable.withString(userId),
            Variable.withString(prayerType),
            Variable.withInt(count),
            Variable(notes),
            Variable(addedAt),
          ],
        );
      }

      // C. Migrate qaza_records in batches (grouped by userId for DAO safety)
      var recordsMigrated = 0;
      final companionsByUser = <String, List<QazaRecordsCompanion>>{};
      for (final row in legacyQazaRows) {
        final id = row.read<String>('id');
        final userId = row.read<String>('user_id');
        final prayerType = row.read<String>('prayer_type');

        // Parse originalDate, completedAt, createdAt, updatedAt safely
        final originalDate = _parseTimestamp(row.data['original_date']);
        final status = row.read<String>('status');
        final completedAt = _parseNullableTimestamp(row.data['completed_at']);
        final completionId = row.readNullable<String>('completion_id');
        final recordVersion = row.readNullable<int>('record_version') ?? 1;
        final createdAt = _parseTimestamp(row.data['created_at']);
        final updatedAt = row.data['updated_at'] != null
            ? _parseTimestamp(row.data['updated_at'])
            : createdAt;

        companionsByUser.putIfAbsent(userId, () => <QazaRecordsCompanion>[]).add(
          QazaRecordsCompanion.insert(
            id: id,
            userId: userId,
            prayerType: prayerType,
            originalDate: originalDate,
            status: status,
            completedAt: Value(completedAt),
            completionId: Value(completionId),
            recordVersion: Value(recordVersion),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
      }

      for (final userCompanions in companionsByUser.values) {
        final insertedIds = await targetPowerSyncDb.qazaRecordsDao
            .insertRecordsReturningInsertedIds(userCompanions);
        recordsMigrated += insertedIds.length;
      }

      // D. Migrate daily_salah_logs
      var dailyLogsMigrated = 0;
      for (final row in legacyDailyRows) {
        final id = row.readNullable<String>('id') ??
            '${row.read<String>('user_id')}_${row.read<String>('prayer_date')}_${row.read<String>('prayer_type')}';
        final userId = row.read<String>('user_id');
        final prayerType = row.read<String>('prayer_type');
        final prayerDate = row.read<String>('prayer_date');
        final status = row.read<String>('status');
        final trackerCreatedQazaId =
            row.data['tracker_created_qaza_id'] as String?;
        final linkedQazaId = row.data['linked_qaza_id'] as String?;
        final completionSyncId = row.data['completion_sync_id'] as String?;
        final updatedAt = row.data['updated_at'] as String? ??
            DateTime.now().toUtc().toIso8601String();
        final createdAt =
            row.data['created_at'] as String? ?? updatedAt;

        await targetPowerSyncDb.customInsert(
          '''INSERT OR IGNORE INTO daily_salah_logs
             (id, user_id, prayer_date, prayer_type, status, tracker_created_qaza_id, linked_qaza_id, completion_sync_id, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          variables: [
            Variable.withString(id),
            Variable.withString(userId),
            Variable.withString(prayerDate),
            Variable.withString(prayerType),
            Variable.withString(status),
            Variable(trackerCreatedQazaId),
            Variable(linkedQazaId),
            Variable(completionSyncId),
            Variable.withString(createdAt),
            Variable.withString(updatedAt),
          ],
        );
        dailyLogsMigrated++;
      }

      // E. Migrate meta_store preferences
      for (final row in legacyMetaRows) {
        final key = row.read<String>('key');
        final value = row.read<String>('value');
        if (key != migrationMarkerKey && key != 'schema_version') {
          await targetPowerSyncDb.customInsert(
            '''INSERT OR IGNORE INTO meta_store (key, value) VALUES (?, ?)''',
            variables: [Variable.withString(key), Variable.withString(value)],
          );
        }
      }

      // F. Migrate qaza_profile_plan_provenance if present in legacy
      final hasProvenanceTable =
          await _tableExists(legacyDb, 'qaza_profile_plan_provenance');
      if (hasProvenanceTable) {
        final provenanceRows = await legacyDb
            .customSelect("SELECT * FROM qaza_profile_plan_provenance")
            .get();
        for (final row in provenanceRows) {
          final recordId = row.read<String>('record_id');
          final userId = row.read<String>('user_id');
          final planRevisionId = row.read<String>('plan_revision_id');
          final planFingerprint = row.read<String>('plan_fingerprint');
          await targetPowerSyncDb.customInsert(
            '''INSERT OR IGNORE INTO qaza_profile_plan_provenance
               (record_id, user_id, plan_revision_id, plan_fingerprint)
               VALUES (?, ?, ?, ?)''',
            variables: [
              Variable.withString(recordId),
              Variable.withString(userId),
              Variable.withString(planRevisionId),
              Variable.withString(planFingerprint),
            ],
          );
        }
      }

      // 6. Verification
      final targetRecords =
          await (targetPowerSyncDb.select(targetPowerSyncDb.qazaRecords)).get();
      if (legacyQazaRows.isNotEmpty && targetRecords.isEmpty) {
        throw StateError(
          'Migration verification failed: 0 records found in target database after copying ${legacyQazaRows.length} rows.',
        );
      }

      // 7. Mark migration complete
      await _recordMigrationMarker(
        targetPowerSyncDb,
        'migrated_${DateTime.now().toUtc().toIso8601String()}',
      );

      return LegacyMigrationResult(
        status: LegacyMigrationStatus.migrated,
        recordsMigrated: recordsMigrated,
        profilesMigrated: profilesMigrated,
        dailyLogsMigrated: dailyLogsMigrated,
        details: 'Successfully migrated from legacy Drift database',
      );
    } finally {
      await legacyDb.close();
    }
  }

  Future<File> _resolveLegacyFile(
    String workspaceId, [
    Future<Directory> Function()? customDirProvider,
  ]) async {
    final effectiveProvider =
        customDirProvider ?? documentsDirectoryProvider;
    final appDir = effectiveProvider != null
        ? await effectiveProvider()
        : await getApplicationDocumentsDirectory();

    final id = workspaceId.trim();
    if (id == 'guest' ||
        id.isEmpty ||
        id.startsWith('guest_') ||
        id.startsWith('guest:')) {
      return File(p.join(appDir.path, 'qaza_namaz.sqlite'));
    }

    final fileName = DatabaseManager.googleFileNameForWorkspaceId(id);
    return File(p.join(appDir.path, fileName));
  }

  Future<bool> _tableExists(AppDatabase db, String tableName) async {
    final rows = await db.customSelect(
      "SELECT count(*) as c FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty && rows.first.read<int>('c') > 0;
  }

  Future<void> _recordMigrationMarker(AppDatabase db, String detail) async {
    await db.customInsert(
      '''INSERT OR REPLACE INTO meta_store (key, value) VALUES (?, ?)''',
      variables: [
        const Variable<String>(migrationMarkerKey),
        Variable.withString(detail),
      ],
    );
  }
}
