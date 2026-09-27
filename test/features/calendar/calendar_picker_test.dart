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
      final scheme = Theme.of(tester.element(daySeven)).colorScheme;
      expect(daySevenText.style?.color, scheme.onSurface);

      await tester.tap(daySeven);
      await tester.pump();
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
              dateSelectablePredicate: (date) =>
                  date != DateTime(2026, 9, 11),
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
}
