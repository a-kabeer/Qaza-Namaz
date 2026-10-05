import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/progress_widgets.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../qaza/completion/qaza_completion_controller.dart';
import '../../prayer_time/application/prayer_time_providers.dart';
import '../../prayer_time/presentation/prayer_timeline_row.dart';
import '../../qaza/qaza_undo_feedback.dart';
import '../../qaza/qaza_navigation.dart';
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
  Future<void> _complete(
    QazaRecord record,
    PrayerType prayer,
    HomePrayerSelectionSource selectionSource,
  ) async {
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
        selectionSource: selectionSource,
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

      if (!mounted) return;

      await showQazaUndoFeedback(
        context: context,
        ref: ref,
        userId: userId,
        entries: [
          QazaCompletionEntry(
            recordId: record.id,
            completionId: completionId,
            prayerType: record.prayerType,
            originalDate: record.originalDate,
            completedAt: completedAt,
          ),
        ],
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('home_today_progress_tap_target'),
        onTap: () => openQazaCompleted(ref),
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
    final daily = ref.watch(homeDashboardActivityProvider);
    final today = ref.watch(homeLocalDateProvider);

    ref.listen<AsyncValue<HomeDashboardActivity>>(
      homeDashboardActivityProvider,
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
            onPressed: () => ref.invalidate(homeDashboardActivityProvider),
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
      data: (dashboard) {
        final progress = dashboard.dailyProgress;
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
  final Future<void> Function(
    QazaRecord record,
    PrayerType prayer,
    HomePrayerSelectionSource selectionSource,
  ) onComplete;

  @override
  ConsumerState<_NextQazaPanel> createState() => _NextQazaPanelState();
}

/// Prayer target is driven by the selected Home completion mode.
class _NextQazaPanelState extends ConsumerState<_NextQazaPanel> {
  QazaRecord? _cachedRecord;
  PrayerType? _cachedPrayer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(homePrayerSelectionProvider);
    final restricted = ref.watch(qazaCompletionRestrictedProvider);
    final isAutoSequence =
        selection.mode == HomePrayerSelectionMode.autoSequence;
    final prayer = isAutoSequence ? null : widget.selected.prayer;

    if (!isAutoSequence && _cachedPrayer != null && _cachedPrayer != prayer) {
      _cachedRecord = null;
      _cachedPrayer = null;
    }

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

    final header = Text(
      l10n.homeNextQaza,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
        if (prayer == null && !isAutoSequence)
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
              final AsyncValue<QazaRecord?> state = isAutoSequence
                  ? ref.watch(homeFallbackPendingProvider)
                  : ref.watch(oldestPendingProvider(prayer!));

              return state.when(
                loading: () {
                  // Auto Sequence must never render a stale completed/previous
                  // record while the chronological ledger is being refreshed.
                  if (!isAutoSequence) {
                    final cached = _cachedRecord;
                    final cachedPrayer = _cachedPrayer;
                    if (cached != null && cachedPrayer != null) {
                      return _HomeNextQazaRecord(
                        record: cached,
                        prayer: cachedPrayer,
                        restricted: restricted,
                        completionWorking: widget.working,
                        refreshing: true,
                        onComplete: widget.onComplete,
                        selectionSource: widget.selected.source,
                      );
                    }
                  }
                  return const HomeNextQazaSkeleton();
                },
                error: (_, __) => ErrorState(
                  key: const Key('home_oldest_qaza_error'),
                  message: l10n.completeLoadError,
                  onRetry: () => ref.invalidate(
                    isAutoSequence
                        ? homeFallbackPendingProvider
                        : oldestPendingProvider(prayer!),
                  ),
                ),
                data: (record) {
                  if (record == null) {
                    _cachedRecord = null;
                    _cachedPrayer = null;
                    return Text(
                      l10n.completeNoPendingTitle,
                      key: const Key('home_oldest_qaza_empty'),
                    );
                  }

                  final targetPrayer = record.prayerType;
                  _cachedRecord = record;
                  _cachedPrayer = targetPrayer;
                  return _HomeNextQazaRecord(
                    record: record,
                    prayer: targetPrayer,
                    restricted: restricted,
                    completionWorking: widget.working,
                    refreshing: state.isLoading || state.isRefreshing,
                    onComplete: widget.onComplete,
                    selectionSource: widget.selected.source,
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _HomeNextQazaRecord extends StatelessWidget {
  const _HomeNextQazaRecord({
    required this.record,
    required this.prayer,
    required this.restricted,
    required this.completionWorking,
    required this.refreshing,
    required this.onComplete,
    required this.selectionSource,
  });

  final QazaRecord record;
  final PrayerType prayer;
  final bool restricted;
  final bool completionWorking;
  final bool refreshing;
  final Future<void> Function(
    QazaRecord record,
    PrayerType prayer,
    HomePrayerSelectionSource selectionSource,
  ) onComplete;
  final HomePrayerSelectionSource selectionSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final completeEnabled = !restricted &&
            !completionWorking &&
            !refreshing;

        final complete = SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('home_complete_oldest_qaza'),
            onPressed: completeEnabled
                ? () => onComplete(record, prayer, selectionSource)
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              completionWorking
                  ? l10n.completeInProgress
                  : l10n.homeCompleteQaza,
            ),
          ),
        );

        final details = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
              child: Icon(_prayerIcon(prayer)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.localizedLabel(l10n),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormatters.formatGregorianDatePadded(
                      record.originalDate,
                    ),
                    key: const Key('home_oldest_qaza_date'),
                  ),
                  Text(
                    l10n.formatHijriDate(record.originalDate),
                    key: const Key('home_oldest_qaza_date_hijri'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 8),
                StatusChip(
                  l10n.homeOldestPending,
                  tone: StatusChipTone.pending,
                ),
              ],
            ),
            const SizedBox(height: 12),
            complete,
          ],
        );
      },
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
