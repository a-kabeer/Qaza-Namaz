// Task 3G — calendar picker widget tests.
//
// Exercises the month-grid picker directly in both Gregorian and Hijri modes:
// mode rendering, single and range selection, alternate-calendar summary,
// past navigation, today handling, and future-date blocking. All selection is
// asserted at the domain level (canonical Gregorian dates) rather than by
// fragile screen positions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/calendar/calendar_engine.dart';
import 'package:qaza_namaz/domain/calendar/calendar_labels.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker_v2.dart';

/// Fixed clock so tests are deterministic regardless of when they run.
final DateTime _now = DateTime(2026, 9, 14);

CalendarEngine get _engine => CalendarEngine(now: () => _now);

Finder _dayKey(DateTime day) =>
    find.byKey(Key('calendar_day_${_engine.dateKey(day)}'));

Future<void> pumpPicker(
  WidgetTester tester, {
  required CalendarEngine engine,
  required CalendarMode mode,
  required ValueChanged<CalendarSelection> onSelectionChanged,
  DateSelectionMode selectionMode = DateSelectionMode.single,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? anchorDate,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: CalendarPicker(
        engine: engine,
        mode: mode,
        selectionMode: selectionMode,
        startDate: startDate,
        endDate: endDate,
        anchorDate: anchorDate,
        onSelectionChanged: onSelectionChanged,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Gregorian mode', () {
    testWidgets('renders the mode banner, grid header, weekdays and today',
        (tester) async {
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (_) {},
      );

      expect(
        find.text('Gregorian calendar'),
        findsOneWidget,
      );
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);

      // Today's cell exists in the current month.
      expect(_dayKey(DateTime(2026, 9, 14)), findsOneWidget);
      expect(
        find.byKey(const Key('calendar_selection_prompt')),
        findsOneWidget,
      );
    });

    testWidgets(
        'selecting a single day reports the canonical Gregorian date and '
        'shows both calendar dates', (tester) async {
      final engine = _engine;
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
      );

      await tester.tap(_dayKey(DateTime(2026, 9, 10)));
      await tester.pumpAndSettle();

      expect(selected?.startDate, DateTime(2026, 9, 10));
      expect(selected?.endDate, isNull);

      // The parent (Add Qaza) owns the selection and re-pumps the picker
      // with the stored date, exactly like the real flow does.
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
      );

      // Corresponding alternate Hijri date comes from the real engine.
      final hijri = engine.gregorianToHijri(DateTime(2026, 9, 10));
      expect(find.text('10 Sep 2026'), findsOneWidget);
      expect(
        find.text(CalendarLabels.formatHijriDate(hijri)),
        findsOneWidget,
      );
    });

    testWidgets('today can be selected and is highlighted', (tester) async {
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
      );

      await tester.tap(_dayKey(DateTime(2026, 9, 14)));
      await tester.pumpAndSettle();

      expect(selected?.startDate, DateTime(2026, 9, 14));

      // Re-pump with the stored selection (parent-owned state), as the
      // real Add Qaza flow does after every change callback.
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
      );

      expect(find.text('14 Sep 2026'), findsOneWidget);
      // Known anchor: 14 Sep 2026 is 3 Rabi' Al-Thani 1448 AH.
      expect(find.text('3 Rabi\' Al-Thani 1448 AH'), findsOneWidget);
    });

    testWidgets('future dates are locked: tapping them never selects',
        (tester) async {
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
      );

      // The day after today exists in the grid but is not tappable.
      final tomorrow = _dayKey(DateTime(2026, 9, 15));
      expect(tomorrow, findsOneWidget);
      expect(
        find.descendant(of: tomorrow, matching: find.byType(InkWell)),
        findsNothing,
      );

      await tester.tap(tomorrow);
      await tester.pumpAndSettle();
      expect(selected, isNull);

      // The picker cannot navigate into a fully-future month either.
      final nextButton = tester.widget<IconButton>(
        find.byKey(const Key('calendar_next_month')),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('past months can be navigated and their days are enabled',
        (tester) async {
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (s) => selected = s,
      );

      await tester.tap(find.byKey(const Key('calendar_prev_month')));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(_dayKey(DateTime(2026, 8, 3)));
      await tester.pumpAndSettle();
      expect(selected?.startDate, DateTime(2026, 8, 3));
    });

    testWidgets('navigation stops at the oldest supported month',
        (tester) async {
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (_) {},
        anchorDate: DateTime(1950, 1, 1),
      );

      expect(find.text('January 1950'), findsOneWidget);
      final prevButton = tester.widget<IconButton>(
        find.byKey(const Key('calendar_prev_month')),
      );
      expect(prevButton.onPressed, isNull);
      expect(_dayKey(DateTime(1950, 1, 15)), findsOneWidget);
    });
  });

  group('Hijri mode', () {
    testWidgets('renders the Hijri banner and a real Hijri month grid',
        (tester) async {
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.hijri,
        onSelectionChanged: (_) {},
        anchorDate: DateTime(2026, 6, 16), // 1 Muharram 1448 AH
      );

      expect(
        find.text('Hijri calendar (Umm al-Qura)'),
        findsOneWidget,
      );
      expect(find.text('Muharram 1448 AH'), findsOneWidget);
      // The canonical Gregorian day behind 1 Muharram 1448 is selectable.
      expect(_dayKey(DateTime(2026, 6, 16)), findsOneWidget);
    });

    testWidgets('selecting a Hijri day stores the canonical Gregorian date '
        'and shows the alternate Gregorian date', (tester) async {
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.hijri,
        onSelectionChanged: (s) => selected = s,
        anchorDate: DateTime(2026, 6, 16),
      );

      await tester.tap(_dayKey(DateTime(2026, 6, 16)));
      await tester.pumpAndSettle();

      expect(selected?.startDate, DateTime(2026, 6, 16));

      // Re-pump with the stored selection (parent-owned state), as the
      // real Add Qaza flow does after every change callback.
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.hijri,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
        anchorDate: DateTime(2026, 6, 16),
      );

      expect(find.text('1 Muharram 1448 AH'), findsOneWidget);
      expect(find.text('16 Jun 2026'), findsOneWidget);
    });
  });

  group('Mode switching', () {
    testWidgets('switching Gregorian -> Hijri re-renders in the Hijri view',
        (tester) async {
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.gregorian,
        onSelectionChanged: (_) {},
      );
      expect(find.text('Gregorian calendar'), findsOneWidget);

      // Restart the widget tree in Hijri mode (as the flow does when the
      // mode segmented control changes).
      await pumpPicker(
        tester,
        engine: _engine,
        mode: CalendarMode.hijri,
        onSelectionChanged: (_) {},
        anchorDate: DateTime(2026, 6, 16),
      );
      expect(find.text('Hijri calendar (Umm al-Qura)'), findsOneWidget);
      expect(find.text('Muharram 1448 AH'), findsOneWidget);
    });
  });

  group('Range selection', () {
    testWidgets('single-month range reports both bounds and expands to every '
        'day without duplicates', (tester) async {
      final engine = _engine;
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        selectionMode: DateSelectionMode.range,
        onSelectionChanged: (s) => selected = s,
        anchorDate: DateTime(2026, 7, 1),
      );

      await tester.tap(_dayKey(DateTime(2026, 7, 25)));
      await tester.pumpAndSettle();
      expect(selected?.startDate, DateTime(2026, 7, 25));
      expect(selected?.endDate, isNull);

      // The parent stores the half-picked selection and re-pumps.
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        selectionMode: DateSelectionMode.range,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
        anchorDate: DateTime(2026, 7, 1),
      );
      await tester.tap(_dayKey(DateTime(2026, 7, 28)));
      await tester.pumpAndSettle();
      expect(selected?.endDate, DateTime(2026, 7, 28));

      // Domain-level assertion: expansion is inclusive, contiguous, unique.
      final picked = selected!;
      final days = engine.expandRange(picked.startDate, picked.endDate!);
      expect(days, [
        DateTime(2026, 7, 25),
        DateTime(2026, 7, 26),
        DateTime(2026, 7, 27),
        DateTime(2026, 7, 28),
      ]);
      expect(days.toSet().length, days.length);

      // Summary shows both boundaries and the inclusive day count.
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        selectionMode: DateSelectionMode.range,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
        endDate: selected?.endDate,
        anchorDate: DateTime(2026, 7, 1),
      );
      expect(find.text('25 Jul 2026'), findsOneWidget);
      expect(find.text('28 Jul 2026'), findsOneWidget);
      // The day count is scoped to the summary so it does not collide with
      // the day-cell "4" rendered in the visible July grid.
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar_selected_summary')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('range spanning months includes every day across the boundary',
        (tester) async {
      final engine = _engine;
      CalendarSelection? selected;
      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        selectionMode: DateSelectionMode.range,
        onSelectionChanged: (s) => selected = s,
        anchorDate: DateTime(2026, 7, 1),
      );

      await tester.tap(_dayKey(DateTime(2026, 7, 28)));
      await tester.pumpAndSettle();

      await pumpPicker(
        tester,
        engine: engine,
        mode: CalendarMode.gregorian,
        selectionMode: DateSelectionMode.range,
        onSelectionChanged: (s) => selected = s,
        startDate: selected?.startDate,
        anchorDate: DateTime(2026, 7, 1),
      );
      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(_dayKey(DateTime(2026, 8, 2)));
      await tester.pumpAndSettle();
      expect(selected?.endDate, DateTime(2026, 8, 2));

      final picked = selected!;
      final days = engine.expandRange(picked.startDate, picked.endDate!);
      expect(days, [
        DateTime(2026, 7, 28),
        DateTime(2026, 7, 29),
        DateTime(2026, 7, 30),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      ]);
      expect(days.toSet().length, days.length);
    });
  });
}