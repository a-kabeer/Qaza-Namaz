import 'dart:async';
import 'dart:io' show Platform;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../../core/widgets/progress_widgets.dart';
import '../../../domain/entities/qaza_progress.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/services/qaza_service.dart';
import '../../../domain/services/sahib_al_tartib_service.dart';
import '../../prayer_times/domain/qaza_restriction_service.dart';
import '../../prayer_times/presentation/prayer_location_picker_screen.dart';
import '../../prayer_times/presentation/prayer_times_localizations.dart';
import '../../prayer_times/prayer_times_providers.dart';
import '../../qaza/completion/qaza_completion_controller.dart';
import '../../qaza/completion/qaza_completion_state.dart';
import '../../../domain/services/sahib_al_tartib_service.dart';
import '../../qaza/qaza_undo_banner.dart';
import '../../qaza/qaza_navigation.dart';
import '../home_controller.dart';
import '../providers/home_providers.dart';
import 'home_skeleton.dart';
import '../home_state.dart';

class HomeTodayProgress extends ConsumerStatefulWidget {
  const HomeTodayProgress({required this.summary});

  final QazaProgressSummary summary;

  @override
  ConsumerState<HomeTodayProgress> createState() =>
      _HomeTodayProgressState();
}

class _HomeTodayProgressState extends ConsumerState<HomeTodayProgress> {
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

