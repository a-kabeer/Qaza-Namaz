import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../../core/widgets/progress_widgets.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/services/qaza_service.dart';
import '../../qaza/completion/qaza_completion_controller.dart';
import '../../qaza/qaza_undo_banner.dart';
import '../home_controller.dart';
import '../providers/home_providers.dart';
import 'home_skeleton.dart';
import '../home_state.dart';

class HomeTodayProgress extends ConsumerStatefulWidget {
  const HomeTodayProgress({super.key, required this.summary});

  final QazaProgressSummary summary;

  @override
  ConsumerState<HomeTodayProgress> createState() => _HomeTodayProgressState();
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

  Future<void> _complete(QazaRecord record, PrayerType prayer) async {
    if (ref.read(qazaCompletionControllerProvider).isWorking) return;

    final userId = ref.read(requiredUserIdProvider);
    final completedAt = DateTime.now();
    final diagnostics = ref.read(diagnosticsProvider);

    QazaCompletionResult result;
    try {
      result = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: completedAt,
          );
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
              '${l10n.completeNoPendingTitle} ${l10n.completeNoPendingMessage}',
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
      final completedRecords =
          await ref.read(qazaServiceProvider).getRecordsByIds(
        userId: userId,
        recordIds: [record.id],
      );
      final completedRecord = completedRecords
          .where(
            (candidate) =>
                candidate.id == record.id &&
                candidate.status == QazaStatus.completed &&
                candidate.completionId != null &&
                candidate.completionId!.isNotEmpty,
          )
          .firstOrNull;

      if (completedRecord == null) {
        throw StateError(
          'Completed Qaza record is missing its completion marker.',
        );
      }

      if (!mounted) return;

      await showQazaUndoSnackBar(
        context: context,
        ref: ref,
        userId: userId,
        records: [completedRecord],
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
                  // Gregorian leads and carries the weekday, month and year,
                  // localized by Material so Urdu reads as Urdu rather than
                  // English month names in an Urdu sentence. The Hijri
                  // reading of the same day sits underneath as secondary.
                  final date = Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MaterialLocalizations.of(context).formatFullDate(today),
                        key: const Key('home_today_date'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        DateFormatters.hijriLabel(today),
                        key: const Key('home_today_date_hijri'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
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
                  '${l10n.homeDailyTarget}: ${l10n.homePerDay(dailyTarget)}',
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
      label: '$percent%, $completed of $target',
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
                  '$percent%',
                  key: const Key('home_today_percent'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  '$completed of $target',
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
  });

  final QazaProgressSummary summary;
  final HomeSelectedPrayerState selected;
  final bool working;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;

  @override
  ConsumerState<_NextQazaPanel> createState() => _NextQazaPanelState();
}

/// Shown while the ordering rule is unknown, in place of any Fard action.
///
/// Two states rather than one, because they call for different things: a
/// check still running is worth waiting for, a failed one is worth retrying.
class _TartibUnavailable extends StatelessWidget {
  const _TartibUnavailable({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: const Key('home_tartib_unavailable'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.lock_clock_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? l10n.homeTartibCheckingTitle
                      : l10n.homeTartibFailedTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? l10n.homeTartibCheckingBody
                      : l10n.homeTartibFailedBody,
                  style: theme.textTheme.bodySmall,
                ),
                if (!loading) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('home_tartib_retry'),
                      onPressed: onRetry,
                      child: Text(l10n.commonRetry),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prayer choice is governed only by Qaza/Sahib al-Tartib rules.
class _NextQazaPanelState extends ConsumerState<_NextQazaPanel> {
  PopupMenuItem<String> _buildPrayerMenuItem(
    BuildContext context,
    PrayerType prayer,
    AsyncValue<SahibAlTartibState> tartibAsync,
    AppLocalizations l10n,
  ) {
    final tartib = tartibAsync.valueOrNull;
    final locked = prayer != PrayerType.witr &&
        (!tartibAsync.hasValue ||
            (tartib?.requiresOrder == true && tartib?.nextPrayer != prayer));
    final selected = widget.selected.mode == HomePrayerSelectionMode.manual &&
        widget.selected.prayer == prayer;

    return PopupMenuItem<String>(
      key: Key('home_qaza_prayer_option_${prayer.name}'),
      value: prayer.name,
      enabled: !locked,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_rounded : _prayerIcon(prayer),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(prayer.localizedLabel(l10n)),
          if (locked) ...[
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline_rounded, size: 16),
          ],
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayer = widget.selected.prayer;
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

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeNextQaza,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (widget.selected.mode == HomePrayerSelectionMode.automatic &&
            widget.selected.source == HomePrayerSelectionSource.sahibAlTartib &&
            widget.selected.prayer != null)
          Text(
            l10n.homeSahibOrderLabel(
              widget.selected.prayer!.localizedLabel(l10n),
            ),
            key: const Key('home_sahib_selection'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
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
        // Until Sahib al-Tartib has resolved, no Fard prayer may be offered.
        // Witr is unaffected and stays reachable from the prayer menu.
        if (widget.selected.source ==
            HomePrayerSelectionSource.tartibUnavailable)
          _TartibUnavailable(
            loading: tartibAsync.isLoading,
            onRetry: () => ref.invalidate(sahibAlTartibProvider),
          )
        else if (prayer == null)
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
                                  DateFormatters.hijriLabel(
                                      record.originalDate),
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
  });

  final QazaRecord record;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    DateFormatters.formatGregorianDatePadded(
                        record.originalDate),
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
