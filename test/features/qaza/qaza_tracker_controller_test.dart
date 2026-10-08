import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';

void main() {
  test('Reset clears filters while preserving the current status workspace',
      () {
    final state = QazaTrackerState(
      statusFilter: QazaStatusFilter.completed,
      prayerFilter: PrayerType.fajr,
      from: DateTime(2026, 9, 10),
      to: DateTime(2026, 9, 12),
      additionId: 'addition-1',
      selectionMode: true,
      selectionScope: QazaSelectionScope.completed,
      selected: {'record-1'},
    );

    final reset = state.copyWith(
      clearPrayerFilter: true,
      clearDates: true,
      clearAdditionId: true,
      selectionMode: false,
      selected: const <String>{},
      clearSelectionScope: true,
    );

    expect(reset.isFiltered, isFalse);
    expect(reset.statusFilter, QazaStatusFilter.completed);
    expect(reset.prayerFilter, isNull);
    expect(reset.from, isNull);
    expect(reset.to, isNull);
    expect(reset.additionId, isNull);
    expect(reset.selectionMode, isFalse);
    expect(reset.selectionScope, isNull);
    expect(reset.selected, isEmpty);
  });
  test('Sort direction is part of shared tracker state', () {
    const initial = QazaTrackerState();
    expect(initial.sortOrder, QazaSortOrder.oldestFirst);

    final newest = initial.copyWith(
      sortOrder: QazaSortOrder.newestFirst,
    );
    expect(newest.sortOrder, QazaSortOrder.newestFirst);
  });

  test('Status-specific default sort mapping is stable', () {
    expect(
      QazaStatusFilter.pending.defaultSortOrder,
      QazaSortOrder.oldestFirst,
    );
    expect(
      QazaStatusFilter.completed.defaultSortOrder,
      QazaSortOrder.newestFirst,
    );
    expect(
      QazaStatusFilter.all.defaultSortOrder,
      QazaSortOrder.oldestFirst,
    );
  });

  test('Fresh Completed request initializes with newest-first sort', () {
    final container = ProviderContainer(
      overrides: [
        activeUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    container.read(qazaTrackerFilterRequestProvider.notifier).state =
        const QazaTrackerFilterRequest(
      status: QazaStatusFilter.completed,
    );

    final state = container.read(qazaTrackerControllerProvider(null));

    expect(state.statusFilter, QazaStatusFilter.completed);
    expect(state.sortOrder, QazaSortOrder.newestFirst);
  });

  test('Status switching resets to the target workspace default', () {
    final container = ProviderContainer(
      overrides: [
        activeUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final provider = qazaTrackerControllerProvider(null);
    final controller = container.read(provider.notifier);

    expect(container.read(provider).sortOrder, QazaSortOrder.oldestFirst);

    controller.setSortOrder(QazaSortOrder.newestFirst);
    expect(container.read(provider).sortOrder, QazaSortOrder.newestFirst);

    controller.setStatusFilter(QazaStatusFilter.completed);
    expect(container.read(provider).sortOrder, QazaSortOrder.newestFirst);

    controller.setSortOrder(QazaSortOrder.oldestFirst);
    expect(container.read(provider).sortOrder, QazaSortOrder.oldestFirst);

    controller.setStatusFilter(QazaStatusFilter.pending);
    expect(container.read(provider).sortOrder, QazaSortOrder.oldestFirst);
  });

  test('Status-changing filter request resets to the target workspace default',
      () async {
    final container = ProviderContainer(
      overrides: [
        activeUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final provider = qazaTrackerControllerProvider(null);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    controller.setSortOrder(QazaSortOrder.newestFirst);
    expect(container.read(provider).sortOrder, QazaSortOrder.newestFirst);

    container.read(qazaTrackerFilterRequestProvider.notifier).state =
        const QazaTrackerFilterRequest(
      status: QazaStatusFilter.completed,
    );

    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider).statusFilter, QazaStatusFilter.completed);
    expect(container.read(provider).sortOrder, QazaSortOrder.newestFirst);
  });

  test('Same-status filter request preserves explicit sort selection',
      () async {
    final container = ProviderContainer(
      overrides: [
        activeUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final provider = qazaTrackerControllerProvider(null);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    controller.setStatusFilter(QazaStatusFilter.completed);
    controller.setSortOrder(QazaSortOrder.oldestFirst);
    expect(container.read(provider).sortOrder, QazaSortOrder.oldestFirst);

    container.read(qazaTrackerFilterRequestProvider.notifier).state =
        const QazaTrackerFilterRequest(
      status: QazaStatusFilter.completed,
    );

    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider).statusFilter, QazaStatusFilter.completed);
    expect(container.read(provider).sortOrder, QazaSortOrder.oldestFirst);
  });
}
