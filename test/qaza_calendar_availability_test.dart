import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

final _today = DateTime(2026, 9, 14);

QazaRecord _record(PrayerType prayer, int day) {
  final date = DateTime(2026, 9, day);
  return QazaRecord(
    id: 'u1_${prayer.name}_2026-09-${day.toString().padLeft(2, '0')}',
    userId: 'u1',
    prayerType: prayer,
    originalDate: date,
    createdAt: date,
    updatedAt: date,
  );
}

Widget _calendar(List<QazaRecord> records) {
  const availability = QazaAvailabilityService();
  return ProviderScope(
    overrides: [calendarTodayProvider.overrideWithValue(_today)],
    child: MaterialApp(
      home: Scaffold(
        body: CalendarPicker(
          isDateUnavailable: (date) => !availability.isDateAvailable(
            userId: 'u1',
            date: date,
            existingRecords: records,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('partial date stays enabled because another prayer is available', (tester) async {
    final records = [
      for (final prayer in [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ])
        _record(prayer, 10),
    ];

    await tester.pumpWidget(_calendar(records));
    await tester.pumpAndSettle();

    final day = tester.widget<InkWell>(find.byKey(const Key('calendar_day_2026-09-10')));
    expect(day.onTap, isNotNull);
  });

  testWidgets('date is disabled when every prayer is already recorded', (tester) async {
    final records = [
      for (final prayer in PrayerType.values) _record(prayer, 10),
    ];

    await tester.pumpWidget(_calendar(records));
    await tester.pumpAndSettle();

    final day = tester.widget<InkWell>(find.byKey(const Key('calendar_day_2026-09-10')));
    expect(day.onTap, isNull);
  });

  testWidgets('fully unavailable date cannot be selected in multiple-date mode', (tester) async {
    final records = [
      for (final prayer in PrayerType.values) _record(prayer, 10),
    ];

    await tester.pumpWidget(_calendar(records));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarPicker)),
    );
    container.read(calendarControllerProvider.notifier).setSelectionMode(DateSelectionMode.multiple);
    await tester.pumpAndSettle();
    expect(container.read(calendarControllerProvider).selectedDates, isEmpty);

    await tester.tap(find.byKey(const Key('calendar_day_2026-09-10')));
    await tester.pumpAndSettle();

    expect(container.read(calendarControllerProvider).selectedDates, isEmpty);
  });
}
