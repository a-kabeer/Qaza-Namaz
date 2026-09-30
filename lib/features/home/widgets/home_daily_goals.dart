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
    final activity = ref.watch(homeQazaActivityDailyGoalsProvider);

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
                onPressed: () => ref.invalidate(homeQazaActivityDailyGoalsProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
          data: (period) => _DailyGoalsContent(
            period: period,
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
                    l10n.homeDailyGoalsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homeLastSevenDays,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                label: '${period.goalDays}/${period.days.length} ${l10n.homeGoalsAchieved}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${period.goalDays}/${period.days.length}',
                      key: const Key('home_daily_goals_achievement'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.homeGoalsAchieved,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DailyGoalsChart(period: period, locale: locale, maxY: maxY),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyGoalsChart extends StatelessWidget {
  const _DailyGoalsChart({required this.period, required this.locale, required this.maxY});

  final QazaActivityPeriod period;
  final String locale;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: _chartSemantics(context),
      child: SizedBox(
        height: 94,
        child: BarChart(
          key: const Key('home_daily_goals_chart'),
          duration: Duration.zero,
          BarChartData(
            minY: 0,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            groupsSpace: 0,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= period.days.length) {
                      return const SizedBox.shrink();
                    }
                    final label = DateFormat('EEEEE', locale).format(period.days[index].date);
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
                        color: scheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _chartSemantics(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return [
      for (final day in period.days)
        '${DateFormat.EEEE(locale).format(day.date)}: ${day.completed} ${l10n.homeCompleted}, ${day.target} ${l10n.homeDailyTarget}',
    ].join(', ');
  }
}