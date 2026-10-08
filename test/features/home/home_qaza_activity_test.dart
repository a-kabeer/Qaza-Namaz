import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_activity.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

const _monthlyCalendarCellCountForTest = 42;

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
    bool fillEveryDay = false,
  }) {
    final dates = <DateTime>[
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
            completed: index == 3
                ? completedOnWednesday
                : fillEveryDay
                    ? 1
                    : 0,
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
      expect(find.byKey(const Key('home_activity_progress')), findsNothing);
      expect(find.text('5/day'), findsOneWidget);
    },
  );

  testWidgets(
    'dynamic weekly chart scale keeps Y-axis labels sparse',
    (tester) async {
      final period = activityPeriod(
        today: DateTime(2026, 9, 30),
        completedOnWednesday: 108,
      );
      await tester.pumpWidget(buildInteractiveWidget(period));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(const Key('home_activity_week_chart')),
          matching: find.byType(BarChart),
        ),
      );

      expect(chart.data.maxY, 120);
      expect(
        chart.data.titlesData.leftTitles.sideTitles.interval,
        20,
      );
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
    'yearly month tap selects inline monthly detail without navigation',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      final chartFinder = find.byKey(const Key('home_activity_year_chart'));
      final initialChart = tester.widget<BarChart>(
        find.descendant(of: chartFinder, matching: find.byType(BarChart)),
      );

      expect(initialChart.data.barGroups, hasLength(12));
      expect(initialChart.data.barTouchData.enabled, isTrue);
      expect(initialChart.data.barTouchData.touchCallback, isNotNull);
      expect(
        find.byKey(const Key('home_activity_inline_month_detail')),
        findsNothing,
      );
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );

      for (final index in <int>[8, 9]) {
        final latestChart = tester.widget<BarChart>(
          find.descendant(
            of: find.byKey(const Key('home_activity_year_chart')),
            matching: find.byType(BarChart),
          ),
        );
        final group = latestChart.data.barGroups[index];
        final rod = group.barRods.first;

        latestChart.data.barTouchData.touchCallback!(
          FlTapUpEvent(
            TapUpDetails(kind: PointerDeviceKind.touch),
          ),
          BarTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            spot: BarTouchedSpot(
              group,
              index,
              rod,
              0,
              null,
              -1,
              FlSpot(group.x.toDouble(), rod.toY),
              Offset.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedMonth = index == 8 ? 'September 2026' : 'October 2026';
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('home_activity_selected_month_title')),
              )
              .data,
          expectedMonth,
        );
        expect(
          find.byKey(const Key('home_activity_inline_month_detail')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('home_qaza_activity')), findsOneWidget);
        expect(
          find.byKey(const Key('home_activity_range_selector')),
          findsOneWidget,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
          isFalse,
        );

        final selectedChart = tester.widget<BarChart>(
          find.descendant(
            of: find.byKey(const Key('home_activity_year_chart')),
            matching: find.byType(BarChart),
          ),
        );
        expect(
          selectedChart.data.barGroups[index].barRods.first.color,
          Theme.of(tester.element(chartFinder)).colorScheme.primary,
        );
      }
    },
  );

  testWidgets(
    'selected month follows year navigation without stale previous-year detail',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_activity_previous')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_date_header')),
            )
            .data,
        '2025',
      );

      final chartWidget = tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(const Key('home_activity_year_chart')),
          matching: find.byType(BarChart),
        ),
      );
      final group = chartWidget.data.barGroups[11];
      final rod = group.barRods.first;

      chartWidget.data.barTouchData.touchCallback!(
        FlTapUpEvent(
          TapUpDetails(kind: PointerDeviceKind.touch),
        ),
        BarTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          spot: BarTouchedSpot(
            group,
            11,
            rod,
            0,
            null,
            -1,
            FlSpot(group.x.toDouble(), rod.toY),
            Offset.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_selected_month_title')),
            )
            .data,
        'December 2025',
      );
      expect(
        find.byKey(const Key('home_activity_inline_month_detail')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('home_activity_previous')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_date_header')),
            )
            .data,
        '2024',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_selected_month_title')),
            )
            .data,
        'December 2024',
      );
      expect(
        find.byKey(const Key('home_activity_inline_month_detail')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'zero-activity yearly months remain selectable inline',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      final chartWidget = tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(const Key('home_activity_year_chart')),
          matching: find.byType(BarChart),
        ),
      );
      final group = chartWidget.data.barGroups[10];
      final rod = group.barRods.first;

      chartWidget.data.barTouchData.touchCallback!(
        FlTapUpEvent(
          TapUpDetails(kind: PointerDeviceKind.touch),
        ),
        BarTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          spot: BarTouchedSpot(
            group,
            10,
            rod,
            0,
            null,
            -1,
            FlSpot(group.x.toDouble(), rod.toY),
            Offset.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_selected_month_title')),
            )
            .data,
        'November 2026',
      );
      expect(
        find.byKey(const Key('home_activity_inline_month_detail')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home_activity_inline_month_detail')),
          matching: find.text('No completed Qaza in this period.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'FL Chart callback maps all seven weekly groups to their dates',
    (tester) async {
      final period = activityPeriod(
        today: DateTime(2026, 10, 3),
        completedOnWednesday: 3,
      );
      await tester.pumpWidget(buildInteractiveWidget(period));
      await tester.pumpAndSettle();

      final chart = find.descendant(
        of: find.byKey(const Key('home_activity_week_chart')),
        matching: find.byType(BarChart),
      );
      final chartWidget = tester.widget<BarChart>(chart);
      final callback = chartWidget.data.barTouchData.touchCallback;
      expect(callback, isNotNull);
      expect(chartWidget.data.barGroups, hasLength(7));

      const expectedLabels = <String>[
        'Sunday, September 27, 2026',
        'Monday, September 28, 2026',
        'Tuesday, September 29, 2026',
        'Wednesday, September 30, 2026',
        'Thursday, October 1, 2026',
        'Friday, October 2, 2026',
        'Saturday, October 3, 2026',
      ];

      for (var index = 0; index < expectedLabels.length; index++) {
        final group = chartWidget.data.barGroups[index];
        final rod = group.barRods.first;
        final spot = BarTouchedSpot(
          group,
          index,
          rod,
          0,
          null,
          -1,
          FlSpot(group.x.toDouble(), rod.toY),
          Offset.zero,
        );
        final response = BarTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          spot: spot,
        );

        callback!(
          FlTapUpEvent(
            TapUpDetails(kind: PointerDeviceKind.touch),
          ),
          response,
        );
        await tester.pump();

        final detail = find.byKey(const Key('home_activity_day_details'));
        expect(detail, findsOneWidget);
        expect(
          find.descendant(
            of: detail,
            matching: find.text(expectedLabels[index]),
          ),
          findsOneWidget,
        );
      }
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
          rect.bottom - 60,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wednesday, September 30, 2026'), findsOneWidget);
      expect(find.text('Daily Target'), findsOneWidget);
      expect(find.text('Remaining'), findsWidgets);
      final detail = find.byKey(const Key('home_activity_day_details'));
      expect(detail, findsOneWidget);
      expect(
        find.descendant(of: detail, matching: find.text('2')),
        findsOneWidget,
      );

      final chartRect = tester.getRect(
        find.byKey(const Key('home_activity_week_chart')),
      );
      final detailRect = tester.getRect(detail);
      final gap = detailRect.top - chartRect.bottom;
      expect(gap, inInclusiveRange(12.0, 16.0));
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
          rect.left + rect.width * (4.5 / 7),
          rect.bottom - 60,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thursday, October 1, 2026'), findsOneWidget);
      expect(find.text('Daily Target'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
    },
  );

  testWidgets(
    'monthly calendar keeps a fixed six-row footprint across month boundaries',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      for (var index = 0; index < 7; index++) {
        await tester.tap(find.byKey(const Key('home_activity_previous')));
        await tester.pumpAndSettle();
      }

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_date_header')),
            )
            .data,
        'February 2026',
      );

      final grid = find.byKey(const Key('home_activity_month_grid'));
      final gridView = tester.widget<GridView>(grid);
      final delegate = gridView.childrenDelegate as SliverChildBuilderDelegate;
      expect(
        delegate.estimatedChildCount,
        _monthlyCalendarCellCountForTest,
      );

      final februaryHeight = tester.getRect(grid).height;

      await tester.tap(find.byKey(const Key('home_activity_next')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_activity_date_header')),
            )
            .data,
        'March 2026',
      );

      final marchHeight = tester
          .getRect(
            find.byKey(const Key('home_activity_month_grid')),
          )
          .height;
      expect(marchHeight, closeTo(februaryHeight, 0.01));
    },
  );

  testWidgets(
    'yearly month drill-down keeps stable monthly geometry',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      Future<void> selectMonth(int index) async {
        final chart = tester.widget<BarChart>(
          find.descendant(
            of: find.byKey(const Key('home_activity_year_chart')),
            matching: find.byType(BarChart),
          ),
        );
        final group = chart.data.barGroups[index];
        final rod = group.barRods.first;
        chart.data.barTouchData.touchCallback!(
          FlTapUpEvent(
            TapUpDetails(kind: PointerDeviceKind.touch),
          ),
          BarTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            spot: BarTouchedSpot(
              group,
              index,
              rod,
              0,
              null,
              -1,
              FlSpot(group.x.toDouble(), rod.toY),
              Offset.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await selectMonth(1);
      final februaryHeight = tester
          .getRect(
            find.byKey(const Key('home_activity_inline_month_detail')),
          )
          .height;

      await selectMonth(2);
      final marchHeight = tester
          .getRect(
            find.byKey(const Key('home_activity_inline_month_detail')),
          )
          .height;

      expect(marchHeight, closeTo(februaryHeight, 0.01));
    },
  );

  testWidgets(
    'daily drill-down does not change monthly calendar geometry',
    (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      final grid = find.byKey(const Key('home_activity_month_grid'));
      final before = tester.getRect(grid).height;
      final dayOne = find.descendant(of: grid, matching: find.text('1'));
      expect(dayOne, findsOneWidget);

      await tester.tap(dayOne);
      await tester.pumpAndSettle();

      expect(
        tester
            .getRect(find.byKey(const Key('home_activity_month_grid')))
            .height,
        closeTo(before, 0.01),
      );
      expect(
        find.byKey(const Key('home_activity_day_details')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'yearly date selection keeps outer scroll position stable during transition',
    (tester) async {
      final outerScrollController = ScrollController();

      addTearDown(outerScrollController.dispose);

      await tester.pumpWidget(
        ProviderScope(
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
            home: Scaffold(
              body: SingleChildScrollView(
                controller: outerScrollController,
                child: const Column(
                  children: [
                    SizedBox(height: 12),
                    HomeQazaActivity(),
                    SizedBox(height: 800),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(
        find.descendant(
          of: find.byKey(const Key('home_activity_year_chart')),
          matching: find.byType(BarChart),
        ),
      );
      final group = chart.data.barGroups[8];
      final rod = group.barRods.first;

      chart.data.barTouchData.touchCallback!(
        FlTapUpEvent(
          TapUpDetails(kind: PointerDeviceKind.touch),
        ),
        BarTouchResponse(
          touchLocation: Offset.zero,
          touchChartCoordinate: Offset.zero,
          spot: BarTouchedSpot(
            group,
            8,
            rod,
            0,
            null,
            -1,
            FlSpot(group.x.toDouble(), rod.toY),
            Offset.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inlineDetail = find.byKey(
        const Key('home_activity_inline_month_detail'),
      );
      expect(inlineDetail, findsOneWidget);

      outerScrollController.jumpTo(500);
      await tester.pump();

      final grid = find.byKey(const Key('home_activity_month_grid'));
      final dayOne = find.descendant(
        of: grid,
        matching: find.text('1'),
      );
      expect(dayOne, findsOneWidget);

      final offsetBefore = outerScrollController.offset;
      final detailHeightBefore = tester.getRect(inlineDetail).height;

      await tester.tap(dayOne);
      await tester.pump(const Duration(milliseconds: 60));
      expect(outerScrollController.offset, closeTo(offsetBefore, 0.01));

      await tester.pump(const Duration(milliseconds: 100));
      expect(outerScrollController.offset, closeTo(offsetBefore, 0.01));

      await tester.pumpAndSettle();
      expect(outerScrollController.offset, closeTo(offsetBefore, 0.01));
      expect(
        tester.getRect(inlineDetail).height,
        closeTo(detailHeightBefore, 0.01),
      );
      expect(
        find.byKey(const Key('home_activity_day_details')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'repeated yearly month and date selections preserve outer scroll position',
    (tester) async {
      final outerScrollController = ScrollController();

      addTearDown(outerScrollController.dispose);

      await tester.pumpWidget(
        ProviderScope(
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
            home: Scaffold(
              body: SingleChildScrollView(
                controller: outerScrollController,
                child: const Column(
                  children: [
                    SizedBox(height: 12),
                    HomeQazaActivity(),
                    SizedBox(height: 800),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      Future<void> selectMonth(int index) async {
        final chart = tester.widget<BarChart>(
          find.descendant(
            of: find.byKey(const Key('home_activity_year_chart')),
            matching: find.byType(BarChart),
          ),
        );
        final group = chart.data.barGroups[index];
        final rod = group.barRods.first;
        chart.data.barTouchData.touchCallback!(
          FlTapUpEvent(
            TapUpDetails(kind: PointerDeviceKind.touch),
          ),
          BarTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            spot: BarTouchedSpot(
              group,
              index,
              rod,
              0,
              null,
              -1,
              FlSpot(group.x.toDouble(), rod.toY),
              Offset.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> selectDay(int day) async {
        final grid = find.byKey(const Key('home_activity_month_grid'));
        final finder = find.descendant(
          of: grid,
          matching: find.text('$day'),
        );
        expect(finder, findsOneWidget);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await selectMonth(8);
      outerScrollController.jumpTo(500);
      await tester.pump();
      final offset = outerScrollController.offset;
      await selectDay(12);
      expect(outerScrollController.offset, closeTo(offset, 0.01));

      await selectMonth(9);
      expect(outerScrollController.offset, closeTo(offset, 0.01));
      await selectDay(8);
      expect(outerScrollController.offset, closeTo(offset, 0.01));

      await selectMonth(10);
      expect(outerScrollController.offset, closeTo(offset, 0.01));
      await selectDay(16);
      expect(outerScrollController.offset, closeTo(offset, 0.01));

      await selectMonth(8);
      expect(outerScrollController.offset, closeTo(offset, 0.01));
      await selectDay(20);
      expect(outerScrollController.offset, closeTo(offset, 0.01));
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
