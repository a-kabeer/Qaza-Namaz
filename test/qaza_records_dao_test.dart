import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/qaza_records_dao.dart';

void main() {
  late AppDatabase database;
  late QazaRecordsDao dao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = database.qazaRecordsDao;
  });

  tearDown(() => database.close());

  QazaRecordsCompanion record({
    required String id,
    required String userId,
    required String prayerType,
    required DateTime date,
    String status = 'pending',
  }) {
    return QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: prayerType,
      originalDate: date,
      status: status,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('getPage filters by user and supports bounded pagination', () async {
    for (var i = 0; i < 120; i++) {
      await dao.insertRecord(record(id: 'user-a-$i', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 1).add(Duration(days: i))));
    }
    await dao.insertRecord(record(id: 'user-b-1', userId: 'user-b', prayerType: 'fajr', date: DateTime(2020, 1, 1)));
    final first = await dao.getPage(userId: 'user-a', limit: 50);
    final second = await dao.getPage(userId: 'user-a', limit: 50, offset: 50);
    expect(first, hasLength(50));
    expect(second, hasLength(50));
    expect(first.first.id, 'user-a-0');
    expect(second.first.id, 'user-a-50');
  });

  test('getPage supports prayer, status and inclusive date filters', () async {
    await dao.insertRecords([
      record(id: 'f1', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 1)),
      record(id: 'f2', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 2), status: 'completed'),
      record(id: 'f3', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 3)),
      record(id: 'z1', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2020, 1, 2)),
    ]);
    final rows = await dao.getByPrayerAndDateRange(userId: 'user-a', prayerType: 'fajr', from: DateTime(2020, 1, 2), to: DateTime(2020, 1, 3));
    expect(rows.map((row) => row.id), ['f2', 'f3']);
    expect((await dao.getPendingPage(userId: 'user-a', prayerType: 'fajr')).map((r) => r.id), ['f1', 'f3']);
    expect((await dao.getCompletedPage(userId: 'user-a', prayerType: 'fajr')).map((r) => r.id), ['f2']);
  });

  test('count, oldest pending and user isolation are database-level queries', () async {
    await dao.insertRecords([
      record(id: 'later', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 3)),
      record(id: 'oldest', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 1)),
      record(id: 'done', userId: 'user-a', prayerType: 'fajr', date: DateTime(2020, 1, 2), status: 'completed'),
      record(id: 'zuhr', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2020, 1, 1)),
      record(id: 'other', userId: 'user-b', prayerType: 'fajr', date: DateTime(2020, 1, 1)),
    ]);
    expect(await dao.count(userId: 'user-a'), 4);
    expect(await dao.countPending(userId: 'user-a'), 3);
    expect(await dao.countCompleted(userId: 'user-a'), 1);
    expect(await dao.countPending(userId: 'user-a', prayerType: 'fajr'), 2);
    expect((await dao.getOldestPending(userId: 'user-a'))!.id, 'oldest');
    expect((await dao.getOldestPending(userId: 'user-a', prayerType: 'zuhr'))!.id, 'zuhr');
    expect(await dao.findById(userId: 'user-b', id: 'oldest'), isNull);
    expect(await dao.deleteById(userId: 'user-b', id: 'oldest'), 0);
    expect(await dao.findById(userId: 'user-a', id: 'oldest'), isNotNull);
  });

  test('rejects invalid page sizes, offsets and date ranges', () {
    expect(() => dao.getPage(userId: 'user-a', limit: 0), throwsArgumentError);
    expect(() => dao.getPage(userId: 'user-a', limit: 501), throwsArgumentError);
    expect(() => dao.getPage(userId: 'user-a', offset: -1), throwsArgumentError);
    expect(() => dao.getPage(userId: 'user-a', from: DateTime(2020, 2, 1), to: DateTime(2020, 1, 1)), throwsArgumentError);
  });

  test('history first page is descending and reports hasMore using limit plus one', () async {
    await dao.insertRecords([
      record(id: 'a', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 3)),
      record(id: 'c', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 2)),
      record(id: 'b', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2026, 9, 3)),
      record(id: 'd', userId: 'user-a', prayerType: 'asr', date: DateTime(2026, 9, 1)),
    ]);
    final page = await dao.getHistoryPage(userId: 'user-a', limit: 3, status: null);
    expect(page.records.map((r) => r.id), ['b', 'a', 'c']);
    expect(page.hasMore, isTrue);
    expect(page.nextOriginalDate, DateTime(2026, 9, 2));
    expect(page.nextId, 'c');
  });

  test('history cursor continues descending order without duplicates', () async {
    await dao.insertRecords([
      record(id: 'a', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 3)),
      record(id: 'c', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 2)),
      record(id: 'b', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2026, 9, 3)),
      record(id: 'd', userId: 'user-a', prayerType: 'asr', date: DateTime(2026, 9, 1)),
    ]);
    final first = await dao.getHistoryPage(userId: 'user-a', limit: 2, status: null);
    final second = await dao.getHistoryPage(userId: 'user-a', limit: 2, status: null, beforeOriginalDate: first.nextOriginalDate, beforeId: first.nextId);
    expect(first.records.map((r) => r.id), ['b', 'a']);
    expect(second.records.map((r) => r.id), ['c', 'd']);
    expect(second.hasMore, isFalse);
  });

  test('history remains deterministic when original dates are identical', () async {
    await dao.insertRecords([
      record(id: 'id-001', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 4)),
      record(id: 'id-003', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2026, 9, 4)),
      record(id: 'id-002', userId: 'user-a', prayerType: 'asr', date: DateTime(2026, 9, 4)),
    ]);
    final page = await dao.getHistoryPage(userId: 'user-a', limit: 2, status: null);
    expect(page.records.map((r) => r.id), ['id-003', 'id-002']);
    final next = await dao.getHistoryPage(userId: 'user-a', limit: 2, status: null, beforeOriginalDate: page.nextOriginalDate, beforeId: page.nextId);
    expect(next.records.map((r) => r.id), ['id-001']);
    expect(next.hasMore, isFalse);
  });

  test('history applies combined prayer, status and date filters in SQLite', () async {
    await dao.insertRecords([
      record(id: 'f-old', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 8, 1), status: 'completed'),
      record(id: 'f-in', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 8, 10), status: 'completed'),
      record(id: 'f-pending', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 8, 11)),
      record(id: 'z-in', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2026, 8, 10), status: 'completed'),
      record(id: 'f-late', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 8, 20), status: 'completed'),
    ]);
    final page = await dao.getHistoryPage(userId: 'user-a', limit: 10, prayerType: 'fajr', status: 'completed', from: DateTime(2026, 8, 5), to: DateTime(2026, 8, 15));
    expect(page.records.map((r) => r.id), ['f-in']);
    expect(page.hasMore, isFalse);
  });

  test('history always isolates user data', () async {
    await dao.insertRecords([
      record(id: 'a-latest', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 9, 10), status: 'completed'),
      record(id: 'b-latest', userId: 'user-b', prayerType: 'fajr', date: DateTime(2026, 9, 20), status: 'completed'),
    ]);
    final page = await dao.getHistoryPage(userId: 'user-a', limit: 50);
    expect(page.records.map((r) => r.id), ['a-latest']);
  });

  test('history rejects partial cursor, invalid sizes and invalid range', () {
    expect(() => dao.getHistoryPage(userId: 'user-a', beforeId: 'id'), throwsArgumentError);
    expect(() => dao.getHistoryPage(userId: 'user-a', beforeOriginalDate: DateTime(2026, 1, 1)), throwsArgumentError);
    expect(() => dao.getHistoryPage(userId: 'user-a', limit: 0), throwsArgumentError);
    expect(() => dao.getHistoryPage(userId: 'user-a', limit: 501), throwsArgumentError);
    expect(() => dao.getHistoryPage(userId: 'user-a', from: DateTime(2026, 2, 1), to: DateTime(2026, 1, 1)), throwsArgumentError);
  });

  test('history stays bounded with 10000 records', () async {
    await dao.insertRecords([
      for (var i = 0; i < 10000; i++)
        record(id: 'record-${i.toString().padLeft(5, '0')}', userId: 'user-a', prayerType: i.isEven ? 'fajr' : 'zuhr', date: DateTime(1999, 1, 1).add(Duration(days: i)), status: i % 3 == 0 ? 'completed' : 'pending'),
    ]);
    final stopwatch = Stopwatch()..start();
    final page = await dao.getHistoryPage(userId: 'user-a', limit: 50, status: null);
    stopwatch.stop();
    expect(page.records, hasLength(50));
    expect(page.hasMore, isTrue);
    expect(page.records.first.id, 'record-09999');
    expect(page.records.last.id, 'record-09950');
    expect(page.records.length, lessThanOrEqualTo(50));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('progress counts are grouped by prayer and status with user isolation', () async {
    await dao.insertRecords([
      record(id: 'f1', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 1, 1)),
      record(id: 'f2', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 1, 2), status: 'completed'),
      record(id: 'f3', userId: 'user-a', prayerType: 'fajr', date: DateTime(2026, 1, 3)),
      record(id: 'z1', userId: 'user-a', prayerType: 'zuhr', date: DateTime(2026, 1, 1), status: 'completed'),
      record(id: 'other', userId: 'user-b', prayerType: 'fajr', date: DateTime(2026, 1, 1), status: 'completed'),
    ]);
    final counts = await dao.getProgressCounts(userId: 'user-a');
    expect(counts[PrayerType.fajr]![QazaStatus.pending], 2);
    expect(counts[PrayerType.fajr]![QazaStatus.completed], 1);
    expect(counts[PrayerType.zuhr]![QazaStatus.completed], 1);
    expect(counts.containsKey(PrayerType.witr), isFalse);
  });
}
