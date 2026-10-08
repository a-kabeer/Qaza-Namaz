import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';

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

QazaRecord _domainRecord(String id, DateTime date) => QazaRecord(
      id: id,
      userId: 'guest',
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

Future<void> _seedAccount(AppDatabase database) async {
  final now = DateTime(2026, 10, 8).microsecondsSinceEpoch;
  await database.customInsert(
    '''INSERT OR IGNORE INTO local_accounts
       (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
       VALUES (?, 'local', 'active', ?, ?)''',
    variables: [
      Variable.withString('guest'),
      Variable.withInt(now),
      Variable.withInt(now),
    ],
  );
  await database.customInsert(
    '''INSERT OR IGNORE INTO app_session_state (id, active_local_account_id)
       VALUES (1, ?)''',
    variables: [Variable.withString('guest')],
  );
}

void main() {
  late AppDatabase database;
  late LocalBackupService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
    await _seedAccount(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('five-row transaction advances revision exactly once', () async {
    await database.transactionWithRevision(() async {
      for (var index = 0; index < 5; index++) {
        await database.qazaRecordsDao.insertRecord(
          _record('guest_fajr_$index', DateTime(2026, 1, index + 1)),
        );
      }
      return 5;
    });

    expect(await database.readDbRevision(), 2);
  });

  test('independent logical transactions advance revision independently',
      () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2026, 1, 1)),
      );
      return true;
    });
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_2', DateTime(2026, 1, 2)),
      );
      return true;
    });

    expect(await database.readDbRevision(), 3);
  });

  test('saving an identical profile is a no-op for db_revision', () async {
    final store = AccountLocalStore(database: database);
    const profile = UserProfile(dailyQazaTarget: 5);

    await store.saveProfile('guest', profile);
    expect(await database.readDbRevision(), 2);

    await store.saveProfile('guest', profile);
    expect(await database.readDbRevision(), 2);
  });

  test('clearing an already clear profile is a no-op for db_revision',
      () async {
    final store = AccountLocalStore(database: database);

    await store.clearProfile('guest');
    expect(await database.readDbRevision(), 1);
  });

  test('saving identical Qaza records is a no-op for db_revision', () async {
    final store = DriftQazaLocalStore(database: database);
    final date = DateTime(2026, 1, 1);
    final record = _domainRecord('guest_fajr_1', date);

    await store.appendRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);

    await store.saveRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);
  });

  test('upserting an identical Qaza record is a no-op for db_revision',
      () async {
    final store = DriftQazaLocalStore(database: database);
    final record = _domainRecord('guest_fajr_upsert', DateTime(2026, 1, 3));

    await store.appendRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);

    await store.upsertRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);
  });

  test('retiring empty user data is a no-op for db_revision', () async {
    final store = DriftQazaLocalStore(database: database);

    await store.retireUserData(userId: 'guest');

    expect(await database.readDbRevision(), 1);
  });

  test('invalid revision metadata is rejected before mutation', () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['db_revision'] = '2';

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('missing required payload node is rejected before mutation', () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['data'] as Map<String, dynamic>).remove('qaza_records');

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('language and theme persist only through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(localeProvider.notifier).set(const Locale('ur'));
    container.read(themeModeProvider.notifier).set(AppThemeMode.dark);
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language_code'), 'ur');
    expect(prefs.getString('qaza_theme_mode'), 'dark');
  });

  test('invalid timestamp is rejected before mutation', () async {
    final beforeRevision = await database.readDbRevision();
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['export_timestamp'] =
        'not-a-timestamp';

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), beforeRevision);
  });

  test('missing metadata is rejected before mutation', () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    decoded.remove('metadata');

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('non-object JSON root is rejected before mutation', () async {
    expect(
      () => service.importJson('[]'),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('invalid non-Qaza table field type is rejected before mutation',
      () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    final additions = (decoded['data']
        as Map<String, dynamic>)['qaza_additions'] as List<dynamic>;
    additions.add({
      'id': 'addition-1',
      'user_id': 'guest',
      'mode': 'single',
      'input_snapshot': '{}',
      'revision': 'not-an-int',
      'created_at': '2026-10-08T00:00:00.000Z',
      'updated_at': '2026-10-08T00:00:00.000Z',
    });

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('duplicate Qaza record IDs are rejected before mutation', () async {
    await database.qazaRecordsDao.insertRecord(
      _record('guest_fajr_1', DateTime(2026, 1, 1)),
    );
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    final records = (decoded['data'] as Map<String, dynamic>)['qaza_records']
        as List<dynamic>;
    records.add(Map<String, dynamic>.from(records.single as Map));

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(isA<LocalBackupException>()),
    );
    expect(await database.readDbRevision(), 1);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      1,
    );
  });

  test('database schema mismatch is rejected before mutation', () async {
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['database_schema_version'] =
        database.schemaVersion - 1;

    expect(
      () => service.importJson(jsonEncode(decoded)),
      throwsA(
        predicate<LocalBackupException>(
          (error) => error.message.contains('database schema'),
        ),
      ),
    );
    expect(await database.readDbRevision(), 1);
  });

  test('newer restore revision becomes max(local, backup) + 1', () async {
    await database.transactionWithRevision(() async {
      await database.qazaRecordsDao.insertRecord(
        _record('guest_fajr_1', DateTime(2026, 1, 1)),
      );
      return true;
    });
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, dynamic>;
    (decoded['metadata'] as Map<String, dynamic>)['db_revision'] = 150;

    final restored = await service.importJson(jsonEncode(decoded));

    expect(restored.dbRevision, 151);
    expect(await database.readDbRevision(), 151);
  });

  test('restore rolls back fully on SQL failure', () async {
    final source = AppDatabase(NativeDatabase.memory());
    try {
      await _seedAccount(source);
      await source.qazaRecordsDao.insertRecord(
        _record('source_record', DateTime(2026, 2, 1)),
      );
      final backup = await LocalBackupService(source).exportJson();

      await database.qazaRecordsDao.insertRecord(
        _record('existing_record', DateTime(2026, 3, 1)),
      );
      final beforeRevision = await database.readDbRevision();

      await database.customStatement('''
        CREATE TRIGGER force_restore_failure
        AFTER INSERT ON qaza_records
        BEGIN
          SELECT RAISE(ABORT, 'forced restore failure');
        END
      ''');

      expect(
        () => service.importJson(backup),
        throwsA(isA<Object>()),
      );

      expect(await database.readDbRevision(), beforeRevision);
      expect(
        (await database.qazaRecordsDao.getAll(userId: 'guest'))
            .map((r) => r.id),
        ['existing_record'],
      );
    } finally {
      await source.close();
    }
  });

  test('restore preserves account, profile, provenance and onboarding state',
      () async {
    final source = AppDatabase(NativeDatabase.memory());
    try {
      await _seedAccount(source);
      const profile = UserProfile(
        dailyQazaTarget: 10,
        gender: Gender.female,
        madhab: Madhab.hanafi,
        pubertyAge: 9,
        startPrayingAge: 12,
        witrIncluded: true,
        onboardingCompleted: true,
      );
      final record = _domainRecord('restored_record', DateTime(2026, 4, 1));

      await source.customInsert(
        '''INSERT INTO account_profiles
           (local_account_id, payload_json, entity_version, updated_at,
            writer_device_id, operation_id)
           VALUES (?, ?, 1, ?, ?, ?)''',
        variables: [
          Variable.withString('guest'),
          Variable.withString(jsonEncode(profile.toJson())),
          Variable.withInt(DateTime(2026, 4, 1).microsecondsSinceEpoch),
          Variable.withString('device-source'),
          Variable.withString('operation-source'),
        ],
      );
      await source.customInsert(
        '''INSERT INTO account_plan_revisions
           (local_account_id, revision_id, payload_json, created_at)
           VALUES (?, ?, ?, ?)''',
        variables: [
          Variable.withString('guest'),
          Variable.withString('plan-1'),
          Variable.withString(
            jsonEncode({
              'revisionId': 'plan-1',
              'userId': 'guest',
              'planFingerprint': 'qazaPlanV2Fixed360|test',
              'createdAt': DateTime(2026, 4, 1).toIso8601String(),
            }),
          ),
          Variable.withInt(DateTime(2026, 4, 1).microsecondsSinceEpoch),
        ],
      );
      await source.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: record.id,
          userId: record.userId,
          prayerType: record.prayerType.name,
          originalDate: record.originalDate,
          status: record.status.name,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
      );
      await source.customInsert(
        '''INSERT INTO qaza_profile_plan_provenance
           (record_id, user_id, plan_revision_id, plan_fingerprint)
           VALUES (?, ?, ?, ?)''',
        variables: [
          Variable.withString(record.id),
          Variable.withString('guest'),
          Variable.withString('plan-1'),
          Variable.withString('qazaPlanV2Fixed360|test'),
        ],
      );
      await source.setOnboardingCompletedInTransaction(true);
      await source.setDbRevisionInTransaction(5);

      final backup = await LocalBackupService(source).exportJson();
      final analysis = await service.importJson(backup);

      expect(analysis.onboardingCompleted, isTrue);
      expect(await database.isOnboardingCompleted(), isTrue);
      expect(
        (await database.qazaRecordsDao.getAll(userId: 'guest')).single.id,
        'restored_record',
      );

      final profileRows = await database.customSelect(
        'SELECT payload_json FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable.withString('guest')],
      ).get();
      final restoredProfile = UserProfile.fromJson(
        jsonDecode(profileRows.single.read<String>('payload_json'))
            as Map<String, dynamic>,
      );
      expect(restoredProfile.dailyQazaTarget, 10);
      expect(restoredProfile.gender, Gender.female);

      final provenanceRows = await database.customSelect(
        'SELECT plan_revision_id, plan_fingerprint '
        'FROM qaza_profile_plan_provenance WHERE record_id = ?',
        variables: [Variable.withString('restored_record')],
      ).get();
      expect(provenanceRows.single.read<String>('plan_revision_id'), 'plan-1');
      expect(
        provenanceRows.single.read<String>('plan_fingerprint'),
        'qazaPlanV2Fixed360|test',
      );
    } finally {
      await source.close();
    }
  });

  test('restore does not change presentation language or theme', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'ur',
      'qaza_theme_mode': 'dark',
    });

    final backup = await service.exportJson();
    await service.importJson(backup);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language_code'), 'ur');
    expect(prefs.getString('qaza_theme_mode'), 'dark');
  });
}
