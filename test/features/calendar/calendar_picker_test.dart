import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/calendar/calendar_picker.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'range selection can cross fully completed dates without disabling them',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(calendarControllerProvider.notifier)
          .setSelectionMode(DateSelectionMode.range);

      final availability = <DateTime, Set<PrayerType>>{
        for (var day = 1; day <= 15; day++)
          DateTime(2026, 9, day):
              (day >= 7 && day <= 10) ? <PrayerType>{} : {PrayerType.fajr},
      };

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CalendarPicker(
                availablePrayersByDate: availability,
                dateSelectablePredicate: (date) =>
                    !date.isBefore(DateTime(2026, 9, 1)) &&
                    !date.isAfter(DateTime(2026, 9, 27)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final daySeven = find.text('7').last;
      final daySevenText = tester.widget<Text>(daySeven);
      final daySevenInkFinder = find.byKey(
        const Key('calendar_day_ink_2026-09-07'),
      );
      expect(daySevenInkFinder, findsOneWidget);
      final scheme = Theme.of(tester.element(daySeven)).colorScheme;
      expect(daySevenText.style?.color, scheme.onSurface);

      await tester.tap(daySeven);
      await tester.pump();
      final selectedDayInk = tester.widget<Ink>(daySevenInkFinder);
      expect(selectedDayInk.decoration, isA<BoxDecoration>());
      expect(
        (selectedDayInk.decoration! as BoxDecoration).shape,
        BoxShape.circle,
      );
      await tester.tap(find.text('15').last);
      await tester.pump();

      final state = container.read(calendarControllerProvider);
      expect(state.isRangeComplete, isTrue);
      expect(state.startDate, DateTime(2026, 9, 7));
      expect(state.endDate, DateTime(2026, 9, 15));
    },
  );

  testWidgets('range does not cross an invalid date', (tester) async {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 9, 27)),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(calendarControllerProvider.notifier)
        .setSelectionMode(DateSelectionMode.range);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              availablePrayersByDate: {
                for (var day = 1; day <= 27; day++)
                  DateTime(2026, 9, day): {PrayerType.fajr},
              },
              dateSelectablePredicate: (date) => date != DateTime(2026, 9, 11),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('7').last);
    await tester.pump();
    await tester.tap(find.text('15').last);
    await tester.pump();

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDates, [DateTime(2026, 9, 7)]);
  });

  testWidgets('single selected date edit opens on the selected month', (
    tester,
  ) async {
    final selected = DateTime(2018, 3, 15);
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
    );
    addTearDown(container.dispose);

    container.read(calendarControllerProvider.notifier).restoreSelection(
      mode: DateSelectionMode.single,
      dates: [selected],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              initialDisplayedMonth: selected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('March 2018'), findsOneWidget);
    expect(
      container.read(calendarControllerProvider).selectedDates,
      [selected],
    );
  });

  testWidgets('range edit opens on the start month, not the end month', (
    tester,
  ) async {
    final start = DateTime(2025, 10, 21);
    final end = DateTime(2026, 10, 21);
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 12, 31)),
      ],
    );
    addTearDown(container.dispose);

    container.read(calendarControllerProvider.notifier).restoreSelection(
      mode: DateSelectionMode.range,
      dates: [start, end],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              initialDisplayedMonth: start,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('October 2025'), findsOneWidget);
    expect(
      container.read(calendarControllerProvider).selectedDates,
      [start, end],
    );
  });

  testWidgets('multiple edit uses the earliest selected date as anchor', (
    tester,
  ) async {
    final first = DateTime(2020, 1, 10);
    final second = DateTime(2021, 6, 15);
    final third = DateTime(2023, 9, 20);
    final selected = [third, first, second];
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
    );
    addTearDown(container.dispose);

    container.read(calendarControllerProvider.notifier).restoreSelection(
          mode: DateSelectionMode.multiple,
          dates: selected,
        );

    final earliest = selected.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              initialDisplayedMonth: earliest,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('January 2020'), findsOneWidget);
    expect(
      container.read(calendarControllerProvider).selectedDates,
      selected,
    );
  });

  testWidgets('normal Add Qaza calendar still opens on the current month', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('manual month navigation is not reset after initialization', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        calendarTodayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              initialDisplayedMonth: DateTime(2025, 10, 21),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('October 2025'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_next_month')));
    await tester.pump();

    expect(find.text('November 2025'), findsOneWidget);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPicker(
              initialDisplayedMonth: DateTime(2025, 10, 21),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('November 2025'), findsOneWidget);
  });
}
