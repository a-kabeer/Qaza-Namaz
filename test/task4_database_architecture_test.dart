import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/migration/shared_preferences_to_drift_migrator.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecord _record({
  String userId = 'user-a',
  String id = 'user-a_fajr_2026-01-01',
  PrayerType prayerType = PrayerType.fajr,
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 2, 10);
  return QazaRecord(
    id: id,
    userId: userId,
    prayerType: prayerType,
    originalDate: DateTime.utc(2026, 1, 1),
    status: status,
    completedAt: completedAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<void> _seedLegacySnapshot(
  SharedPreferences preferences,
  Map<String, List<QazaRecord>> recordsByUser, {
  bool includeSchemaVersion = true,
}) async {
  final payload = <String, dynamic>{
    if (includeSchemaVersion) 'schemaVersion': 1,
    'recordsByUser': {
      for (final entry in recordsByUser.entries)
        entry.key: entry.value.map((record) => record.toJson()).toList(),
    },
  };
  await preferences.setString(
    SharedPreferencesToDriftMigrator.legacyStorageKey,
    jsonEncode(payload),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Qaza record preserves the complete database field set', () {
    final completedAt = DateTime.utc(2026, 1, 3, 10);
    final record = _record(
      status: QazaStatus.completed,
      completedAt: completedAt,
    );
    final json = record.toJson();

    expect(
      json.keys,
      containsAll([
        'id',
        'userId',
        'prayerType',
        'originalDate',
        'status',
        'completedAt',
        'createdAt',
        'updatedAt',
      ]),
    );

    final restored = QazaRecord.fromJson(json);
    expect(restored.id, record.id);
    expect(restored.userId, record.userId);
    expect(restored.prayerType, record.prayerType);
    expect(restored.originalDate, record.originalDate);
    expect(restored.status, record.status);
    expect(restored.completedAt, completedAt);
    expect(restored.createdAt, record.createdAt);
    expect(restored.updatedAt, record.updatedAt);
  });

  test('legacy snapshot migrates into Drift and records migration version',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await _seedLegacySnapshot(preferences, {
      'user-a': [_record()],
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    ).migrate();

    expect(result.migratedRecordCount, 1);
    expect(await database.qazaRecordsDao.count(userId: 'user-a'), 1);
    expect(
      preferences.getInt(SharedPreferencesToDriftMigrator.migrationVersionKey),
      SharedPreferencesToDriftMigrator.migrationVersion,
    );
    expect(preferences.getBool(SharedPreferencesToDriftMigrator.migrationKey),
        true);
  });

  test('legacy v1 snapshot without schemaVersion remains migratable', () async {
    final preferences = await SharedPreferences.getInstance();
    await _seedLegacySnapshot(
      preferences,
      {
        'user-a': [_record()]
      },
      includeSchemaVersion: false,
    );

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final result = await SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    ).migrate();

    expect(result.migratedRecordCount, 1);
    expect(await database.qazaRecordsDao.count(userId: 'user-a'), 1);
  });

  test(
      'unsupported completed migration version is rejected instead of silently reset',
      () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesToDriftMigrator.migrationKey: true,
      SharedPreferencesToDriftMigrator.migrationVersionKey:
          SharedPreferencesToDriftMigrator.migrationVersion + 1,
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(
      SharedPreferencesToDriftMigrator(
        database: database,
        preferences: preferences,
      ).migrate(),
      throwsA(isA<StateError>()),
    );
  });

  test('migrated records remain isolated by Firebase UID', () async {
    final preferences = await SharedPreferences.getInstance();
    await _seedLegacySnapshot(preferences, {
      'user-a': [_record(userId: 'user-a')],
      'user-b': [
        _record(
          userId: 'user-b',
          id: 'user-b_witr_2026-01-01',
          prayerType: PrayerType.witr,
        ),
      ],
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await SharedPreferencesToDriftMigrator(
      database: database,
      preferences: preferences,
    ).migrate();

    final userA = await database.qazaRecordsDao.getPage(userId: 'user-a');
    final userB = await database.qazaRecordsDao.getPage(userId: 'user-b');
    expect(userA, hasLength(1));
    expect(userB, hasLength(1));
    expect(userA.single.userId, 'user-a');
    expect(userB.single.userId, 'user-b');
    expect(userA.single.prayerType, PrayerType.fajr);
    expect(userB.single.prayerType, PrayerType.witr);
  });
}
