import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../home_state.dart';
import '../providers/home_providers.dart';

class HomeProgressHistory extends ConsumerStatefulWidget {
  const HomeProgressHistory({super.key});

  @override
  ConsumerState<HomeProgressHistory> createState() =>
      _HomeProgressChartSectionState();
}

class _HomeProgressChartSectionState
    extends ConsumerState<HomeProgressHistory> {
  static const double _chartContainerHeight = 280;
  static const double _chartVisualHeight = 210;

  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charts = AppChartColors.of(context);
    final range = ref.watch(homeProgressRangeProvider);
    final weekStart = ref.watch(homeProgressWeekProvider);
    final dailyTarget = ref.watch(homeQazaPlanProvider).dailyTarget;
    final data = ref.watch(homeProgressHistoryProvider(range));

    ref.listen<AsyncValue<List<HomeProgressPoint>>>(
      homeProgressHistoryProvider(range),
      (previous, next) {
        if (!next.hasError || next.error == previous?.error) return;
        ref.read(diagnosticsProvider).recordFailure(
              DiagnosticArea.uncaught,
              'home_progress_history_failed',
              next.error!,
              stack: next.stackTrace,
            );
      },
    );

    return AppCard(
      key: const Key('home_your_progress'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeYourProgress,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<HomeProgressRange>(
                key: const Key('home_progress_range'),
                segments: [
                  ButtonSegment<HomeProgressRange>(
                    value: HomeProgressRange.sevenDays,
                    label: Text(l10n.homeRange7Days),
                  ),
                  ButtonSegment<HomeProgressRange>(
                    value: HomeProgressRange.thirtyDays,
                    label: Text(l10n.homeRange30Days),
                  ),
                  ButtonSegment<HomeProgressRange>(
                    value: HomeProgressRange.monthly,
                    label: Text(l10n.homeRangeMonthly),
                  ),
                ],
                selected: {range},
                onSelectionChanged: (selection) {
                  setState(() => selectedIndex = null);
                  ref
                      .read(homeProgressWeekProvider.notifier)
                      .resetToCurrentWeek();
                  ref.read(homeProgressRangeProvider.notifier).state =
                      selection.single;
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          data.when(
            loading: () => const HomeChartSkeleton(),
            error: (_, __) => ErrorState(
              key: const Key('home_progress_history_error'),
              message: l10n.homeProgressError,
              onRetry: () => ref.invalidate(homeProgressHistoryProvider(range)),
            ),
            data: (points) {
              if (points.isEmpty) {
                return Padding(
                  key: const Key('home_progress_no_points'),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      l10n.homeChartNoData,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final hasCompletedData = points.any((point) => point.count > 0);

              return Column(
                children: [
                  if (range == HomeProgressRange.sevenDays) ...[
                    Text(
                      _weekRangeLabel(weekStart),
                      key: const Key('home_progress_week_range'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!hasCompletedData)
                    Padding(
                      key: const Key('home_progress_zero_state'),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.homeChartNoData,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  SizedBox(
                    key: const Key('home_progress_chart'),
                    height: _chartContainerHeight,
                    width: double.infinity,
                    child: GestureDetector(
                      key: const Key('home_progress_week_gesture'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: range == HomeProgressRange.sevenDays
                          ? (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (velocity < -250) {
                                setState(() => selectedIndex = null);
                                ref
                                    .read(homeProgressWeekProvider.notifier)
                                    .nextWeek();
                              } else if (velocity > 250) {
                                setState(() => selectedIndex = null);
                                ref
                                    .read(homeProgressWeekProvider.notifier)
                                    .previousWeek();
                              }
                            }
                          : null,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth =
                              range == HomeProgressRange.sevenDays
                                  ? constraints.maxWidth
                                  : math.max(
                                      constraints.maxWidth,
                                      points.length * _slotWidth(range),
                                    );

                          final chart = SizedBox(
                            key: const Key('home_progress_chart_visual'),
                            height: _chartVisualHeight,
                            width: chartWidth,
                            child: Semantics(
                              label: l10n.homeYourProgress,
                              child: BarChart(
                                _chartData(
                                  context,
                                  points,
                                  range,
                                  charts,
                                  dailyTarget,
                                  l10n,
                                ),
                                duration: Duration.zero,
                              ),
                            ),
                          );

                          if (range == HomeProgressRange.sevenDays) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: chart,
                            );
                          }

                          return Align(
                            alignment: Alignment.topCenter,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: chart,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _slotWidth(HomeProgressRange range) => switch (range) {
        HomeProgressRange.sevenDays => 44,
        HomeProgressRange.thirtyDays => 22,
        HomeProgressRange.monthly => 44,
      };

  BarChartData _chartData(
    BuildContext context,
    List<HomeProgressPoint> points,
    HomeProgressRange range,
    AppChartColors charts,
    int dailyTarget,
    AppLocalizations l10n,
  ) {
    final axisInterval = _axisInterval(points);
    final maxY = _chartMaxY(points, axisInterval);
    final textStyle = Theme.of(context).textTheme.labelSmall;
    final colorScheme = Theme.of(context).colorScheme;
    final textDirection = Directionality.of(context);

    return BarChartData(
      minY: 0,
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      groupsSpace: 4,
      barGroups: [
        for (var i = 0; i < points.length; i++)
          BarChartGroupData(
            x: i,
            showingTooltipIndicators: selectedIndex == i ? const [0] : const [],
            barRods: [
              BarChartRodData(
                toY: points[i].count.toDouble(),
                width: range == HomeProgressRange.thirtyDays ? 12 : 20,
                color: charts.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                label: BarChartRodLabel(
                  show: range == HomeProgressRange.sevenDays &&
                      points[i].count >= dailyTarget,
                  text: '✓',
                  style: TextStyle(
                    color: charts.completed,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  textDirection: textDirection,
                  offset: const Offset(0, 48),
                ),
              ),
            ],
          ),
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: axisInterval,
        getDrawingHorizontalLine: (_) => FlLine(
          color: charts.grid,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: axisInterval,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              space: 6,
              child: Text(
                DateFormatters.formatCount(value.round()),
                style: textStyle,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: range == HomeProgressRange.sevenDays ? 34 : 28,
            getTitlesWidget: (value, meta) => _bottomTitle(
              value,
              meta,
              points,
              range,
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        enabled: true,
        handleBuiltInTouches: false,
        touchTooltipData: BarTouchTooltipData(
          direction: TooltipDirection.top,
          tooltipMargin: 18,
          getTooltipColor: (_) => colorScheme.primaryContainer,
          tooltipBorder: BorderSide(
            color: colorScheme.outlineVariant,
          ),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final index = groupIndex.clamp(0, points.length - 1);
            final point = points[index];
            final weekday =
                DateFormatters.weekdayShortNames[point.start.weekday - 1];
            return BarTooltipItem(
              '${DateFormatters.formatCount(point.count)} ${l10n.qazaTitle} — ${point.start.day} $weekday',
              TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
        touchCallback: (_, response) {
          final index = response?.spot?.touchedBarGroupIndex;
          if (index == null || index < 0 || index >= points.length) return;
          if (index != selectedIndex) {
            setState(() => selectedIndex = index);
          }
        },
      ),
    );
  }

  double _axisInterval(List<HomeProgressPoint> points) {
    final maxValue = points.fold<int>(
      0,
      (maxValue, point) => point.count > maxValue ? point.count : maxValue,
    );
    if (maxValue <= 4) return 1;

    final raw = maxValue / 4;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final nice = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;
    return nice * magnitude;
  }

  double _chartMaxY(
    List<HomeProgressPoint> points,
    double interval,
  ) {
    final maxValue = points.fold<int>(
      0,
      (maxValue, point) => point.count > maxValue ? point.count : maxValue,
    );
    if (maxValue <= 0) return 1;
    return math.max(
      interval,
      (maxValue / interval).ceil() * interval,
    );
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final startMonth = DateFormatters.gregorianMonthFullName(start.month);
    final endMonth = DateFormatters.gregorianMonthFullName(end.month);

    if (start.year == end.year && start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}';
    }
    if (start.year == end.year) {
      return '$startMonth ${start.day} – $endMonth ${end.day}';
    }
    return '$startMonth ${start.day}, ${start.year} – $endMonth ${end.day}, ${end.year}';
  }

  Widget _bottomTitle(
    double value,
    TitleMeta meta,
    List<HomeProgressPoint> points,
    HomeProgressRange range,
  ) {
    final index = value.round();
    if (index < 0 ||
        index >= points.length ||
        (value - index).abs() > 0.01 ||
        !_shouldShowLabel(index, points.length, range)) {
      return const SizedBox.shrink();
    }

    final point = points[index];
    final String label;
    switch (range) {
      case HomeProgressRange.sevenDays:
        label = DateFormatters.weekdayShortNames[point.start.weekday - 1];
      case HomeProgressRange.thirtyDays:
        label =
            '${point.start.day} ${DateFormatters.gregorianMonthName(point.start.month)}';
      case HomeProgressRange.monthly:
        label = DateFormatters.gregorianMonthName(point.start.month);
    }

    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  bool _shouldShowLabel(
    int index,
    int length,
    HomeProgressRange range,
  ) {
    switch (range) {
      case HomeProgressRange.sevenDays:
        return true;
      case HomeProgressRange.thirtyDays:
        return index == 0 || index == length - 1 || index % 5 == 0;
      case HomeProgressRange.monthly:
        return true;
    }
  }
}

class HomeChartSkeleton extends StatelessWidget {
  const HomeChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Align(
        alignment: Alignment.topCenter,
        child: SkeletonBox(
          width: double.infinity,
          height: 210,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
