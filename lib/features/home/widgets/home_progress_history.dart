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
import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';
import 'home_skeleton.dart';
import '../home_state.dart';

class HomeProgressHistory extends ConsumerStatefulWidget {
  const HomeProgressHistory();

  @override
  ConsumerState<HomeProgressHistory> createState() =>
      _HomeProgressChartSectionState();
}

class _HomeProgressChartSectionState
    extends ConsumerState<HomeProgressHistory> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charts = AppChartColors.of(context);
    final range = ref.watch(homeProgressRangeProvider);
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<HomeProgressRange>(
              key: const Key('home_progress_range'),
              segments: [
                ButtonSegment<HomeProgressRange>(
                  value: HomeProgressRange.oneDay,
                  label: Text(l10n.homeRange1Day),
                ),
                ButtonSegment<HomeProgressRange>(
                  value: HomeProgressRange.threeDays,
                  label: Text(l10n.homeRange3Days),
                ),
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
                ref.read(homeProgressRangeProvider.notifier).state =
                    selection.single;
              },
            ),
          ),
          const SizedBox(height: 16),
          data.when(
            loading: () => const HomeChartSkeleton(),
            error: (_, __) => ErrorState(
              key: const Key('home_progress_history_error'),
              message: l10n.homeProgressError,
              onRetry: () => ref.invalidate(
                homeProgressHistoryProvider(range),
              ),
            ),
            data: (points) {
              if (points.every((point) => point.count == 0)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      l10n.homeChartNoData,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final selected = selectedIndex == null || points.isEmpty
                  ? null
                  : points[
                      selectedIndex!.clamp(0, points.length - 1).toInt()
                    ];

              return Column(
                children: [
                  if (selected != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        key: const Key('home_chart_selected_value'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormatters.formatGregorianDatePadded(
                                selected.start,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              l10n.homeCompletedCount(selected.count),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    key: const Key('home_progress_chart'),
                    height: 190,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: points.length <= 1
                            ? 1
                            : (points.length - 1).toDouble(),
                        minY: 0,
                        maxY: _maxY(points),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _gridInterval(points),
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: charts.grid,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _labelInterval(points),
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) =>
                                  _bottomTitle(value, meta, points),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) =>
                                Theme.of(context).colorScheme.inverseSurface,
                            tooltipBorder: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                            tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (spots) => spots
                                .map(
                                  (spot) {
                                    final index = spot.x
                                        .round()
                                        .clamp(0, points.length - 1)
                                        .toInt();
                                    final point = points[index];
                                    return LineTooltipItem(
                                      DateFormatters.formatGregorianDatePadded(
                                            point.start,
                                          ) +
                                          '\n' +
                                          l10n.homeCompletedCount(point.count),
                                      TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                )
                                .toList(),
                          ),
                          touchCallback: (_, response) {
                            final spots = response?.lineBarSpots;
                            if (spots == null || spots.isEmpty) return;
                            final index = spots.first.x.round();
                            if (index != selectedIndex) {
                              setState(() => selectedIndex = index);
                            }
                          },
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  points[i].count.toDouble(),
                                ),
                            ],
                            isCurved: true,
                            color: charts.primary,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: charts.primary.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                      duration: Duration.zero,
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

  double _maxY(List<HomeProgressPoint> points) {
    final maxValue = points.fold<int>(
      0,
      (maxValue, point) =>
          point.count > maxValue ? point.count : maxValue,
    );
    return maxValue <= 0 ? 1 : (maxValue * 1.2).ceilToDouble();
  }

  double _gridInterval(List<HomeProgressPoint> points) {
    final maxY = _maxY(points);
    return maxY <= 4 ? 1 : (maxY / 4).ceilToDouble();
  }

  double _labelInterval(List<HomeProgressPoint> points) {
    if (points.length <= 7) return 1;
    return (points.length / 4).ceilToDouble();
  }

  Widget _bottomTitle(
    double value,
    TitleMeta meta,
    List<HomeProgressPoint> points,
  ) {
    final index = value.round();
    if (index < 0 ||
        index >= points.length ||
        (value - index).abs() > 0.01) {
      return const SizedBox.shrink();
    }

    final point = points[index];
    final label = points.length <= 7
        ? point.start.day.toString() +
            ' ' +
            DateFormatters.gregorianMonthName(point.start.month)
        : point.start.day == 1
            ? DateFormatters.gregorianMonthName(point.start.month)
            : point.start.day.toString();

    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class HomeChartSkeleton extends StatelessWidget {
  const HomeChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonBox(
      width: double.infinity,
      height: 190,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
  }
}
