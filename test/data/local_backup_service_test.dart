import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';

QazaRecordsCompanion _record(String id, DateTime date) =>
    QazaRecordsCompanion.insert(
      id: id,
      userId: 'guest',
      prayerType: PrayerType.fajr.name,
      originalDate: date,
      status: QazaStatus.pending.name,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  late AppDatabase database;
  late LocalBackupService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('fresh meta store starts at revision 1', () async {
    expect(await database.isOnboardingCompleted(), isFalse);
    expect(await database.readDbRevision(), 1);
  });

  test('one logical multi-row transaction increments revision once', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_2', DateTime(2025, 1, 2)),
      );
      return <int>[1, 1];
    });

    expect(await database.readDbRevision(), 2);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      2,
    );
  });

  test('export uses the versioned metadata header and complete data envelope',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded = jsonDecode(await service.exportJson());
    expect(decoded['metadata']['app_id'], 'qaza_namaz_app');
    expect(decoded['metadata']['schema_version'], 1);
    expect(decoded['metadata']['db_revision'], 2);
    expect(decoded['metadata']['export_timestamp'], isA<String>());
    expect(decoded['data']['qaza_records'], hasLength(1));
    expect(decoded['data']['local_accounts'], isA<List<dynamic>>());
    expect(decoded['data']['meta_store']['is_onboarding_completed'], false);
  });

  test('malformed import leaves existing local database untouched', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });
    final before = await database.qazaRecordsDao.getAll(userId: 'guest');
    final beforeRevision = await database.readDbRevision();

    expect(
      () => service.importJson('{bad json'),
      throwsA(isA<LocalBackupException>()),
    );

    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .map((record) => record.toJson())
          .toList(),
      before.map((record) => record.toJson()).toList(),
    );
    expect(await database.readDbRevision(), beforeRevision);
  });

  test('newer backup schema is rejected before database mutation', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });
    final decoded = jsonDecode(await service.exportJson())
        as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['schema_version'] = 2;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('App update required'),
        ),
      ),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('restoring an older revision never rewinds the local revision', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });
    final olderBackup = await service.exportJson();

    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_2', DateTime(2025, 1, 2)),
      );
    });
    expect(await database.readDbRevision(), 3);

    final restored = await service.importJson(olderBackup);

    expect(restored.recordCount, 1);
    expect(await database.readDbRevision(), 4);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).map((r) => r.id),
      ['guest_fajr_1'],
    );
  });
}
