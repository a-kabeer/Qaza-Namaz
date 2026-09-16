import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/features/calendar/calendar_controller.dart';

void main() {
  final today = DateTime(2027, 1, 15);

  ProviderContainer container() => ProviderContainer(
        overrides: [calendarTodayProvider.overrideWithValue(today)],
      );

  test('normalizes dates and prevents duplicate multiple selections', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.setSelectionMode(DateSelectionMode.multiple);
    controller.select(DateTime(2027, 1, 10, 23, 59));
    controller.select(DateTime(2027, 1, 10, 1, 2));

    expect(scope.read(calendarControllerProvider).selectedDates, isEmpty);
    expect(scope.read(calendarControllerProvider).selectedCount, 0);
  });

  test('multiple selection stays unique and chronologically ordered', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.setSelectionMode(DateSelectionMode.multiple);
    controller.select(DateTime(2027, 1, 12));
    controller.select(DateTime(2027, 1, 8));
    controller.select(DateTime(2027, 1, 10));

    final state = scope.read(calendarControllerProvider);
    expect(state.selectedDates, [
      DateTime(2027, 1, 8),
      DateTime(2027, 1, 10),
      DateTime(2027, 1, 12),
    ]);
    expect(state.selectedCount, 3);
    expect(state.hasSelection, isTrue);
  });

  test('range restarts when an earlier date is tapped', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2027, 1, 10));
    controller.select(DateTime(2027, 1, 5));

    final state = scope.read(calendarControllerProvider);
    expect(state.selectedDates, [DateTime(2027, 1, 5)]);
    expect(state.isRangeComplete, isFalse);
    expect(state.datesForStorage, [DateTime(2027, 1, 5)]);
  });

  test('range exposes inclusive canonical storage dates', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2027, 1, 14, 23));
    controller.select(DateTime(2027, 1, 15, 5));

    final state = scope.read(calendarControllerProvider);
    expect(state.isRangeComplete, isTrue);
    expect(state.startDate, DateTime(2027, 1, 14));
    expect(state.endDate, DateTime(2027, 1, 15));
    expect(state.datesForStorage, [
      DateTime(2027, 1, 14),
      DateTime(2027, 1, 15),
    ]);
  });

  test('future dates are rejected centrally', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.select(DateTime(2027, 1, 16));

    expect(scope.read(calendarControllerProvider).hasSelection, isFalse);
  });

  test('changing selection mode clears previous selection', () {
    final scope = container();
    addTearDown(scope.dispose);
    final controller = scope.read(calendarControllerProvider.notifier);

    controller.select(DateTime(2027, 1, 10));
    controller.setSelectionMode(DateSelectionMode.range);

    final state = scope.read(calendarControllerProvider);
    expect(state.selectionMode, DateSelectionMode.range);
    expect(state.selectedDates, isEmpty);
  });
}
