import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../../../domain/services/qaza_activity_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../providers/home_providers.dart';
import 'home_prayer_icon.dart';

enum _ActivityRange { weekly, monthly, yearly }

const _monthlyCalendarRows = 6;
const _monthlyCalendarSpacing = 6.0;

class HomeQazaActivity extends ConsumerStatefulWidget {
  const HomeQazaActivity({super.key});

  @override
  ConsumerState<HomeQazaActivity> createState() => _HomeQazaActivityState();
}

class _HomeQazaActivityState extends ConsumerState<HomeQazaActivity> {
  static const _basePage = 10000;

  late final PageController _pageController;
  late final int _maxPage;
  var _range = _ActivityRange.weekly;
  var _pageIndex = _basePage;
  DateTime? _selectedDay;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();

    _maxPage = _basePage;
    _pageController = PageController(initialPage: _basePage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _periodOffset => _pageIndex - _basePage;

  DateTime _anchorForOffset(DateTime today, int offset) {
    switch (_range) {
      case _ActivityRange.weekly:
        final currentStart =
            QazaActivityService.calendarWeekStartForDate(today);
        return DateTime(
          currentStart.year,
          currentStart.month,
          currentStart.day + offset * 7,
        );
      case _ActivityRange.monthly:
        return DateTime(today.year, today.month + offset);
      case _ActivityRange.yearly:
        return DateTime(today.year + offset, 1);
    }
  }

  void _selectRange(_ActivityRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _pageIndex = _basePage;
      _selectedDay = null;
      _selectedMonth = null;
    });
    _pageController.jumpToPage(_basePage);
  }

  void _goToPage(int page) {
    if (page < 0 || page > _maxPage) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(homeLocalDateProvider);
    final anchor = _anchorForOffset(today, _periodOffset);
    final canPrevious = _pageIndex > 0;
    final canNext = _pageIndex < _maxPage;

    final content = Card(
      key: const Key('home_qaza_activity'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              SegmentedButton<_ActivityRange>(
              key: const Key('home_activity_range_selector'),
              segments: [
                ButtonSegment(
                  value: _ActivityRange.weekly,
                  label: Text(l10n.homeRangeWeekly),
                ),
                ButtonSegment(
                  value: _ActivityRange.monthly,
                  label: Text(l10n.homeRangeMonthly),
                ),
                ButtonSegment(
                  value: _ActivityRange.yearly,
                  label: Text(l10n.homeRangeYearly),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) _selectRange(selected.first);
              },
              ),
              const SizedBox(height: 14),
            Row(
              key: const Key('home_activity_period_header'),
              children: [
                IconButton(
                  key: const Key('home_activity_previous'),
                  tooltip: _previousTooltip(l10n),
                  onPressed: canPrevious
                      ? () => _goToPage(_pageIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _formatHeader(context, anchor),
                      key: const Key('home_activity_date_header'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('home_activity_next'),
                  tooltip: _nextTooltip(l10n),
                  onPressed: canNext
                      ? () => _goToPage(_pageIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final height = _activityViewportHeight(
                  constraints.maxWidth,
                );

                return AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    height: height,
                    child: PageView.builder(
                key: ValueKey('home_activity_pager_${_range.name}'),
                controller: _pageController,
                itemCount: _maxPage + 1,
                onPageChanged: (index) {
                  final pageAnchor =
                      _anchorForOffset(today, index - _basePage);
                  setState(() {
                    _pageIndex = index;
                    _selectedDay = null;
                    if (_selectedMonth != null) {
                      _selectedMonth =
                          DateTime(pageAnchor.year, _selectedMonth!.month);
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final pageAnchor =
                      _anchorForOffset(today, index - _basePage);
                  return _ActivityPeriodPage(
                    key: ValueKey(
                      'home_activity_page_${_range.name}_$index',
                    ),
                    range: _range,
                    anchor: pageAnchor,
                    selectedDay: index == _pageIndex ? _selectedDay : null,
                    onSelectedDay: index == _pageIndex
                        ? (date) => setState(() => _selectedDay = date)
                        : null,
                    selectedMonth:
                        index == _pageIndex ? _selectedMonth : null,
                    onSelectedMonth: index == _pageIndex
                        ? (month) => setState(() {
                              _selectedMonth =
                                  DateTime(month.year, month.month);
                              _selectedDay = null;
                            })
                        : null,
                  );
                  },
                ),
              ),
            );
              },
            ),
            if (_range == _ActivityRange.yearly && _selectedMonth != null) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: _yearlyInlineMonthlyDetailHeight(
                      constraints.maxWidth,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _InlineMonthlyDetail(
                        key: ValueKey(
                          'home_activity_month_detail_${_selectedMonth!.year}_${_selectedMonth!.month}',
                        ),
                        month: _selectedMonth!,
                        selectedDay: _selectedDay,
                        onSelectedDay: (date) {
                          setState(() => _selectedDay = date);
                        },
                      ),
                    ),
                  );
                },
              ),
            ] else if (_selectedDay != null &&
                _range != _ActivityRange.yearly) ...[
              const SizedBox(height: 12),
              _SelectedActivityDayDetails(
                key: const Key('home_activity_selected_day_details'),
                range: _range,
                anchor: anchor,
                selectedDay: _selectedDay!,
              ),
            ],
          ],
        ),
      ),
    );

    return content;
  }

  static const _selectedActivityDetailsReservedHeight = 380.0;

  double _yearlyInlineMonthlyDetailHeight(double width) {
    const dividerHeight = 1.0;
    const topSpacing = 14.0;
    const monthTitleHeight = 32.0;
    const titleSpacing = 10.0;
    const summaryHeight = 64.0;
    const summarySpacing = 12.0;
    const noActivityHeight = 28.0;
    const weekdayHeaderHeight = 24.0;
    const calendarSpacing = _monthlyCalendarSpacing;
    const selectedDetailsSpacing = 12.0;

    // The inline monthly detail is not inside the 1px-padded activity
    // content ListView, so its calendar uses the full available width.
    final gridWidth = math.max(width, 0).toDouble();
    final gridHeight = _monthlyCalendarGridHeight(gridWidth);

    return dividerHeight +
        topSpacing +
        monthTitleHeight +
        titleSpacing +
        summaryHeight +
        summarySpacing +
        noActivityHeight +
        weekdayHeaderHeight +
        calendarSpacing +
        gridHeight +
        selectedDetailsSpacing +
        _selectedActivityDetailsReservedHeight;
  }

  double _activityViewportHeight(double width) {
    const chartHeight = 250.0;
    const listVerticalPadding = 8.0;
    const contentSpacing = 12.0;

    // Keep the period viewport geometry stable while data changes. Monthly
    // calendars always reserve the maximum six-week footprint.
    // Reserve enough height for the two-line target metric without overflow.
    const summaryHeight = 64.0;
    const noActivityHeight = 28.0;

    if (_range == _ActivityRange.monthly) {
      const weekdayHeaderHeight = 24.0;
      final gridWidth = math.max(width - 2, 0).toDouble();
      final gridHeight = _monthlyCalendarGridHeight(gridWidth);

      return listVerticalPadding +
          summaryHeight +
          contentSpacing +
          noActivityHeight +
          weekdayHeaderHeight +
          gridHeight;
    }

    return listVerticalPadding +
        summaryHeight +
        contentSpacing +
        noActivityHeight +
        chartHeight;
  }

  String _formatHeader(BuildContext context, DateTime anchor) {
    final locale = Localizations.localeOf(context).languageCode;

    switch (_range) {
      case _ActivityRange.weekly:
        final start = QazaActivityService.calendarWeekStartForDate(anchor);
        final end = DateTime(start.year, start.month, start.day + 6);
        if (start.year == end.year) {
          return '${DateFormat.MMMd(locale).format(start)} – ${DateFormat.MMMd(locale).format(end)} ${end.year}';
        }
        return '${DateFormat.yMMMd(locale).format(start)} – ${DateFormat.yMMMd(locale).format(end)}';
      case _ActivityRange.monthly:
        return DateFormat.yMMMM(locale).format(anchor);
      case _ActivityRange.yearly:
        return anchor.year.toString();
    }
  }

  String _previousTooltip(AppLocalizations l10n) {
    switch (_range) {
      case _ActivityRange.weekly:
        return l10n.homePreviousWeek;
      case _ActivityRange.monthly:
        return l10n.homePreviousMonth;
      case _ActivityRange.yearly:
        return l10n.homePreviousYear;
    }
  }

  String _nextTooltip(AppLocalizations l10n) {
    switch (_range) {
      case _ActivityRange.weekly:
        return l10n.homeNextWeek;
      case _ActivityRange.monthly:
        return l10n.homeNextMonth;
      case _ActivityRange.yearly:
        return l10n.homeNextYear;
    }
  }
}

