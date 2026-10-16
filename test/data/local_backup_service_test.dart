import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

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

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await database.customInsert(
      '''INSERT INTO app_session_state (id, active_local_account_id)
         VALUES (1, ?)''',
      variables: [Variable.withString('guest')],
    );
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

  test('no-op transaction does not advance db revision', () async {
    final beforeRevision = await database.readDbRevision();

    final changed = await database.transactionWithRevision(() async => false);

    expect(changed, isFalse);
    expect(await database.readDbRevision(), beforeRevision);
  });

  test('failed transaction rolls back state and db revision', () async {
    final beforeRevision = await database.readDbRevision();

    expect(
      () => database.transactionWithRevision(() async {
        await database.qazaRecordsDao.insertRecord(
          _record('guest_fajr_failed', DateTime(2025, 1, 1)),
        );
        throw StateError('forced transaction failure');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await database.readDbRevision(), beforeRevision);
    expect(
      await database.qazaRecordsDao.getAll(userId: 'guest'),
      isEmpty,
    );
  });

  test('export uses the stable versioned metadata header', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded = jsonDecode(await service.exportJson());
    expect(decoded['metadata']['app_id'], 'qaza_namaz_app');
    expect(decoded['metadata']['backup_schema_version'], 1);
    expect(
      decoded['metadata']['database_schema_version'],
      database.schemaVersion,
    );
    expect(decoded['metadata']['db_revision'], 2);
    expect(decoded['metadata']['export_timestamp'], isA<String>());
    expect(decoded['data']['qaza_records'], hasLength(1));
    expect(decoded['data']['local_accounts'], isA<List<dynamic>>());
    expect(decoded['data']['daily_salah_logs'], isA<List<dynamic>>());
    expect(decoded['data']['meta_store']['is_onboarding_completed'], false);
    expect(
      decoded['data']['meta_store']['daily_salah_tracking_enabled'],
      false,
    );
  });

  test('backup preserves daily Salah logs and the tracking preference', () async {
    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status,
          tracker_created_qaza_id, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withString('2026-10-16'),
        Variable.withString('fajr'),
        Variable.withString('prayed'),
        Variable<String>(null),
        Variable.withString(DateTime.utc(2026, 10, 16).toIso8601String()),
      ],
    );
    await database.setDailySalahTrackingEnabled(true);
    final backup = await service.exportJson();

    await database.customStatement('DELETE FROM daily_salah_logs');
    await database.setDailySalahTrackingEnabled(false);
    expect(await database.isDailySalahTrackingEnabled(), isFalse);

    await service.importJson(backup);

    expect(await database.isDailySalahTrackingEnabled(), isTrue);
    final logs = await database.customSelect(
      'SELECT user_id, prayer_date, prayer_type, status '
      'FROM daily_salah_logs',
    ).get();
    expect(logs, hasLength(1));
    expect(logs.single.read<String>('prayer_date'), '2026-10-16');
    expect(logs.single.read<String>('status'), 'prayed');
  });

  test('schema 19 backups without daily tracking fields remain importable',
      () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    final metadata = decoded['metadata'] as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    metadata['database_schema_version'] = 19;
    data.remove('daily_salah_logs');
    (data['meta_store'] as Map<String, dynamic>)
        .remove('daily_salah_tracking_enabled');

    await service.importJson(jsonEncode(decoded));

    expect(await database.isDailySalahTrackingEnabled(), isFalse);
    final logs = await database.customSelect(
      'SELECT user_id FROM daily_salah_logs',
    ).get();
    expect(logs, isEmpty);
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

  test('wrong app id is rejected before database mutation', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['app_id'] = 'other_app';

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('newer backup schema is rejected before database mutation', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['backup_schema_version'] = 2;

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

  test('export normalizes a supplied timestamp to UTC', () async {
    final json = await service.exportJson(
      exportedAt: DateTime(2026, 10, 8, 12, 34, 56),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final timestamp = (decoded['metadata']
        as Map<String, dynamic>)['export_timestamp'] as String;

    expect(timestamp, '2026-10-08T12:34:56.000Z');
  });

  test('unsupported older backup schema is rejected without mutation',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2025, 1, 1)),
      );
    });

    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['backup_schema_version'] = 0;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('invalid'),
        ),
      ),
    );
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
    expect(await database.readDbRevision(), 2);
  });

  test('restoring an older revision never rewinds the local revision',
      () async {
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

  test('backup restore preserves the receiving device instance id', () async {
    await database.customInsert(
      'INSERT INTO device_metadata (id, device_instance_id) VALUES (1, ?)',
      variables: [Variable.withString('device-local-test')],
    );

    final backup = await service.exportJson();
    await service.importJson(backup);

    final after = await database
        .customSelect(
          'SELECT device_instance_id FROM device_metadata WHERE id = 1',
        )
        .get();

    expect(
      after.single.read<String>('device_instance_id'),
      'device-local-test',
    );

    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(jsonEncode(decoded['data']).contains('device-local-test'), isFalse);
  });
}
