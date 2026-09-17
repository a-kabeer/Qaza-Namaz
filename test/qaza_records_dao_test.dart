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

  test('getPage filters by user and supports pagination', () async {
    for (var i = 0; i < 5; i++) {
      await dao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'user-a-$i',
          userId: 'user-a',
          prayerType: 'fajr',
          originalDate: DateTime(2020, 1, i + 1),
          status: 'pending',
          createdAt: DateTime(2020, 1, i + 1),
          updatedAt: DateTime(2020, 1, i + 1),
        ),
      );
    }
    await dao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'user-b-1',
        userId: 'user-b',
        prayerType: 'fajr',
        originalDate: DateTime(2020, 1, 1),
        status: 'pending',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      ),
    );

    final first = await dao.getPage(userId: 'user-a', limit: 2);
    final second = await dao.getPage(userId: 'user-a', limit: 2, offset: 2);

    expect(first.map((r) => r.id), ['user-a-0', 'user-a-1']);
    expect(second.map((r) => r.id), ['user-a-2', 'user-a-3']);
  });

  test('count applies filters in SQLite', () async {
    for (var i = 0; i < 3; i++) {
      await dao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'pending-$i',
          userId: 'user-a',
          prayerType: i == 0 ? 'witr' : 'fajr',
          originalDate: DateTime(2020, 1, i + 1),
          status: 'pending',
          createdAt: DateTime(2020, 1, i + 1),
          updatedAt: DateTime(2020, 1, i + 1),
        ),
      );
    }

    expect(await dao.count(userId: 'user-a'), 3);
    expect(await dao.count(userId: 'user-a', prayerType: 'fajr'), 2);
    expect(await dao.count(userId: 'user-a', status: 'pending'), 3);
  });

  test('findById and deleteById are user-scoped', () async {
    await dao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'shared-id',
        userId: 'user-a',
        prayerType: 'isha',
        originalDate: DateTime(2020, 2, 1),
        status: 'pending',
        createdAt: DateTime(2020, 2, 1),
        updatedAt: DateTime(2020, 2, 1),
      ),
    );

    expect(await dao.findById(userId: 'user-b', id: 'shared-id'), isNull);
    expect(await dao.deleteById(userId: 'user-b', id: 'shared-id'), 0);
    expect(await dao.findById(userId: 'user-a', id: 'shared-id'), isNotNull);
  });
}
