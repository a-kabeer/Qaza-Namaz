import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/migration/shared_preferences_to_drift_migrator.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecord record({
  required String id,
  required String userId,
  required PrayerType prayerType,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  return QazaRecord(
    id: id,
    userId: userId,
    prayerType: prayerType,
    originalDate: date,
    status: status,
    completedAt: completedAt,
    createdAt: date,
    updatedAt: completedAt ?? date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('migrates all users and preserves completed records', () async {
    final preferences = await SharedPreferences.getInstance();
    final first = record(
      id: 'a1',
      userId: 'user-a',
      prayerType: PrayerType.fajr,
      date: DateTime.utc(2025, 1, 1),
    );
    final second = record(
      id: 'b1',
      userId: 'user-b',
      prayerType: PrayerType.witr,
      date: DateTime.utc(2025, 2, 1),
      status: QazaStatus.completed,
      completedAt: DateTime.utc(2026, 1, 1),
    );
    await preferences.setString(
      SharedPreferencesToDriftMigrator.legacyStorageKey,
      jsonEncode({
        'schemaVersion': 1,
        'recordsByUser': {
          'user-a': [first.toJson()],
          'user-b': [second.toJson()],
        },
      }),
    );

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    ).migrate();

    expect(result.sourceRecordCount, 2);
    expect(result.migratedRecordCount, 2);
    expect(await database.qazaRecordsDao.count(userId: 'user-a'), 1);
    expect(await database.qazaRecordsDao.count(userId: 'user-b'), 1);
    expect(
      (await database.qazaRecordsDao.findById(userId: 'user-b', id: 'b1'))!.status,
      QazaStatus.completed,
    );
    expect(preferences.getBool(SharedPreferencesToDriftMigrator.migrationKey), true);
  });

  test('deduplicates the same logical prayer without losing completion', () async {
    final preferences = await SharedPreferences.getInstance();
    final date = DateTime.utc(2025, 3, 1);
    final pending = record(
      id: 'pending-id',
      userId: 'user-a',
      prayerType: PrayerType.asr,
      date: date,
    );
    final completed = record(
      id: 'completed-id',
      userId: 'user-a',
      prayerType: PrayerType.asr,
      date: date,
      status: QazaStatus.completed,
      completedAt: DateTime.utc(2026, 2, 1),
    );
    await preferences.setString(
      SharedPreferencesToDriftMigrator.legacyStorageKey,
      jsonEncode({
        'schemaVersion': 1,
        'recordsByUser': {
          'user-a': [pending.toJson(), completed.toJson()],
        },
      }),
    );

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    ).migrate();

    expect(result.sourceRecordCount, 2);
    expect(result.migratedRecordCount, 1);
    expect(result.duplicateRecordCount, 1);
    expect(await database.qazaRecordsDao.count(userId: 'user-a'), 1);
    final migrated = (await database.qazaRecordsDao.getPage(userId: 'user-a')).single;
    expect(migrated.status, QazaStatus.completed);
    expect(migrated.completedAt, DateTime.utc(2026, 2, 1));
  });

  test('does not mark migration complete when legacy data is invalid', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SharedPreferencesToDriftMigrator.legacyStorageKey,
      '{not-valid-json',
    );

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      SharedPreferencesToDriftMigrator(
        database: database,
        preferences: preferences,
      ).migrate(),
      throwsA(isA<StateError>()),
    );
    expect(preferences.getBool(SharedPreferencesToDriftMigrator.migrationKey), isNot(true));
  });

  test('migration is idempotent after successful completion', () async {
    final preferences = await SharedPreferences.getInstance();
    final item = record(
      id: 'same',
      userId: 'user-a',
      prayerType: PrayerType.isha,
      date: DateTime.utc(2025, 4, 1),
    );
    await preferences.setString(
      SharedPreferencesToDriftMigrator.legacyStorageKey,
      jsonEncode({
        'schemaVersion': 1,
        'recordsByUser': {'user-a': [item.toJson()]},
      }),
    );

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final migrator = SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    );

    final first = await migrator.migrate();
    final second = await migrator.migrate();

    expect(first.migratedRecordCount, 1);
    expect(second.alreadyComplete, true);
    expect(await database.qazaRecordsDao.count(userId: 'user-a'), 1);
  });
}
