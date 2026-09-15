import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';

import 'package:qaza_namaz/core/utils/qaza_date.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

void main() {
  final today = DateTime(2027, 3, 9);

  ProviderScope scope(Widget child, {DateTime? calendarToday}) => ProviderScope(
        overrides: [
          calendarTodayProvider.overrideWithValue(calendarToday ?? today),
        ],
        child: child,
      );

  test('matches independent Umm al-Qura Gregorian reference dates', () {
    final references = <({DateTime gregorian, int year, int month, int day})>[
      (gregorian: DateTime(2026, 6, 15), year: 1447, month: 12, day: 29),
      (gregorian: DateTime(2026, 6, 16), year: 1448, month: 1, day: 1),
      (gregorian: DateTime(2026, 6, 25), year: 1448, month: 1, day: 10),
      (gregorian: DateTime(2027, 2, 8), year: 1448, month: 9, day: 1),
      (gregorian: DateTime(2027, 3, 8), year: 1448, month: 9, day: 29),
      (gregorian: DateTime(2027, 3, 9), year: 1448, month: 10, day: 1),
    ];

    for (final reference in references) {
      final hijri = HijriCalendar.fromDate(reference.gregorian);
      expect(
        [hijri.hYear, hijri.hMonth, hijri.hDay],
        [reference.year, reference.month, reference.day],
      );
      expect(
        HijriCalendar().hijriToGregorian(
          reference.year,
          reference.month,
          reference.day,
        ),
        reference.gregorian,
      );
    }
  });

  test('serializes and deserializes calendar dates without timezone offsets', () {
    final values = <DateTime>[
      DateTime.utc(2026, 6, 16, 23, 59),
      DateTime.utc(2027, 3, 9, 0, 1),
      DateTime(2024, 2, 29, 12, 30),
    ];

    for (final value in values) {
      final stored = QazaDate.key(value);
      final restored = QazaDate.parseKey(stored);

      expect(stored, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(restored, DateTime(value.year, value.month, value.day));
      expect(restored.isUtc, isFalse);
    }
  });

  test('inclusive date range crosses Gregorian year boundary', () {
    final container = ProviderContainer(
      overrides: [calendarTodayProvider.overrideWithValue(DateTime(2027, 1, 2))],
    );
    addTearDown(container.dispose);

    final controller = container.read(calendarControllerProvider.notifier);
    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2026, 12, 30));
    controller.select(DateTime(2027, 1, 2));

    expect(container.read(calendarControllerProvider).datesForStorage, [
      DateTime(2026, 12, 30),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 1),
      DateTime(2027, 1, 2),
    ]);
  });

  testWidgets('Gregorian navigation crosses December to January', (tester) async {
    await tester.pumpWidget(
      scope(const MaterialApp(home: Scaffold(body: CalendarPicker())),
          calendarToday: DateTime(2027, 1, 15)),
    );
    await tester.pumpAndSettle();

    expect(find.text('January 2027'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_prev_month')));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_next_month')));
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
  });

  testWidgets('Hijri navigation crosses Ramadan to Shawwal boundary', (tester) async {
    await tester.pumpWidget(
      scope(
        const MaterialApp(home: Scaffold(body: CalendarPicker())),
        calendarToday: today,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hijri'));
    await tester.pumpAndSettle();

    final shawwal = HijriCalendar.fromDate(today);
    expect(shawwal.hYear, 1448);
    expect(shawwal.hMonth, 10);
    expect(
      find.text('${shawwal.getLongMonthName()} ${shawwal.hYear} AH'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar_prev_month')));
    await tester.pumpAndSettle();

    final ramadan = HijriCalendar()
      ..hYear = 1448
      ..hMonth = 9
      ..hDay = 1;
    expect(
      find.text('${ramadan.getLongMonthName()} ${ramadan.hYear} AH'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar_next_month')));
    await tester.pumpAndSettle();
    expect(
      find.text('${shawwal.getLongMonthName()} ${shawwal.hYear} AH'),
      findsOneWidget,
    );
  });

  testWidgets('Gregorian leap-day boundary renders February 29', (tester) async {
    await tester.pumpWidget(
      scope(const MaterialApp(home: Scaffold(body: CalendarPicker())),
          calendarToday: DateTime(2024, 3, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('March 2024'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_prev_month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_2024-02-29')), findsOneWidget);
  });

  testWidgets('future Gregorian dates are disabled at the today boundary', (tester) async {
    await tester.pumpWidget(
      scope(
        const MaterialApp(home: Scaffold(body: CalendarPicker())),
        calendarToday: DateTime(2027, 1, 15),
      ),
    );
    await tester.pumpAndSettle();

    final todayCell = tester.widget<InkWell>(
      find.byKey(const Key('calendar_day_2027-01-15')),
    );
    final futureCell = tester.widget<InkWell>(
      find.byKey(const Key('calendar_day_2027-01-16')),
    );

    expect(todayCell.onTap, isNotNull);
    expect(futureCell.onTap, isNull);
  });

  testWidgets('Gregorian minimum supported date blocks previous navigation', (tester) async {
    await tester.pumpWidget(
      scope(
        const MaterialApp(home: Scaffold(body: CalendarPicker())),
        calendarToday: DateTime(1950, 1, 15),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('January 1950'), findsOneWidget);
    final previous = tester.widget<IconButton>(
      find.byKey(const Key('calendar_prev_month')),
    );
    expect(previous.onPressed, isNull);
  });
}
