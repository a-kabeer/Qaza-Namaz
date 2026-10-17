import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'when all Qaza is completed, keeps overall progress without a replacement card',
    (tester) async {
      final today = DateTime(2026, 10, 17);
      const summary = QazaProgressSummary(
        overall: QazaProgress(pending: 0, completed: 3),
        byPrayer: {},
      );
      final activityPeriod = QazaActivityPeriod(
        from: today,
        toExclusive: today.add(const Duration(days: 1)),
        today: today,
        days: const [],
        dailyTarget: 5,
      );
      final activity = HomeDashboardActivity(
        dailyProgress: const HomeDailyProgress(completed: 0, target: 5),
        currentWeek: activityPeriod,
        dailyGoals: activityPeriod,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressSummaryProvider.overrideWith(
              (ref) async => summary,
            ),
            homeDashboardActivityProvider.overrideWith(
              (ref) async => activity,
            ),
            homeNowProvider.overrideWithValue(today),
            dailySalahTrackingEnabledProvider.overrideWith(
              (ref) async => false,
            ),
            dailySalahTrackingSetupDismissedProvider.overrideWith(
              (ref) async => true,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The existing Overall Qaza card is the single source of completion UI.
      expect(find.byKey(const Key('home_overall_qaza')), findsOneWidget);
      expect(find.byKey(const Key('home_overall_percent')), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // There is no action to complete and no redundant all-completed card.
      expect(find.byKey(const Key('home_today_progress')), findsNothing);
      expect(find.byKey(const Key('home_complete_oldest_qaza')), findsNothing);
      expect(find.byKey(const Key('home_all_completed_state')), findsNothing);

      // Other dashboard sections remain available.
      expect(find.byKey(const Key('home_daily_goals')), findsOneWidget);
      expect(find.byKey(const Key('home_qaza_goals')), findsOneWidget);
    },
  );
}
