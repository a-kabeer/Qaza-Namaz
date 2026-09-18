import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  late AppDatabase database;
  late DriftQazaRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftQazaRepository(database);
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

  test('maps Drift rows to domain records and preserves user isolation',
      () async {
    await repository.addRecords([
      record(
          id: 'a1',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1)),
      record(
          id: 'a2',
          userId: 'a',
          prayer: PrayerType.zuhr,
          date: DateTime(2026, 1, 2)),
    ]);
    await repository.addRecord(
      record(
          id: 'b1',
          userId: 'b',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1)),
    );

    final rows = await repository.getRecords(userId: 'a');
    expect(rows.map((row) => row.id), ['a1', 'a2']);
    expect(rows.every((row) => row.userId == 'a'), isTrue);
  });

  test('filters through DAO and handles more than one database page', () async {
    await repository.addRecords([
      for (var i = 0; i < 1001; i++)
        record(
          id: 'f$i',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2020, 1, 1).add(Duration(days: i)),
        ),
    ]);
    await repository.addRecord(
      record(
          id: 'z1',
          userId: 'a',
          prayer: PrayerType.zuhr,
          date: DateTime(2020, 1, 1)),
    );

    final fajr = await repository.getRecords(
      userId: 'a',
      prayerType: PrayerType.fajr,
      status: QazaStatus.pending,
    );

    expect(fajr, hasLength(1001));
    expect(fajr.first.id, 'f0');
    expect(fajr.last.id, 'f1000');
  });

  test('history delegates to descending database pagination and cursor',
      () async {
    await repository.addRecords([
      record(
          id: 'old',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1),
          status: QazaStatus.completed),
      record(
          id: 'new-a',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 3),
          status: QazaStatus.completed),
      record(
          id: 'new-b',
          userId: 'a',
          prayer: PrayerType.zuhr,
          date: DateTime(2026, 1, 3),
          status: QazaStatus.completed),
      record(
          id: 'mid',
          userId: 'a',
          prayer: PrayerType.asr,
          date: DateTime(2026, 1, 2),
          status: QazaStatus.completed),
    ]);
    await repository.addRecord(
      record(
          id: 'other',
          userId: 'b',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 4),
          status: QazaStatus.completed),
    );

    final first = await repository.getHistoryPage(
      userId: 'a',
      limit: 2,
      status: QazaStatus.completed,
    );
    final second = await repository.getHistoryPage(
      userId: 'a',
      limit: 2,
      status: QazaStatus.completed,
      beforeOriginalDate: first.nextOriginalDate,
      beforeId: first.nextId,
    );

    expect(first.records.map((r) => r.id), ['new-b', 'new-a']);
    expect(first.hasMore, isTrue);
    expect(second.records.map((r) => r.id), ['mid', 'old']);
    expect(second.hasMore, isFalse);
  });

  test('history filters are passed to SQLite and do not include another user',
      () async {
    await repository.addRecords([
      record(
          id: 'f1',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 5, 1),
          status: QazaStatus.completed),
      record(
          id: 'f2',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 5, 10),
          status: QazaStatus.completed),
      record(
          id: 'f3',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 5, 11),
          status: QazaStatus.pending),
      record(
          id: 'z1',
          userId: 'a',
          prayer: PrayerType.zuhr,
          date: DateTime(2026, 5, 10),
          status: QazaStatus.completed),
    ]);
    await repository.addRecord(
      record(
          id: 'b1',
          userId: 'b',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 5, 10),
          status: QazaStatus.completed),
    );

    final page = await repository.getHistoryPage(
      userId: 'a',
      limit: 10,
      prayerType: PrayerType.fajr,
      status: QazaStatus.completed,
      from: DateTime(2026, 5, 5),
      to: DateTime(2026, 5, 15),
    );

    expect(page.records.map((r) => r.id), ['f2']);
    expect(page.records.every((r) => r.userId == 'a'), isTrue);
  });

  test('progress summary is database-backed and includes all six prayers',
      () async {
    await repository.addRecords([
      record(
          id: 'f1',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1)),
      record(
          id: 'f2',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 2),
          status: QazaStatus.completed),
      record(
          id: 'z1',
          userId: 'a',
          prayer: PrayerType.zuhr,
          date: DateTime(2026, 1, 1),
          status: QazaStatus.completed),
      record(
          id: 'w1',
          userId: 'a',
          prayer: PrayerType.witr,
          date: DateTime(2026, 1, 1)),
    ]);
    await repository.addRecord(
      record(
          id: 'other',
          userId: 'b',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1),
          status: QazaStatus.completed),
    );

    final summary = await repository.getProgressSummary(userId: 'a');
    expect(summary.overall.pending, 2);
    expect(summary.overall.completed, 2);
    expect(summary.overall.total, 4);
    expect(summary.byPrayer, hasLength(PrayerType.values.length));
    expect(summary.byPrayer[PrayerType.fajr]!.progress.pending, 1);
    expect(summary.byPrayer[PrayerType.fajr]!.progress.completed, 1);
    expect(summary.byPrayer[PrayerType.witr]!.progress.pending, 1);
  });

  test('completion is transactional and does not complete another user record',
      () async {
    await repository.addRecord(
      record(
          id: 'a1',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1)),
    );
    await repository.addRecord(
      record(
          id: 'b1',
          userId: 'b',
          prayer: PrayerType.fajr,
          date: DateTime(2026, 1, 1)),
    );

    await repository.completeRecords(
      userId: 'a',
      recordIds: ['a1', 'b1'],
      completedAt: DateTime(2026, 2, 1),
    );

    final a = await repository.getRecords(userId: 'a');
    final b = await repository.getRecords(userId: 'b');
    expect(a.single.status, QazaStatus.completed);
    expect(b.single.status, QazaStatus.pending);
  });
}
