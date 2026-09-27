import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_target_sheet.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _TestHomePrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _TestHomePrayerSelectionNotifier(this.initial);

  final HomePrayerSelectionState initial;

  @override
  HomePrayerSelectionState build() => initial;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows three modes and expands the 3x2 Prayer Selection grid', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        homePrayerSelectionProvider.overrideWith(
          () => _TestHomePrayerSelectionNotifier(
            const HomePrayerSelectionState(),
          ),
        ),
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
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showHomeQazaTargetSheet(
                  context: context,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Qaza Target'), findsOneWidget);
    expect(find.text('Prayer Time'), findsOneWidget);
    expect(find.text('Auto Sequence'), findsOneWidget);
    expect(find.text('Prayer Selection'), findsOneWidget);

    await tester.tap(find.byKey(
      const Key('home_qaza_target_mode_prayer_selection'),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home_qaza_target_prayer_grid')),
      findsOneWidget,
    );
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Zuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(find.text('Witr'), findsOneWidget);
  });

  testWidgets('Prayer Selection keeps exactly one selected prayer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        homePrayerSelectionProvider.overrideWith(
          () => _TestHomePrayerSelectionNotifier(
            const HomePrayerSelectionState(
              mode: HomePrayerSelectionMode.prayerSelection,
              selectedPrayer: PrayerType.fajr,
            ),
          ),
        ),
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
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showHomeQazaTargetSheet(
                  context: context,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final chips =
        tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips.where((chip) => chip.selected), hasLength(1));

    await tester.tap(find.widgetWithText(FilterChip, 'Zuhr'));
    await tester.pumpAndSettle();

    expect(
      container.read(homePrayerSelectionProvider).selectedPrayer,
      PrayerType.zuhr,
    );
    expect(
      container.read(homePrayerSelectionProvider).mode,
      HomePrayerSelectionMode.prayerSelection,
    );
   });
}
