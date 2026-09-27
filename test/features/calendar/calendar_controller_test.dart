import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';

void main() {
  group('range exclusions', () {
    test('subtracts excluded days from the final Gregorian selection', () {
      final state = CalendarSelectionState(
        selectionMode: DateSelectionMode.range,
        selectedDates: [
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 27),
        ],
        excludedDates: {
          DateTime(2026, 9, 11),
          DateTime(2026, 9, 21),
          DateTime(2026, 9, 22),
          DateTime(2026, 9, 23),
          DateTime(2026, 9, 24),
          DateTime(2026, 9, 25),
        },
      );

      expect(state.selectedCount, 15);
      expect(state.datesForStorage, [
        for (var day = 7; day <= 10; day++) DateTime(2026, 9, day),
        for (var day = 12; day <= 20; day++) DateTime(2026, 9, day),
        DateTime(2026, 9, 26),
        DateTime(2026, 9, 27),
      ]);
    });

    test('allows exclusions at range boundaries', () {
      final state = CalendarSelectionState(
        selectionMode: DateSelectionMode.range,
        selectedDates: [
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 9),
        ],
        excludedDates: {
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 9),
        },
      );

      expect(state.datesForStorage, [DateTime(2026, 9, 8)]);
    });
  });

  test('range exclusions become multiple dates without losing the selection', () {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2026, 9, 7));
    controller.select(DateTime(2026, 9, 10));
    controller.toggleRangeExclusion(DateTime(2026, 9, 8));
    controller.setSelectionMode(DateSelectionMode.multiple);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 10),
    ]);
    expect(state.excludedDates, isEmpty);
  });

  test('scattered multiple dates become a range with gap exclusions', () {
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
    expect(state.selectedDates, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 10),
    ]);
    expect(state.excludedDates, {DateTime(2026, 9, 8)});
    expect(state.datesForStorage, [
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 10),
    ]);
  });
}
