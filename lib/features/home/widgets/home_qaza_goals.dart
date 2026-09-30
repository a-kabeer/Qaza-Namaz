import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/icon_action_button.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';

class HomeQazaGoals extends ConsumerWidget {
  const HomeQazaGoals({
    super.key,
    required this.onDetails,
  });

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activity = ref.watch(homeQazaActivitySevenDaysProvider);

    return Card(
      key: const Key('home_qaza_goals'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: activity.when(
          loading: () => const SizedBox(
            height: 112,
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
                key: const Key('home_qaza_goals_retry'),
                onPressed: () => ref.invalidate(
                  homeQazaActivitySevenDaysProvider,
                ),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
          data: (period) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final locale = Localizations.localeOf(context).languageCode;
            final maxY = period.days.fold<double>(
              1,
              (current, day) => math.max(
                current,
                math.max(day.completed, day.target).toDouble(),
              ),
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
                            l10n.homeGoalsLastSevenDays,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeLastSevenDays,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconActionButton(
                      key: const Key('home_qaza_goals_details'),
                      tooltip: l10n.homeViewDetails,
                      icon: Icons.chevron_right_rounded,
                      onPressed: onDetails,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 58,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period.goalDays.toString() +
                                '/' +
                                period.days.length.toString(),
                            key: const Key('home_qaza_goals_achievement'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            l10n.homeGoalsAchieved,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HomeQazaGoalsChart(
                        key: const Key('home_qaza_goals_chart'),
                        period: period,
                        locale: locale,
                        maxY: maxY,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeQazaGoalsChart extends StatelessWidget {
  const _HomeQazaGoalsChart({
    super.key,
    required this.period,
    required this.locale,
    required this.maxY,
  });

  final QazaActivityPeriod period;
  final String locale;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 92,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
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
            bottomTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= period.days.length) {
                  return const SizedBox.shrink();
                }

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat.E(locale).format(period.days[index].date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
          barTouchData: const BarTouchData(enabled: false),
          barGroups: [
            for (var index = 0; index < period.days.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: period.days[index].completed.toDouble(),
                    width: 10,
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: period.days[index].target > 0,
                      toY: period.days[index].target.toDouble(),
                      color: scheme.primary.withAlpha(35),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
