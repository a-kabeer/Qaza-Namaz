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
  const userId = 'daily-salah-test-user';
  final date = DateTime(2026, 1, 2);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    repository = OfflineFirstQazaRepository(
      localStore: DriftQazaLocalStore(database: database),
    );
    await repository.setActiveUser(userId);
    qazaService = QazaService(repository);
    tracking = DailySalahTrackingService(
      database: database,
      qazaService: qazaService,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('tracking is off by default and preference persists', () async {
    expect(await tracking.isEnabled(), isFalse);
    await tracking.setEnabled(true);
    expect(await tracking.isEnabled(), isTrue);
    await tracking.setEnabled(false);
    expect(await tracking.isEnabled(), isFalse);
  });

  test('confirmed missed is idempotent and creates one linked Qaza', () async {
    await tracking.setEnabled(true);

    await tracking.recordMissed(
      userId: userId,
      prayerType: PrayerType.fajr,
      date: date,
    );
    await tracking.recordMissed(
      userId: userId,
      prayerType: PrayerType.fajr,
      date: date,
    );

    final records = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.fajr,
      from: date,
      to: date,
      status: null,
    );
    expect(records.records, hasLength(1));

    final logs = await tracking.logsForDate(userId: userId, date: date);
    expect(logs[PrayerType.fajr]?.status, DailySalahStatus.missed);
    expect(
      logs[PrayerType.fajr]?.trackerCreatedQazaId,
      records.records.single.id,
    );
  });

  test(
    'correcting Missed preserves Qaza; confirmed undo removes only its pending entry',
    () async {
      await tracking.setEnabled(true);
      await tracking.recordMissed(
        userId: userId,
        prayerType: PrayerType.zuhr,
        date: date,
      );

      await tracking.setStatus(
        userId: userId,
        prayerType: PrayerType.zuhr,
        date: date,
        status: DailySalahStatus.prayed,
      );
      final afterCorrection = await qazaService.getPage(
        userId: userId,
        prayerType: PrayerType.zuhr,
        from: date,
        to: date,
        status: null,
      );
      expect(afterCorrection.records, hasLength(1));
      expect(
        await tracking.canUndoTrackerCreatedQaza(
          userId: userId,
          prayerType: PrayerType.zuhr,
          date: date,
        ),
        isTrue,
      );

      expect(
        await tracking.undoTrackerCreatedQaza(
          userId: userId,
          prayerType: PrayerType.zuhr,
          date: date,
        ),
        isTrue,
      );
      final afterUndo = await qazaService.getPage(
        userId: userId,
        prayerType: PrayerType.zuhr,
        from: date,
        to: date,
        status: null,
      );
      expect(afterUndo.records, isEmpty);
      final log = await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.zuhr,
      );
      expect(log?.status, DailySalahStatus.prayed);
      expect(log?.trackerCreatedQazaId, isNull);
    },
  );

  test('existing manual Qaza is never claimed or duplicated', () async {
    await tracking.setEnabled(true);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    await qazaService.addRecords([
      QazaRecord(
        id: 'manual-existing',
        userId: userId,
        prayerType: PrayerType.asr,
        originalDate: normalizedDate,
        status: QazaStatus.pending,
        createdAt: date,
        updatedAt: date,
      ),
    ]);

    await tracking.recordMissed(
      userId: userId,
      prayerType: PrayerType.asr,
      date: date,
    );
    final records = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.asr,
      from: date,
      to: date,
      status: null,
    );
    expect(records.records, hasLength(1));
    final log = await tracking.logForDate(
      userId: userId,
      date: date,
      prayerType: PrayerType.asr,
    );
    expect(log?.trackerCreatedQazaId, isNull);
    expect(
      await tracking.canUndoTrackerCreatedQaza(
        userId: userId,
        prayerType: PrayerType.asr,
        date: date,
      ),
      isFalse,
    );
  });

  test('completed tracker-created Qaza cannot be undone', () async {
    await tracking.setEnabled(true);
    await tracking.recordMissed(
      userId: userId,
      prayerType: PrayerType.isha,
      date: date,
    );
    final logs = await tracking.logsForDate(userId: userId, date: date);
    final recordId = logs[PrayerType.isha]!.trackerCreatedQazaId!;

    await qazaService.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: DateTime(2026, 1, 3),
    );

    expect(
      await tracking.canUndoTrackerCreatedQaza(
        userId: userId,
        prayerType: PrayerType.isha,
        date: date,
      ),
      isFalse,
    );
    expect(
      await tracking.undoTrackerCreatedQaza(
        userId: userId,
        prayerType: PrayerType.isha,
        date: date,
      ),
      isFalse,
    );
  });

  test('status changes require tracking to be enabled', () async {
    expect(
      tracking.setStatus(
        userId: userId,
        prayerType: PrayerType.fajr,
        date: date,
        status: DailySalahStatus.prayed,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('logs are retained when tracking is disabled and re-enabled', () async {
    await tracking.setEnabled(true);
    await tracking.setStatus(
      userId: userId,
      prayerType: PrayerType.maghrib,
      date: date,
      status: DailySalahStatus.prayed,
    );

    await tracking.setEnabled(false);
    await tracking.setEnabled(true);

    final log = await tracking.logForDate(
      userId: userId,
      date: date,
      prayerType: PrayerType.maghrib,
    );
    expect(log?.status, DailySalahStatus.prayed);
  });
}
