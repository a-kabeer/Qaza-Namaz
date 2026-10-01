import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecordsCompanion _row({
  required String id,
  required String userId,
  required PrayerType prayerType,
  required DateTime originalDate,
  required QazaStatus status,
  DateTime? completedAt,
}) {
  return QazaRecordsCompanion.insert(
    id: id,
    userId: userId,
    prayerType: prayerType.name,
    originalDate: originalDate,
    status: status.name,
    completedAt:
        completedAt == null ? const Value.absent() : Value(completedAt),
    completionId: status == QazaStatus.completed
        ? Value('completion-$id')
        : const Value.absent(),
    createdAt: originalDate,
    updatedAt: completedAt ?? originalDate,
  );
}

QazaRecord _record({
  required String id,
  required QazaStatus status,
  required DateTime originalDate,
  DateTime? completedAt,
}) {
  final at = completedAt ?? originalDate;
  return QazaRecord(
    id: id,
    userId: 'local',
    prayerType: PrayerType.fajr,
    originalDate: originalDate,
    status: status,
    completedAt: completedAt,
    completionId:
        status == QazaStatus.completed ? 'completion-$id' : null,
    createdAt: originalDate,
    updatedAt: at,
  );
}

class _MemoryQazaStore extends QazaLocalStore {
  _MemoryQazaStore(this.records);

  Map<String, List<QazaRecord>> records;

