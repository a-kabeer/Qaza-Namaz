import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../providers/home_providers.dart';
import 'home_prayer_icon.dart';

enum _ActivityRange { sevenDays, thirtyDays, monthly }

class HomeQazaActivity extends ConsumerStatefulWidget {
  const HomeQazaActivity({super.key});

  @override
  ConsumerState<HomeQazaActivity> createState() => _HomeQazaActivityState();
}

class _HomeQazaActivityState extends ConsumerState<HomeQazaActivity> {
  late DateTime _month;
  _ActivityRange _range = _ActivityRange.sevenDays;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(homeLocalDateProvider);
    final periodAsync = switch (_range) {
      _ActivityRange.sevenDays =>
        ref.watch(homeQazaActivitySevenDaysProvider),
      _ActivityRange.thirtyDays =>
        ref.watch(homeQazaActivityThirtyDaysProvider),
      _ActivityRange.monthly =>
        ref.watch(homeQazaActivityMonthProvider(_month)),
    };

    final currentMonth = DateTime(today.year, today.month);
    if (_month.isAfter(currentMonth)) _month = currentMonth;

    return Card(
      key: const Key('home_qaza_activity'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeQazaActivity,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.homeProgressHistory,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_range == _ActivityRange.monthly)
                  _MonthNavigator(
                    month: _month,
                    canNext: _month.isBefore(currentMonth),
                    onPrevious: () {
                      setState(() {
                        _month = DateTime(_month.year, _month.month - 1);
                        _selectedDay = null;
                      });
                    },
                    onNext: () {
                      if (!_month.isBefore(currentMonth)) return;
                      setState(() {
                        _month = DateTime(_month.year, _month.month + 1);
                        _selectedDay = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<_ActivityRange>(
              key: const Key('home_activity_range_selector'),
              segments: [
                ButtonSegment(
                  value: _ActivityRange.sevenDays,
                  label: Text(l10n.homeRangeSevenDays),
                ),
                ButtonSegment(
                  value: _ActivityRange.thirtyDays,
                  label: Text(l10n.homeRangeThirtyDays),
                ),
                ButtonSegment(
                  value: _ActivityRange.monthly,
                  label: Text(l10n.homeRangeMonthly),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (selected) {
                setState(() {
                  _range = selected.first;
                  _selectedDay = null;
                });
              },
            ),
            const SizedBox(height: 16),
            periodAsync.when(
              loading: () => const SizedBox(
                height: 238,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => _ActivityError(
                onRetry: () => _invalidateCurrentRange(),
              ),
              data: (period) => _ActivityPeriodContent(
                period: period,
                range: _range,
                selectedDay: _selectedDay,
                onSelectedDay: (date) => setState(() => _selectedDay = date),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _invalidateCurrentRange() {
    switch (_range) {
      case _ActivityRange.sevenDays:
        ref.invalidate(homeQazaActivitySevenDaysProvider);
      case _ActivityRange.thirtyDays:
        ref.invalidate(homeQazaActivityThirtyDaysProvider);
      case _ActivityRange.monthly:
        ref.invalidate(homeQazaActivityMonthProvider(_month));
    }
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.homePreviousMonth,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          DateFormat.yMMMM(locale).format(month),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        IconButton(
          tooltip: l10n.homeNextMonth,
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _ActivityPeriodContent extends StatelessWidget {
  const _ActivityPeriodContent({
    required this.period,
    required this.range,
    required this.selectedDay,
    required this.onSelectedDay,
  });

  final QazaActivityPeriod period;
  final _ActivityRange range;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final target = period.days.isEmpty ? 0 : period.days.first.target;
    final selected = selectedDay == null ? null : period.dayFor(selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActivitySummary(period: period),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            key: const Key('home_activity_progress'),
            value: period.progress,
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 14),
        if (period.totalCompleted == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.homeNoActivity,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (range == _ActivityRange.monthly)
          _ActivityMonthGrid(
            period: period,
            selectedDay: selectedDay,
            onSelectedDay: onSelectedDay,
          )
        else
          _ActivityBarChart(
            period: period,
            compact: range == _ActivityRange.thirtyDays,
            onSelectedDay: onSelectedDay,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${l10n.homeActual}: ${DateFormatters.formatCount(period.totalCompleted)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              '${l10n.homeDailyTarget}: ${DateFormatters.formatCount(target)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          _ActivityDayDetails(day: selected),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            l10n.homeSelectDay,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.period});

  final QazaActivityPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _SummaryMetric(
            label: l10n.homeCompleted,
            value: DateFormatters.formatCount(period.totalCompleted),
          ),
        ),
        Expanded(
          child: _SummaryMetric(
            label: l10n.homeDailyTarget,
            value: DateFormatters.formatCount(period.totalTarget),
          ),
        ),
        Expanded(
          child: _SummaryMetric(
            label: l10n.homeRemaining,
            value: DateFormatters.formatCount(period.remaining),
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart({
    required this.period,
    required this.compact,
    required this.onSelectedDay,
  });

  final QazaActivityPeriod period;
  final bool compact;
  final ValueChanged<DateTime> onSelectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final maxCompleted = period.days.fold<int>(
      0,
      (maxValue, day) => math.max(maxValue, day.completed),
    );
    final maxY = math.max(
      1,
      maxCompleted + math.max(1, (maxCompleted * 0.15).ceil()),
    ).toDouble();
    final leftInterval = maxY > 10 ? 5.0 : 1.0;
    final bottomInterval = compact ? 5.0 : 1.0;

    return SizedBox(
      key: Key(compact ? 'home_activity_30_chart' : 'home_activity_7_chart'),
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: leftInterval,
          ),
          borderData: FlBorderData(show: false),
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
                reservedSize: 28,
                interval: leftInterval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= period.days.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      compact
                          ? period.days[index].date.day.toString()
                          : DateFormat.E(locale).format(period.days[index].date),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;
              final index = response?.spot?.touchedBarGroupIndex;
              if (index == null || index < 0 || index >= period.days.length) {
                return;
              }
              onSelectedDay(period.days[index].date);
            },
          ),
          barGroups: [
            for (var index = 0; index < period.days.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: period.days[index].completed.toDouble(),
                    width: compact ? 8 : 20,
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMonthGrid extends StatelessWidget {
  const _ActivityMonthGrid({
    required this.period,
    required this.selectedDay,
    required this.onSelectedDay,
  });

  final QazaActivityPeriod period;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectedDay;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final first = period.days.first.date;
    final leading = first.weekday - 1;
    final cells = leading + period.days.length;
    final labels = [
      for (var index = 0; index < 7; index++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + index)),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          key: const Key('home_activity_month_grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = period.days[index - leading];
            final selected = selectedDay != null && day.date == selectedDay;
            return _ActivityDayCell(
              day: day,
              selected: selected,
              onTap: () => onSelectedDay(day.date),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityDayCell extends StatelessWidget {
  const _ActivityDayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final QazaDailyActivity day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = math.min(day.completed, 10);
    final alpha = day.isFuture ? 18 : (day.completed == 0 ? 22 : 35 + intensity * 12);
    return Semantics(
      button: true,
      label: '${day.date.day}, ${day.completed} ${AppLocalizations.of(context).homeCompleted}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(alpha),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.date.day.toString(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                day.isFuture ? '–' : day.completed.toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDayDetails extends StatelessWidget {
  const _ActivityDayDetails({required this.day});

  final QazaDailyActivity day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final title = DateFormat.yMMMMEEEEd(locale).format(day.date);
    final enabled = [
      for (final prayer in PrayerType.values)
        if (day.byPrayer.containsKey(prayer)) prayer,
    ];

    return Card(
      key: const Key('home_activity_day_details'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (day.isFuture)
                  Text(
                    l10n.homeFutureDay,
                    style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  )
                else if (day.goalReached)
                  Text(
                    l10n.homeGoalReached,
                    style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _DetailMetricRow(
              label: l10n.homeActual,
              value: day.completed.toString(),
            ),
            _DetailMetricRow(
              label: l10n.homeDailyTarget,
              value: day.hasGoal ? day.target.toString() : '–',
            ),
            _DetailMetricRow(
              label: l10n.homeRemaining,
              value: day.hasGoal ? day.remaining.toString() : '–',
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homePrayerBreakdown,
              style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            for (final prayer in enabled)
              _PrayerActivityRow(
                prayer: prayer,
                completed: day.byPrayer[prayer] ?? 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  const _DetailMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PrayerActivityRow extends StatelessWidget {
  const _PrayerActivityRow({
    required this.prayer,
    required this.completed,
  });

  final PrayerType prayer;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(homePrayerIcon(prayer), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(prayer.localizedLabel(l10n))),
          Text(
            completed.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 28),
          const SizedBox(height: 8),
          Text(l10n.homeProgressError, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}