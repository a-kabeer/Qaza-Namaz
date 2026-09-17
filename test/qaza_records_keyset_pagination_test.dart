import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  QazaRecordsCompanion record(int i, {String userId = 'user-a'}) {
    final date = DateTime(2020, 1, 1).add(Duration(days: i));
    return QazaRecordsCompanion.insert(
      id: '$userId-$i',
      userId: userId,
      prayerType: 'fajr',
      originalDate: date,
      status: 'pending',
      createdAt: date,
      updatedAt: date,
    );
  }

  test('keyset pagination advances by date and stable id without offset', () async {
    await database.qazaRecordsDao.insertRecords([
      for (var i = 0; i < 1200; i++) record(i),
    ]);

    final first = await database.qazaRecordsDao.getKeysetPage(
      userId: 'user-a',
      limit: 50,
    );
    expect(first.records, hasLength(50));
    expect(first.hasMore, isTrue);
    expect(first.records.first.id, 'user-a-0');
    expect(first.nextId, 'user-a-49');

    final second = await database.qazaRecordsDao.getKeysetPage(
      userId: 'user-a',
      limit: 50,
      afterOriginalDate: first.nextOriginalDate,
      afterId: first.nextId,
    );
    expect(second.records, hasLength(50));
    expect(second.records.first.id, 'user-a-50');

    final last = await database.qazaRecordsDao.getKeysetPage(
      userId: 'user-a',
      limit: 50,
      afterOriginalDate: DateTime(2023, 4, 14),
      afterId: 'user-a-1199',
    );
    expect(last.records, isEmpty);
    expect(last.hasMore, isFalse);
  });

  test('keyset pagination preserves filters and rejects partial cursor', () async {
    await database.qazaRecordsDao.insertRecords([
      record(0),
      record(1),
      QazaRecordsCompanion.insert(
        id: 'user-a-z',
        userId: 'user-a',
        prayerType: 'zuhr',
        originalDate: DateTime(2020, 1, 2),
        status: 'pending',
        createdAt: DateTime(2020, 1, 2),
        updatedAt: DateTime(2020, 1, 2),
      ),
    ]);

    final page = await database.qazaRecordsDao.getKeysetPage(
      userId: 'user-a',
      prayerType: 'fajr',
      limit: 10,
    );
    expect(page.records.map((r) => r.id), ['user-a-0', 'user-a-1']);
    expect(
      () => database.qazaRecordsDao.getKeysetPage(
        userId: 'user-a',
        afterId: 'user-a-0',
      ),
      throwsArgumentError,
    );
  });
}
