import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/widgets/home_daily_goals.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_goals.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

QazaActivityPeriod _period({
  required DateTime today,
  List<int> completed = const [0, 5, 5, 5, 5, 4, 2],
  int target = 5,
  bool targetAvailable = true,
}) {
  final from = DateTime(today.year, today.month, today.day - 6);
  final days = [
    for (var index = 0; index < 7; index++)
      QazaDailyActivity(
        date: DateTime(from.year, from.month, from.day + index),
        completed: completed[index],
        byPrayer: const {},
        target: target,
        isFuture: false,
      ),
  ];
  return QazaActivityPeriod(
    from: from,
    toExclusive: DateTime(today.year, today.month, today.day + 1),
    today: today,
    days: days,
    dailyTarget: target,
    targetAvailable: targetAvailable,
  );
}

Widget _app({
  required Widget child,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.light,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme ??
          ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
      darkTheme: darkTheme ?? ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      home: Scaffold(body: child),
    );

void main() {
  final today = DateTime(2026, 9, 30);
  testWidgets('renders Daily Goals with exactly seven FL Chart groups',
      (tester) async {
    final period = _period(today: today);
    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(child: HomeDailyGoals(onDetails: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_daily_goals')), findsOneWidget);
    expect(find.text('Your daily goals'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('4/7'), findsOneWidget);
    expect(find.text('Achieved'), findsOneWidget);

    final chart = tester.widget<BarChart>(
      find.byKey(const Key('home_daily_goals_chart')),
    );
    expect(chart.data.barGroups, hasLength(7));
  });

  testWidgets('Daily Goals card details remain reachable outside the chart',
      (tester) async {
    var tapped = false;
    final period = _period(today: today);

    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(child: HomeDailyGoals(onDetails: () => tapped = true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_daily_goals_details')), findsNothing);
    final cardRect = tester.getRect(find.byKey(const Key('home_daily_goals_tap')));
    await tester.tapAt(Offset(cardRect.center.dx, cardRect.top + 10));
    expect(tapped, isTrue);
  });

  testWidgets('uses period target and completed values for each rod',
      (tester) async {
    final period = _period(
      today: today,
      completed: const [0, 6, 5, 3, 8, 4, 2],
      target: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(child: HomeDailyGoals(onDetails: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(
      find.byKey(const Key('home_daily_goals_chart')),
    );
    expect(chart.data.barGroups[1].barRods.single.toY, 5);
    expect(chart.data.barGroups[1].barRods.single.backDrawRodData.toY, 5);
    expect(chart.data.barGroups[4].barRods.single.toY, 5);
    expect(chart.data.maxY, 5);
  });

  testWidgets('press tooltip shows only the actual count, including zero',
      (tester) async {
    var detailsOpened = false;
    final period = _period(
      today: today,
      completed: const [0, 6, 5, 3, 8, 4, 2],
      target: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(
          child: HomeDailyGoals(onDetails: () => detailsOpened = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final interaction = find.byKey(
      const Key('home_daily_goals_chart_interaction'),
    );
    final chartRect = tester.getRect(interaction);

    // The first day has no visible bar, but its chart region remains tappable.
    final zeroGesture = await tester.startGesture(
      Offset(chartRect.left + chartRect.width * (0.5 / 7), chartRect.top + 40),
    );
    await tester.pump();
    final tooltip = find.byKey(const Key('home_daily_goals_tooltip'));
    expect(tester.widget<Text>(tooltip).data, '0');
    final tooltipTopForZero = tester.getTopLeft(tooltip).dy;
    expect(find.text('0 completed'), findsNothing);
    expect(detailsOpened, isFalse);
    await zeroGesture.up();
    await tester.pump();
    expect(tooltip, findsNothing);

    // Day five completed eight; the visible bar is capped at the target of 5.
    final overTargetGesture = await tester.startGesture(
      Offset(
        chartRect.left + chartRect.width * (4.5 / 7),
        chartRect.top + 40,
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(tooltip).data, '8');
    expect(tester.getTopLeft(tooltip).dy, tooltipTopForZero);
    expect(find.text('Daily target: 5'), findsNothing);
    expect(detailsOpened, isFalse);
    await overTargetGesture.up();
    await tester.pump();
    expect(tooltip, findsNothing);
  });

  testWidgets('missing target keeps completion visible without goal tracks',
      (tester) async {
    final period = _period(
      today: today,
      completed: const [0, 2, 1, 0, 0, 0, 0],
      target: 0,
      targetAvailable: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardActivityProvider.overrideWith(
            (ref) => Future.value(
              HomeDashboardActivity(
                dailyProgress: const HomeDailyProgress(completed: 0, target: 0),
                currentWeek: period,
                dailyGoals: period,
              ),
            ),
          ),
        ],
        child: _app(child: HomeDailyGoals(onDetails: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(
      find.byKey(const Key('home_daily_goals_chart')),
    );
    expect(chart.data.maxY, 2);
    expect(chart.data.barGroups[1].barRods.single.toY, 2);
    expect(chart.data.barGroups[1].barRods.single.backDrawRodData.show, isFalse);
  });

  testWidgets('chart colors follow the active dark theme', (tester) async {
    final period = _period(today: today);
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(
          child: HomeDailyGoals(onDetails: () {}),
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(
      find.byKey(const Key('home_daily_goals_chart')),
    );
    expect(chart.data.barGroups.first.barRods.single.color,
        darkTheme.colorScheme.primary);
    expect(
      chart.data.barGroups.first.barRods.single.backDrawRodData.color,
      darkTheme.colorScheme.primaryContainer,
    );
  });

  testWidgets('weekday labels come from the seven actual dates',
      (tester) async {
    final period = _period(today: today);
    await tester.pumpWidget(
      ProviderScope(
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
        child: _app(child: HomeDailyGoals(onDetails: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final labels = [
      for (final day in period.days) DateFormat('EEEEE', 'en').format(day.date),
    ];
    final expectedCounts = <String, int>{};
    for (final label in labels) {
      expectedCounts[label] = (expectedCounts[label] ?? 0) + 1;
    }
    for (final entry in expectedCounts.entries) {
      expect(find.text(entry.key), findsNWidgets(entry.value));
    }
  });

  testWidgets('daily goals provider returns today minus six through today',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeLocalDateProvider.overrideWithValue(today),
          activeUserIdProvider.overrideWithValue(null),
          dailyQazaTargetProvider.overrideWithValue(5),
        ],
        child: _app(
          child: Consumer(
            builder: (context, ref, child) {
              final period = ref.watch(homeQazaActivityDailyGoalsProvider);
              return period.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => Text('error: $error'),
                data: (value) => Text(
                  '${value.from}|${value.days.first.date}|${value.days.last.date}|${value.toExclusive}|${value.days.length}',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('2026-09-24'),
      findsWidgets,
    );
    expect(find.textContaining('2026-09-30'), findsWidgets);
    expect(find.textContaining('|7'), findsOneWidget);
  });

  testWidgets('daily goals rolls forward with the local date', (tester) async {
    final nextDay = DateTime(2026, 10, 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeLocalDateProvider.overrideWithValue(nextDay),
          activeUserIdProvider.overrideWithValue(null),
          dailyQazaTargetProvider.overrideWithValue(5),
        ],
        child: _app(
          child: Consumer(
            builder: (context, ref, child) {
              final period = ref.watch(homeQazaActivityDailyGoalsProvider);
              return period.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => Text('error: $error'),
                data: (value) => Text(
                  '${value.days.first.date}|${value.days.last.date}',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-09-25'), findsWidgets);
    expect(find.textContaining('2026-10-01'), findsWidgets);
  });

  testWidgets('loading and error states stay local to Daily Goals',
      (tester) async {
    var attempts = 0;
    final period = _period(today: today);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardActivityProvider.overrideWith((ref) async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('daily goals failed');
            }
            return HomeDashboardActivity(
              dailyProgress: const HomeDailyProgress(completed: 0, target: 5),
              currentWeek: period,
              dailyGoals: period,
            );
          }),
        ],
        child: _app(child: HomeDailyGoals(onDetails: () {})),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load your Qaza progress. Pull to retry.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('home_daily_goals_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_daily_goals_chart')), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('Daily Goals coexists with the existing Weekly Target',
      (tester) async {
    final dailyPeriod = _period(today: today);
    final weeklyDays = [
      for (var index = 0; index < 7; index++)
        QazaDailyActivity(
          date: DateTime(2026, 9, 27 + index),
          completed: index == 6 ? 29 : 0,
          byPrayer: const {},
          target: 5,
          isFuture: index > 3,
        ),
    ];
    final weeklyPeriod = QazaActivityPeriod(
      from: DateTime(2026, 9, 27),
      toExclusive: DateTime(2026, 10, 4),
      today: today,
      days: weeklyDays,
      dailyTarget: 5,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardActivityProvider.overrideWith(
            (ref) => Future.value(
              HomeDashboardActivity(
                dailyProgress: const HomeDailyProgress(completed: 2, target: 5),
                currentWeek: weeklyPeriod,
                dailyGoals: dailyPeriod,
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
            body: Column(
              children: [
                HomeDailyGoals(onDetails: () {}),
                HomeQazaGoals(onDetails: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your daily goals'), findsOneWidget);
    expect(find.text('Your weekly target'), findsOneWidget);
    expect(find.text('29 of 35'), findsOneWidget);
    expect(find.byKey(const Key('home_daily_goals_chart')), findsOneWidget);
    expect(find.byKey(const Key('home_qaza_goals_progress')), findsOneWidget);
  });
}
