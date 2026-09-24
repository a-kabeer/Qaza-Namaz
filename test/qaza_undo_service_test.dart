import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';

void main() {
  final base = DateTime(2026, 9, 21, 19);

  QazaRecord record(
    String id,
    PrayerType prayer, {
    QazaStatus status = QazaStatus.pending,
    String? completionId,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      QazaRecord(
        id: id,
        userId: 'u1',
        prayerType: prayer,
        originalDate: DateTime(2026, 1, prayer.index + 1),
        status: status,
        completedAt: completedAt,
        completionId: completionId,
        createdAt: DateTime(2026, 1, prayer.index + 1),
        updatedAt: updatedAt ?? DateTime(2026, 1, prayer.index + 1),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists completionId in the active undo window', () async {
    final completedAt = base.add(const Duration(minutes: 1));
    final completed = record(
      'r1',
      PrayerType.fajr,
      status: QazaStatus.completed,
      completionId: 'completion-1',
      completedAt: completedAt,
    );

    final manager = QazaUndoManager(now: () => base);
    await manager.register(userId: 'u1', records: [completed]);

    final restored = QazaUndoManager(
      now: () => base.add(const Duration(seconds: 4)),
    );
    final batch = await restored.restore(userId: 'u1');
    expect(batch, isNotNull);
    expect(batch!.completionIds, {'r1': 'completion-1'});

    final expired = QazaUndoManager(
      now: () => base.add(const Duration(seconds: 5)),
    );
    expect(await expired.restore(userId: 'u1'), isNull);
    expect(QazaUndoStore.window, const Duration(seconds: 5));
  });

  test('undo restores a single completion using only its completionId',
      () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );
    final completed = (await repository.getRecords(userId: 'u1')).single;

    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(userId: 'u1', records: [completed]);

    final result = await manager.undo(userId: 'u1', service: service);
    expect(result.count, 1);

    final restored = (await repository.getRecords(userId: 'u1')).single;
    expect(restored.status, QazaStatus.pending);
    expect(restored.completedAt, isNull);
    expect(restored.completionId, isNull);
  });

  test('server timestamp changes do not invalidate Undo', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );
    final completed = (await repository.getRecords(userId: 'u1')).single;

    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(userId: 'u1', records: [completed]);

    await repository.updateRecord(
      record: completed.copyWith(
        updatedAt: base.add(const Duration(minutes: 5)),
      ),
    );

    final result = await manager.undo(userId: 'u1', service: service);
    expect(result.count, 1);

    final restored = (await repository.getRecords(userId: 'u1')).single;
    expect(restored.status, QazaStatus.pending);
    expect(restored.completedAt, isNull);
    expect(restored.completionId, isNull);
  });

  test('a changed completion marker rejects the old Undo', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );
    final first = (await repository.getRecords(userId: 'u1')).single;
    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    final oldBatch =
        await manager.register(userId: 'u1', records: [first]);

    await repository.updateRecord(
      record: first.copyWith(
        completionId: 'newer-marker',
        updatedAt: base.add(const Duration(minutes: 3)),
      ),
    );

    await expectLater(
      manager.undo(
        userId: 'u1',
        service: service,
        expectedBatch: oldBatch,
      ),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.targetChanged,
        ),
      ),
    );
    expect(
      (await repository.getRecords(userId: 'u1')).single.status,
      QazaStatus.completed,
    );
  });

  test('deleted record rejects Undo and clears the stale action', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );
    final completed = (await repository.getRecords(userId: 'u1')).single;
    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(userId: 'u1', records: [completed]);
    await repository.deleteRecord(userId: 'u1', recordId: 'r1');

    await expectLater(
      manager.undo(userId: 'u1', service: service),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.targetChanged,
        ),
      ),
    );
    expect(await manager.restore(userId: 'u1'), isNull);
  });

  test('older Undo cannot affect a newer completion', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: base.add(const Duration(minutes: 1)),
    );
    final first = (await repository.getRecords(userId: 'u1')).single;

    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    final oldBatch =
        await manager.register(userId: 'u1', records: [first]);

    await repository.updateRecord(
      record: first.copyWith(
        completionId: 'newer-marker',
        completedAt: base.add(const Duration(minutes: 2)),
        updatedAt: base.add(const Duration(minutes: 2)),
      ),
    );
    final newer = (await repository.getRecords(userId: 'u1')).single;
    await manager.register(userId: 'u1', records: [newer]);

    await expectLater(
      manager.undo(
        userId: 'u1',
        service: service,
        expectedBatch: oldBatch,
      ),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.staleBatch,
        ),
      ),
    );
    expect(
      (await repository.getRecords(userId: 'u1')).single.completionId,
      'newer-marker',
    );
  });

  test('bulk Undo restores all entries and clears completion metadata',
      () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecords([
      record('r1', PrayerType.fajr),
      record('r2', PrayerType.zuhr),
      record('r3', PrayerType.asr),
    ]);
    await repository.completeRecords(
      userId: 'u1',
      recordIds: ['r1', 'r2', 'r3'],
      completedAt: completedAt,
    );

    final completed = await repository.getRecords(userId: 'u1');
    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(userId: 'u1', records: completed);

    final result = await manager.undo(userId: 'u1', service: service);
    expect(result.count, 3);
    expect(
      (await repository.getRecords(userId: 'u1')).every(
        (item) =>
            item.status == QazaStatus.pending &&
            item.completedAt == null &&
            item.completionId == null,
      ),
      isTrue,
    );
  });

  test('count zero is surfaced and removes the stale Undo action', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));

    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );
    final completed = (await repository.getRecords(userId: 'u1')).single;
    final manager =
        QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(userId: 'u1', records: [completed]);

    await repository.updateRecord(
      record: completed.copyWith(
        completionId: 'different-marker',
        completedAt: base.add(const Duration(minutes: 4)),
        updatedAt: base.add(const Duration(minutes: 4)),
      ),
    );

    await expectLater(
      manager.undo(userId: 'u1', service: service),
      throwsA(isA<QazaUndoException>()),
    );
    expect(await manager.restore(userId: 'u1'), isNull);
  });
}
