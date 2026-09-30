import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_activity.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget buildWidget() {
    return ProviderScope(
      overrides: [
        homeLocalDateProvider.overrideWithValue(DateTime(2026, 9, 30)),
        activeUserIdProvider.overrideWithValue(null),
        dailyQazaTargetProvider.overrideWithValue(5),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: HomeQazaActivity(),
          ),
        ),
      ),
    );
  }

  QazaActivityPeriod activityPeriod({
    required DateTime today,
    required int completedOnWednesday,
  }) {
    const dates = <DateTime>[
      DateTime(2026, 9, 27),
      DateTime(2026, 9, 28),
      DateTime(2026, 9, 29),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 2),
      DateTime(2026, 10, 3),
    ];

    return QazaActivityPeriod(
      from: dates.first,
      toExclusive: DateTime(2026, 10, 4),
      today: today,
      dailyTarget: 5,
      targetAvailable: true,
      days: [
        for (var index = 0; index < dates.length; index++)
          QazaDailyActivity(
            date: dates[index],
            completed: index == 3 ? completedOnWednesday : 0,
            byPrayer: const {},
            target: 5,
            isFuture: dates[index].isAfter(today),
          ),
      ],
    );
  }

  Widget buildInteractiveWidget(QazaActivityPeriod period) {
    return ProviderScope(
      overrides: [
        homeLocalDateProvider.overrideWithValue(period.today),
        homeQazaActivityWeekProvider.overrideWith(
          (ref, _) async => period,
        ),
        activeUserIdProvider.overrideWithValue(null),
        dailyQazaTargetProvider.overrideWithValue(5),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: HomeQazaActivity(),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows Weekly, Monthly and Yearly without rolling ranges',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('7 Days'), findsNothing);
      expect(find.text('30 Days'), findsNothing);
      final header = tester.widget<Text>(
        find.byKey(const Key('home_activity_date_header')),
      );
      expect(header.data, contains('2026'));
      expect(header.data, contains('Sep'));
      expect(header.data, contains('Oct'));
      expect(find.text('Weekly Target'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Target To Date'), findsNothing);
    },
  );

  testWidgets(
    'swipe changes one week and historical target is hidden',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('home_activity_pager_weekly')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      final nextHeader = tester.widget<Text>(
        find.byKey(const Key('home_activity_date_header')),
      );
      expect(nextHeader.data, contains('Oct'));
      expect(nextHeader.data, contains('2026'));
      await tester.drag(
        find.byKey(const Key('home_activity_pager_weekly')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      final previousHeader = tester.widget<Text>(
        find.byKey(const Key('home_activity_date_header')),
      );
      expect(previousHeader.data, contains('Sep'));
      expect(previousHeader.data, contains('2026'));
    },
  );

  testWidgets('monthly shows calendar-month target semantics', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Monthly Target'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Target To Date'), findsNothing);
    expect(find.byKey(const Key('home_activity_month_grid')), findsOneWidget);
  });

  testWidgets(
    'yearly shows twelve buckets and actual-activity metrics',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Active Days'), findsOneWidget);
      expect(find.text('Active Months'), findsOneWidget);
      expect(find.byKey(const Key('home_activity_year_chart')), findsOneWidget);
      expect(find.text('Monthly Target'), findsNothing);
      expect(find.text('Weekly Target'), findsNothing);
    },
  );

  testWidgets(
    'tapping Wednesday shows completed, daily target and remaining',
    (tester) async {
      final period = activityPeriod(
        today: DateTime(2026, 9, 30),
        completedOnWednesday: 3,
      );
      await tester.pumpWidget(buildInteractiveWidget(period));
      await tester.pumpAndSettle();

      final chart = find.byKey(const Key('home_activity_week_chart'));
      final rect = tester.getRect(chart);
      await tester.tapAt(
        Offset(
          rect.left + rect.width * (3.5 / 7),
          rect.bottom - 28,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wednesday, September 30, 2026'), findsOneWidget);
      expect(find.text('Daily Target'), findsOneWidget);
      expect(find.text('Remaining'), findsWidgets);
      expect(find.byKey(const Key('home_activity_day_details')), findsOneWidget);
    },
  );

  testWidgets(
    'future selected day shows its remaining target',
    (tester) async {
      final period = activityPeriod(
        today: DateTime(2026, 9, 30),
        completedOnWednesday: 3,
      );
      await tester.pumpWidget(buildInteractiveWidget(period));
      await tester.pumpAndSettle();

      final chart = find.byKey(const Key('home_activity_week_chart'));
      final rect = tester.getRect(chart);
      await tester.tapAt(
        Offset(
          rect.left + rect.width * (5.5 / 7),
          rect.bottom - 28,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thursday, October 1, 2026'), findsOneWidget);
      expect(find.text('Daily Target'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
    },
  );

  testWidgets('current period blocks navigation into the future',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    final next = tester.widget<IconButton>(
      find.byKey(const Key('home_activity_next')),
    );
    expect(next.onPressed, isNull);

    final previous = tester.widget<IconButton>(
      find.byKey(const Key('home_activity_previous')),
    );
    expect(previous.onPressed, isNotNull);
  });
}
