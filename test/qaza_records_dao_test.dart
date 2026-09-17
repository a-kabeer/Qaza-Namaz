import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await dao.insertRecord(
        record(
          id: 'user-a-$i',
          userId: 'user-a',
          prayerType: 'fajr',
          date: DateTime(2020, 1, 1).add(Duration(days: i)),
        ),
      );
    }
    await dao.insertRecord(
      record(
        id: 'user-b-1',
        userId: 'user-b',
        prayerType: 'fajr',
        date: DateTime(2020, 1, 1),
      ),
    );

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

    final rows = await dao.getByPrayerAndDateRange(
      userId: 'user-a',
      prayerType: 'fajr',
      from: DateTime(2020, 1, 2),
      to: DateTime(2020, 1, 3),
    );

    expect(rows.map((row) => row.id), ['f2', 'f3']);
    expect(
      (await dao.getPendingPage(userId: 'user-a', prayerType: 'fajr')).map((r) => r.id),
      ['f1', 'f3'],
    );
    expect(
      (await dao.getCompletedPage(userId: 'user-a', prayerType: 'fajr')).map((r) => r.id),
      ['f2'],
    );
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
    expect(
      () => dao.getPage(
        userId: 'user-a',
        from: DateTime(2020, 2, 1),
        to: DateTime(2020, 1, 1),
      ),
      throwsArgumentError,
    );
  });
}
