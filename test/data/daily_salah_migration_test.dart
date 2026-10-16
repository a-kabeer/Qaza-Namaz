import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_service.dart';

void main() {
  late AppDatabase database;
  late OfflineFirstQazaRepository repository;
  late QazaService qazaService;
  late DailySalahTrackingService tracking;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    repository = OfflineFirstQazaRepository(
      localStore: DriftQazaLocalStore(database: database),
    );
    await repository.setActiveUser('migration-test-user');
    qazaService = QazaService(repository);
    tracking = DailySalahTrackingService(
      database: database,
      qazaService: qazaService,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('daily Salah schema is created with a unique date/prayer key', () async {
    final columns = await database
        .customSelect(
          'PRAGMA table_info(daily_salah_logs)',
        )
        .get();
    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>[
        'user_id',
        'prayer_date',
        'prayer_type',
        'status',
        'tracker_created_qaza_id',
        'updated_at',
      ]),
    );
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'daily_salah_logs_user_date_idx'",
        )
        .get();
    expect(indexes, hasLength(1));
    expect(await tracking.isEnabled(), isFalse);
  });

  test('schema setup leaves existing Qaza records unchanged', () async {
    final date = DateTime(2024, 4, 10);
    await qazaService.addRecords([
      QazaRecord(
        id: 'existing-qaza',
        userId: 'migration-test-user',
        prayerType: PrayerType.fajr,
        originalDate: date,
        status: QazaStatus.pending,
        createdAt: date,
        updatedAt: date,
      ),
    ]);

    await tracking.setEnabled(true);
    final afterMigration = await qazaService.getPage(
      userId: 'migration-test-user',
      prayerType: PrayerType.fajr,
      from: date,
      to: date,
      status: null,
    );
    expect(afterMigration.records, hasLength(1));
    expect(afterMigration.records.single.id, 'existing-qaza');
    expect(afterMigration.records.single.status, QazaStatus.pending);
  });
}
