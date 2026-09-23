import 'dart:async';
import 'dart:io' show Platform;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/theme/app_theme.dart';
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
import '../../features/prayer_times/domain/qaza_restriction_service.dart';
import '../../features/prayer_times/prayer_times_providers.dart';
import '../../features/prayer_times/presentation/prayer_times_localizations.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'home_plan.dart';
import 'home_qaza_completion.dart';
import '../qaza/qaza_undo_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
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
                _TodayProgressSection(summary: summary),
                const SizedBox(height: 12),
                _OverallQazaSection(
                  progress: summary.overall,
                  onDetails: () => _open(
                    context,
                    ref,
                    _DetailedStatisticsScreen(summary: summary),
                  ),
                ),
                const SizedBox(height: 12),
                _PendingByPrayerSection(summary: summary),
                const SizedBox(height: 12),
                const _HomeProgressChartSection(),
                const SizedBox(height: 12),
                _DetailedStatisticsCard(
                  onTap: () => _open(
                    context,
                    ref,
                    _DetailedStatisticsScreen(summary: summary),
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
  const _TodayProgressSection({required this.summary});

  final QazaProgressSummary summary;

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
      final restriction =
          await ref.read(qazaRestrictionServiceProvider).evaluateCurrent();
      if (restriction.isRestricted && restriction.type != null) {
        ref.invalidate(qazaRestrictionEvaluationProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  PrayerTimesStrings.qazaRestricted(
                    context,
                    restriction.type!,
                  ),
                ),
              ),
            );
        }
        return;
      }

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

      final pendingBefore =
          widget.summary.byPrayer[prayer]?.progress.pending ?? 0;
      if (pendingBefore <= 1 && mounted) {
        ref.read(homePrayerSelectionProvider.notifier).useAutomatic();
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    l10n.homeTodayProgressHeader,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  );
                  final date = Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: date,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      date,
                    ],
                  );
                },
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
                    summary: widget.summary,
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
    final charts = AppChartColors.of(context);
    final percent = (progress * 100).round();

    return Semantics(
      label: percent.toString() + '%, ' +
          completed.toString() + ' of ' + target.toString(),
      child: SizedBox(
        key: const Key('home_today_donut'),
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 50,
                startDegreeOffset: -90,
                sections: [
                  PieChartSectionData(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    color: charts.primary,
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: (1 - progress).clamp(0.0, 1.0).toDouble(),
                    color: charts.track,
                    radius: 16,
                    showTitle: false,
                  ),
                ],
              ),
              duration: Duration.zero,
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

IconData _prayerIcon(PrayerType prayer) {
  switch (prayer) {
    case PrayerType.fajr:
      return Icons.wb_twilight_outlined;
    case PrayerType.zuhr:
      return Icons.wb_sunny_outlined;
    case PrayerType.asr:
      return Icons.sunny_snowing;
    case PrayerType.maghrib:
      return Icons.wb_twilight;
    case PrayerType.isha:
      return Icons.nightlight_outlined;
    case PrayerType.witr:
      return Icons.nightlight_round;
  }
}

class _NextQazaPanel extends ConsumerStatefulWidget {
  const _NextQazaPanel({
    required this.summary,
    required this.selected,
    required this.working,
    required this.onComplete,
    required this.onPlan,
  });

  final QazaProgressSummary summary;
  final HomeSelectedPrayerState selected;
  final bool working;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;

  @override
  ConsumerState<_NextQazaPanel> createState() => _NextQazaPanelState();
}

class _NextQazaPanelState extends ConsumerState<_NextQazaPanel> {
  Timer? _restrictionTicker;
  QazaRestrictionEvaluation? _lastRestriction;
  bool _restrictionInvalidated = false;

  @override
  void initState() {
    super.initState();
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    _restrictionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final current =
          _lastRestriction ??
          ref.read(qazaRestrictionEvaluationProvider).valueOrNull;
      if (current?.isRestricted != true) return;

      final end = current?.end;
      if (end != null && !DateTime.now().isBefore(end)) {
        if (!_restrictionInvalidated) {
          _restrictionInvalidated = true;
          ref.invalidate(qazaRestrictionEvaluationProvider);
        }
        return;
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _restrictionTicker?.cancel();
    super.dispose();
  }

  Duration _liveRestrictionRemaining(
    QazaRestrictionEvaluation restriction,
  ) {
    final end = restriction.end;
    final remaining = end == null
        ? restriction.remaining
        : end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<QazaRestrictionEvaluation>>(
      qazaRestrictionEvaluationProvider,
      (previous, next) {
        if (next.hasValue) {
          _lastRestriction = next.value;
          _restrictionInvalidated = false;
        }
      },
    );

    final l10n = AppLocalizations.of(context);
    final prayer = widget.selected.prayer;
    final restrictionAsync = ref.watch(qazaRestrictionEvaluationProvider);
    final restriction =
        _lastRestriction ?? restrictionAsync.valueOrNull;
    final restrictedRestriction =
        restriction?.isRestricted == true ? restriction : null;
    final restrictedType = restriction?.type;
    final pendingPrayers = PrayerType.values
        .where(
          (item) => (widget.summary.byPrayer[item]?.progress.pending ?? 0) > 0,
        )
        .toList(growable: false);

    final prayerSelector = PopupMenuButton<String>(
      key: const Key('home_qaza_prayer_selector'),
      tooltip: l10n.homeNextQaza,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'auto') {
          ref.read(homePrayerSelectionProvider.notifier).useAutomatic();
          return;
        }
        final selectedPrayer = PrayerType.values.firstWhere(
          (item) => item.name == value,
        );
        ref.read(homePrayerSelectionProvider.notifier).selectPrayer(
              selectedPrayer,
            );
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: const Key('home_qaza_prayer_option_auto'),
          value: 'auto',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected.mode == HomePrayerSelectionMode.automatic
                    ? Icons.check_rounded
                    : Icons.auto_awesome_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(l10n.homeAuto),
            ],
          ),
        ),
        for (final item in pendingPrayers)
          PopupMenuItem<String>(
            key: Key('home_qaza_prayer_option_' + item.name),
            value: item.name,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.selected.prayer == item
                      ? Icons.check_rounded
                      : _prayerIcon(item),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(item.localizedLabel(l10n)),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.tune_rounded, size: 18),
        label: Text(
          widget.selected.mode == HomePrayerSelectionMode.automatic
              ? l10n.homeAuto
              : prayer!.localizedLabel(l10n),
        ),
      ),
    );

    final header = Text(
      widget.selected.mode == HomePrayerSelectionMode.automatic
          ? l10n.homeNextQazaCurrentPrayer
          : l10n.homeNextQaza,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: header),
            const SizedBox(width: 8),
            prayerSelector,
          ],
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

                  if (restrictedRestriction != null && restrictedType != null) {
                    final nextAllowedTime =
                        restrictedRestriction.nextAllowedTime;
                    final timeLabel = nextAllowedTime == null
                        ? null
                        : MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(nextAllowedTime),
                          );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          key: const Key('home_qaza_restricted_state'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lock_clock_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      PrayerTimesStrings
                                          .qazaTemporarilyUnavailable(context),
                                      key: const Key(
                                        'home_qaza_restricted_title',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      PrayerTimesStrings.qazaRestricted(
                                        context,
                                        restrictedType,
                                      ),
                                      key: const Key(
                                        'home_qaza_restricted_reason',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      PrayerTimesStrings.restrictionRemaining(
                                        context,
                                        _liveRestrictionRemaining(restrictedRestriction),
                                      ),
                                      key: const Key(
                                        'home_qaza_restricted_remaining',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (timeLabel != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        PrayerTimesStrings.availableAt(
                                          context,
                                          timeLabel,
                                        ),
                                        key: const Key(
                                          'home_qaza_restricted_available_at',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('home_qaza_view_all'),
                                onPressed: () => openQazaAll(ref),
                                icon: const Icon(
                                  Icons.list_alt_rounded,
                                ),
                                label: Text(l10n.homeViewAllQaza),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              key: const Key('home_qaza_plan_button'),
                              onPressed: widget.onPlan,
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                              label: Text(l10n.homeQazaPlan),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final details = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onErrorContainer,
                            child: Icon(_prayerIcon(prayer)),
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
                      );

                      final complete = FilledButton.icon(
                        key: const Key('home_complete_oldest_qaza'),
                        onPressed: widget.working
                            ? null
                            : () => widget.onComplete(record, prayer),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          widget.working
                              ? l10n.completeInProgress
                              : l10n.homeCompleteQaza,
                        ),
                      );
                      final plan = OutlinedButton.icon(
                        key: const Key('home_qaza_plan_button'),
                        onPressed: widget.onPlan,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(l10n.homeQazaPlan),
                      );

                      if (constraints.maxWidth < 340) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  child: Icon(_prayerIcon(prayer)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prayer.localizedLabel(l10n),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        DateFormatters
                                            .formatGregorianDatePadded(
                                          record.originalDate,
                                        ),
                                        key: const Key('home_oldest_qaza_date'),
                                      ),
                                      Text(
                                        DateFormatters.hijriLabel(
                                          record.originalDate,
                                        ),
                                        key: const Key(
                                          'home_oldest_qaza_date_hijri',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: StatusChip(
                                l10n.homeOldestPending,
                                tone: StatusChipTone.pending,
                              ),
                            ),
                            const SizedBox(height: 12),
                            complete,
                            const SizedBox(height: 8),
                            plan,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: complete),
                              const SizedBox(width: 8),
                              plan,
                            ],
                          ),
                        ],
                      );
                    },
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    l10n.homeOverallQaza,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final action = TextButton(
                    key: const Key('home_overall_view_details'),
                    onPressed: onDetails,
                    child: Text(l10n.homeViewDetails),
                  );
                  if (constraints.maxWidth < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      action,
                    ],
                  );
                },
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

          if (constraints.maxWidth < 520) {
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
    final charts = AppChartColors.of(context);

    return SizedBox(
      key: const Key('home_overall_donut'),
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 52,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  color: charts.primary,
                  radius: 16,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - progress).clamp(0.0, 1.0).toDouble(),
                  color: charts.track,
                  radius: 16,
                  showTitle: false,
                ),
              ],
            ),
            duration: Duration.zero,
          ),
          Text(
            (progress * 100).round().toString() + '%',
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
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
    final totalPending = summary.overall.pending;
    final pendingPrayers = PrayerType.values
        .where(
          (prayer) => (summary.byPrayer[prayer]?.progress.pending ?? 0) > 0,
        )
        .toList(growable: false);

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
          if (pendingPrayers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: charts.completed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.completeNoPendingTitle,
                    key: const Key('home_pending_by_prayer_empty'),
                  ),
                ],
              ),
            )
          else
            for (final prayer in pendingPrayers)
              _PrayerPendingBar(
                prayer: prayer,
                pending: summary.byPrayer[prayer]?.progress.pending ?? 0,
                totalPending: totalPending,
                charts: charts,
                onTap: () => openQazaForPrayer(ref, prayer),
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
    required this.totalPending,
    required this.charts,
    required this.onTap,
  });

  final PrayerType prayer;
  final int pending;
  final int totalPending;
  final AppChartColors charts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fraction = totalPending <= 0
        ? 0.0
        : (pending / totalPending).clamp(0.0, 1.0).toDouble();
    final prayerLabel = prayer.localizedLabel(l10n);
    final pendingLabel = DateFormatters.formatCount(pending);

    return Semantics(
      key: Key('home_pending_prayer_semantics_' + prayer.name),
      button: true,
      label: prayerLabel + ', ' + pendingLabel + ' ' + l10n.homePending,
      child: InkWell(
        key: Key('home_pending_prayer_' + prayer.name),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(
                  _prayerIcon(prayer),
                  size: 20,
                  color: charts.forPrayer(prayer),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 74,
                child: Text(
                  prayerLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  pendingLabel,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
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
    final charts = AppChartColors.of(context);
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
                            getTooltipItems: (spots) => spots
                                .map(
                                  (spot) => LineTooltipItem(
                                    DateFormatters.formatCount(
                                      spot.y.round(),
                                    ),
                                    TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