class _SelectedActivityDayDetails extends ConsumerWidget {
  const _SelectedActivityDayDetails({
    super.key,
    required this.range,
    required this.anchor,
    required this.selectedDay,
  });

  final _ActivityRange range;
  final DateTime anchor;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = switch (range) {
      _ActivityRange.weekly =>
        ref.watch(homeQazaActivityWeekProvider(anchor)),
      _ActivityRange.monthly =>
        ref.watch(homeQazaActivityMonthProvider(anchor)),
      _ActivityRange.yearly => const AsyncValue<QazaActivityPeriod>.loading(),
    };

    return periodAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (period) => _ActivityDayDetails(
        day: period.dayFor(selectedDay),
        period: period,
      ),
    );
  }
}

class _ActivityPeriodPage extends ConsumerWidget {
  const _ActivityPeriodPage({
    super.key,
    required this.range,
    required this.anchor,
    required this.selectedDay,
    required this.onSelectedDay,
    required this.selectedMonth,
    required this.onSelectedMonth,
  });

  final _ActivityRange range;
  final DateTime anchor;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelectedDay;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime>? onSelectedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = switch (range) {
      _ActivityRange.weekly =>
        ref.watch(homeQazaActivityWeekProvider(anchor)),
      _ActivityRange.monthly =>
        ref.watch(homeQazaActivityMonthProvider(anchor)),
      _ActivityRange.yearly =>
        ref.watch(homeQazaActivityYearProvider(anchor)),
    };

