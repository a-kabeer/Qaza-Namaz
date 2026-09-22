import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';

import 'support/in_memory_qaza_repository.dart';

/// Task 14 — the tracker reads from either end, deterministically.
void main() {
  const userId = 'u1';
  final now = DateTime(2026, 9, 22);

  QazaRecord record(String id, DateTime date,
          {PrayerType prayer = PrayerType.fajr}) =>
      QazaRecord(
        id: id,
        userId: userId,
        prayerType: prayer,
        originalDate: date,
        createdAt: now,
        updatedAt: now,
      );

  /// Five days, and two records that share a day so the tie-breaker matters.
  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record('r_03', DateTime(2026, 1, 3)),
      record('r_01', DateTime(2026, 1, 1)),
      record('r_05', DateTime(2026, 1, 5)),
      // Same day as r_03, different prayer: only the id can separate them.
      record('r_03b', DateTime(2026, 1, 3), prayer: PrayerType.asr),
      record('r_02', DateTime(2026, 1, 2)),
    ]);
    return repository;
  }

  ProviderContainer container(InMemoryQazaRepository repository) {
    final result = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(result.dispose);
    result.listen(qazaTrackerControllerProvider, (_, __) {});
    return result;
  }

  Future<QazaTrackerController> ready(ProviderContainer scope) async {
    final controller = scope.read(qazaTrackerControllerProvider.notifier);
    await controller.refresh();
    return controller;
  }

  List<String> ids(ProviderContainer scope) => scope
      .read(qazaTrackerControllerProvider)
      .records
      .map((r) => r.id)
      .toList();

  test('the default is oldest first', () async {
    final scope = container(await ledger());
    await ready(scope);

    expect(scope.read(qazaTrackerControllerProvider).sortOrder,
        QazaSortOrder.oldestFirst);
    expect(ids(scope), ['r_01', 'r_02', 'r_03', 'r_03b', 'r_05']);
  });

  test('newest first reverses the ledger', () async {
    final scope = container(await ledger());
    final controller = await ready(scope);

    controller.setSortOrder(QazaSortOrder.newestFirst);
    await Future<void>.delayed(Duration.zero);

    expect(ids(scope), ['r_05', 'r_03b', 'r_03', 'r_02', 'r_01']);
  });

  test('records sharing a date are separated by id, both ways', () async {
    final scope = container(await ledger());
    final controller = await ready(scope);

    // Ascending: r_03 before r_03b.
    final ascending = ids(scope);
    expect(ascending.indexOf('r_03'), lessThan(ascending.indexOf('r_03b')));

    controller.setSortOrder(QazaSortOrder.newestFirst);
    await Future<void>.delayed(Duration.zero);

    // Descending: exactly the reverse, never an arbitrary shuffle.
    final descending = ids(scope);
    expect(descending.indexOf('r_03b'), lessThan(descending.indexOf('r_03')));
    expect(descending, ascending.reversed.toList());
  });

  test('the order is stable across repeated reads', () async {
    final scope = container(await ledger());
    final controller = await ready(scope);
    final first = ids(scope);

    await controller.refresh();
    await controller.refresh();

    expect(ids(scope), first);
  });

  test('switching order clears the page and the selection', () async {
    final scope = container(await ledger());
    final controller = await ready(scope);
    controller.toggleSelection('r_01');
    expect(scope.read(qazaTrackerControllerProvider).selected, {'r_01'});

    controller.setSortOrder(QazaSortOrder.newestFirst);
    await Future<void>.delayed(Duration.zero);

    // Paging state cannot survive a direction change, so neither does a
    // selection made against the old page.
    expect(scope.read(qazaTrackerControllerProvider).selected, isEmpty);
    expect(ids(scope), isNotEmpty);
  });

  group('select all matching (task 13)', () {
    test('selects every pending record, not just the loaded page', () async {
      final repository = InMemoryQazaRepository();
      // More than one page, so "loaded" and "matching" genuinely differ.
      await repository.addRecords([
        for (var day = 1; day <= 120; day++)
          record('r_${day.toString().padLeft(3, '0')}', DateTime(2026, 3, day)),
      ]);
      final scope = container(repository);
      final controller = await ready(scope);

      final loaded = scope.read(qazaTrackerControllerProvider).records.length;
      expect(loaded, lessThan(120), reason: 'the list is paged');

      await controller.selectAllMatching();

      expect(
          scope.read(qazaTrackerControllerProvider).selected, hasLength(120));
    });

    test('respects the filter it is run under', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        record('f_1', DateTime(2026, 4, 1)),
        record('f_2', DateTime(2026, 4, 2)),
        record('a_1', DateTime(2026, 4, 3), prayer: PrayerType.asr),
      ]);
      final scope = container(repository);
      final controller = await ready(scope);

      controller.setPrayerFilter(PrayerType.asr);
      await Future<void>.delayed(Duration.zero);
      await controller.selectAllMatching();

      expect(scope.read(qazaTrackerControllerProvider).selected, {'a_1'});
    });

    test('never gathers more than its cap', () async {
      final repository = InMemoryQazaRepository();
      final over = QazaTrackerController.selectAllMatchingCap + 50;
      await repository.addRecords([
        for (var i = 0; i < over; i++)
          record('r_${i.toString().padLeft(5, '0')}',
              DateTime(2026, 1, 1).add(Duration(days: i))),
      ]);
      final scope = container(repository);
      final controller = await ready(scope);

      await controller.selectAllMatching();

      expect(scope.read(qazaTrackerControllerProvider).selected,
          hasLength(QazaTrackerController.selectAllMatchingCap));
    });

    test('a large selection is flagged as needing confirmation', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        for (var day = 1; day <= 30; day++)
          record('r_${day.toString().padLeft(2, '0')}', DateTime(2026, 5, day)),
      ]);
      final scope = container(repository);
      final controller = await ready(scope);

      controller.toggleSelection('r_01');
      expect(
          scope.read(qazaTrackerControllerProvider).selectionNeedsConfirmation,
          isFalse,
          reason: 'one record needs no ceremony');

      await controller.selectAllMatching();

      expect(
          scope.read(qazaTrackerControllerProvider).selectionNeedsConfirmation,
          isTrue);
    });
  });

  test('re-selecting the same order is a no-op', () async {
    final scope = container(await ledger());
    final controller = await ready(scope);
    controller.toggleSelection('r_01');

    controller.setSortOrder(QazaSortOrder.oldestFirst);
    await Future<void>.delayed(Duration.zero);

    expect(scope.read(qazaTrackerControllerProvider).selected, {'r_01'},
        reason: 'nothing changed, so nothing should have been thrown away');
  });
}
