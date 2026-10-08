import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecord _record(String id, DateTime date) => QazaRecord(
      id: id,
      userId: 'guest',
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  late AppDatabase database;
  late DriftQazaLocalStore store;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftQazaLocalStore(database: database);
  });

  tearDown(() => database.close());

  test('one-row creation is exactly one logical revision', () async {
    await store.appendRecords(
      'guest',
      [_record('one', DateTime(2026, 1, 1))],
    );

    expect(await database.readDbRevision(), 2);
  });

  test('five-row creation in one call is exactly one revision', () async {
    await store.appendRecords(
      'guest',
      List.generate(
        5,
        (index) => _record(
          'five-$index',
          DateTime(2026, 1, index + 1),
        ),
      ),
    );

    expect(await database.readDbRevision(), 2);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest')).length,
      5,
    );
  });

  test('duplicate creation is a no-op and does not advance revision', () async {
    final record = _record('duplicate', DateTime(2026, 2, 1));

    await store.appendRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);

    await store.appendRecords('guest', [record]);
    expect(await database.readDbRevision(), 2);
  });

  test('update advances revision exactly once', () async {
    final record = _record('update', DateTime(2026, 3, 1));
    await store.appendRecords('guest', [record]);

    final current =
        await database.qazaRecordsDao.findById(userId: 'guest', id: record.id);
    expect(current, isNotNull);

    await store.updateRecord(
      current!.copyWith(
        originalDate: DateTime(2026, 3, 2),
        updatedAt: DateTime(2026, 3, 2),
      ),
    );

    expect(await database.readDbRevision(), 3);
    expect(
      (await database.qazaRecordsDao.findById(
        userId: 'guest',
        id: record.id,
      ))!
          .recordVersion,
      2,
    );
  });

  test('batch completion advances revision once for five rows', () async {
    final records = List.generate(
      5,
      (index) => _record(
        'complete-$index',
        DateTime(2026, 4, index + 1),
      ),
    );
    await store.appendRecords('guest', records);

    final completed = await store.completeRecords(
      userId: 'guest',
      recordIds: records.map((record) => record.id).toList(),
      completedAt: DateTime(2026, 5, 1, 12),
    );

    expect(completed, hasLength(5));
    expect(await database.readDbRevision(), 3);
    expect(
      (await database.qazaRecordsDao.getAll(userId: 'guest'))
          .every((record) => record.status == QazaStatus.completed),
      isTrue,
    );
  });

  test('undo completion advances revision once', () async {
    final record = _record('undo', DateTime(2026, 6, 1));
    await store.appendRecords('guest', [record]);
    final completed = await store.completeRecords(
      userId: 'guest',
      recordIds: [record.id],
      completedAt: DateTime(2026, 6, 2, 12),
    );
    final completionId = completed.single.completionId!;

    final undone = await store.undoCompletions(
      userId: 'guest',
      expectedCompletionIds: {record.id: completionId},
      undoneAt: DateTime(2026, 6, 2, 13),
    );

    expect(undone.single.status, QazaStatus.pending);
    expect(await database.readDbRevision(), 4);
  });

  test('delete advances revision once and repeated delete is a no-op',
      () async {
    final record = _record('delete', DateTime(2026, 7, 1));
    await store.appendRecords('guest', [record]);

    expect(
      await store.deleteRecord(userId: 'guest', recordId: record.id),
      isTrue,
    );
    expect(await database.readDbRevision(), 3);

    expect(
      await store.deleteRecord(userId: 'guest', recordId: record.id),
      isFalse,
    );
    expect(await database.readDbRevision(), 3);
  });

  test('reset advances revision once and repeated reset is a no-op', () async {
    await store.appendRecords(
      'guest',
      [_record('reset', DateTime(2026, 8, 1))],
    );

    await store.retireUserData(userId: 'guest');
    expect(await database.readDbRevision(), 3);
    expect(await database.qazaRecordsDao.getAll(userId: 'guest'), isEmpty);

    await store.retireUserData(userId: 'guest');
    expect(await database.readDbRevision(), 3);
  });

  test('failed logical transaction rolls back both data and revision',
      () async {
    final beforeRevision = await database.readDbRevision();

    expect(
      () => database.transactionWithRevision(() async {
        await database.qazaRecordsDao.insertRecord(
          QazaRecordsCompanion.insert(
            id: 'failed',
            userId: 'guest',
            prayerType: PrayerType.fajr.name,
            originalDate: DateTime(2026, 9, 1),
            status: QazaStatus.pending.name,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
        throw StateError('forced failure');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await database.readDbRevision(), beforeRevision);
    expect(
      await database.qazaRecordsDao.findById(
        userId: 'guest',
        id: 'failed',
      ),
      isNull,
    );
  });
}
