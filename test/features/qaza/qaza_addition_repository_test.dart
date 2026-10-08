import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('create links inserted records and does not create empty additions',
      () async {
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
    expect(
        (await repo.getRecordsForAddition(userId: 'u', additionId: 'a1'))
            .single
            .id,
        'r1');

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
    expect(await repo.getRecordsForAddition(userId: 'u', additionId: 'a3'),
        isEmpty);

    final restored = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(restored.restoredCount, 1);
    expect(restored.alreadyResolved, isFalse);
    final rows =
        await repo.getRecordsForAddition(userId: 'u', additionId: 'a3');
    expect(rows.single.id, 'r3');
    expect(rows.single.additionId, 'a3');

    final deletedAfterRestore =
        await repo.getRecentDeletionActions(userId: 'u');
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

  test(
      'unresolved deletion hides Recent Additions even when protected records remain',
      () async {
    final date1 = DateTime(2026, 9, 21);
    final date2 = DateTime(2026, 9, 22);
    final a = addition('a-lifecycle', date1);

    await repo.createAddition(
      addition: a,
      records: [
        record('r-lifecycle-pending', a.id, date1),
        record('r-lifecycle-completed', a.id, date2),
      ],
    );
    await db.qazaRecordsDao.completeByIds(
      userId: 'u',
      ids: ['r-lifecycle-completed'],
      completedAt: DateTime(2026, 9, 23),
    );

    expect(
      (await repo.getRecentAdditions(userId: 'u')).items.map(
            (item) => item.addition.id,
          ),
      contains(a.id),
    );

    final deletedA = await repo.deleteAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(deletedA.deletionActionId, isNotNull);
    expect(
      (await repo.getRecentDeletionActions(userId: 'u')).items.single.id,
      deletedA.deletionActionId,
    );

    final afterFirstDelete = await repo.getAdditionDetail(
      userId: 'u',
      additionId: a.id,
    );
    expect(afterFirstDelete, isNotNull);
    expect(afterFirstDelete!.isDeleted, isTrue);
    expect(afterFirstDelete.pendingCount, 0);
    expect(afterFirstDelete.completedCount, 1);
    expect(
      (await repo.getRecentAdditions(userId: 'u')).items,
      isEmpty,
    );

    final restoredA = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deletedA.deletionActionId!,
    );
    expect(restoredA.restoredCount, 1);
    expect(
      (await repo.getRecentAdditions(userId: 'u')).items.map(
            (item) => item.addition.id,
          ),
      contains(a.id),
    );

    final restoredDetail = await repo.getAdditionDetail(
      userId: 'u',
      additionId: a.id,
    );
    expect(restoredDetail!.isDeleted, isFalse);

    final deletedB = await repo.deleteAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(deletedB.deletionActionId, isNot(deletedA.deletionActionId));
    expect(
      (await repo.getRecentAdditions(userId: 'u')).items,
      isEmpty,
    );
    final unresolvedActions = await repo.getRecentDeletionActions(userId: 'u');
    expect(unresolvedActions.items, hasLength(1));
    expect(unresolvedActions.items.single.id, deletedB.deletionActionId);

    final deletedAgainDetail = await repo.getAdditionDetail(
      userId: 'u',
      additionId: a.id,
    );
    expect(deletedAgainDetail!.isDeleted, isTrue);

    final restoredB = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deletedB.deletionActionId!,
    );
    expect(restoredB.restoredCount, 1);

    final finalDetail = await repo.getAdditionDetail(
      userId: 'u',
      additionId: a.id,
    );
    expect(finalDetail!.isDeleted, isFalse);
    expect(
      (await repo.getRecentAdditions(userId: 'u')).items.map(
            (item) => item.addition.id,
          ),
      contains(a.id),
    );
  });

  test('edit and delete reject mutations while a deletion action is unresolved',
      () async {
    final date = DateTime(2026, 9, 24);
    final a = addition('a-guard', date);
    await repo.createAddition(
      addition: a,
      records: [record('r-guard', a.id, date)],
    );

    final deleted = await repo.deleteAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(deleted.deletionActionId, isNotNull);

    final before = await repo.getAddition(userId: 'u', additionId: a.id);

    await expectLater(
      repo.editAddition(
        userId: 'u',
        additionId: a.id,
        expectedRevision: before!.revision,
        snapshot: before.currentInputSnapshot,
        requestedKeys: {
          QazaRecordKey(
            date: date,
            prayerType: PrayerType.fajr,
          ),
        },
        recordsToAdd: const [],
      ),
      throwsA(isA<StateError>()),
    );

    final afterEdit = await repo.getAddition(userId: 'u', additionId: a.id);
    expect(afterEdit!.revision, before.revision);

    await expectLater(
      repo.deleteAddition(
        userId: 'u',
        additionId: a.id,
      ),
      throwsA(isA<StateError>()),
    );

    final unresolvedActions = await repo.getRecentDeletionActions(userId: 'u');
    expect(unresolvedActions.items, hasLength(1));
    expect(unresolvedActions.items.single.id, deleted.deletionActionId);
  });

  test('partial restore resolves the deletion action after conflicts',
      () async {
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

  test('edit removes eligible pending records with no new records', () async {
    final date1 = DateTime(2026, 9, 11);
    final date2 = DateTime(2026, 9, 12);
    final a = addition('a-edit-only', date1);
    final snap = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.multiple,
      selectedDates: [date1],
      selectedPrayers: const [PrayerType.fajr],
    );

    await repo.createAddition(
      addition: a,
      records: [
        record('r-edit-keep', a.id, date1),
        record('r-edit-remove', a.id, date2),
      ],
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
    expect(result.addedCount, 0);
    expect(result.removedCount, 1);
    expect(result.protectedCount, 0);

    final rows = await repo.getRecordsForAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(rows, hasLength(1));
    expect(rows.single.id, 'r-edit-keep');
  });

  test('edit keeps existing records without duplicate insertion', () async {
    final date = DateTime(2026, 9, 13);
    final a = addition('a-keep', date);

    await repo.createAddition(
      addition: a,
      records: [record('r-keep', a.id, date)],
    );

    final result = await repo.editAddition(
      userId: 'u',
      additionId: a.id,
      expectedRevision: 1,
      snapshot: a.currentInputSnapshot,
      requestedKeys: {
        QazaRecordKey(date: date, prayerType: PrayerType.fajr),
      },
      recordsToAdd: const [],
    );

    expect(result.revision, 2);
    expect(result.addedCount, 0);
    expect(result.removedCount, 0);
    expect(
        (await repo.getRecordsForAddition(
          userId: 'u',
          additionId: a.id,
        )),
        hasLength(1));
  });

  test(
      'edit performs add and remove atomically while preserving completed records',
      () async {
    final date1 = DateTime(2026, 9, 14);
    final date2 = DateTime(2026, 9, 15);
    final date3 = DateTime(2026, 9, 16);
    final a = addition('a-mixed', date1);
    final snapshot = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.multiple,
      selectedDates: [date1, date3],
      selectedPrayers: const [PrayerType.fajr],
    );

    await repo.createAddition(
      addition: a,
      records: [
        record('r-remove', a.id, date2),
        record('r-completed', a.id, date1),
      ],
    );
    await db.qazaRecordsDao.completeByIds(
      userId: 'u',
      ids: ['r-completed'],
      completedAt: DateTime(2026, 9, 17),
    );

    final result = await repo.editAddition(
      userId: 'u',
      additionId: a.id,
      expectedRevision: 1,
      snapshot: snapshot,
      requestedKeys: {
        QazaRecordKey(date: date1, prayerType: PrayerType.fajr),
        QazaRecordKey(date: date3, prayerType: PrayerType.fajr),
      },
      recordsToAdd: [
        QazaRecord(
          id: 'r-new',
          userId: 'u',
          additionId: a.id,
          prayerType: PrayerType.fajr,
          originalDate: date3,
          createdAt: date3,
          updatedAt: date3,
        ),
      ],
    );

    expect(result.revision, 2);
    expect(result.addedCount, 1);
    expect(result.removedCount, 1);
    expect(result.protectedCount, 0);

    final rows = await repo.getRecordsForAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(rows.map((row) => row.id).toSet(), {'r-completed', 'r-new'});
  });

  test('edit counts a deselected completed record as protected', () async {
    final date1 = DateTime(2026, 9, 18);
    final date2 = DateTime(2026, 9, 19);
    final a = addition('a-protected', date1);
    final snapshot = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.single,
      selectedDates: [date1],
      selectedPrayers: const [PrayerType.fajr],
    );

    await repo.createAddition(
      addition: a,
      records: [
        record('r-pending', a.id, date1),
        record('r-completed-protected', a.id, date2),
      ],
    );
    await db.qazaRecordsDao.completeByIds(
      userId: 'u',
      ids: ['r-completed-protected'],
      completedAt: DateTime(2026, 9, 20),
    );

    final result = await repo.editAddition(
      userId: 'u',
      additionId: a.id,
      expectedRevision: 1,
      snapshot: snapshot,
      requestedKeys: {
        QazaRecordKey(date: date1, prayerType: PrayerType.fajr),
      },
      recordsToAdd: const [],
    );

    expect(result.removedCount, 0);
    expect(result.protectedCount, 1);
    expect(
        (await repo.getRecordsForAddition(
          userId: 'u',
          additionId: a.id,
        )),
        hasLength(2));
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
    expect(
        (await repo.getRecordsForAddition(userId: 'u', additionId: a.id))
            .length,
        2);
  });
  test('delete includes records changed from completed back to pending',
      () async {
    final start = DateTime(2026, 10, 1);
    final a = addition('a-delete-repending', start);
    final records = [
      for (var i = 0; i < 10; i++)
        record(
          'r-delete-repending-$i',
          a.id,
          DateTime(start.year, start.month, start.day + i),
        ),
    ];

    await repo.createAddition(
      addition: a,
      records: records,
    );

    final completed = await db.qazaRecordsDao.completeByIds(
      userId: 'u',
      ids: records.take(6).map((item) => item.id).toList(growable: false),
      completedAt: DateTime(2026, 10, 12),
    );
    expect(completed, hasLength(6));
    expect(
      completed.every((item) => item.completionId != null),
      isTrue,
    );

    final returnedToPendingId = completed.first.id;
    final completionId = completed.first.completionId!;
    final reverted = await db.qazaRecordsDao.markCompletedAsPendingBatch(
      userId: 'u',
      expectedCompletionIds: {
        returnedToPendingId: completionId,
      },
      updatedAt: DateTime(2026, 10, 13),
    );
    expect(reverted, hasLength(1));
    expect(reverted.single.id, returnedToPendingId);
    expect(reverted.single.status, QazaStatus.pending);
    expect(reverted.single.recordVersion, greaterThan(1));

    final beforeDelete = await repo.getRecordsForAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(
      beforeDelete.where((item) => item.status == QazaStatus.pending),
      hasLength(5),
    );
    expect(
      beforeDelete.where((item) => item.status == QazaStatus.completed),
      hasLength(5),
    );

    final deleted = await repo.deleteAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(deleted.deletedCount, 5);
    expect(deleted.protectedCount, 5);
    expect(deleted.deletionActionId, isNotNull);

    final afterDelete = await repo.getRecordsForAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(afterDelete, hasLength(5));
    expect(
      afterDelete.every((item) => item.status == QazaStatus.completed),
      isTrue,
    );
    expect(
      afterDelete.map((item) => item.id).toSet(),
      completed.skip(1).map((item) => item.id).toSet(),
    );

    final deletedActions = await repo.getRecentDeletionActions(userId: 'u');
    expect(deletedActions.items, hasLength(1));
    expect(deletedActions.items.single.deletedCount, 5);
    expect(
      deletedActions.items.single.additionId,
      a.id,
    );

    final restored = await repo.restoreDeletionAction(
      userId: 'u',
      deletionActionId: deleted.deletionActionId!,
    );
    expect(restored.restoredCount, 5);
    expect(restored.conflictCount, 0);

    final afterRestore = await repo.getRecordsForAddition(
      userId: 'u',
      additionId: a.id,
    );
    expect(afterRestore, hasLength(10));
    final restoredReturnedToPending =
        afterRestore.singleWhere((item) => item.id == returnedToPendingId);
    expect(restoredReturnedToPending.status, QazaStatus.pending);
    expect(restoredReturnedToPending.recordVersion, greaterThan(1));
  });
}