    return periodAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (_, __) => _ActivityError(
        onRetry: () => _invalidate(ref),
      ),
      data: (period) => _ActivityPeriodContent(
        period: period,
        range: range,
        selectedDay: selectedDay,
        onSelectedDay: onSelectedDay,
        selectedMonth: selectedMonth,
        onSelectedMonth: range == _ActivityRange.yearly
            ? onSelectedMonth
            : null,
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    switch (range) {
      case _ActivityRange.weekly:
        ref.invalidate(homeQazaActivityWeekProvider(anchor));
      case _ActivityRange.monthly:
        ref.invalidate(homeQazaActivityMonthProvider(anchor));
      case _ActivityRange.yearly:
        ref.invalidate(homeQazaActivityYearProvider(anchor));
    }
  }
}

class _ActivityPeriodContent extends ConsumerWidget {
  const _ActivityPeriodContent({
    required this.period,
    required this.range,
    required this.selectedDay,
    required this.onSelectedDay,
    required this.selectedMonth,
    required this.onSelectedMonth,
  });

  final QazaActivityPeriod period;
  final _ActivityRange range;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelectedDay;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime>? onSelectedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: Key('home_activity_${range.name}_content'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      children: [
        if (range == _ActivityRange.weekly ||
            range == _ActivityRange.monthly) ...[
          _ActivityTargetSummary(period: period, range: range),
        ] else
          _ActivityYearSummary(period: period),
        const SizedBox(height: 12),
        SizedBox(
          height: 28,
          child: period.totalCompleted == 0
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    l10n.homeNoActivity,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (range == _ActivityRange.monthly)
          _ActivityMonthGrid(
            period: period,
            selectedDay: selectedDay,
            onSelectedDay: onSelectedDay,
          )
        else if (range == _ActivityRange.weekly)
          _ActivityBarChart(
            key: const Key('home_activity_week_chart'),
            period: period,
            labelsAreDates: true,
            selectedDay: selectedDay,
            onSelectedDay: onSelectedDay,
          )
        else
          _ActivityBarChart(
            key: const Key('home_activity_year_chart'),
            period: period,
            labelsAreDates: false,
            selectedDay: null,
            onSelectedDay: null,
            selectedMonth: selectedMonth,
            onSelectedMonth: onSelectedMonth,
          ),
      ],
    );
  }
}

