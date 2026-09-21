import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';

void main() {
  final base = DateTime(2026, 9, 21, 19);

  QazaRecord record() => QazaRecord(
        id: 'u1_fajr_2026-01-01',
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 1, 1),
        status: QazaStatus.pending,
        completedAt: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('completion undo works offline, queues update, and syncs later', () async {
    final local = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: local,
      now: () => base,
    );

    await repository.setActiveUser('u1');
    await repository.addRecord(record());
    await repository.syncNow();

    final completedAt = base.add(const Duration(minutes: 1));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'u1_fajr_2026-01-01',
      completedAt: completedAt,
    );
    await repository.syncNow();

    final undoneAt = base.add(const Duration(minutes: 2));
    final undone = await repository.undoCompletions(
      userId: 'u1',
      expectedCompletedAt: {
        'u1_fajr_2026-01-01': completedAt,
      },
      undoneAt: undoneAt,
    );

    expect(undone, 1);
    expect(
      (await repository.getRecords(userId: 'u1')).single.status,
      QazaStatus.pending,
    );
    expect((await local.load()).outboxByUser['u1'], hasLength(1));
    expect(
      (await remote.getRecords(userId: 'u1')).single.status,
      QazaStatus.completed,
    );

    await repository.syncNow();

    expect((await local.load()).outboxByUser['u1'], isEmpty);
    expect(
      (await remote.getRecords(userId: 'u1')).single.status,
      QazaStatus.pending,
    );

    repository.dispose();
  });

  test('undo is skipped after a later local edit', () async {
    final local = InMemoryQazaLocalStore();
    final remote = InMemoryQazaRepository();
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: local,
      now: () => base,
    );

    await repository.setActiveUser('u1');
    await repository.addRecord(record());
    await repository.syncNow();

    final completedAt = base.add(const Duration(minutes: 1));
    await repository.completeRecord(
      userId: 'u1',
      recordId: 'u1_fajr_2026-01-01',
      completedAt: completedAt,
    );

    final laterEdit = base.add(const Duration(minutes: 3));
    final completed = (await repository.getRecords(userId: 'u1')).single;
    await repository.updateRecord(
      record: completed.copyWith(updatedAt: laterEdit),
    );

    final undone = await repository.undoCompletions(
      userId: 'u1',
      expectedCompletedAt: {
        'u1_fajr_2026-01-01': completedAt,
      },
      undoneAt: base.add(const Duration(minutes: 4)),
    );

    expect(undone, 0);
    expect(
      (await repository.getRecords(userId: 'u1')).single.status,
      QazaStatus.completed,
    );

    repository.dispose();
  });
}
