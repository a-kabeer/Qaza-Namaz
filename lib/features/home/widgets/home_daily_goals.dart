import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/qaza_activity.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';

class HomeDailyGoals extends ConsumerWidget {
  const HomeDailyGoals({super.key, required this.onDetails});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activity = ref.watch(homeDashboardActivityProvider);

    return Card(
      key: const Key('home_daily_goals'),
      child: InkWell(
        key: const Key('home_daily_goals_tap'),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: activity.when(
            loading: () => const SizedBox(
              height: 108,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Row(
              children: [
                const Icon(Icons.refresh_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.homeProgressError)),
                TextButton(
                  key: const Key('home_daily_goals_retry'),
                  onPressed: () =>
                      ref.invalidate(homeDashboardActivityProvider),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
            data: (dashboard) => _DailyGoalsContent(
              period: dashboard.dailyGoals,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyGoalsContent extends StatelessWidget {
  const _DailyGoalsContent({required this.period});

  final QazaActivityPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final hasValidTarget = period.targetAvailable && period.dailyTarget > 0;
    final maxY = hasValidTarget
        ? period.dailyTarget.toDouble()
        : period.days.fold<double>(
            1,
            (current, day) => math.max(current, day.completed.toDouble()),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeDailyGoalsTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homeLastSevenDays,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Semantics(
                container: true,
                label:
                    '${period.goalDays}/${period.days.length} ${l10n.homeGoalsAchieved}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${period.goalDays}/${period.days.length}',
                      key: const Key('home_daily_goals_achievement'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.homeGoalsAchieved,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DailyGoalsChart(
                period: period,
                locale: locale,
                maxY: maxY,
                hasValidTarget: hasValidTarget,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyGoalsChart extends StatefulWidget {
  const _DailyGoalsChart({
    required this.period,
    required this.locale,
    required this.maxY,
    required this.hasValidTarget,
  });

  final QazaActivityPeriod period;
  final String locale;
  final double maxY;
  final bool hasValidTarget;

  @override
  State<_DailyGoalsChart> createState() => _DailyGoalsChartState();
}

class _DailyGoalsChartState extends State<_DailyGoalsChart> {
  static const double _tooltipRowHeight = 18;

  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = widget.period.days;

    return Semantics(
      container: true,
      label: _chartSemantics(context),
      child: LayoutBuilder(
        builder: (context, constraints) => Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (days.isEmpty || constraints.maxWidth <= 0) return;
            final index =
                (event.localPosition.dx / constraints.maxWidth * days.length)
                    .floor()
                    .clamp(0, days.length - 1);
            setState(() => _pressedIndex = index);
          },
          onPointerUp: (_) => _clearPressedIndex(),
          onPointerCancel: (_) => _clearPressedIndex(),
          child: GestureDetector(
            key: const Key('home_daily_goals_chart_interaction'),
            behavior: HitTestBehavior.opaque,
            // Consume chart taps so the surrounding card does not navigate.
            onTap: () {},
            child: Column(
              children: [
                SizedBox(
                  height: _tooltipRowHeight,
                  child: Row(
                    children: [
                      for (var index = 0; index < days.length; index++)
                        Expanded(
                          child: Center(
                            child: _pressedIndex == index
                                ? Text(
                                    '${days[index].completed}',
                                    key: const Key('home_daily_goals_tooltip'),
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 94,
                  child: BarChart(
                    key: const Key('home_daily_goals_chart'),
                    duration: Duration.zero,
                    BarChartData(
                      minY: 0,
                      maxY: widget.maxY,
                      alignment: BarChartAlignment.spaceAround,
                      groupsSpace: 0,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 20,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= days.length) {
                                return const SizedBox.shrink();
                              }
                              final label = DateFormat('EEEEE', widget.locale)
                                  .format(days[index].date);
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: const BarTouchData(enabled: false),
                      barGroups: [
                        for (var index = 0; index < days.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: _visibleCompletion(index),
                                width: 10,
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: widget.hasValidTarget &&
                                      days[index].target > 0,
                                  toY: widget.hasValidTarget
                                      ? days[index].target.toDouble()
                                      : 0,
                                  color: scheme.primaryContainer,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _visibleCompletion(int index) {
    final day = widget.period.days[index];
    if (!widget.hasValidTarget) return day.completed.toDouble();

    final target = day.target > 0 ? day.target : widget.period.dailyTarget;
    return math.min(day.completed, target).toDouble();
  }

  void _clearPressedIndex() {
    if (_pressedIndex == null) return;
    setState(() => _pressedIndex = null);
  }

  String _chartSemantics(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return [
      for (final day in widget.period.days)
        widget.hasValidTarget
            ? '${DateFormat.EEEE(locale).format(day.date)}: ${day.completed} ${l10n.homeCompleted}, ${day.target} ${l10n.homeDailyTarget}'
            : '${DateFormat.EEEE(locale).format(day.date)}: ${day.completed} ${l10n.homeCompleted}',
    ].join(', ');
  }
}
