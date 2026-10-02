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

  test('Pending ordering uses canonical prayer sequence and composite keysets',
      () async {
    final sameDay = DateTime(2026, 9, 10);
    await database.qazaRecordsDao.insertRecords([
      _record(
        id: 'z-fajr',
        prayerType: PrayerType.fajr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'a-zuhr',
        prayerType: PrayerType.zuhr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'z-asr',
        prayerType: PrayerType.asr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'a-maghrib',
        prayerType: PrayerType.maghrib,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'z-isha',
        prayerType: PrayerType.isha,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'a-witr',
        prayerType: PrayerType.witr,
        originalDate: sameDay,
        status: QazaStatus.pending,
      ),
      _record(
        id: 'next-day',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 11),
        status: QazaStatus.pending,
      ),
    ]);

    final oldest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 3,
    );
    expect(
      oldest.records.map((record) => record.prayerType),
      [PrayerType.fajr, PrayerType.zuhr, PrayerType.asr],
    );
    expect(oldest.hasMore, isTrue);
    expect(oldest.nextPrayerType, PrayerType.asr);

    final second = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 3,
      afterOriginalDate: oldest.nextOriginalDate,
      afterPrayerType: oldest.nextPrayerType?.name,
      afterId: oldest.nextId,
    );
    expect(
      second.records.map((record) => record.prayerType),
      [PrayerType.maghrib, PrayerType.isha, PrayerType.witr],
    );
    expect(second.hasMore, isTrue);

    final third = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 3,
      afterOriginalDate: second.nextOriginalDate,
      afterPrayerType: second.nextPrayerType?.name,
      afterId: second.nextId,
    );
    expect(third.records.map((record) => record.id), ['next-day']);
    expect(third.hasMore, isFalse);

    final newest = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 4,
      descending: true,
    );
    expect(
      newest.records.map((record) => record.prayerType),
      [PrayerType.fajr, PrayerType.witr, PrayerType.isha, PrayerType.maghrib],
    );
    expect(newest.hasMore, isTrue);

    final newestNext = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 4,
      beforeOriginalDate: newest.nextOriginalDate,
      beforePrayerType: newest.nextPrayerType?.name,
      beforeId: newest.nextId,
      descending: true,
    );
    expect(
      newestNext.records.map((record) => record.prayerType),
      [PrayerType.asr, PrayerType.zuhr, PrayerType.fajr],
    );
    expect(newestNext.hasMore, isFalse);
  });

  test('Pending ordering handles missing Witr without gaps', () async {
    final date = DateTime(2026, 9, 10);
    await database.qazaRecordsDao.insertRecords([
      for (final entry in [
        MapEntry('c', PrayerType.asr),
        MapEntry('a', PrayerType.fajr),
        MapEntry('b', PrayerType.zuhr),
        MapEntry('e', PrayerType.isha),
        MapEntry('d', PrayerType.maghrib),
      ])
        _record(
          id: entry.key,
          prayerType: entry.value,
          originalDate: date,
          status: QazaStatus.pending,
        ),
    ]);

    final page = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      limit: 10,
    );
    expect(
      page.records.map((record) => record.prayerType),
      [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ],
    );
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
