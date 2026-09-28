import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/progress_widgets.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/services/qaza_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../qaza/completion/qaza_completion_controller.dart';
import '../../prayer_time/application/prayer_time_providers.dart';
import '../../prayer_time/presentation/prayer_timeline_row.dart';
import '../../qaza/qaza_undo_feedback.dart';
import '../home_controller.dart';
import '../providers/home_providers.dart';
import 'home_qaza_target_sheet.dart';
import 'home_skeleton.dart';
import '../home_state.dart';

class HomeTodayProgress extends ConsumerStatefulWidget {
  const HomeTodayProgress({super.key, required this.summary});

  final QazaProgressSummary summary;

  @override
  ConsumerState<HomeTodayProgress> createState() => _HomeTodayProgressState();
}

class _HomeTodayProgressState extends ConsumerState<HomeTodayProgress> {
  Future<void> _complete(QazaRecord record, PrayerType prayer) async {
    if (ref.read(qazaCompletionControllerProvider).isWorking) return;

    final userId = ref.read(requiredUserIdProvider);
    final completedAt = DateTime.now();
    final diagnostics = ref.read(diagnosticsProvider);

    QazaCompletionReceipt receipt;
    try {
      receipt = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecordWithReceipt(
            userId: userId,
            recordId: record.id,
            completedAt: completedAt,
          );
    } on QazaTartibViolationException catch (error) {
      ref.invalidate(sahibAlTartibProvider);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ref.read(appSnackbarServiceProvider).warning(
            l10n.qazaTartibBlocked(
              error.requiredPrayer.localizedLabel(l10n),
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
      ref.read(appSnackbarServiceProvider).error(
            AppLocalizations.of(context).completeFailed,
          );
      return;
    }

    final result = receipt.result;

    if (result == QazaCompletionResult.blockedByRestrictedTime) {
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
      ref.read(appSnackbarServiceProvider).info(
            '${l10n.completeNoPendingTitle} ${l10n.completeNoPendingMessage}',
          );
      return;
    }

    // Persistence has confirmed the completion. From this point onward,
    // refresh and undo UI failures must never be presented as completion
    // failures.
    try {
      ref.read(homeControllerProvider).afterCompletion(
        completedPrayer: prayer,
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
      final completionId = receipt.completionId;
      if (completionId == null || completionId.isEmpty) {
        throw StateError(
          'Completed Qaza record is missing its completion marker.',
        );
      }

      final completedRecord = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: completionId,
        updatedAt: completedAt,
      );

      if (!mounted) return;

      await showQazaUndoFeedback(
        context: context,
        ref: ref,
        userId: userId,
        records: [completedRecord],
        onUndone: () async {
          ref.read(homeControllerProvider).afterUndo();
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
    final working = ref.watch(qazaCompletionControllerProvider).isWorking;
    final selected = ref.watch(homeSelectedPrayerProvider);

    return Card(
      key: const Key('home_today_progress'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TodayProgressSection(summary: widget.summary),
            const SizedBox(height: 18),
            _NextQazaPanel(
              summary: widget.summary,
              selected: selected,
              working: working,
              onComplete: _complete,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayProgressSection extends ConsumerWidget {
  const _TodayProgressSection({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daily = ref.watch(homeDailyProgressProvider);
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

    return daily.when(
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
        final percent = (progress.percentage * 100).round();
        final summaryText =
            l10n.homeDailyProgress(progress.completed, progress.target);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.homeTodayProgressHeader,
              key: const Key('home_today_progress_header'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: '$summaryText, $percent%',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: const Key('home_today_progress_bar'),
                  value: progress.percentage,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$summaryText • $percent%',
              key: const Key('home_today_progress_summary'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (summary.overall.pending > 0) ...[
              const SizedBox(height: 12),
              _EstimatedCompletion(
                date: homeEstimatedCompletionDate(
                  now: today,
                  pending: summary.overall.pending,
                  dailyTarget: progress.target,
                  completedToday: progress.completed,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EstimatedCompletion extends StatelessWidget {
  const _EstimatedCompletion({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      key: const Key('home_estimated_completion'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.event_available_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.homeEstimatedCompletion(
              DateFormatters.formatGregorianDatePadded(date),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _NextQazaPanel extends ConsumerStatefulWidget {
  const _NextQazaPanel({
    required this.summary,
    required this.selected,
    required this.working,
    required this.onComplete,
  });

  final QazaProgressSummary summary;
  final HomeSelectedPrayerState selected;
  final bool working;
  final Future<void> Function(QazaRecord record, PrayerType prayer) onComplete;

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

/// Prayer target is driven by the selected Home completion mode, while Sahib al-Tartib remains authoritative.
class _NextQazaPanelState extends ConsumerState<_NextQazaPanel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayer = widget.selected.prayer;
    final tartibAsync = ref.watch(sahibAlTartibProvider);
    final selection = ref.watch(homePrayerSelectionProvider);

    final targetLabel = switch (selection.mode) {
      HomePrayerSelectionMode.prayerTime => l10n.prayerTimeTitle,
      HomePrayerSelectionMode.autoSequence => l10n.homeAutoSequence,
      HomePrayerSelectionMode.prayerSelection =>
        selection.selectedPrayer?.localizedLabel(l10n) ??
            l10n.homePrayerSelection,
    };

    final prayerSelector = ActionChip(
      key: const Key('home_qaza_prayer_selector'),
      tooltip: l10n.homeQazaTarget,
      avatar: Icon(
        switch (selection.mode) {
          HomePrayerSelectionMode.prayerTime => Icons.schedule_outlined,
          HomePrayerSelectionMode.autoSequence => Icons.repeat_rounded,
          HomePrayerSelectionMode.prayerSelection => Icons.touch_app_outlined,
        },
        size: 18,
      ),
      label: Text(targetLabel),
      onPressed: () => showHomeQazaTargetSheet(
        context: context,
      ),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeNextQaza,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (widget.selected.source == HomePrayerSelectionSource.sahibAlTartib &&
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
        const RestrictedTimeTimelineRow(),
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
          Container(
            key: const Key('home_prayer_target_unavailable'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              l10n.homePrayerTimeUnavailable,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final AsyncValue<QazaRecord?> state =
                  widget.selected.source ==
                          HomePrayerSelectionSource.sahibAlTartib
                      ? ref.watch(homeFallbackPendingProvider)
                      : ref.watch(oldestPendingProvider(prayer));
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
                                  l10n.formatHijriDate(
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
                        onPressed: restricted || widget.working
                            ? null
                            : () => widget.onComplete(record, prayer),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          widget.working
                              ? l10n.completeInProgress
                              : l10n.homeCompleteQaza,
                        ),
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
                                        l10n.formatHijriDate(
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
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: 12),
                          complete,
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
