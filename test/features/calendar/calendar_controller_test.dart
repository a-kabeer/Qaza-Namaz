import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';

void main() {
  test('range selection keeps every date in the selected span', () {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2026, 9, 1));
    controller.select(
      DateTime(2026, 9, 15),
      isDateSelectable: (date) =>
          !date.isBefore(DateTime(2026, 9, 1)) &&
          !date.isAfter(DateTime(2026, 9, 27)),
    );

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 15),
    ]);
    expect(state.selectedCount, 15);
    expect(state.datesForStorage, [
      for (var day = 1; day <= 15; day++) DateTime(2026, 9, day),
    ]);
  });

  test('range rejects an endpoint when the span contains an invalid date', () {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2026, 9, 7));
    controller.select(
      DateTime(2026, 9, 15),
      isDateSelectable: (date) => date != DateTime(2026, 9, 11),
    );

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [DateTime(2026, 9, 7)]);
  });

  test('contiguous multiple dates convert to a normal range', () {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.multiple);
    for (var day = 7; day <= 10; day++) {
      controller.select(DateTime(2026, 9, day));
    }
    controller.setSelectionMode(DateSelectionMode.range);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 10),
    ]);
    expect(state.datesForStorage, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 8),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 10),
    ]);
  });

  test(
      'scattered multiple dates keep only a clear range start when entering range mode',
      () {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.multiple);
    controller.select(DateTime(2026, 9, 7));
    controller.select(DateTime(2026, 9, 9));
    controller.select(DateTime(2026, 9, 10));
    controller.setSelectionMode(DateSelectionMode.range);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [DateTime(2026, 9, 7)]);
    expect(state.datesForStorage, [DateTime(2026, 9, 7)]);
  });
}
