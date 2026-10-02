import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/tables/qaza_records.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecordsCompanion _record({
  required String id,
  required PrayerType prayerType,
  required DateTime originalDate,
  required QazaStatus status,
  DateTime? completedAt,
}) {
  return QazaRecordsCompanion.insert(
    id: id,
    userId: 'local',
    prayerType: prayerType.name,
    originalDate: originalDate,
    status: status.name,
    completedAt: completedAt == null ? const Value.absent() : Value(completedAt),
    createdAt: originalDate,
    updatedAt: completedAt ?? originalDate,
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('Pending oldest/newest sorting uses originalDate keysets', () async {
    final sameDay = DateTime(2026, 9, 10);
    await database.qazaRecordsDao.insertRecords([
      _record(
        id: 'a',
        prayerType: PrayerType.fajr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'b',
        prayerType: PrayerType.zuhr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'c',
        prayerType: PrayerType.asr,
        originalDate: DateTime(2026, 9, 11),
        status: QazaStatus.pending,
      ),
      _record(
        id: 'd',
        prayerType: PrayerType.maghrib,
        originalDate: DateTime(2026, 9, 12),
        status: QazaStatus.pending,
      ),
    ]);

    final oldest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 2,
      descending: false,
    );
    expect(oldest.records.map((record) => record.id), ['a', 'b']);
    expect(oldest.hasMore, isTrue);

    final oldestNext = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 2,
      afterOriginalDate: oldest.records.last.originalDate,
      afterId: oldest.records.last.id,
      descending: false,
    );
    expect(oldestNext.records.map((record) => record.id), ['c', 'd']);
    expect(oldestNext.hasMore, isFalse);

    final newest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 2,
      descending: true,
    );
    expect(newest.records.map((record) => record.id), ['d', 'c']);
    expect(newest.hasMore, isTrue);

    final newestNext = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 2,
      beforeOriginalDate: newest.records.last.originalDate,
      beforeId: newest.records.last.id,
      descending: true,
    );
    expect(newestNext.records.map((record) => record.id), ['b', 'a']);
    expect(newestNext.hasMore, isFalse);
  });

  test('Completed oldest/newest sorting uses completedAt keysets only', () async {
    final sameCompletion = DateTime(2026, 9, 10, 8);
    await database.qazaRecordsDao.insertRecords([
      _record(
        id: 'a',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 10, 1),
        status: QazaStatus.completed,
        completedAt: sameCompletion,
      ),
      _record(
        id: 'b',
        prayerType: PrayerType.zuhr,
        originalDate: DateTime(2025, 1, 1),
        status: QazaStatus.completed,
        completedAt: sameCompletion,
      ),
      _record(
        id: 'c',
        prayerType: PrayerType.asr,
        originalDate: DateTime(2020, 1, 1),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 11, 9),
      ),
      _record(
        id: 'd',
        prayerType: PrayerType.maghrib,
        originalDate: DateTime(2010, 1, 1),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 12, 10),
      ),
    ]);

    final oldest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
      descending: false,
    );
    expect(oldest.records.map((record) => record.id), ['a', 'b']);

    final oldestNext = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
      afterCompletedAt: oldest.records.last.completedAt,
      afterId: oldest.records.last.id,
      descending: false,
    );
    expect(oldestNext.records.map((record) => record.id), ['c', 'd']);

    final newest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
      descending: true,
    );
    expect(newest.records.map((record) => record.id), ['d', 'c']);

    final newestNext = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
      beforeCompletedAt: newest.records.last.completedAt,
      beforeId: newest.records.last.id,
      descending: true,
    );
    expect(newestNext.records.map((record) => record.id), ['b', 'a']);
  });

  test('Sorting stays inside active filters and preserves date-field separation', () async {
    await database.qazaRecordsDao.insertRecords([
      _record(
        id: 'pending-in-range',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 10),
        status: QazaStatus.pending,
      ),
      _record(
        id: 'pending-out-of-prayer-filter',
        prayerType: PrayerType.zuhr,
        originalDate: DateTime(2026, 9, 11),
        status: QazaStatus.pending,
      ),
      _record(
        id: 'completed-in-range',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(1999, 1, 1),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 10, 7),
      ),
      _record(
        id: 'completed-out-of-range',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 12),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 20, 7),
      ),
    ]);

    final pendingFiltered = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      prayerType: PrayerType.fajr.name,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      descending: true,
    );
    expect(
      pendingFiltered.records.map((record) => record.id),
      ['pending-in-range'],
    );

    final completedFiltered = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      prayerType: PrayerType.fajr.name,
      from: DateTime(2026, 9, 1),
      toExclusive: DateTime(2026, 9, 15),
      descending: true,
    );
    expect(
      completedFiltered.records.map((record) => record.id),
      ['completed-in-range'],
    );
  });
}
