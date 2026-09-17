import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';

void main() {
  late AppDatabase database;
  late DriftQazaRepository repository;
  late QazaService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftQazaRepository(database);
    service = QazaService(repository);
  });

  tearDown(() => database.close());

  QazaRecord record({
    required String id,
    required String userId,
    required PrayerType prayer,
    required DateTime date,
    QazaStatus status = QazaStatus.pending,
  }) {
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: date,
      status: status,
      completedAt: status == QazaStatus.completed ? date : null,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('production read paths stay bounded with a 5000-record ledger', () async {
    await repository.addRecords([
      for (var i = 0; i < 5000; i++)
        record(id: 'a-$i', userId: 'user-a', prayer: PrayerType.fajr, date: DateTime(2010, 1, 1).add(Duration(days: i))),
    ]);

    final page = await service.getPage(userId: 'user-a', limit: 50, prayerType: PrayerType.fajr, status: QazaStatus.pending);
    final oldest = await service.oldestPending(userId: 'user-a', prayerType: PrayerType.fajr);
    final summary = await service.getProgressSummary(userId: 'user-a');

    expect(page.records, hasLength(50));
    expect(page.hasMore, isTrue);
    expect(oldest?.id, 'a-0');
    expect(summary.overall.pending, 5000);
    expect(summary.overall.completed, 0);
  });

  test('history remains paginated and user-scoped', () async {
    await repository.addRecords([
      for (var i = 0; i < 101; i++)
        record(id: 'history-$i', userId: 'user-a', prayer: PrayerType.isha, date: DateTime(2025, 1, 1).add(Duration(days: i)), status: QazaStatus.completed),
    ]);
    await repository.addRecord(
      record(id: 'other-user', userId: 'user-b', prayer: PrayerType.isha, date: DateTime(2025, 12, 31), status: QazaStatus.completed),
    );

    final first = await service.getHistoryPage(userId: 'user-a', limit: 50, status: QazaStatus.completed);
    final second = await service.getHistoryPage(userId: 'user-a', limit: 50, status: QazaStatus.completed, beforeOriginalDate: first.nextOriginalDate, beforeId: first.nextId);

    expect(first.records, hasLength(50));
    expect(second.records, hasLength(50));
    expect(first.hasMore, isTrue);
    expect(second.hasMore, isTrue);
    expect(first.records.every((r) => r.userId == 'user-a'), isTrue);
    expect(second.records.every((r) => r.userId == 'user-a'), isTrue);
  });

  test('complete-oldest workflow changes only the selected prayer record', () async {
    await repository.addRecords([
      record(id: 'f-late', userId: 'user-a', prayer: PrayerType.fajr, date: DateTime(2024, 1, 3)),
      record(id: 'f-old', userId: 'user-a', prayer: PrayerType.fajr, date: DateTime(2024, 1, 1)),
      record(id: 'z-old', userId: 'user-a', prayer: PrayerType.zuhr, date: DateTime(2024, 1, 1)),
    ]);

    final completed = await service.completeOldestPending(userId: 'user-a', prayerType: PrayerType.fajr, completedAt: DateTime(2026, 9, 17));

    expect(completed, isTrue);
    final fajr = await repository.getRecords(userId: 'user-a', prayerType: PrayerType.fajr);
    final zuhr = await repository.getRecords(userId: 'user-a', prayerType: PrayerType.zuhr);
    expect(fajr.firstWhere((r) => r.id == 'f-old').status, QazaStatus.completed);
    expect(fajr.firstWhere((r) => r.id == 'f-late').status, QazaStatus.pending);
    expect(zuhr.single.status, QazaStatus.pending);
  });

  test('duplicate protection and account isolation hold across the production repository', () async {
    final original = record(id: 'original', userId: 'user-a', prayer: PrayerType.witr, date: DateTime(2026, 1, 1));
    await repository.addRecord(original);
    await repository.addRecord(original.copyWith(id: 'duplicate'));

    expect(await repository.getRecords(userId: 'user-a'), hasLength(1));
    expect(await repository.getRecords(userId: 'user-b'), isEmpty);

    await repository.completeRecord(userId: 'user-b', recordId: 'original', completedAt: DateTime(2026, 2, 1));
    expect((await repository.getRecords(userId: 'user-a')).single.status, QazaStatus.pending);
  });
}
