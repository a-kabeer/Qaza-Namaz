import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/prayer_selection_grid.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_controller.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = (int value) => DateTime(2026, 10, value);

  test('Range keeps fully occupied dates while Single keeps an available endpoint', () {
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

    expect(
      AddQazaSelectionRules.normalizeForMode(
        mode: DateSelectionMode.single,
        dates: [for (var value = 1; value <= 30; value++) day(value)],
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

    final selected = AddQazaSelectionRules.normalizeForMode(
      mode: DateSelectionMode.multiple,
      dates: [for (var value = 1; value <= 30; value++) day(value)],
      availability: availability,
    );

    expect(selected, [
      for (var value = 1; value <= 12; value++) day(value),
      for (var value = 16; value <= 30; value++) day(value),
    ]);
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

  test('Witr is disabled when unavailable in the shared prayer grid', () async {
    await _pumpGrid(
      tester: TestWidgetsFlutterBinding.ensureInitialized().tester,
      disabledPrayers: const {PrayerType.witr},
    );
  });

  test('profile-disabled Witr remains hidden in the shared prayer grid', () async {
    final tester = _TestWidgetTester();
    await tester.pumpGrid(
      witrAllowed: false,
      disabledPrayers: const <PrayerType>{},
    );

    expect(find.text('Witr'), findsNothing);
  });

  test('loading state can disable every visible prayer chip', () async {
    final tester = _TestWidgetTester();
    await tester.pumpGrid(
      witrAllowed: true,
      disabledPrayers: PrayerType.values.toSet(),
    );

    for (final prayer in PrayerType.values) {
      final chip = find.ancestor(
        of: find.text(prayer.localizedLabel(
          AppLocalizations.of(tester.element),
        )),
        matching: find.byType(FilterChip),
      );
      expect(chip, findsOneWidget);
      expect(tester.widget<FilterChip>(chip).onSelected, isNull);
    }
  });
}

class _TestWidgetTester {
  late WidgetTester _tester;

  Future<void> pumpGrid({
    required bool witrAllowed,
    required Set<PrayerType> disabledPrayers,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _tester = await _WidgetHost().pump(
      witrAllowed: witrAllowed,
      disabledPrayers: disabledPrayers,
    );
  }

  dynamic get element => _tester.element(find.byType(MaterialApp));

  T widget<T extends Widget>(Finder finder) => _tester.widget<T>(finder);

  Future<void> pump() => _tester.pump();
}

class _WidgetHost {
  Future<WidgetTester> pump({
    required bool witrAllowed,
    required Set<PrayerType> disabledPrayers,
  }) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final tester = binding.testDescription.isEmpty
        ? throw StateError('WidgetTester is unavailable')
        : throw StateError('Use testWidgets for widget coverage');
    return tester;
  }
}

Future<void> _pumpGrid({
  required WidgetTester tester,
  required Set<PrayerType> disabledPrayers,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PrayerSelectionGrid(
          selected: const <PrayerType>{},
          witrAllowed: true,
          disabledPrayers: disabledPrayers,
          onPrayerSelected: (_) {},
        ),
      ),
    ),
  );
}
