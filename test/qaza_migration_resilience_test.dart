import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/migration/shared_preferences_to_drift_migrator.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  QazaRecord record(
    String id, {
    String userId = 'user-a',
    PrayerType prayer = PrayerType.fajr,
    QazaStatus status = QazaStatus.pending,
    DateTime? completedAt,
  }) {
    final date = DateTime.utc(2020, 1, 1);
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: date,
      status: status,
      completedAt: completedAt,
      createdAt: date,
      updatedAt: completedAt ?? date,
    );
  }

  Future<SharedPreferences> prefsWith(Map<String, dynamic> recordsByUser) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesToDriftMigrator.legacyStorageKey:
          jsonEncode({'recordsByUser': recordsByUser}),
    });
    return SharedPreferences.getInstance();
  }

  test('fresh install with no legacy cache completes safely', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await SharedPreferencesToDriftMigrator(
      database: db,
      preferences: prefs,
    ).migrate();

    expect(result.migratedRecordCount, 0);
    expect(prefs.getBool(SharedPreferencesToDriftMigrator.migrationKey), true);
    expect(
      prefs.getInt(SharedPreferencesToDriftMigrator.migrationVersionKey),
      SharedPreferencesToDriftMigrator.migrationVersion,
    );
  });

  test('migrates records, deduplicates by prayer/date, and is idempotent', () async {
    final pending = record('pending-id');
    final completed = record(
      'completed-id',
      status: QazaStatus.completed,
      completedAt: DateTime.utc(2026, 1, 1),
    );
    final duplicatePending = pending.copyWith(id: 'duplicate-id');
    final duplicateCompleted = completed.copyWith(id: 'duplicate-completed-id');
    final prefs = await prefsWith({
      'user-a': [
        pending.toJson(),
        duplicatePending.toJson(),
        completed.toJson(),
        duplicateCompleted.toJson(),
      ],
    });

    final migrator = SharedPreferencesToDriftMigrator(
      database: db,
      preferences: prefs,
    );
    final first = await migrator.migrate();
    final second = await migrator.migrate();

    expect(first.sourceRecordCount, 4);
    expect(first.migratedRecordCount, 2);
    expect(first.duplicateRecordCount, 2);
    expect(second.alreadyComplete, true);
    expect(
      await DriftQazaRepository(db).getRecords(userId: 'user-a'),
      hasLength(2),
    );
  });

  test('malformed legacy JSON does not set completion marker', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesToDriftMigrator.legacyStorageKey: '{invalid-json',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      () => SharedPreferencesToDriftMigrator(
        database: db,
        preferences: prefs,
      ).migrate(),
      throwsStateError,
    );
    expect(
      prefs.getBool(SharedPreferencesToDriftMigrator.migrationKey),
      isNot(true),
    );
  });

  test('user isolation mismatch aborts migration without marking complete', () async {
    final mismatched = record('record-a', userId: 'user-b');
    final prefs = await prefsWith({'user-a': [mismatched.toJson()]});

    expect(
      () => SharedPreferencesToDriftMigrator(
        database: db,
        preferences: prefs,
      ).migrate(),
      throwsStateError,
    );
    expect(
      prefs.getBool(SharedPreferencesToDriftMigrator.migrationKey),
      isNot(true),
    );
    expect(
      await DriftQazaRepository(db).getRecords(userId: 'user-a'),
      isEmpty,
    );
  });

  test('conflicting existing row aborts before completion marker', () async {
    final repository = DriftQazaRepository(db);
    await repository.addRecords([record('conflict')]);
    final conflicting =
        record('conflict').copyWith(status: QazaStatus.completed);
    final prefs = await prefsWith({'user-a': [conflicting.toJson()]});

    expect(
      () => SharedPreferencesToDriftMigrator(
        database: db,
        preferences: prefs,
      ).migrate(),
      throwsStateError,
    );
    expect(
      prefs.getBool(SharedPreferencesToDriftMigrator.migrationKey),
      isNot(true),
    );
  });

  test('unsupported completed marker version is rejected', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesToDriftMigrator.migrationKey: true,
      SharedPreferencesToDriftMigrator.migrationVersionKey: 999,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      () => SharedPreferencesToDriftMigrator(
        database: db,
        preferences: prefs,
      ).migrate(),
      throwsStateError,
    );
  });
}
