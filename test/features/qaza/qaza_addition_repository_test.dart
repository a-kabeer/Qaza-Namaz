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
    expect(restored.alreadyResolved, isFalse);
    final rows = await repo.getRecordsForAddition(userId: 'u', additionId: 'a3');
    expect(rows.single.id, 'r3');
    expect(rows.single.additionId, 'a3');

    final deletedAfterRestore = await repo.getRecentDeletionActions(userId: 'u');
    expect(deletedAfterRestore.items, isEmpty);

    final again = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(again.restoredCount, 0);
    expect(again.conflictCount, 0);
    expect(again.alreadyResolved, isTrue);

    final deletedAgain = await repo.deleteAddition(
      userId: 'u',
      additionId: 'a3',
    );
    expect(deletedAgain.deletedCount, 1);
    expect(deletedAgain.deletionActionId, isNot(deleted.deletionActionId));

    final recentDeleted = await repo.getRecentDeletionActions(userId: 'u');
    expect(recentDeleted.items, hasLength(1));
    expect(recentDeleted.items.single.id, deletedAgain.deletionActionId);

    final restoredAgain = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deletedAgain.deletionActionId!,
    );
    expect(restoredAgain.restoredCount, 1);
    expect(
      (await repo.getRecentDeletionActions(userId: 'u')).items,
      isEmpty,
    );
  });

  test('partial restore resolves the deletion action after conflicts', () async {
    final date1 = DateTime(2026, 9, 6);
    final date2 = DateTime(2026, 9, 7);
    final a = addition('a5', date1);
    await repo.createAddition(
      addition: a,
      records: [
        record('r6', a.id, date1),
        record('r7', a.id, date2),
      ],
    );

    final deleted = await repo.deleteAddition(
      userId: 'u',
      additionId: a.id,
    );

    final insertedConflict = await db.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'replacement-r6',
        userId: 'u',
        prayerType: PrayerType.fajr.name,
        originalDate: date1,
        status: QazaStatus.pending.name,
        additionId: Value(a.id),
        recordVersion: const Value(1),
        createdAt: date1,
        updatedAt: date1,
      ),
    );
    expect(insertedConflict, 1);

    final restored = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(restored.restoredCount, 1);
    expect(restored.conflictCount, 1);
    expect(
      (await repo.getRecentDeletionActions(userId: 'u')).items,
      isEmpty,
    );

    final secondAttempt = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(secondAttempt.alreadyResolved, isTrue);
    expect(secondAttempt.restoredCount, 0);
    expect(secondAttempt.conflictCount, 0);
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
