import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';

import 'support/test_app.dart';

void main() {
  // A current month in the middle of the year, so "months after the current
  // month" is a real boundary rather than December.
  final today = DateTime(2026, 9, 18);

  final monthChanges = <DateTime>[];

  setUp(monthChanges.clear);

  Future<void> pumpCalendar(
    WidgetTester tester, {
    DateTime? calendarToday,
    Map<DateTime, Set<PrayerType>>? availability,
    Set<DateTime> qazaDates = const <DateTime>{},
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        calendarTodayProvider.overrideWithValue(calendarToday ?? today),
      ],
      child: TestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarPicker(
              qazaDates: qazaDates,
              availablePrayersByDate: availability,
              onMonthChanged: monthChanges.add,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openYearSelector(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('calendar_month_header_button')));
    await tester.pumpAndSettle();
  }

  /// The grid inside the dialog, not the page behind it.
  Finder yearGrid() => find.descendant(
        of: find.byKey(const Key('calendar_year_selector')),
        matching: find.byType(Scrollable),
      );

  /// Brings a year cell fully on screen. The grid builds a cache beyond the
  /// viewport, so being findable is not the same as being tappable.
  Future<void> revealYear(WidgetTester tester, int year) async {
    final target = find.byKey(Key('calendar_year_$year'));
    await tester.scrollUntilVisible(target, -120, scrollable: yearGrid());
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> chooseYear(WidgetTester tester, int year) async {
    await openYearSelector(tester);
    await revealYear(tester, year);
    await tester.tap(find.byKey(Key('calendar_year_$year')));
    await tester.pumpAndSettle();
  }

  String headerText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('calendar_month_header'))).data!;

  group('opening the selector', () {
    testWidgets('the month header opens a year selector', (tester) async {
      await pumpCalendar(tester);

      expect(find.byKey(const Key('calendar_year_selector')), findsNothing);
      await openYearSelector(tester);

      expect(find.byKey(const Key('calendar_year_selector')), findsOneWidget);
      expect(find.text('Select year'), findsOneWidget);
    });

    testWidgets('offers 1950 through the current year and no further',
        (tester) async {
      // A 1952 "today" puts the whole range on one screen, so the bounds are
      // asserted directly instead of through scrolling.
      await pumpCalendar(tester, calendarToday: DateTime(1952, 3, 4));
      await openYearSelector(tester);

      expect(find.byKey(const Key('calendar_year_1949')), findsNothing);
      expect(find.byKey(const Key('calendar_year_1950')), findsOneWidget);
      expect(find.byKey(const Key('calendar_year_1951')), findsOneWidget);
      expect(find.byKey(const Key('calendar_year_1952')), findsOneWidget);
      expect(find.byKey(const Key('calendar_year_1953')), findsNothing);
    });

    testWidgets('never offers a year beyond the current one', (tester) async {
      await pumpCalendar(tester);
      await openYearSelector(tester);

      // The grid opens on the current year, so a later one would be on screen
      // if it existed at all.
      expect(find.byKey(const Key('calendar_year_2026')), findsOneWidget);
      expect(find.byKey(const Key('calendar_year_2027')), findsNothing);
    });

    testWidgets('dismissing changes nothing', (tester) async {
      await pumpCalendar(tester);
      final before = headerText(tester);
      monthChanges.clear();

      await openYearSelector(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(headerText(tester), before);
      expect(monthChanges, isEmpty);
    });
  });

  group('selecting a year', () {
    testWidgets('jumps to that year and keeps the month', (tester) async {
      await pumpCalendar(tester);
      expect(headerText(tester), 'September 2026');

      await chooseYear(tester, 1950);

      expect(headerText(tester), 'September 1950');
    });

    testWidgets('reloads availability for the new month', (tester) async {
      await pumpCalendar(tester);
      monthChanges.clear();

      await chooseYear(tester, 1975);

      expect(monthChanges, [DateTime(1975, 9, 1)]);
    });

    testWidgets('re-picking the same year does not reload', (tester) async {
      await pumpCalendar(tester);
      monthChanges.clear();

      await chooseYear(tester, 2026);

      expect(monthChanges, isEmpty);
      expect(headerText(tester), 'September 2026');
    });

    testWidgets('month navigation still works afterwards', (tester) async {
      await pumpCalendar(tester);
      await chooseYear(tester, 1990);
      monthChanges.clear();

      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.pumpAndSettle();
      expect(headerText(tester), 'October 1990');

      await tester.tap(find.byKey(const Key('calendar_prev_month')));
      await tester.tap(find.byKey(const Key('calendar_prev_month')));
      await tester.pumpAndSettle();
      expect(headerText(tester), 'August 1990');
      expect(monthChanges, [
        DateTime(1990, 10, 1),
        DateTime(1990, 9, 1),
        DateTime(1990, 8, 1),
      ]);
    });

    testWidgets('the Hijri label follows the Gregorian jump', (tester) async {
      await pumpCalendar(tester);
      final before = tester
          .widget<Text>(find.byKey(const Key('calendar_hijri_month_label')))
          .data;

      await chooseYear(tester, 1960);

      final after = tester
          .widget<Text>(find.byKey(const Key('calendar_hijri_month_label')))
          .data;
      expect(after, isNot(before));
      expect(after, isNotEmpty);
    });
  });

  group('boundaries', () {
    testWidgets('a month after today clamps to the current month',
        (tester) async {
      await pumpCalendar(tester);
      // Walk back a year first so December is reachable, then return to 2026.
      await chooseYear(tester, 2025);
      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.pumpAndSettle();
      expect(headerText(tester), 'December 2025');
      monthChanges.clear();

      await chooseYear(tester, 2026);

      // December 2026 does not exist yet, so the jump lands on September.
      expect(headerText(tester), 'September 2026');
      expect(monthChanges, [DateTime(2026, 9, 1)]);
    });

    testWidgets('the next arrow is disabled in the current month',
        (tester) async {
      await pumpCalendar(tester);

      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendar_next_month')))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendar_prev_month')))
              .onPressed,
          isNotNull);
    });

    testWidgets('the previous arrow is disabled at January 1950',
        (tester) async {
      await pumpCalendar(tester, calendarToday: DateTime(1950, 3, 4));
      await tester.tap(find.byKey(const Key('calendar_prev_month')));
      await tester.tap(find.byKey(const Key('calendar_prev_month')));
      await tester.pumpAndSettle();

      expect(headerText(tester), 'January 1950');
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendar_prev_month')))
              .onPressed,
          isNull);
    });

    testWidgets('days beyond today stay unselectable after a year jump',
        (tester) async {
      await pumpCalendar(tester);
      await chooseYear(tester, 2026);

      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('calendar_day_2026-09-18')))
              .onTap,
          isNotNull);
      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('calendar_day_2026-09-19')))
              .onTap,
          isNull);
    });
  });

  group('selection is preserved', () {
    for (final mode in DateSelectionMode.values) {
      testWidgets('a ${mode.name} selection survives a year jump',
          (tester) async {
        await pumpCalendar(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CalendarPicker)),
        );
        container
            .read(calendarControllerProvider.notifier)
            .setSelectionMode(mode);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('calendar_day_2026-09-10')));
        if (mode == DateSelectionMode.range) {
          await tester.tap(find.byKey(const Key('calendar_day_2026-09-12')));
        }
        await tester.pumpAndSettle();
        final before = container.read(calendarControllerProvider).selectedDates;
        expect(before, isNotEmpty);

        await chooseYear(tester, 1985);

        final after = container.read(calendarControllerProvider);
        expect(after.selectedDates, before);
        expect(after.selectionMode, mode);
      });
    }

    testWidgets('per-date availability still governs the new year',
        (tester) async {
      await pumpCalendar(
        tester,
        availability: {
          DateTime(1980, 5, 3): {PrayerType.fajr},
          DateTime(1980, 5, 4): <PrayerType>{},
        },
      );
      await chooseYear(tester, 1980);
      // Back from September to May in the chosen year.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('calendar_prev_month')));
      }
      await tester.pumpAndSettle();
      expect(headerText(tester), 'May 1980');

      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('calendar_day_1980-05-03')))
              .onTap,
          isNotNull);
      // Listed with no prayers left, and listed-but-empty means unavailable.
      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('calendar_day_1980-05-04')))
              .onTap,
          isNull);
      // Absent from the map entirely is also unavailable.
      expect(
          tester
              .widget<InkWell>(find.byKey(const Key('calendar_day_1980-05-05')))
              .onTap,
          isNull);
    });
  });
}
