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

  test('setup dismissal persists independently of the tracking toggle',
      () async {
    expect(await tracking.isSetupDismissed(), isFalse);
    await tracking.setSetupDismissed(true);
    expect(await tracking.isSetupDismissed(), isTrue);
    expect(await tracking.isEnabled(), isFalse);
    await tracking.setEnabled(true);
    expect(await tracking.isSetupDismissed(), isTrue);
  });

  test('initial Prayed does not create a Qaza record', () async {
    await tracking.setEnabled(true);

    await tracking.setStatus(
      userId: userId,
      prayerType: PrayerType.fajr,
      date: date,
      status: DailySalahStatus.prayed,
    );

    final records = await qazaService.getPage(
      userId: userId,
      prayerType: PrayerType.fajr,
      from: date,
      to: date,
      status: null,
    );
    expect(records.records, isEmpty);
    expect(
      (await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.fajr,
      ))?.status,
      DailySalahStatus.prayed,
    );
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
    'Missed to Prayed completes the linked Qaza; changing back reopens it',
    () async {
      await tracking.setEnabled(true);
      await tracking.recordMissed(
        userId: userId,
        prayerType: PrayerType.zuhr,
        date: date,
      );

      final missedLog = await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.zuhr,
      );
      final recordId = missedLog!.linkedQazaId!;
      expect(missedLog.trackerCreatedQazaId, recordId);

      await tracking.setStatus(
        userId: userId,
        prayerType: PrayerType.zuhr,
        date: date,
        status: DailySalahStatus.prayed,
      );
      var records = await qazaService.getPage(
        userId: userId,
        prayerType: PrayerType.zuhr,
        from: date,
        to: date,
        status: null,
      );
      expect(records.records, hasLength(1));
      expect(records.records.single.id, recordId);
      expect(records.records.single.status, QazaStatus.completed);

      var log = await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.zuhr,
      );
      expect(log?.status, DailySalahStatus.prayed);
      expect(log?.linkedQazaId, recordId);
      expect(log?.completionSyncId, isNotNull);

      await tracking.recordMissed(
        userId: userId,
        prayerType: PrayerType.zuhr,
        date: date,
      );
      records = await qazaService.getPage(
        userId: userId,
        prayerType: PrayerType.zuhr,
        from: date,
        to: date,
        status: null,
      );
      expect(records.records, hasLength(1));
      expect(records.records.single.id, recordId);
      expect(records.records.single.status, QazaStatus.pending);
      log = await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.zuhr,
      );
      expect(log?.status, DailySalahStatus.missed);
      expect(log?.linkedQazaId, recordId);
      expect(log?.completionSyncId, isNull);
    },
  );

  test('completing a linked Qaza updates its missed Daily Salah log', () async {
    await tracking.setEnabled(true);
    await tracking.recordMissed(
      userId: userId,
      prayerType: PrayerType.isha,
      date: date,
    );
    final logBefore = await tracking.logForDate(
      userId: userId,
      date: date,
      prayerType: PrayerType.isha,
    );
    final recordId = logBefore!.linkedQazaId!;

    await qazaService.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: DateTime(2026, 1, 3),
    );

    final logs = await tracking.logsForDate(userId: userId, date: date);
    expect(logs[PrayerType.isha]?.status, DailySalahStatus.prayed);
    final completionId = logs[PrayerType.isha]?.completionSyncId;
    expect(completionId, isNotNull);
    final records = await qazaService.getRecordsByIds(
      userId: userId,
      recordIds: [recordId],
    );
    expect(records.single.status, QazaStatus.completed);

    expect(
      await qazaService.markCompletedAsPending(
        userId: userId,
        recordId: recordId,
      ),
      isTrue,
    );
    await tracking.syncQazaReopened(
      userId: userId,
      recordId: recordId,
      prayerType: PrayerType.isha,
      originalDate: date,
      expectedCompletionId: completionId!,
    );
    expect(
      (await tracking.logForDate(
        userId: userId,
        date: date,
        prayerType: PrayerType.isha,
      ))?.status,
      DailySalahStatus.missed,
    );
    final reopened = await qazaService.getRecordsByIds(
      userId: userId,
      recordIds: [recordId],
    );
    expect(reopened.single.status, QazaStatus.pending);
  });

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
    expect(log?.linkedQazaId, 'manual-existing');
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
