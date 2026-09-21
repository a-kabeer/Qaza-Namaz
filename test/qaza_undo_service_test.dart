import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';

void main() {
  final base = DateTime(2026, 9, 21, 19);

  QazaRecord record(String id, PrayerType prayer) => QazaRecord(
        id: id,
        userId: 'u1',
        prayerType: prayer,
        originalDate: DateTime(2026, 1, prayer.index + 1),
        status: QazaStatus.pending,
        completedAt: null,
        createdAt: DateTime(2026, 1, prayer.index + 1),
        updatedAt: DateTime(2026, 1, prayer.index + 1),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists an undo window and expires it deterministically', () async {
    var now = base;
    final first = QazaUndoManager(now: () => now);
    await first.register(
      userId: 'u1',
      recordIds: ['r1', 'r2'],
      completedAt: base,
    );

    final restored = QazaUndoManager(now: () => now.add(const Duration(seconds: 5)));
    final batch = await restored.restore(userId: 'u1');
    expect(batch, isNotNull);
    expect(batch!.recordIds, containsAll(<String>['r1', 'r2']));

    now = base.add(const Duration(seconds: 10));
    final expired = QazaUndoManager(now: () => now);
    expect(await expired.restore(userId: 'u1'), isNull);
  });

  test('undoes one completion only when its completion timestamp still matches',
      () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));
    var now = base.add(const Duration(minutes: 2));
    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );

    final manager = QazaUndoManager(now: () => now);
    await manager.register(
      userId: 'u1',
      recordIds: ['r1'],
      completedAt: completedAt,
    );

    final count = await manager.undo(userId: 'u1', service: service);
    expect(count, 1);
    expect(
      (await repository.getRecords(userId: 'u1')).single.status,
      QazaStatus.pending,
    );
  });

  test('undoes a bulk completion as one persisted batch', () async {
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

    final manager = QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    await manager.register(
      userId: 'u1',
      recordIds: ['r1', 'r2', 'r3'],
      completedAt: completedAt,
    );

    expect(
      await manager.undo(userId: 'u1', service: service),
      3,
    );
    expect(
      (await repository.getRecords(userId: 'u1'))
          .every((item) => item.status == QazaStatus.pending),
      isTrue,
    );
  });

  test('a later edit invalidates the old undo action', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final completedAt = base.add(const Duration(minutes: 1));
    final editedAt = base.add(const Duration(minutes: 3));
    await repository.addRecord(record('r1', PrayerType.fajr));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: completedAt,
    );

    final manager = QazaUndoManager(now: () => base.add(const Duration(minutes: 2)));
    final batch = await manager.register(
      userId: 'u1',
      recordIds: ['r1'],
      completedAt: completedAt,
    );

    await repository.updateRecord(
      record: (await repository.getRecords(userId: 'u1')).single.copyWith(
        updatedAt: editedAt,
      ),
    );

    expect(
      await manager.undo(
        userId: 'u1',
        service: service,
        expectedBatch: batch,
      ),
      0,
    );
    expect(
      (await repository.getRecords(userId: 'u1')).single.status,
      QazaStatus.completed,
    );
  });

  test('an old snackbar cannot undo a newer completion batch', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final firstAt = base.add(const Duration(minutes: 1));
    final secondAt = base.add(const Duration(minutes: 2));
    await repository.addRecords([
      record('r1', PrayerType.fajr),
      record('r2', PrayerType.zuhr),
    ]);
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r1',
      completedAt: firstAt,
    );
    var now = base.add(const Duration(minutes: 3));
    final manager = QazaUndoManager(now: () => now);
    final oldBatch = await manager.register(
      userId: 'u1',
      recordIds: ['r1'],
      completedAt: firstAt,
    );

    await repository.completeRecord(
      userId: 'u1',
      recordId: 'r2',
      completedAt: secondAt,
    );
    await manager.register(
      userId: 'u1',
      recordIds: ['r2'],
      completedAt: secondAt,
    );

    expect(
      await manager.undo(
        userId: 'u1',
        service: service,
        expectedBatch: oldBatch,
      ),
      0,
    );
    expect(
      (await repository.getRecords(userId: 'u1')).every(
        (item) => item.status == QazaStatus.completed,
      ),
      isTrue,
    );
  });
}
