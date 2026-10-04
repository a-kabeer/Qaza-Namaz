import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_goals.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

QazaActivityPeriod _period({
  required int completed,
  required int dailyTarget,
}) {
  final from = DateTime(2026, 9, 27);
  final days = <QazaDailyActivity>[];
  var remaining = completed;

  for (var index = 0; index < 7; index++) {
    final dayCompleted = index == 6
        ? remaining
        : (remaining > 0 ? remaining.clamp(0, dailyTarget + 10).toInt() : 0);
    remaining -= dayCompleted;
    days.add(
      QazaDailyActivity(
        date: DateTime(2026, 9, 27 + index),
        completed: dayCompleted,
        byPrayer: const {},
        target: dailyTarget,
        isFuture: index > 3,
      ),
    );
  }

  return QazaActivityPeriod(
    from: from,
    toExclusive: DateTime(2026, 10, 4),
    today: DateTime(2026, 9, 30),
    days: days,
  );
}

Widget _buildWidget(QazaActivityPeriod period) {
  return ProviderScope(
    overrides: [
      homeDashboardActivityProvider.overrideWith(
        (ref) => Future.value(
          HomeDashboardActivity(
            dailyProgress: const HomeDailyProgress(completed: 0, target: 5),
            currentWeek: period,
            dailyGoals: period,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: HomeQazaGoals(onDetails: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders current Sunday-Saturday date range and weekly progress',
    (
    tester,
  ) async {
    final period = _period(completed: 29, dailyTarget: 5);

    await tester.pumpWidget(_buildWidget(period));
    await tester.pumpAndSettle();

    expect(find.text('Your weekly target'), findsOneWidget);
    expect(find.text('Sep 27 – Oct 3'), findsOneWidget);
    expect(find.text('29 of 35'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('home_qaza_goals_progress')),
    );
    expect(progress.value, closeTo(29 / 35, 0.0001));
  });

  testWidgets(
    'includes all seven days in weekly target even when three are future',
    (
    tester,
  ) async {
    final period = _period(completed: 20, dailyTarget: 5);

    await tester.pumpWidget(_buildWidget(period));
    await tester.pumpAndSettle();

    expect(period.days, hasLength(7));
    expect(period.days.where((day) => day.isFuture), hasLength(3));
    expect(find.text('20 of 35'), findsOneWidget);
  });

  testWidgets(
    'zero daily target keeps the card stable without division by zero',
    (
    tester,
  ) async {
    final period = _period(completed: 0, dailyTarget: 0);

    await tester.pumpWidget(_buildWidget(period));
    await tester.pumpAndSettle();

    expect(find.text('0 of 0'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('home_qaza_goals_progress')),
    );
    expect(progress.value, 0);
  });

  testWidgets('weekly progress is clamped at 100 percent', (tester) async {
    final period = _period(completed: 40, dailyTarget: 5);

    await tester.pumpWidget(_buildWidget(period));
    await tester.pumpAndSettle();

    expect(find.text('40 of 35'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('home_qaza_goals_progress')),
    );
    expect(progress.value, 1);
  });

  testWidgets('entire Weekly Target card opens details', (tester) async {
    var tapped = false;
    final period = _period(completed: 0, dailyTarget: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardActivityProvider.overrideWith(
            (ref) => Future.value(
              HomeDashboardActivity(
                dailyProgress:
                    const HomeDailyProgress(completed: 0, target: 5),
                currentWeek: period,
                dailyGoals: period,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: HomeQazaGoals(onDetails: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_qaza_goals_details')), findsNothing);
    await tester.tap(find.byKey(const Key('home_qaza_goals_tap')));
    expect(tapped, isTrue);
  });
}
