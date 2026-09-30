import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/database/qaza_addition_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecord record(String id, String additionId, DateTime date) => QazaRecord(
  id: id,
  userId: 'u',
  additionId: additionId,
  prayerType: PrayerType.fajr,
  originalDate: date,
  createdAt: date,
  updatedAt: date,
);

QazaAddition addition(String id, DateTime date) {
  final s = QazaAdditionInputSnapshot(
    schemaVersion: 1,
    mode: QazaAdditionMode.single,
    selectedDates: [date],
    selectedPrayers: const [PrayerType.fajr],
  );
  return QazaAddition(
    id: id,
    userId: 'u',
    mode: s.mode,
    currentInputSnapshot: s,
    revision: 1,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  late AppDatabase db;
  late DriftQazaAdditionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftQazaAdditionRepository(db);
  });
  tearDown(() => db.close());

  test('create links inserted records and does not create empty additions', () async {
    final date = DateTime(2026, 9, 1);
    final a = addition('a1', date);

    final result = await repo.createAddition(
      addition: a,
      records: [
        record('r1', a.id, date),
        record('r1', a.id, date),
      ],
    );

    expect(result.additionId, 'a1');
    expect(result.addedCount, 1);
    expect(result.insertedRecordIds, ['r1']);
    expect((await repo.getRecordsForAddition(userId: 'u', additionId: 'a1')).single.id, 'r1');

    final duplicate = addition('a2', date);
    final zero = await repo.createAddition(
      addition: duplicate,
      records: [record('r1', 'a2', date)],
    );
    expect(zero.addedCount, 0);
    expect(await repo.getAddition(userId: 'u', additionId: 'a2'), isNull);
  });

  test('delete and restore preserve the original record identity', () async {
    final date = DateTime(2026, 9, 2);
    final a = addition('a3', date);
    await repo.createAddition(
      addition: a,
      records: [record('r3', a.id, date)],
    );

    final deleted = await repo.deleteAddition(userId: 'u', additionId: 'a3');
    expect(deleted.deletedCount, 1);
    expect(deleted.deletionActionId, isNotNull);
    expect(await repo.getRecordsForAddition(userId: 'u', additionId: 'a3'), isEmpty);

    final restored = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(restored.restoredCount, 1);
    final rows = await repo.getRecordsForAddition(userId: 'u', additionId: 'a3');
    expect(rows.single.id, 'r3');
    expect(rows.single.additionId, 'a3');

    final again = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(again.restoredCount, 0);
    expect(again.conflictCount, 1);
  });

  test('edit removes only unchanged pending linked records', () async {
    final date1 = DateTime(2026, 9, 3);
    final date2 = DateTime(2026, 9, 4);
    final a = addition('a4', date1);
    final snap = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.multiple,
      selectedDates: [date1, date2],
      selectedPrayers: const [PrayerType.fajr],
    );
    await repo.createAddition(
      addition: a,
      records: [
        record('r4', a.id, date1),
        record('r5', a.id, date2),
      ],
    );
    await db.qazaRecordsDao.completeByIds(
      userId: 'u',
      ids: ['r5'],
      completedAt: DateTime(2026, 9, 5),
    );

    final result = await repo.editAddition(
      userId: 'u',
      additionId: a.id,
      expectedRevision: 1,
      snapshot: snap,
      requestedKeys: {
        QazaRecordKey(date: date1, prayerType: PrayerType.fajr),
      },
      recordsToAdd: const [],
    );

    expect(result.revision, 2);
    expect(result.removedCount, 0);
    expect(result.protectedCount, 1);
    expect((await repo.getRecordsForAddition(userId: 'u', additionId: a.id)).length, 2);
  });
}