  Future<void> _openPrayerTimeSetup() async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PrayerLocationPickerScreen(),
      ),
    );
    if (!mounted) return;
    ref.invalidate(qazaRestrictionEvaluationProvider);
    ref.invalidate(homeCurrentPrayerProvider);
    ref.invalidate(homeFallbackPendingProvider);
  }

  Future<QazaRestrictionEvaluation?> _restrictionForCompletion() async {
    final current = ref.read(qazaRestrictionEvaluationProvider);

    if (current.hasValue) {
      return current.valueOrNull;
    }

    // The button is already rendered while this provider is loading or after
    // a transient lookup failure. Reuse the same provider instead of running
    // a second independent prayer-time lookup on tap.
    if (current.hasError) {
      ref.invalidate(qazaRestrictionEvaluationProvider);
    }

    try {
      return await ref.read(qazaRestrictionEvaluationProvider.future);
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
        DiagnosticArea.qazaCompletion,
        'restriction_lookup_failed',
        error,
        stack: stack,
      );
      // Restriction lookup is advisory when the UI could not resolve one; the
      // completion action remains available in this state.
      return null;
    }
  }

  Future<void> _complete(QazaRecord record, PrayerType prayer) async {
    if (ref.read(qazaCompletionControllerProvider).isWorking) return;

    final userId = ref.read(requiredUserIdProvider);
    final completedAt = ref.read(prayerTimesClockProvider).now();
    final diagnostics = ref.read(diagnosticsProvider);

    QazaCompletionResult result;
    try {
      final restriction = await _restrictionForCompletion();
      result = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: completedAt,
            restriction: restriction,
          );
    } on QazaCompletionRestrictedException catch (error) {
      ref.invalidate(qazaRestrictionEvaluationProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              PrayerTimesStrings.qazaRestricted(
                context,
                error.restriction.type!,
              ),
            ),
          ),
        );
      return;
    } on QazaTartibViolationException catch (error) {
      ref.invalidate(sahibAlTartibProvider);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.qazaTartibBlocked(
                error.requiredPrayer.localizedLabel(l10n),
              ),
            ),
          ),
        );
      return;
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'completion_failed',
        error,
        stack: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).completeFailed),
          ),
        );
      return;
    }

    if (result != QazaCompletionResult.completed) {
      try {
        ref.read(homeControllerProvider).afterStaleCompletion();
      } catch (error, stack) {
        diagnostics.recordFailure(
          DiagnosticArea.qazaCompletion,
          'post_completion_refresh_failed',
          error,
          stack: stack,
        );
      }

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.completeNoPendingTitle +
                  ' ' +
                  l10n.completeNoPendingMessage,
            ),
          ),
        );
      return;
    }

    // Persistence has confirmed the completion. From this point onward,
    // refresh and undo UI failures must never be presented as completion
    // failures.
    try {
      ref.read(homeControllerProvider).afterCompletion(
            pendingBefore:
                widget.summary.byPrayer[prayer]?.progress.pending ?? 0,
          );
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'post_completion_refresh_failed',
        error,
        stack: stack,
      );
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    try {
      await showQazaUndoSnackBar(
        context: context,
        ref: ref,
        userId: userId,
        recordIds: [record.id],
        completedAt: completedAt,
        onUndone: () async {
          ref.read(homeControllerProvider).afterUndo(prayer);
        },
      );
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'undo_ui_failed',
        error,
        stack: stack,
      );
      // Completion succeeded; undo registration is optional recovery UI.
    }
  }

  bool _isManualPrayerAllowed(
    PrayerType prayer,
    AsyncValue<SahibAlTartibState> tartibAsync,
  ) {
    if (prayer == PrayerType.witr) return true;
    final tartib = tartibAsync.valueOrNull;
    if (!tartibAsync.hasValue || tartib == null) return false;
    if (!tartib.requiresOrder) return true;
    return tartib.nextPrayer == prayer;
  }

  PopupMenuItem<String> _buildPrayerMenuItem(
    BuildContext context,
    PrayerType item,
    AsyncValue<SahibAlTartibState> tartibAsync,
    AppLocalizations l10n,
  ) {
    final tartib = tartibAsync.valueOrNull;
    final isWitr = item == PrayerType.witr;
    final loadingOrFailed = !tartibAsync.hasValue;
    final allowed = isWitr ||
        (!loadingOrFailed &&
            (!tartib!.requiresOrder || tartib.nextPrayer == item));
    final explanation = loadingOrFailed
        ? l10n.completeLoadError
        : tartib!.requiresOrder && tartib.nextPrayer != null
            ? l10n.qazaTartibBlocked(
                tartib.nextPrayer!.localizedLabel(l10n),
              )
            : '';

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          !allowed
              ? Icons.lock_outline_rounded
              : widget.selected.prayer == item
                  ? Icons.check_rounded
                  : _prayerIcon(item),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(item.localizedLabel(l10n)),
      ],
    );

    return PopupMenuItem<String>(
      key: Key('home_qaza_prayer_option_' + item.name),
      value: item.name,
      enabled: allowed,
      child: !allowed && explanation.isNotEmpty
          ? Tooltip(message: explanation, child: child)
          : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final working = ref.watch(qazaCompletionControllerProvider).isWorking;
    final daily = ref.watch(homeDailyProgressProvider);
    final selected = ref.watch(homeSelectedPrayerProvider);
    final today = ref.watch(homeLocalDateProvider);

    ref.listen<AsyncValue<HomeDailyProgress>>(
      homeDailyProgressProvider,
      (previous, next) {
        if (!next.hasError || next.error == previous?.error) return;
        ref.read(diagnosticsProvider).recordFailure(
          DiagnosticArea.uncaught,
          'home_daily_progress_failed',
          next.error!,
          stack: next.stackTrace,
        );
      },
    );

    final dateLabel = DateFormatters.weekdayShortNames[today.weekday - 1] +
        ', ' +
        DateFormatters.formatGregorianDatePadded(today);

    return AppCard(
      key: const Key('home_today_progress'),
      padding: const EdgeInsets.all(16),
      child: daily.when(
        loading: () => const HomeTodayProgressSkeleton(),
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
                    onSetupPrayerTimes: _openPrayerTimeSetup,
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
              if (widget.summary.overall.pending > 0) ...[
                const SizedBox(height: 16),
                _EstimatedCompletion(
                  date: homeEstimatedCompletionDate(
                    now: today,
                    pending: widget.summary.overall.pending,
                    dailyTarget: progress.target,
                    completedToday: progress.completed,
                  ),
                  dailyTarget: progress.target,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EstimatedCompletion extends StatelessWidget {
  const _EstimatedCompletion({
    required this.date,
    required this.dailyTarget,
  });

  final DateTime date;
  final int dailyTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('home_estimated_completion'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeEstimatedCompletion(
                    DateFormatters.formatGregorianDatePadded(date),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.homeDailyTarget + ': ' + l10n.homePerDay(dailyTarget),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
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

class _NextQazaPanel extends ConsumerStatefulWidget {
  const _NextQazaPanel({
    required this.summary,
    required this.selected,
    required this.working,
    required this.onComplete,
    required this.onPlan,
    required this.onSetupPrayerTimes,
  });

  final QazaProgressSummary summary;
  final HomeSelectedPrayerState selected;
  final bool working;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;
  final Future<void> Function() onSetupPrayerTimes;

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
      if (end != null &&
          !ref.read(prayerTimesClockProvider).now().isBefore(end)) {
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
        : end.difference(ref.read(prayerTimesClockProvider).now());
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

    ref.listen<AsyncValue<QazaRestrictionEvaluation>>(
      qazaRestrictionEvaluationProvider,
      (previous, next) {
        if (!next.hasError || next.error == previous?.error) return;
        ref.read(diagnosticsProvider).recordFailure(
          DiagnosticArea.uncaught,
          'home_restriction_evaluation_failed',
          next.error!,
          stack: next.stackTrace,
        );
      },
    );
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
    final tartibAsync = ref.watch(sahibAlTartibProvider);

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
          _buildPrayerMenuItem(
            context,
            item,
            tartibAsync,
            l10n,
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

    final tartib = tartibAsync.valueOrNull;
    final automaticTartib =
        widget.selected.mode == HomePrayerSelectionMode.automatic &&
        tartib?.requiresOrder == true &&
        tartib?.nextPrayer != null;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          automaticTartib
              ? l10n.homeNextQaza
              : widget.selected.mode == HomePrayerSelectionMode.automatic
                  ? (prayer == null
                      ? l10n.homeNextQaza
                      : l10n.homeNextQazaCurrentPrayer)
                  : l10n.homeNextQaza,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (widget.selected.mode == HomePrayerSelectionMode.automatic &&
            widget.selected.currentPrayer != null)
          Text(
            l10n.homeNextQazaCurrentPrayer +
                ': ' +
                widget.selected.currentPrayer!.localizedLabel(l10n),
            key: const Key('home_current_prayer'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
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
          Consumer(
            builder: (context, ref, _) {
              final fallback = ref.watch(homeFallbackPendingProvider);
              return fallback.when(
                loading: () => const HomeNextQazaSkeleton(),
                error: (_, __) => ErrorState(
                  key: const Key('home_oldest_qaza_error'),
                  message: l10n.completeLoadError,
                  onRetry: () => ref.invalidate(homeFallbackPendingProvider),
                ),
                data: (record) {
                  if (record == null) {
                    return Text(
                      l10n.completeNoPendingTitle,
                      key: const Key('home_oldest_qaza_empty'),
                    );
                  }
                  return _HomeFallbackNextQaza(
                    record: record,
                    onComplete: widget.onComplete,
                    onPlan: widget.onPlan,
                    onSetupPrayerTimes: widget.onSetupPrayerTimes,
                  );
                },
              );
            },
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(oldestPendingProvider(prayer));
              return state.when(
                loading: () => const HomeNextQazaSkeleton(),
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
                        onPressed: widget.working ||
                                (widget.selected.mode ==
                                        HomePrayerSelectionMode.manual &&
                                    !_isManualPrayerAllowed(
                                      prayer,
                                      tartibAsync,
                                    ))
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

class _HomeFallbackNextQaza extends StatelessWidget {
  const _HomeFallbackNextQaza({
    required this.record,
    required this.onComplete,
    required this.onPlan,
    required this.onSetupPrayerTimes,
  });

  final QazaRecord record;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;
  final Future<void> Function() onSetupPrayerTimes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('home_qaza_prayer_time_setup'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PrayerTimesStrings.setupRequired(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('home_setup_prayer_times'),
                      onPressed: onSetupPrayerTimes,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: Text(PrayerTimesStrings.setupAction(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
              child: Icon(_prayerIcon(record.prayerType)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.prayerType.localizedLabel(l10n),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormatters.formatGregorianDatePadded(record.originalDate),
                    key: const Key('home_oldest_qaza_date'),
                  ),
                  Text(
                    DateFormatters.hijriLabel(record.originalDate),
                    key: const Key('home_oldest_qaza_date_hijri'),
                    style: theme.textTheme.bodySmall,
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
                onPressed: () => onComplete(record, record.prayerType),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.homeCompleteQaza),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('home_qaza_plan_button'),
              onPressed: onPlan,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(l10n.homeQazaPlan),
            ),
          ],
        ),
      ],
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