  @override
  Future<OfflineCacheSnapshot> load() => Future.value(
        OfflineCacheSnapshot(
          recordsByUser: records,
          outboxByUser: const {},
        ),
      );

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> values) async {
    records[userId] = List<QazaRecord>.of(values);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {}

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {}

  @override
  Future<void> retireUserData({required String userId}) async {
    records.remove(userId);
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('Pending date range uses originalDate and ignores completedAt', () async {
    await database.qazaRecordsDao.insertRecords([
      _row(
        id: 'pending-in-range',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 10),
        status: QazaStatus.pending,
        completedAt: DateTime(2026, 9, 30, 23),
      ),
      _row(
        id: 'pending-out-of-range',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 11),
        status: QazaStatus.pending,
        completedAt: DateTime(2026, 9, 1, 1),
      ),
    ]);

    final page = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.pending.name,
      from: DateTime(2026, 9, 10),
      to: DateTime(2026, 9, 10),
    );

    expect(page.records.map((record) => record.id), ['pending-in-range']);
  });

  test('Completed date range uses completedAt with an exclusive next-day bound',
      () async {
    await database.qazaRecordsDao.insertRecords([
      _row(
        id: 'late-completed',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2000, 1, 1),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 10, 23, 59, 59),
      ),
      _row(
        id: 'next-day-completed',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 1),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 11),
      ),
      _row(
        id: 'same-day-early',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 2),
        status: QazaStatus.completed,
        completedAt: DateTime(2026, 9, 10, 1),
      ),
    ]);

    final page = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      from: DateTime(2026, 9, 10),
      toExclusive: DateTime(2026, 9, 11),
    );

    expect(
      page.records.map((record) => record.id).toSet(),
      {'late-completed', 'same-day-early'},
    );
    expect(page.records.length, 2);
  });

  test('Completed keyset pagination uses completedAt and id deterministically',
      () async {
    const ids = ['1', '2', '3', '4'];
    final timestamp = DateTime(2026, 9, 10, 12);
    await database.qazaRecordsDao.insertRecords([
      for (final id in ids)
        _row(
          id: id,
          userId: 'local',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 1, 1),
          status: QazaStatus.completed,
          completedAt: timestamp,
        ),
    ]);

    final first = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
    );
    expect(first.records.map((record) => record.id), ['4', '3']);
    expect(first.hasMore, isTrue);

    final second = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      limit: 2,
      beforeCompletedAt: first.records.last.completedAt,
      beforeId: first.records.last.id,
    );

    expect(second.records.map((record) => record.id), ['2', '1']);
    expect(second.records.map((record) => record.id).toSet().intersection(
          first.records.map((record) => record.id).toSet(),
        ), isEmpty);
  });

  test('Drift and in-memory Completed pages return equivalent records', () async {
    final completed = [
      _record(
        id: 'a',
        status: QazaStatus.completed,
        originalDate: DateTime(2000, 1, 1),
        completedAt: DateTime(2026, 9, 10, 23),
      ),
      _record(
        id: 'b',
        status: QazaStatus.completed,
        originalDate: DateTime(2026, 9, 10),
        completedAt: DateTime(2026, 9, 10, 12),
      ),
      _record(
        id: 'c',
        status: QazaStatus.completed,
        originalDate: DateTime(2026, 1, 1),
        completedAt: DateTime(2026, 9, 11),
      ),
    ];

    await database.qazaRecordsDao.insertRecords([
      for (final record in completed)
        QazaRecordsCompanion.insert(
          id: record.id,
          userId: record.userId,
          prayerType: record.prayerType.name,
          originalDate: record.originalDate,
          status: record.status.name,
          completedAt: Value(record.completedAt!),
          completionId: Value(record.completionId!),
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
    ]);

    final store = _MemoryQazaStore({'local': completed});
    final from = DateTime(2026, 9, 10);
    final toExclusive = DateTime(2026, 9, 11);

    final drift = await database.qazaRecordsDao.getKeysetPage(
      userId: 'local',
      status: QazaStatus.completed.name,
      from: from,
      toExclusive: toExclusive,
    );
    final memory = await store.getPage(
      userId: 'local',
      status: QazaStatus.completed,
      from: from,
      toExclusive: toExclusive,
    );

    expect(
      memory.records.map((record) => record.id),
      drift.records.map((record) => record.id),
    );
  });
  test('Completed to Pending batch changes only matching current completions',
      () async {
    final timestamp = DateTime(2026, 9, 10, 12);
    await database.qazaRecordsDao.insertRecords([
      _row(
        id: 'valid',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 1, 1),
        status: QazaStatus.completed,
        completedAt: timestamp,
      ),
      _row(
        id: 'stale',
        userId: 'local',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 1, 2),
        status: QazaStatus.completed,
        completedAt: timestamp,
      ),
    ]);

    final changed =
        await database.qazaRecordsDao.markCompletedAsPendingBatch(
      userId: 'local',
      expectedCompletionIds: const {
        'valid': 'completion-valid',
        'stale': 'wrong-marker',
      },
      updatedAt: DateTime(2026, 9, 10, 13),
    );

    expect(changed.map((record) => record.id), ['valid']);
    expect(changed.single.recordVersion, 2);

    final rows = await database.qazaRecordsDao.getRowsByIds(
      userId: 'local',
      ids: const ['valid', 'stale'],
    );
    final valid = rows.singleWhere((row) => row.id == 'valid');
    final stale = rows.singleWhere((row) => row.id == 'stale');

    expect(valid.status, QazaStatus.pending.name);
    expect(valid.completedAt, isNull);
    expect(valid.completionId, isNull);
    expect(valid.recordVersion, 2);
    expect(stale.status, QazaStatus.completed.name);
    expect(stale.completionId, 'completion-stale');
    expect(stale.recordVersion, 1);
  });

  test('in-memory Completed to Pending batch follows the same guard', () async {
    final timestamp = DateTime(2026, 9, 10, 12);
    final store = _MemoryQazaStore({
      'local': [
        _record(
          id: 'valid',
          status: QazaStatus.completed,
          originalDate: DateTime(2026, 1, 1),
          completedAt: timestamp,
        ),
        _record(
          id: 'stale',
          status: QazaStatus.completed,
          originalDate: DateTime(2026, 1, 2),
          completedAt: timestamp,
        ),
      ],
    });

    final changed = await store.markCompletedAsPendingBatch(
      userId: 'local',
      expectedCompletionIds: const {
        'valid': 'completion-valid',
        'stale': 'wrong-marker',
      },
      updatedAt: DateTime(2026, 9, 10, 13),
    );

    expect(changed.map((record) => record.id), ['valid']);
    expect(store.records['local']![0].status, QazaStatus.pending);
    expect(store.records['local']![0].recordVersion, 2);
    expect(store.records['local']![1].status, QazaStatus.completed);
  });

}
