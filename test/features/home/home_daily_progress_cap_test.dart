import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_today_progress.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  group('HomeDailyProgress Entity Logic & 100% Cap Audit', () {
    test('calculates correct fractional percentage when below target', () {
      const progress = HomeDailyProgress(completed: 2, target: 5);
      expect(progress.percentage, closeTo(0.40, 0.001));
    });

    test('reaches exactly 1.0 (100%) when completed equals target', () {
      const progress = HomeDailyProgress(completed: 5, target: 5);
      expect(progress.percentage, 1.0);
    });

    test('intentionally clamps percentage to 1.0 (100%) when completed exceeds target', () {
      // Documented product rule: Daily progress bar and percentage are capped at 100%
      // to conform to LinearProgressIndicator [0.0, 1.0] domain and celebrate goal attainment.
      const progress = HomeDailyProgress(completed: 6, target: 5);
      expect(progress.percentage, 1.0);

      const excess = HomeDailyProgress(completed: 15, target: 5);
      expect(excess.percentage, 1.0);
    });

    test('safely handles zero or negative target without division by zero', () {
      const zeroTarget = HomeDailyProgress(completed: 5, target: 0);
      expect(zeroTarget.percentage, 0.0);

      const negativeTarget = HomeDailyProgress(completed: 5, target: -1);
      expect(negativeTarget.percentage, 0.0);
    });
  });

  group('HomeTodayProgress Widget Presentation for 6/5 (100%)', () {
    testWidgets('renders raw counts and 100% capped text consistently', (tester) async {
      final record = QazaRecord(
        id: 'fajr-test',
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 11, 11),
        createdAt: DateTime(2026, 11, 11),
        updatedAt: DateTime(2026, 11, 11),
      );

      final today = DateTime(2026, 11, 11);
      final period = QazaActivityPeriod(
        from: today,
        toExclusive: today.add(const Duration(days: 1)),
        today: today,
        days: const [],
        dailyTarget: 5,
      );

      final container = ProviderContainer(
        overrides: [
          homePrayerSelectionProvider.overrideWith(
            () => HomePrayerSelectionNotifier(),
          ),
          progressSummaryProvider.overrideWith(
            (ref) => Future.value(QazaProgressSummary.fromRecords([record])),
          ),
          qazaCompletionRestrictedProvider.overrideWith((ref) => false),
          currentQazaPrayerTypeProvider.overrideWith((ref) => PrayerType.fajr),
          oldestPendingProvider(PrayerType.fajr).overrideWith(
            (ref) => Future.value(record),
          ),
          homeFallbackPendingProvider.overrideWith(
            (ref) => Future.value(record),
          ),
          homeDashboardActivityProvider.overrideWith(
            (ref) async => HomeDashboardActivity(
              dailyProgress: const HomeDailyProgress(completed: 6, target: 5),
              currentWeek: period,
              dailyGoals: period,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: HomeTodayProgress(
                summary: QazaProgressSummary(
                  overall: QazaProgress(pending: 985, completed: 16),
                  byPrayer: {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that the summary text shows actual count 6 / 5 alongside capped 100%
      expect(find.text('6 / 5 completed • 100%'), findsOneWidget);

      // Verify progress bar value is exactly 1.0
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_today_progress_bar')),
      );
      expect(progressIndicator.value, 1.0);
    });
  });
}
