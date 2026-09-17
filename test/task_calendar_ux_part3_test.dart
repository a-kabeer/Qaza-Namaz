import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

void main() {
  Widget app({required DateSelectionMode mode}) => ProviderScope(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2027, 3, 15)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, child) => Column(
                  children: [
                    SegmentedButton<DateSelectionMode>(
                      segments: const [
                        ButtonSegment(value: DateSelectionMode.single, label: Text('Single')),
                        ButtonSegment(value: DateSelectionMode.range, label: Text('Range')),
                        ButtonSegment(value: DateSelectionMode.multiple, label: Text('Multiple')),
                      ],
                      selected: {ref.watch(calendarControllerProvider).selectionMode},
                      onSelectionChanged: (value) => ref
                          .read(calendarControllerProvider.notifier)
                          .setSelectionMode(value.first),
                    ),
                    const CalendarPicker(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('single selection shows Gregorian and Hijri date summary', (tester) async {
    await tester.pumpWidget(app(mode: DateSelectionMode.single));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-15')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_selected_summary')), findsOneWidget);
    expect(find.byKey(const Key('calendar_clear_selection')), findsOneWidget);
    expect(find.textContaining('1 date selected'), findsOneWidget);
    expect(find.textContaining('15'), findsWidgets);
  });

  testWidgets('range selection shows both selected Gregorian dates', (tester) async {
    await tester.pumpWidget(app(mode: DateSelectionMode.range));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Range'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-10')));
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-12')));
    await tester.pumpAndSettle();

    final summary = find.byKey(const Key('calendar_selected_summary'));
    expect(find.textContaining('2 dates selected'), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('10')), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('12')), findsOneWidget);
  });

  testWidgets('multiple selection lists every selected Gregorian date', (tester) async {
    await tester.pumpWidget(app(mode: DateSelectionMode.multiple));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Multiple'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-12')));
    await tester.tap(find.byKey(const Key('calendar_day_2027-03-10')));
    await tester.pumpAndSettle();

    final summary = find.byKey(const Key('calendar_selected_summary'));
    expect(find.textContaining('2 dates selected'), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('10')), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('12')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_day_2027-03-10')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 date selected'), findsOneWidget);
  });
}
