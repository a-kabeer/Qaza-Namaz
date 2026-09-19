import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/utils/date_formatters.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_day_colors.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

import 'support/test_app.dart';

/// A range that leaves the month it started in.
void main() {
  // Far enough ahead that the task's own examples are all in the past.
  final today = DateTime(2027, 6, 1);

  /// Availability for one month at a time, the way Add Qaza loads it, with
  /// [unavailable] having nothing left to record.
  Map<DateTime, Set<PrayerType>> monthAvailability(
    DateTime month, {
    Set<DateTime> unavailable = const {},
  }) {
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.isAfter(today) ? today : last;
    return {
      for (var d = DateTime(month.year, month.month, 1);
          !d.isAfter(end);
          d = DateTime(d.year, d.month, d.day + 1))
        d: unavailable.any(
                (u) => u.year == d.year && u.month == d.month && u.day == d.day)
            ? <PrayerType>{}
            : {PrayerType.fajr},
    };
  }

  /// A picker wired the way Add Qaza wires it: month-by-month availability,
  /// plus a resolver for a span that reaches past the visible month.
  Widget app({
    Set<DateTime> unavailable = const {},
    DateSelectionMode mode = DateSelectionMode.range,
    ThemeData? theme,
    List<DateTime>? spanRequests,
  }) {
    return ProviderScope(
      overrides: [calendarTodayProvider.overrideWithValue(today)],
      child: TestApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, child) {
                Future.microtask(() => ref
                    .read(calendarControllerProvider.notifier)
                    .setSelectionMode(mode));
                return _Host(
                  unavailable: unavailable,
                  availabilityFor: monthAvailability,
                  onSpan: (start, end) => spanRequests?.addAll([start, end]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapDay(WidgetTester tester, DateTime date) async {
    final key = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    await tester.tap(find.byKey(Key('calendar_day_$key')));
    await tester.pumpAndSettle();
  }

  Future<void> goToMonth(WidgetTester tester, int months) async {
    final key = months > 0
        ? const Key('calendar_next_month')
        : const Key('calendar_prev_month');
    for (var i = 0; i < months.abs(); i++) {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }
  }

  /// The month the picker opens on is the current one; step back to [month].
  Future<void> openMonth(WidgetTester tester, DateTime month) async {
    final delta = (month.year - today.year) * 12 + (month.month - today.month);
    await goToMonth(tester, delta);
  }

  CalendarSelectionState selection(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(CalendarPicker)),
      ).read(calendarControllerProvider);

  group('a range across months and years', () {
    testWidgets('1 Sep 2026 to 3 Nov 2026 is one continuous range',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 1));
      await goToMonth(tester, 2);
      await tapDay(tester, DateTime(2026, 11, 3));

      final state = selection(tester);
      expect(state.isRangeComplete, isTrue);
      expect(state.startDate, DateTime(2026, 9, 1));
      expect(state.endDate, DateTime(2026, 11, 3));
      // September 30 + October 31 + November 3.
      expect(state.datesForStorage, hasLength(64));
    });

    testWidgets('20 Dec 2026 to 5 Jan 2027 crosses the year', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 12));
      await tapDay(tester, DateTime(2026, 12, 20));
      await goToMonth(tester, 1);
      await tapDay(tester, DateTime(2027, 1, 5));

      final state = selection(tester);
      expect(state.startDate, DateTime(2026, 12, 20));
      expect(state.endDate, DateTime(2027, 1, 5));
      expect(state.datesForStorage, hasLength(17));
      expect(state.datesForStorage.last, DateTime(2027, 1, 5));
    });

    testWidgets('the span that is checked is the whole range', (tester) async {
      final requests = <DateTime>[];
      await tester.pumpWidget(app(spanRequests: requests));
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 1));
      await goToMonth(tester, 2);
      await tapDay(tester, DateTime(2026, 11, 3));

      expect(requests, [DateTime(2026, 9, 1), DateTime(2026, 11, 3)]);
    });

    testWidgets('an ineligible date inside the range still refuses it',
        (tester) async {
      // Eligibility is unchanged: one fully recorded day in October blocks a
      // range that would cover it.
      await tester.pumpWidget(app(unavailable: {DateTime(2026, 10, 12)}));
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 1));
      await goToMonth(tester, 2);
      await tapDay(tester, DateTime(2026, 11, 3));

      final state = selection(tester);
      expect(state.isRangeComplete, isFalse);
      expect(state.selectedDates, [DateTime(2026, 9, 1)]);
    });

    testWidgets('a range inside one month still works', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 4));
      await tapDay(tester, DateTime(2026, 9, 9));

      final state = selection(tester);
      expect(state.datesForStorage, hasLength(6));
    });

    testWidgets('Single mode is untouched', (tester) async {
      await tester.pumpWidget(app(mode: DateSelectionMode.single));
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 4));
      await tapDay(tester, DateTime(2026, 9, 9));

      expect(selection(tester).selectedDates, [DateTime(2026, 9, 9)]);
    });

    testWidgets('Multiple mode is untouched', (tester) async {
      await tester.pumpWidget(app(mode: DateSelectionMode.multiple));
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 4));
      await tapDay(tester, DateTime(2026, 9, 9));

      expect(selection(tester).selectedDates,
          [DateTime(2026, 9, 4), DateTime(2026, 9, 9)]);
    });
  });

  group('range colours', () {
    /// The day number's own style.
    TextStyle dayStyle(WidgetTester tester, DateTime date) {
      final key = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return tester
          .widget<Text>(find.descendant(
            of: find.byKey(Key('calendar_day_$key')),
            matching: find.text('${date.day}'),
          ))
          .style!;
    }

    Color? dayBackground(WidgetTester tester, DateTime date) {
      final key = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final container = tester.widget<Container>(find.descendant(
        of: find.byKey(Key('calendar_day_$key')),
        matching: find.byType(Container),
      ));
      return (container.decoration as BoxDecoration).color;
    }

    for (final brightness in Brightness.values) {
      testWidgets(
          'an end and a middle both sit on their own colour in '
          '${brightness.name}', (tester) async {
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        await tester.pumpWidget(app(theme: theme));
        await tester.pumpAndSettle();

        await openMonth(tester, DateTime(2026, 9));
        await tapDay(tester, DateTime(2026, 9, 4));
        await tapDay(tester, DateTime(2026, 9, 9));

        final scheme = theme.colorScheme;
        for (final end in [DateTime(2026, 9, 4), DateTime(2026, 9, 9)]) {
          expect(dayBackground(tester, end), scheme.primary, reason: '$end');
          expect(dayStyle(tester, end).color, scheme.onPrimary, reason: '$end');
        }
        for (final middle in [DateTime(2026, 9, 6), DateTime(2026, 9, 7)]) {
          expect(dayBackground(tester, middle), scheme.primaryContainer);
          // The defect: this used to be the plain body colour on a container
          // it was never paired with.
          expect(dayStyle(tester, middle).color, scheme.onPrimaryContainer);
        }
      });
    }

    test('every status pairs its text with its own background', () {
      for (final brightness in Brightness.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        expect(
          CalendarDayColors.resolve(scheme, CalendarDayStatus.selected)
              .foreground,
          scheme.onPrimary,
        );
        expect(
          CalendarDayColors.resolve(scheme, CalendarDayStatus.inRange)
              .foreground,
          scheme.onPrimaryContainer,
        );
        expect(
          CalendarDayColors.resolve(scheme, CalendarDayStatus.today).foreground,
          scheme.onSecondaryContainer,
        );
        expect(
          CalendarDayColors.resolve(scheme, CalendarDayStatus.normal)
              .foreground,
          scheme.onSurface,
        );
        expect(
          CalendarDayColors.resolve(scheme, CalendarDayStatus.normal)
              .background,
          isNull,
        );
      }
    });

    test('selection wins over the range, and the range over today', () {
      expect(
        CalendarDayColors.statusFor(
            selected: true, inRange: true, isToday: true, available: true),
        CalendarDayStatus.selected,
      );
      expect(
        CalendarDayColors.statusFor(
            selected: false, inRange: true, isToday: true, available: true),
        CalendarDayStatus.inRange,
      );
      expect(
        CalendarDayColors.statusFor(
            selected: false, inRange: false, isToday: true, available: false),
        CalendarDayStatus.unavailable,
      );
    });
  });

  group('the selected-date summary', () {
    test('a complete Gregorian date carries its year', () {
      expect(DateFormatters.formatGregorianFull(DateTime(2026, 9, 1)),
          '1 September 2026');
      expect(DateFormatters.formatGregorianFull(DateTime(2027, 1, 31)),
          '31 January 2027');
    });

    testWidgets('a single date shows day, month and year over the Hijri date',
        (tester) async {
      await tester.pumpWidget(app(mode: DateSelectionMode.single));
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 1));

      final summary = find.byKey(const Key('calendar_selected_summary'));
      expect(
        find.descendant(of: summary, matching: find.text('1 September 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.text(DateFormatters.hijriLabel(DateTime(2026, 9, 1))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('both ends of a range are formatted the same way',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openMonth(tester, DateTime(2026, 9));
      await tapDay(tester, DateTime(2026, 9, 1));
      await goToMonth(tester, 2);
      await tapDay(tester, DateTime(2026, 11, 3));

      final summary = find.byKey(const Key('calendar_selected_summary'));
      expect(
        find.descendant(of: summary, matching: find.text('1 September 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('3 November 2026')),
        findsOneWidget,
      );
    });
  });
}

/// Holds the month-by-month availability the way Add Qaza does.
class _Host extends StatefulWidget {
  const _Host({
    required this.unavailable,
    required this.availabilityFor,
    required this.onSpan,
  });

  final Set<DateTime> unavailable;
  final Map<DateTime, Set<PrayerType>> Function(DateTime month,
      {Set<DateTime> unavailable}) availabilityFor;
  final void Function(DateTime start, DateTime end) onSpan;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Map<DateTime, Set<PrayerType>>? availability;

  void _loadMonth(DateTime month) {
    setState(() => availability =
        widget.availabilityFor(month, unavailable: widget.unavailable));
  }

  Future<Map<DateTime, Set<PrayerType>>> _loadSpan(
      DateTime start, DateTime end) async {
    widget.onSpan(start, end);
    final result = <DateTime, Set<PrayerType>>{};
    for (var month = DateTime(start.year, start.month, 1);
        !month.isAfter(DateTime(end.year, end.month, 1));
        month = DateTime(month.year, month.month + 1, 1)) {
      result.addAll(
          widget.availabilityFor(month, unavailable: widget.unavailable));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => CalendarPicker(
        availablePrayersByDate: availability,
        onMonthChanged: _loadMonth,
        resolveAvailability: _loadSpan,
      );
}
