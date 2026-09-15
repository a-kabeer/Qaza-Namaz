import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';
import 'package:qaza_namaz/features/qaza/qaza_add_flow_v2.dart';

final _today = DateTime(2026, 9, 14);

ProviderScope _scope(Widget child, {InMemoryQazaRepository? repository}) => ProviderScope(
      overrides: [
        calendarTodayProvider.overrideWithValue(_today),
        if (repository != null) ...[
          qazaRepositoryProvider.overrideWithValue(repository),
          activeUserIdProvider.overrideWithValue('u1'),
        ],
      ],
      child: child,
    );

Future<void> _scrollToContinue(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(const Key('qaza_continue_button')), 300, scrollable: find.byType(Scrollable).first);
}

void main() {
  test('package converts Gregorian to Umm al-Qura Hijri and back exactly', () {
    final hijri = HijriCalendar.fromDate(_today);
    expect([hijri.hYear, hijri.hMonth, hijri.hDay], [1448, 4, 3]);
    expect(HijriCalendar().hijriToGregorian(hijri.hYear, hijri.hMonth, hijri.hDay), _today);
  });

  test('package handles Gregorian leap day conversion', () {
    final leap = DateTime(2024, 2, 29);
    final hijri = HijriCalendar.fromDate(leap);
    expect(HijriCalendar().hijriToGregorian(hijri.hYear, hijri.hMonth, hijri.hDay), leap);
  });

  test('Riverpod controller supports single, range and multi-date selection', () {
    final container = ProviderContainer(overrides: [calendarTodayProvider.overrideWithValue(_today)]);
    addTearDown(container.dispose);
    final controller = container.read(calendarControllerProvider.notifier);
    controller.select(DateTime(2026, 9, 10));
    expect(container.read(calendarControllerProvider).selectedDates, [DateTime(2026, 9, 10)]);
    controller.setSelectionMode(DateSelectionMode.range);
    controller.select(DateTime(2026, 9, 10));
    controller.select(DateTime(2026, 9, 13));
    expect(container.read(calendarControllerProvider).selectedDates, [DateTime(2026, 9, 10), DateTime(2026, 9, 13)]);
    controller.setSelectionMode(DateSelectionMode.multiple);
    controller.select(DateTime(2026, 9, 12));
    controller.select(DateTime(2026, 9, 10));
    controller.select(DateTime(2026, 9, 10));
    expect(container.read(calendarControllerProvider).selectedDates, [DateTime(2026, 9, 12)]);
    controller.setSelectionMode(DateSelectionMode.single);
    controller.select(DateTime(2026, 9, 12));
    controller.select(DateTime(2026, 9, 15));
    expect(container.read(calendarControllerProvider).selectedDates, [DateTime(2026, 9, 12)]);
  });

  testWidgets('Gregorian calendar renders and navigates months', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: Scaffold(body: CalendarPicker()))));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_prev_month')));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('Hijri calendar renders package month and converts a selected day', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: Scaffold(body: CalendarPicker()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hijri'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1448 AH'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-13')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_selected_summary')), findsOneWidget);
  });

  testWidgets('future date is disabled and qaza indicator is rendered', (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecord(QazaRecord(id: 'u1_fajr_2026-09-10', userId: 'u1', prayerType: PrayerType.fajr, originalDate: DateTime(2026, 9, 10), createdAt: _today, updatedAt: _today));
    await tester.pumpWidget(_scope(MaterialApp(home: Scaffold(body: CalendarPicker(qazaDates: {DateTime(2026, 9, 10)}))), repository: repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_qaza_indicator_2026-09-10')), findsOneWidget);
    final tomorrow = find.byKey(const Key('calendar_day_2026-09-15'));
    final ink = tester.widget<InkWell>(tomorrow);
    expect(ink.onTap, isNull);
  });

  testWidgets('calendar stores canonical Gregorian originalDate through Qaza flow', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: QazaAddFlowV2Screen()), repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hijri'));
    await tester.pumpAndSettle();
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-13')));
    await tester.tap(find.text('Next: Choose missed prayers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maghrib'));
    await tester.tap(find.text('Review & Create Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final records = await repository.getRecords(userId: 'u1');
    expect(records.single.originalDate, DateTime(2026, 9, 13));
    expect(records.single.prayerType, PrayerType.maghrib);
  });

  testWidgets('range flow persists every day in the selected range', (tester) async {
    final repository = InMemoryQazaRepository();
    await tester.pumpWidget(_scope(const MaterialApp(home: QazaAddFlowV2Screen()), repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Range'));
    await _scrollToContinue(tester);
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2026-09-13')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Choose missed prayers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fajr'));
    await tester.tap(find.text('Review & Create Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(4));
    expect(records.map((r) => r.originalDate).toSet(), {DateTime(2026, 9, 10), DateTime(2026, 9, 11), DateTime(2026, 9, 12), DateTime(2026, 9, 13)});
  });
}
