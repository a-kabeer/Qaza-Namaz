import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../features/calculator/calculator_screen.dart';
import '../../features/qaza/add_qaza_screen.dart';
import '../../features/qaza/qaza_navigation.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'home_plan.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    _invalidateHome(ref);
  }

  Future<void> _refresh(WidgetRef ref) async {
    _invalidateHome(ref);
    await ref.read(progressSummaryProvider.future);
  }

  void _invalidateHome(WidgetRef ref) {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeDailyProgressProvider);
    for (final prayer in PrayerType.values) {
      ref.invalidate(oldestPendingProvider(prayer));
    }
    for (final range in HomeProgressRange.values) {
      ref.invalidate(homeProgressHistoryProvider(range));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return AppScaffold(
      title: l10n.homeTitle,
      body: summaryAsync.when(
        loading: () => const _HomeSkeleton(),
        error: (_, __) => _HomeError(onRetry: () => _refresh(ref)),
        data: (summary) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    QazaProgressSummary summary,
  ) {
    if (summary.overall.total == 0) {
      return _EmptyLedger(
        onCalculate: () => _open(context, ref, const CalculatorScreen()),
        onAdd: () => _open(context, ref, const AddQazaScreen()),
      );
    }

    return ListView(
      key: const Key('home_dashboard'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TodayProgressSection(),
                const SizedBox(height: 12),
                _OverallQazaSection(
                  progress: summary.overall,
                  onDetails: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _DetailedStatisticsScreen(
                        summary: summary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PendingByPrayerSection(summary: summary),
                const SizedBox(height: 12),
                const _HomeProgressChartSection(),
                const SizedBox(height: 12),
                _DetailedStatisticsCard(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _DetailedStatisticsScreen(
                        summary: summary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayProgressSection extends ConsumerStatefulWidget {
  const _TodayProgressSection();

  @override
  ConsumerState<_TodayProgressSection> createState() =>
      _TodayProgressSectionState();
}

class _TodayProgressSectionState extends ConsumerState<_TodayProgressSection> {
  bool working = false;

  Future<void> _showPlanDialog() async {
    final l10n = AppLocalizations.of(context);
    var selected = ref.read(homeQazaPlanProvider).dailyTarget;
    const options = [1, 2, 3, 5, 10, 15, 20, 30, 50];

    final target = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          key: const Key('home_qaza_plan_dialog'),
          title: Text(l10n.homeQazaPlan),
          content: DropdownButton<int>(
            key: const Key('home_qaza_plan_target'),
            isExpanded: true,
            value: options.contains(selected)
                ? selected
                : HomeQazaPlanState.defaultDailyTarget,
            items: [
              for (final value in options)
                DropdownMenuItem<int>(
                  value: value,
                  child: Text(l10n.homePerDay(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              key: const Key('home_qaza_plan_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('home_qaza_plan_done'),
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      ),
    );

    if (target == null || !mounted) return;
    await ref.read(homeQazaPlanProvider.notifier).setDailyTarget(target);
    ref.invalidate(homeDailyProgressProvider);
  }

  Future<void> _complete(QazaRecord record, PrayerType prayer) async {
    if (working) return;
    setState(() => working = true);

    final userId = ref.read(requiredUserIdProvider);
    final completedAt = ref.read(homeNowProvider);

    try {
      await ref.read(qazaServiceProvider).completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: completedAt,
          );

      for (final prayerType in PrayerType.values) {
        ref.invalidate(oldestPendingProvider(prayerType));
      }
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(homeDailyProgressProvider);
      for (final range in HomeProgressRange.values) {
        ref.invalidate(homeProgressHistoryProvider(range));
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showQazaUndoSnackBar(
        context: context,
        ref: ref,
        userId: userId,
        recordIds: [record.id],
        completedAt: completedAt,
        onUndone: () async {
          ref.invalidate(progressSummaryProvider);
          ref.invalidate(homeDailyProgressProvider);
          ref.invalidate(oldestPendingProvider(prayer));
          for (final range in HomeProgressRange.values) {
            ref.invalidate(homeProgressHistoryProvider(range));
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).completeFailed)),
        );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final daily = ref.watch(homeDailyProgressProvider);
    final selected = ref.watch(homeSelectedPrayerProvider);
    final now = ref.watch(homeNowProvider);
    final dateLabel = DateFormatters.weekdayShortNames[now.weekday - 1] +
        ', ' +
        DateFormatters.formatGregorianDatePadded(now);

    return AppCard(
      key: const Key('home_today_progress'),
      padding: const EdgeInsets.all(16),
      child: daily.when(
        loading: () => const _TodayProgressSkeleton(),
        error: (_, __) => Row(
          children: [
            const Icon(Icons.refresh_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.homeDailyProgressError)),
            TextButton(
              key: const Key('home_daily_progress_retry'),
              onPressed: () => ref.invalidate(homeDailyProgressProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
        data: (progress) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeTodayProgressHeader,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final donut = _TodayDonut(
                    progress: progress.percentage,
                    completed: progress.completed,
                    target: progress.target,
                  );
                  final next = _NextQazaPanel(
                    selected: selected,
                    working: working,
                    onComplete: _complete,
                    onPlan: _showPlanDialog,
                  );

                  if (constraints.maxWidth < 500) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: donut),
                        const SizedBox(height: 18),
                        next,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 190, child: Center(child: donut)),
                      const SizedBox(width: 18),
                      Container(
                        width: 1,
                        height: 128,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: next),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayDonut extends StatelessWidget {
  const _TodayDonut({
    required this.progress,
    required this.completed,
    required this.target,
  });

  final double progress;
  final int completed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Semantics(
      label: percent.toString() +
          '%, ' +
          completed.toString() +
          ' of ' +
          target.toString(),
      child: SizedBox(
        key: const Key('home_today_donut'),
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: AppChartColors.of(context).track,
              color: AppChartColors.of(context).primary,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percent.toString() + '%',
                  key: const Key('home_today_percent'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  completed.toString() + ' of ' + target.toString(),
                  key: const Key('home_today_count'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  AppLocalizations.of(context).homeCompleted,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextQazaPanel extends StatelessWidget {
  const _NextQazaPanel({
    required this.selected,
    required this.working,
    required this.onComplete,
    required this.onPlan,
  });

  final HomeSelectedPrayerState selected;
  final bool working;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayer = selected.prayer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.homeNextQazaCurrentPrayer,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (prayer == null)
          Text(
            l10n.homePrayerTimeUnavailable,
            key: const Key('home_qaza_prayer_time_unavailable'),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(oldestPendingProvider(prayer));
              return state.when(
                loading: () => const _NextQazaSkeleton(),
                error: (_, __) => ErrorState(
                  key: const Key('home_oldest_qaza_error'),
                  message: l10n.completeLoadError,
                  onRetry: () => ref.invalidate(oldestPendingProvider(prayer)),
                ),
                data: (record) {
                  if (record == null) {
                    return Text(
                      l10n.completeNoPendingTitle,
                      key: const Key('home_oldest_qaza_empty'),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onErrorContainer,
                            child: Icon(prayer.icon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prayer.localizedLabel(l10n),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  DateFormatters.formatGregorianDatePadded(
                                    record.originalDate,
                                  ),
                                  key: const Key('home_oldest_qaza_date'),
                                ),
                                Text(
                                  DateFormatters.hijriLabel(record.originalDate),
                                  key: const Key('home_oldest_qaza_date_hijri'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            l10n.homeOldestPending,
                            tone: StatusChipTone.pending,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('home_complete_oldest_qaza'),
                              onPressed: working
                                  ? null
                                  : () => onComplete(record, prayer),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                working
                                    ? l10n.completeInProgress
                                    : l10n.homeCompleteQaza,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            key: const Key('home_qaza_plan_button'),
                            onPressed: onPlan,
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                            ),
                            label: Text(l10n.homeQazaPlan),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _OverallQazaSection extends StatelessWidget {
  const _OverallQazaSection({
    required this.progress,
    required this.onDetails,
  });

  final QazaProgress progress;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      key: const Key('home_overall_qaza'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeOverallQaza,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('home_overall_view_details'),
                    onPressed: onDetails,
                    child: Text(l10n.homeViewDetails),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _StatLine(
                key: const Key('home_completed_value'),
                label: l10n.homeCompleted,
                value: DateFormatters.formatCount(progress.completed),
                color: AppChartColors.of(context).completed,
              ),
              _StatLine(
                key: const Key('home_pending_value'),
                label: l10n.homePending,
                value: DateFormatters.formatCount(progress.pending),
                color: AppChartColors.of(context).pending,
              ),
              _StatLine(
                key: const Key('home_total_value'),
                label: l10n.homeStatTotal,
                value: DateFormatters.formatCount(progress.total),
                color: AppChartColors.of(context).total,
              ),
            ],
          );

          final donut = _OverviewDonut(progress: progress.percentage);

          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    donut,
                    const SizedBox(width: 16),
                    Expanded(child: stats),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: stats),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewDonut extends StatelessWidget {
  const _OverviewDonut({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home_overall_donut'),
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 16,
            backgroundColor: AppChartColors.of(context).track,
            color: AppChartColors.of(context).primary,
          ),
          Text(
            ((progress * 100).round()).toString() + '%',
            key: const Key('home_overall_percent'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PendingByPrayerSection extends ConsumerWidget {
  const _PendingByPrayerSection({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final charts = AppChartColors.of(context);
    final maxPending = summary.byPrayer.values.fold<int>(
      0,
      (maxValue, item) => item.progress.pending > maxValue
          ? item.progress.pending
          : maxValue,
    );

    return AppCard(
      key: const Key('home_pending_by_prayer'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homePendingByPrayer,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                key: const Key('home_pending_by_prayer_view_all'),
                onPressed: () => openQazaAll(ref),
                child: Text(l10n.homeViewAll),
              ),
            ],
          ),
          for (final prayer in PrayerType.values)
            _PrayerPendingBar(
              prayer: prayer,
              pending: summary.byPrayer[prayer]?.progress.pending ?? 0,
              maxPending: maxPending,
              charts: charts,
            ),
        ],
      ),
    );
  }
}

class _PrayerPendingBar extends StatelessWidget {
  const _PrayerPendingBar({
    required this.prayer,
    required this.pending,
    required this.maxPending,
    required this.charts,
  });

  final PrayerType prayer;
  final int pending;
  final int maxPending;
  final AppChartColors charts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fraction =
        maxPending == 0 ? 0.0 : (pending / maxPending).clamp(0, 1).toDouble();

    return InkWell(
      key: Key('home_pending_prayer_' + prayer.name),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPrayer(context, prayer),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(prayer.localizedLabel(l10n)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: Key('home_pending_bar_' + prayer.name),
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: charts.track,
                  color: charts.forPrayer(prayer),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 62,
              child: Text(
                DateFormatters.formatCount(pending),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPrayer(BuildContext context, PrayerType prayer) {
    final scope = ProviderScope.containerOf(context, listen: false);
    final container = scope;
    // The navigation helper updates the existing workspace destination and
    // applies the selected prayer filter without pushing a duplicate tracker.
    // This row is a non-Consumer widget, so obtain the current WidgetRef by
    // using the page-level ProviderScope container through a small local bridge.
    _HomePrayerNavigation.open(container, prayer);
  }
}

class _HomePrayerNavigation {
  static void open(ProviderContainer container, PrayerType prayer) {
    container
        .read(qazaTrackerFilterRequestProvider.notifier)
        .state = QazaTrackerFilterRequest(
      prayer: prayer,
      status: QazaStatusFilter.pending,
    );
    container
        .read(workspaceDestinationProvider.notifier)
        .state = WorkspaceDestination.qaza;
  }
}

class _HomeProgressChartSection extends ConsumerStatefulWidget {
  const _HomeProgressChartSection();

  @override
  ConsumerState<_HomeProgressChartSection> createState() =>
      _HomeProgressChartSectionState();
}

class _HomeProgressChartSectionState
    extends ConsumerState<_HomeProgressChartSection> {
  HomeProgressRange range = HomeProgressRange.sevenDays;
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(homeProgressHistoryProvider(range));

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
          SegmentedButton<HomeProgressRange>(
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
              setState(() {
                range = selection.single;
                selectedIndex = null;
              });
            },
          ),
          const SizedBox(height: 16),
          data.when(
            loading: () => const _ChartSkeleton(),
            error: (_, __) => Text(l10n.homeProgressError),
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
                      child: Text(
                        DateFormatters.gregorianMonthName(selected.start.month) +
                            ' ' +
                            selected.start.day.toString() +
                            ': ' +
                            DateFormatters.formatCount(selected.count),
                        key: const Key('home_chart_selected_value'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    key: const Key('home_progress_chart'),
                    height: 190,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final index = _nearestIndex(
                              details.localPosition.dx,
                              points.length,
                              constraints.maxWidth,
                            );
                            setState(() => selectedIndex = index);
                          },
                          child: CustomPaint(
                            painter: _HomeProgressChartPainter(
                              points: points,
                              primary: AppChartColors.of(context).primary,
                              grid: AppChartColors.of(context).grid,
                              track: AppChartColors.of(context).track,
                              textColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
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

  int _nearestIndex(double dx, int length, double width) {
    if (length <= 1 || width <= 0) return 0;
    final fraction = (dx / width).clamp(0, 1).toDouble();
    return (fraction * (length - 1)).round();
  }
}

class _HomeProgressChartPainter extends CustomPainter {
  _HomeProgressChartPainter({
    required this.points,
    required this.primary,
    required this.grid,
    required this.track,
    required this.textColor,
  });

  final List<HomeProgressPoint> points;
  final Color primary;
  final Color grid;
  final Color track;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const right = 8.0;
    const top = 10.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxCount = points.fold<int>(
      1,
      (value, point) => point.count > value ? point.count : value,
    );

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * (i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    if (points.isEmpty) return;

    final line = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y =
          chart.bottom - chart.height * (points[i].count / maxCount);

      if (i == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, chart.bottom);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }

    final lastX = points.length == 1
        ? chart.center.dx
        : chart.left + chart.width;
    fill.lineTo(lastX, chart.bottom);
    fill.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: 0.22),
          track.withValues(alpha: 0.30),
        ],
      ).createShader(chart);
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(line, linePaint);

    final pointPaint = Paint()..color = primary;
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y =
          chart.bottom - chart.height * (points[i].count / maxCount);
      canvas.drawCircle(Offset(x, y), 4.5, pointPaint);
    }

    final labels = points.length <= 7
        ? [for (var i = 0; i < points.length; i++) i]
        : <int>{
            0,
            points.length ~/ 2,
            points.length - 1,
          }.toList()
      ..sort();

    for (final index in labels) {
      final point = points[index];
      final label = points.length <= 7
          ? point.start.day.toString() +
              ' ' +
              DateFormatters.gregorianMonthName(point.start.month)
          : point.start.day == 1
              ? DateFormatters.gregorianMonthName(point.start.month)
              : point.start.day.toString();

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);

      final x = points.length == 1
          ? chart.center.dx - tp.width / 2
          : chart.left +
              chart.width * index / (points.length - 1) -
              tp.width / 2;
      tp.paint(
        canvas,
        Offset(
          x.clamp(0, size.width - tp.width).toDouble(),
          chart.bottom + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeProgressChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.primary != primary ||
      oldDelegate.grid != grid ||
      oldDelegate.track != track ||
      oldDelegate.textColor != textColor;
}

class _DetailedStatisticsCard extends StatelessWidget {
  const _DetailedStatisticsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppCard(
      key: const Key('home_detailed_statistics'),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor:
                Theme.of(context).colorScheme.onPrimaryContainer,
            child: const Icon(Icons.pie_chart_outline_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeDetailedStatistics,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.homeDetailedStatisticsSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _DetailedStatisticsScreen extends StatelessWidget {
  const _DetailedStatisticsScreen({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.homeDetailedStatistics,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeOverallQaza,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                _StatLine(
                  label: l10n.homeCompleted,
                  value: DateFormatters.formatCount(summary.overall.completed),
                  color: AppChartColors.of(context).completed,
                ),
                _StatLine(
                  label: l10n.homePending,
                  value: DateFormatters.formatCount(summary.overall.pending),
                  color: AppChartColors.of(context).pending,
                ),
                _StatLine(
                  label: l10n.homeStatTotal,
                  value: DateFormatters.formatCount(summary.overall.total),
                  color: AppChartColors.of(context).total,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homePendingByPrayer,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final prayer in PrayerType.values)
                  _StatLine(
                    label: prayer.localizedLabel(l10n),
                    value: DateFormatters.formatCount(
                      summary.byPrayer[prayer]?.progress.pending ?? 0,
                    ),
                    color: AppChartColors.of(context).forPrayer(prayer),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.onCalculate, required this.onAdd});

  final VoidCallback onCalculate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: const Key('home_empty_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: l10n.homeHeadingSetup,
              message: l10n.homeSetupMessage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    key: const Key('home_empty_calculate'),
                    expand: true,
                    icon: Icons.calculate_outlined,
                    label: l10n.homeCalculateQaza,
                    onPressed: onCalculate,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    key: const Key('home_empty_add'),
                    expand: true,
                    secondary: true,
                    icon: Icons.add_rounded,
                    label: l10n.homeAddManually,
                    onPressed: onAdd,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        const _HomeSkeletonCard(height: 300),
        const SizedBox(height: 12),
        const _HomeSkeletonCard(height: 190),
        const SizedBox(height: 12),
        const _HomeSkeletonCard(height: 280),
        const SizedBox(height: 12),
        const _HomeSkeletonCard(height: 300),
        const SizedBox(height: 12),
        const _HomeSkeletonCard(height: 76),
      ],
    );
  }
}

class _HomeSkeletonCard extends StatelessWidget {
  const _HomeSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonText(width: 160, height: 18)),
                  SizedBox(width: 12),
                  SkeletonText(width: 72, height: 14),
                ],
              ),
              Spacer(),
              SkeletonBox(
                width: double.infinity,
                height: 10,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayProgressSkeleton extends StatelessWidget {
  const _TodayProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonCircle(size: 138),
        SizedBox(height: 18),
        SkeletonBox(
          width: double.infinity,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ],
    );
  }
}

class _NextQazaSkeleton extends StatelessWidget {
  const _NextQazaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(
          width: double.infinity,
          height: 58,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        SizedBox(height: 12),
        SkeletonBox(
          width: double.infinity,
          height: 44,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ],
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonBox(
      width: double.infinity,
      height: 190,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      key: const Key('home_error'),
      message: AppLocalizations.of(context).homeProgressError,
      onRetry: onRetry,
    );
  }
}
