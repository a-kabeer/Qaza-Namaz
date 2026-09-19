import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

import 'support/in_memory_qaza_repository.dart';

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) {
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: date,
    status: status,
    completedAt: status == QazaStatus.completed ? date : null,
    createdAt: date,
    updatedAt: date,
  );
}

DateTime _day(int day) => DateTime(2026, 9, day);

void main() {
  group('Calendar selection', () {
    test('single and multiple modes never accept unavailable dates', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(17)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      bool selectable(DateTime date) => date != _day(12);

      controller.select(_day(12), isDateSelectable: selectable);
      expect(container.read(calendarControllerProvider).selectedDates, isEmpty);

      controller.select(_day(10), isDateSelectable: selectable);
      expect(
          container.read(calendarControllerProvider).selectedDates, [_day(10)]);
    });

    test('range mode rejects a range containing an unavailable day', () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      bool selectable(DateTime date) => date != _day(12);

      controller.select(_day(10), isDateSelectable: selectable);
      controller.select(_day(15), isDateSelectable: selectable);

      expect(
          container.read(calendarControllerProvider).selectedDates, [_day(10)]);
    });

    test('range mode accepts a fully eligible range and expands it for storage',
        () {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(_day(30)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      controller.setSelectionMode(DateSelectionMode.range);
      controller.select(_day(10));
      controller.select(_day(12));

      final state = container.read(calendarControllerProvider);
      expect(state.selectedDates, [_day(10), _day(12)]);
      expect(state.datesForStorage, [_day(10), _day(11), _day(12)]);
    });
  });

  group('Calendar widget', () {
    testWidgets('disables dates with no remaining eligible prayers',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarTodayProvider.overrideWithValue(_day(17)),
          ],
          child: TestApp(
            home: CalendarPicker(
              availablePrayersByDate: {
                _day(10): {PrayerType.fajr},
                _day(11): <PrayerType>{},
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final availableCell = tester.widget<InkWell>(
        find.byKey(const Key('calendar_day_2026-09-10')),
      );
      final unavailableCell = tester.widget<InkWell>(
        find.byKey(const Key('calendar_day_2026-09-11')),
      );
      expect(availableCell.onTap, isNotNull);
      expect(unavailableCell.onTap, isNull);
    });
  });

}
