import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/prayer_selection_grid.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_controller.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime day(int value) => DateTime(2026, 10, value);

  test('edit review is available for a removal-only delta', () {
    final date = day(6);
    final snapshot = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.single,
      selectedDates: [date],
      selectedPrayers: const [PrayerType.fajr, PrayerType.zuhr],
    );
    final state = AddQazaState(
      selectedDates: [date],
      selectedPrayers: const {PrayerType.fajr},
      analysis: AddQazaAnalysis(
        items: [
          AddQazaCandidate(
            key: QazaPrayerKey(
              userId: 'guest',
              date: date,
              prayerType: PrayerType.fajr,
            ),
            status: AddQazaCandidateStatus.alreadyAdded,
          ),
        ],
      ),
      editSnapshot: snapshot,
      calendarLoading: false,
    );

    expect(state.hasEditChanges, isTrue);
    expect(state.canReview, isTrue);
  });

  test('unchanged edit stays disabled when there are no new records', () {
    final date = day(7);
    final snapshot = QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: QazaAdditionMode.single,
      selectedDates: [date],
      selectedPrayers: const [PrayerType.fajr],
    );
    final state = AddQazaState(
      selectedDates: [date],
      selectedPrayers: const {PrayerType.fajr},
      analysis: AddQazaAnalysis.empty,
      editSnapshot: snapshot,
      calendarLoading: false,
    );

    expect(state.hasEditChanges, isFalse);
    expect(state.canReview, isFalse);
  });

  test('Range keeps fully occupied dates', () {
    final availability = <DateTime, Set<PrayerType>>{
      for (var value = 1; value <= 30; value++)
        day(value): value >= 13 && value <= 15
            ? <PrayerType>{}
            : <PrayerType>{PrayerType.fajr},
    };

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.range,
        dates: [for (var value = 1; value <= 30; value++) day(value)],
        availability: availability,
      ),
      [for (var value = 1; value <= 30; value++) day(value)],
    );
  });

  test('Range to Single keeps an available endpoint', () {
    final availability = <DateTime, Set<PrayerType>>{
      day(1): {PrayerType.fajr},
      day(30): {PrayerType.isha},
    };

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.single,
        dates: [day(1), day(30)],
        availability: availability,
      ),
      [day(30)],
    );
  });

  test('Range to Single clears an unavailable endpoint without replacement', () {
    final availability = <DateTime, Set<PrayerType>>{
      day(1): {PrayerType.fajr},
      day(30): <PrayerType>{},
    };

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.single,
        dates: [day(1), day(30)],
        availability: availability,
      ),
      isEmpty,
    );
  });

  test('Range to Multiple removes only fully unavailable dates', () {
    final availability = <DateTime, Set<PrayerType>>{
      for (var value = 1; value <= 30; value++)
        day(value): value >= 13 && value <= 15
            ? <PrayerType>{}
            : <PrayerType>{PrayerType.fajr},
    };

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.multiple,
        dates: [for (var value = 1; value <= 30; value++) day(value)],
        availability: availability,
      ),
      [
        for (var value = 1; value <= 12; value++) day(value),
        for (var value = 16; value <= 30; value++) day(value),
      ],
    );
  });

  test('Single and Multiple reject fully occupied dates', () {
    final availability = <DateTime, Set<PrayerType>>{
      day(3): <PrayerType>{},
      day(4): {PrayerType.isha},
      day(5): <PrayerType>{},
    };

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.single,
        dates: [day(3)],
        availability: availability,
      ),
      isEmpty,
    );
    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.multiple,
        dates: [day(3), day(4), day(5)],
        availability: availability,
      ),
      [day(4)],
    );
  });

  testWidgets('Witr is visually disabled when unavailable', (tester) async {
    await tester.pumpWidget(
      _gridApp(
        witrAllowed: true,
        disabledPrayers: const {PrayerType.witr},
      ),
    );
    await tester.pumpAndSettle();

    final witrChip = find.ancestor(
      of: find.text('Witr'),
      matching: find.byType(FilterChip),
    );
    expect(witrChip, findsOneWidget);
    expect(tester.widget<FilterChip>(witrChip).onSelected, isNull);
  });

  testWidgets('profile-disabled Witr remains hidden', (tester) async {
    await tester.pumpWidget(
      _gridApp(
        witrAllowed: false,
        disabledPrayers: const <PrayerType>{},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Witr'), findsNothing);
    expect(find.byType(FilterChip), findsNWidgets(5));
  });

  testWidgets(
    'loading can make every visible prayer chip non-interactive',
    (tester) async {
      await tester.pumpWidget(
        _gridApp(
          witrAllowed: true,
          disabledPrayers: PrayerType.values.toSet(),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byType(FilterChip);
      expect(chips, findsNWidgets(6));
      for (var index = 0; index < chips.evaluate().length; index++) {
        expect(
          tester.widget<FilterChip>(chips.at(index)).onSelected,
          isNull,
        );
      }
    },
  );
}

Widget _gridApp({
  required bool witrAllowed,
  required Set<PrayerType> disabledPrayers,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PrayerSelectionGrid(
          selected: const <PrayerType>{},
          witrAllowed: witrAllowed,
          disabledPrayers: disabledPrayers,
          onPrayerSelected: (_) {},
        ),
      ),
    );
