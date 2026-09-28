import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_today_progress.dart';
import 'package:qaza_namaz/features/qaza/completion/qaza_completion_controller.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

class _TestHomePrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _TestHomePrayerSelectionNotifier(this.initial);

  final HomePrayerSelectionState initial;

  @override
  HomePrayerSelectionState build() => initial;
}

QazaRecord _pendingFajr() => QazaRecord(
      id: 'fajr',
      userId: 'u1',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
    );

Future<ProviderContainer> _containerFor({
  required HomePrayerSelectionState selection,
  required void Function() onDailyProgressRead,
}) async {
  return ProviderContainer(
    overrides: [
      homePrayerSelectionProvider.overrideWith(
        () => _TestHomePrayerSelectionNotifier(selection),
      ),
      homeSelectedPrayerProvider.overrideWith(
        (ref) => HomeSelectedPrayerState(
          mode: selection.mode,
          prayer: PrayerType.fajr,
          source: switch (selection.mode) {
            HomePrayerSelectionMode.prayerTime =>
              HomePrayerSelectionSource.prayerTime,
            HomePrayerSelectionMode.autoSequence =>
              HomePrayerSelectionSource.autoSequence,
            HomePrayerSelectionMode.prayerSelection =>
              HomePrayerSelectionSource.prayerSelection,
          },
        ),
      ),
      sahibAlTartibProvider.overrideWith(
        (ref) async => const SahibAlTartibState(
          pendingFarzCount: 6,
          requiresOrder: false,
          nextPending: null,
        ),
      ),
      qazaCompletionRestrictedProvider.overrideWith((ref) => false),
      oldestPendingProvider(PrayerType.fajr).overrideWith(
        (ref) async => _pendingFajr(),
      ),
      homeDailyProgressProvider.overrideWith((ref) {
        onDailyProgressRead();
        return const HomeDailyProgress(completed: 2, target: 5);
      }),
      progressSummaryProvider.overrideWith(
        (ref) async => QazaProgressSummary.fromRecords([_pendingFajr()]),
      ),
    ],
  );
}

Future<void> _pumpHomeTodayProgress(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeTodayProgress(
            summary: QazaProgressSummary.fromRecords([_pendingFajr()]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows Today Progress and Next Qaza in Auto Sequence', (
    tester,
  ) async {
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container);

    expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
    expect(find.byKey(const Key('home_today_donut')), findsOneWidget);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(dailyReads, 1);
  });

  testWidgets('hides Today Progress but keeps completion in Prayer Time', (
    tester,
  ) async {
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerTime,
      ),
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container);

    expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
    expect(find.byKey(const Key('home_today_donut')), findsNothing);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(find.text('Today’s Progress'), findsNothing);
    expect(dailyReads, 0);
  });

  testWidgets('hides Today Progress but keeps completion in Prayer Selection', (
    tester,
  ) async {
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: PrayerType.fajr,
      ),
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container);

    expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
    expect(find.byKey(const Key('home_today_donut')), findsNothing);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(find.text('Today’s Progress'), findsNothing);
    expect(dailyReads, 0);
  });
}