class _ActivityTargetSummary extends StatelessWidget {
  const _ActivityTargetSummary({
    required this.period,
    required this.range,
  });

  final QazaActivityPeriod period;
  final _ActivityRange range;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = <_SummaryMetricData>[
      _SummaryMetricData(
        label: l10n.homeCompleted,
        value: DateFormatters.formatCount(period.totalCompleted),
      ),
    ];

    if (period.targetAvailable) {
      metrics.addAll([
        _SummaryMetricData(
          label: range == _ActivityRange.weekly
              ? l10n.homeWeeklyTargetLabel
              : l10n.homeMonthlyTarget,
          value: DateFormatters.formatCount(period.fullTarget ?? 0),
          secondary:
              '${DateFormatters.formatCount(period.dailyTarget)}/day',
        ),
        _SummaryMetricData(
          label: l10n.homeRemaining,
          value: DateFormatters.formatCount(period.remainingTarget ?? 0),
        ),
      ]);
    }

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (final metric in metrics)
            Expanded(
              child: _SummaryMetric(
                label: metric.label,
                value: metric.value,
                secondary: metric.secondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityYearSummary extends StatelessWidget {
  const _ActivityYearSummary({required this.period});

  final QazaActivityPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: l10n.homeCompleted,
              value: DateFormatters.formatCount(period.totalCompleted),
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              label: l10n.homeActiveDays,
              value: DateFormatters.formatCount(period.activeDays),
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              label: l10n.homeActiveMonths,
              value: DateFormatters.formatCount(period.activeMonths),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricData {
  const _SummaryMetricData({
    required this.label,
    required this.value,
    this.secondary,
  });

  final String label;
  final String value;
  final String? secondary;
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.secondary,
  });

  final String label;
  final String value;
  final String? secondary;

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
        if (secondary != null) ...[
          const SizedBox(height: 2),
          Text(
            secondary!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

({double maxY, double interval}) _activityAxisScale(int maxCompleted) {
  if (maxCompleted <= 0) {
    return (maxY: 5, interval: 5);
  }

  final interval = maxCompleted <= 5
      ? 1.0
      : maxCompleted <= 15
          ? 5.0
          : _niceChartInterval(maxCompleted / 6);
  var maxY = (maxCompleted / interval).ceil() * interval;

  if (maxY <= maxCompleted) {
    maxY += interval;
  }

  return (maxY: maxY, interval: interval);
}

double _niceChartInterval(double rawInterval) {
  final safeRaw = math.max(rawInterval, 1.0);
  final magnitude =
      math.pow(10, (math.log(safeRaw) / math.ln10).floor()).toDouble();
  final normalized = safeRaw / magnitude;
  final niceNormalized = normalized <= 1
      ? 1.0
      : normalized <= 2
          ? 2.0
          : normalized <= 5
              ? 5.0
              : 10.0;
  return niceNormalized * magnitude;
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart({
    super.key,
    required this.period,
    required this.labelsAreDates,
    required this.selectedDay,
    required this.onSelectedDay,
    this.selectedMonth,
    this.onSelectedMonth,
  });

  final QazaActivityPeriod period;
  final bool labelsAreDates;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelectedDay;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime>? onSelectedMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final maxCompleted = period.days.fold<int>(
      0,
      (maxValue, bucket) => math.max(maxValue, bucket.completed),
    );
    final axis = _activityAxisScale(maxCompleted);
    final maxY = axis.maxY;
    final leftInterval = axis.interval;

    return Semantics(
      container: true,
      label: _chartSemantics(context),
      child: SizedBox(
        height: 250,
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
                  reservedSize: 36,
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
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= period.days.length) {
                      return const SizedBox.shrink();
                    }
                    final date = period.days[index].date;
                    final label = labelsAreDates
                        ? DateFormat.E(locale).format(date)
                        : DateFormat.MMM(locale).format(date);
                    final selectedMonthValue = selectedMonth;
                    final selected = selectedMonthValue != null &&
                        date.year == selectedMonthValue.year &&
                        date.month == selectedMonthValue.month;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected ? theme.colorScheme.primary : null,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: onSelectedDay != null || onSelectedMonth != null,
              // FL Chart's built-in back-draw touch region keeps zero-height
              // bars, including future days, selectable without custom hit testing.
              allowTouchBarBackDraw: true,
              touchExtraThreshold: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 20,
              ),
              touchCallback: (event, response) {
                if ((onSelectedDay == null && onSelectedMonth == null) ||
                    event is! FlTapUpEvent) {
                  return;
                }
                final index = response?.spot?.touchedBarGroupIndex;
                if (index == null ||
                    index < 0 ||
                    index >= period.days.length) {
                  return;
                }
                final date = period.days[index].date;
                if (onSelectedMonth != null) {
                  onSelectedMonth!(date);
                } else {
                  onSelectedDay!(date);
                }
              },
            ),
            barGroups: [
              for (var index = 0; index < period.days.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: period.days[index].completed.toDouble(),
                      width: labelsAreDates ? 20 : 15,
                      color: _barColor(context, period.days[index]),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: theme.colorScheme.surface.withAlpha(0),
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

  Color _barColor(BuildContext context, QazaDailyActivity day) {
    final scheme = Theme.of(context).colorScheme;
    final selectedDayValue = selectedDay;
    final selectedDayMatches = selectedDayValue != null &&
        day.date == DateTime(
          selectedDayValue.year,
          selectedDayValue.month,
          selectedDayValue.day,
        );
    final selectedMonthValue = selectedMonth;
    final selectedMonthMatches = selectedMonthValue != null &&
        day.date.year == selectedMonthValue.year &&
        day.date.month == selectedMonthValue.month;

    return selectedDayMatches || selectedMonthMatches
        ? scheme.primary
        : scheme.primary.withAlpha(120);
  }

  String _chartSemantics(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return [
      for (var index = 0; index < period.days.length; index++)
        labelsAreDates
            ? '${DateFormat.EEEE(locale).format(period.days[index].date)}: ${period.days[index].completed} ${l10n.homeCompleted}'
            : '${DateFormat.MMMM(locale).format(period.days[index].date)}: ${period.days[index].completed} ${l10n.homeCompleted}',
    ].join(', ');
  }
}

class _InlineMonthlyDetail extends ConsumerWidget {
  const _InlineMonthlyDetail({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onSelectedDay,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final normalizedMonth = DateTime(month.year, month.month);
    final periodAsync = ref.watch(
      homeQazaActivityMonthProvider(normalizedMonth),
    );

    return periodAsync.when(
      loading: () => const Center(
        key: Key('home_activity_inline_month_loading'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, __) => _ActivityError(
        onRetry: () => ref.invalidate(
          homeQazaActivityMonthProvider(normalizedMonth),
        ),
      ),
      data: (period) => Column(
        key: const Key('home_activity_inline_month_detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 14),
          Text(
            DateFormat.yMMMM(locale).format(normalizedMonth),
            key: const Key('home_activity_selected_month_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _ActivityTargetSummary(
            period: period,
            range: _ActivityRange.monthly,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 28,
            child: period.totalCompleted == 0
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      AppLocalizations.of(context).homeNoActivity,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _ActivityMonthGrid(
            period: period,
            selectedDay: selectedDay,
            onSelectedDay: onSelectedDay,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: selectedDay == null
                  ? const SizedBox.expand(
                      key: ValueKey('home_activity_no_selected_day'),
                    )
                  : Align(
                      key: const ValueKey('home_activity_selected_day'),
                      alignment: Alignment.topCenter,
                      child: _SelectedActivityDayDetails(
                        key: const Key('home_activity_selected_day_details'),
                        range: _ActivityRange.monthly,
                        anchor: normalizedMonth,
                        selectedDay: selectedDay!,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

double _monthlyCalendarCellExtent(double width) {
  final availableWidth = math.max(width, 0.0);
  return math.max(
    (availableWidth -
            (_monthlyCalendarRows - 1) * _monthlyCalendarSpacing) /
        7,
    0.0,
  );
}

double _monthlyCalendarGridHeight(double width) {
  final cellExtent = _monthlyCalendarCellExtent(width);
  return _monthlyCalendarRows * cellExtent +
      (_monthlyCalendarRows - 1) * _monthlyCalendarSpacing;
}

class _ActivityMonthGrid extends StatelessWidget {
  const _ActivityMonthGrid({
    required this.period,
    required this.selectedDay,
    required this.onSelectedDay,
  });

  final QazaActivityPeriod period;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelectedDay;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final first = period.days.first.date;
    final leading = first.weekday % 7;
    final labels = [
      for (var index = 0; index < 7; index++)
        DateFormat.E(locale).format(DateTime(2024, 1, 7 + index)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellExtent = _monthlyCalendarCellExtent(constraints.maxWidth);
        final gridHeight = _monthlyCalendarGridHeight(constraints.maxWidth);

        return Column(
          children: [
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  for (final label in labels)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: _monthlyCalendarSpacing),
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                key: const Key('home_activity_month_grid'),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _monthlyCalendarRows * 7,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: _monthlyCalendarSpacing,
                  crossAxisSpacing: _monthlyCalendarSpacing,
                  mainAxisExtent: cellExtent,
                ),
                itemBuilder: (context, index) {
                  if (index < leading ||
                      index - leading >= period.days.length) {
                    return const SizedBox.expand();
                  }
                  final day = period.days[index - leading];
                  final selected =
                      selectedDay != null && day.date == selectedDay;
                  return _ActivityDayCell(
                    day: day,
                    selected: selected,
                    onTap: onSelectedDay == null
                        ? null
                        : () => onSelectedDay!(day.date),
                  );
                },
              ),
            ),
          ],
        );
      },
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = math.min(day.completed, 10);
    final fill = day.isFuture
        ? scheme.surfaceContainerHighest
        : day.completed == 0
            ? scheme.surfaceContainerHighest
            : scheme.primary.withAlpha(35 + intensity * 12);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label:
          '${day.date.day}, ${day.completed} ${AppLocalizations.of(context).homeCompleted}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
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

class _ActivityDayDetails extends ConsumerWidget {
  const _ActivityDayDetails({
    required this.day,
    required this.period,
  });

  final QazaDailyActivity? day;
  final QazaActivityPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isToday =
        day != null && !day!.isFuture && day!.date == period.today;
    final enabledNow = ref.watch(enabledPrayerTypesProvider);
    final selected = day;

    if (selected == null) return const SizedBox.shrink();

    final prayers = isToday
        ? enabledNow
        : PrayerType.values.toList(growable: false);

    return Card(
      key: const Key('home_activity_day_details'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat.yMMMMEEEEd(
                Localizations.localeOf(context).languageCode,
              ).format(selected.date),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _DetailMetricRow(
              label: l10n.homeCompleted,
              value: selected.completed.toString(),
            ),
            if (period.targetAvailable && selected.target > 0) ...[
              _DetailMetricRow(
                label: l10n.homeDailyTarget,
                value: period.dailyTarget.toString(),
              ),
              _DetailMetricRow(
                label: l10n.homeRemaining,
                value: selected.remaining.toString(),
              ),
              _DetailMetricRow(
                label: l10n.homeProgressLabel,
                value: '${(selected.progress * 100).round()}%',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.homePrayerBreakdown,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final prayer in prayers)
              _PrayerActivityRow(
                prayer: prayer,
                completed: selected.byPrayer[prayer] ?? 0,
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
          Text(
            l10n.homeProgressError,
            textAlign: TextAlign.center,
          ),
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
