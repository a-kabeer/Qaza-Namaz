import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_target_sheet.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_controller.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _TestPrayerTimeController extends PrayerTimeController {
  @override
  Future<PrayerTimeSnapshot?> build() async => null;
}

class _TestHomePrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _TestHomePrayerSelectionNotifier(this.initial);

  final HomePrayerSelectionState initial;

  @override
  HomePrayerSelectionState build() => initial;
}

void main() {
  QazaProgressSummary summaryFor(Map<PrayerType, int> pending) {
    final byPrayer = <PrayerType, PrayerProgress>{
      for (final prayer in PrayerType.values)
        prayer: PrayerProgress(
          prayerType: prayer,
          progress: QazaProgress(
            pending: pending[prayer] ?? 0,
            completed: 0,
          ),
        ),
    };
    final totalPending = byPrayer.values.fold<int>(
      0,
      (sum, item) => sum + item.progress.pending,
    );
    return QazaProgressSummary(
      overall: QazaProgress(pending: totalPending, completed: 0),
      byPrayer: byPrayer,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows three modes and expands the 3x2 Prayer Selection grid', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        progressSummaryProvider.overrideWith(
          (ref) => Future.value(
            summaryFor({
              PrayerType.fajr: 1,
              PrayerType.zuhr: 2,
            }),
          ),
        ),
        effectiveWitrProvider.overrideWith((ref) => true),
        homePrayerSelectionProvider.overrideWith(
          () => _TestHomePrayerSelectionNotifier(
            const HomePrayerSelectionState(),
          ),
        ),
        prayerTimeControllerProvider.overrideWith(
          _TestPrayerTimeController.new,
        ),
        progressSummaryProvider.overrideWith(
          (ref) => Future.value(
            summaryFor({
              PrayerType.zuhr: 2,
              PrayerType.maghrib: 1,
              PrayerType.witr: 3,
            }),
          ),
        ),
        effectiveWitrProvider.overrideWith((ref) => true),
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
      const Key('home_qaza_target_mode_prayer_time'),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home_qaza_target_prayer_time_setup')),
      findsOneWidget,
    );
    expect(find.text('Prayer times are not set up yet.'), findsOneWidget);
    expect(
      container.read(homePrayerSelectionProvider).mode,
      HomePrayerSelectionMode.autoSequence,
    );

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

    for (final prayer in [
      PrayerType.fajr,
      PrayerType.asr,
      PrayerType.isha,
    ]) {
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, prayer.label),
      );
      expect(chip.onSelected, isNull);
    }

    for (final prayer in [
      PrayerType.zuhr,
      PrayerType.maghrib,
      PrayerType.witr,
    ]) {
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, prayer.label),
      );
      expect(chip.onSelected, isNotNull);
    }

    await tester.tap(find.byKey(
      const Key('home_qaza_target_mode_prayer_time'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('home_qaza_target_setup_prayer_times'),
    ));
    await tester.pumpAndSettle();

    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.prayerTime,
    );
    expect(
      find.byKey(const Key('home_qaza_target_sheet')),
      findsNothing,
    );
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
