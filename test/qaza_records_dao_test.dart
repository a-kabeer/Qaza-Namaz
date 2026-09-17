import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/qaza_records_dao.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

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

  test('returns distinct user ids', () async {
    await dao.insertRecords([
      record(id: '1', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 1)),
      record(id: '2', userId: 'u1', prayerType: 'zuhr', date: DateTime(2026, 9, 2)),
      record(id: '3', userId: 'u2', prayerType: 'asr', date: DateTime(2026, 9, 3)),
    ]);
    expect(await dao.userIds(), ['u1', 'u2']);
  });

  test('loads keyset pages in ascending stable order', () async {
    await dao.insertRecords([
      record(id: 'b', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 2)),
      record(id: 'a', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 2)),
      record(id: 'c', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 3)),
    ]);

    final first = await dao.getKeysetPage(userId: 'u1', limit: 2);
    expect(first.records.map((value) => value.id), ['a', 'b']);
    expect(first.hasMore, isTrue);

    final second = await dao.getKeysetPage(
      userId: 'u1',
      limit: 2,
      afterOriginalDate: first.nextOriginalDate,
      afterId: first.nextId,
    );
    expect(second.records.map((value) => value.id), ['c']);
    expect(second.hasMore, isFalse);
  });

  test('loads history newest first', () async {
    await dao.insertRecords([
      record(id: 'old', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 1), status: 'completed'),
      record(id: 'new', userId: 'u1', prayerType: 'fajr', date: DateTime(2026, 9, 3), status: 'completed'),
    ]);

    final page = await dao.getHistoryPage(userId: 'u1', limit: 10, status: QazaStatus.completed.name);
    expect(page.records.map((value) => value.id), ['new', 'old']);
  });
}
