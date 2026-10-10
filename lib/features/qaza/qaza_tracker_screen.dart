import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prayer_time/application/prayer_time_providers.dart';
import '../prayer_time/presentation/prayer_timeline_row.dart';

import '../../app/providers.dart';
import '../../core/calendar/hijri_date_service.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_messages.dart';
import '../../core/time/local_date_service.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'qaza_tracker_controller.dart';
import 'qaza_undo_feedback.dart';
import 'qaza_navigation.dart';

/// The canonical Qaza workspace: progress, bounded paging, status/prayer/date
/// filters, and bulk completion. The full ledger is never loaded.
class QazaTrackerScreen extends ConsumerWidget {
  const QazaTrackerScreen({super.key, this.additionId});

  final String? additionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qazaTrackerControllerProvider(additionId));
    final controller =
        ref.read(qazaTrackerControllerProvider(additionId).notifier);
    final l10n = AppLocalizations.of(context);
    final title = state.selectionMode
        ? l10n.qazaSelectedCount(state.selected.length)
        : l10n.qazaTitle;

    return PopScope(
      canPop: !state.selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.selectionMode) {
          controller.exitSelectionMode();
        }
      },
      child: AppScaffold(
        title: title,
        actions: [
          if (!state.selectionMode && state.additionId == null)
            IconButton(
              tooltip: l10n.qazaTrackerHistoryTooltip,
              onPressed: () => openQazaAdditionHistory(context),
              icon: const Icon(Icons.history_rounded),
            ),
          if (state.selectionMode)
            IconButton(
              key: const Key('qaza_tracker_exit_selection'),
              tooltip: l10n.commonClose,
              onPressed: controller.exitSelectionMode,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        floatingActionButton: state.selectionMode ? null : const AddQazaFab(),
        body: SafeArea(
          child: Column(
            children: [
              _QazaTrackerHeader(
                selectionMode: state.selectionMode,
                statusFilter: state.statusFilter,
                controller: controller,
              ),
              Expanded(
                child: _TrackerContent(
                  state: state,
                  controller: controller,
                  additionId: state.additionId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stable header slot above the Qaza workspace content.
class _QazaTrackerHeader extends StatelessWidget {
  const _QazaTrackerHeader({
    required this.selectionMode,
    required this.statusFilter,
    required this.controller,
  });

  static const double _headerContentHeight = kTextTabBarHeight;

  final bool selectionMode;
  final QazaStatusFilter statusFilter;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _headerContentHeight,
          child: selectionMode
              ? const _SelectionContextHeader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<QazaStatusFilter>(
                    key: const Key('qaza_status_switch'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: QazaStatusFilter.pending,
                        label: Text(l10n.statusPending),
                      ),
                      ButtonSegment(
                        value: QazaStatusFilter.completed,
                        label: Text(l10n.statusCompleted),
                      ),
                    ],
                    selected: {statusFilter},
                    onSelectionChanged: (value) {
                      if (value.isNotEmpty) {
                        controller.setStatusFilter(value.first);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SelectionContextHeader extends StatelessWidget {
  const _SelectionContextHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.addQazaSelectionLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Aggregate progress. Reads the database summary, never the record list.
class _ProgressHeader extends ConsumerWidget {
  const _ProgressHeader({this.additionId});

  static const double _headerHeight = 84;

  final String? additionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = additionId != null
        ? ref.watch(qazaAdditionDetailProvider(additionId!)).when(
              loading: () => _buildLoading(context),
              error: (_, __) => const SizedBox.shrink(),
              data: (detail) {
                if (detail == null) return const SizedBox.shrink();
                final total = detail.pendingCount + detail.completedCount;
                final percentage =
                    total == 0 ? 0.0 : detail.completedCount / total;
                return _buildProgress(
                  context,
                  label: l10n.qazaTrackerAdditionProgress,
                  percentage: percentage,
                  completed: detail.completedCount,
                  pending: detail.pendingCount,
                );
              },
            )
        : ref.watch(progressSummaryProvider).when(
              loading: () => _buildLoading(context),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => _buildProgress(
                context,
                label: AppLocalizations.of(context).qazaProgressLabel,
                percentage: summary.overall.percentage,
                completed: summary.overall.completed,
                pending: summary.overall.pending,
              ),
            );

    return SizedBox(
      key: const Key('qaza_tracker_progress_header'),
      height: _headerHeight,
      child: content,
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: const LinearProgressIndicator(minHeight: 3),
        ),
      ),
    );
  }

  Widget _buildProgress(
    BuildContext context, {
    required String label,
    required double percentage,
    required int completed,
    required int pending,
  }) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        key: const Key('qaza_tracker_progress'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '${(percentage * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(value: percentage),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.progressCompletedPending(
              DateFormatters.formatCount(completed),
              DateFormatters.formatCount(pending),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerContent extends StatelessWidget {
  const _TrackerContent({
    required this.state,
    required this.controller,
    this.additionId,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;
  final String? additionId;

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _FilterSheet(additionId: state.additionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressHeader(additionId: additionId),
        _FilterSortBar(
          state: state,
          controller: controller,
          onFilterTap: () => _openFilters(context),
        ),
        Expanded(
          child: state.statusFilter == QazaStatusFilter.completed
              ? _CompletedTrackerBody(state: state, controller: controller)
              : _PendingTrackerBody(state: state, controller: controller),
        ),
      ],
    );
  }
}

class _PendingTrackerBody extends ConsumerWidget {
  const _PendingTrackerBody({
    required this.state,
    required this.controller,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<bool> _completeSingle(
      BuildContext context, WidgetRef ref, QazaRecord record) async {
    final batch = await controller.completeRecordWithUndo(record.id);
    if (!context.mounted) return false;
    if (batch != null) {
      await showQazaUndoFeedback(
        context: context,
        ref: ref,
        userId: ref.read(requiredUserIdProvider),
        entries: batch.entries,
        onUndone: controller.refresh,
      );
      return true;
    }
    return false;
  }

  Future<void> _openDetails(
    BuildContext context,
    WidgetRef ref,
    QazaRecord record, {
    required bool canComplete,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _PendingRecordDetails(
        record: record,
        canComplete: canComplete,
        onComplete: canComplete
            ? () async {
                Navigator.of(sheetContext).pop();
                await _completeSingle(context, ref, record);
              }
            : null,
      ),
    );
  }

  Future<void> _completeSelected(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final count = state.selected.length;
    if (count == 0 || state.completing) return;

    if (state.selectionNeedsConfirmation) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.qazaConfirmBulkTitle('$count'),
        message: l10n.qazaConfirmBulkMessage('$count'),
        confirmLabel: l10n.qazaConfirmBulkAction,
      );
      if (!confirmed || !context.mounted) return;
    }

    // This context belongs to the stable Pending workspace body. The
    // transient bulk-action bar may disappear when completion clears
    // selection mode, so Undo feedback must not depend on that child context.
    final feedbackContext = context;
    final batch = await controller.completeSelectedWithUndo();

    if (!feedbackContext.mounted) return;
    if (batch == null) return;

    await showQazaUndoFeedback(
      context: feedbackContext,
      ref: ref,
      userId: ref.read(requiredUserIdProvider),
      entries: batch.entries,
      onUndone: controller.refresh,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final restricted = ref.watch(qazaCompletionRestrictedProvider);

    if (state.loading && state.records.isEmpty) {
      return const _TrackerSkeleton();
    }
    if (state.error != null) {
      final failure = AppError.from(state.error!);
      return ErrorState(
        key: const Key('qaza_tracker_error'),
        message: failure.message(context),
        onRetry: failure.isRetryable ? controller.refresh : null,
      );
    }
    if (state.records.isEmpty) {
      return state.isFiltered
          ? EmptyState(
              key: const Key('qaza_tracker_filtered_empty'),
              title: l10n.qazaFilteredEmptyTitle,
              message: l10n.qazaFilteredEmptyMessage,
              child: TextButton(
                onPressed: controller.clearFilters,
                child: Text(l10n.qazaResetFilters),
              ),
            )
          : EmptyState(
              key: const Key('qaza_tracker_empty'),
              title: l10n.qazaEmptyTitle,
              message: l10n.qazaEmptyMessage,
            );
    }

    return Column(
      children: [
        if (restricted)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: RestrictedTimeTimelineRow(
              onTap: () => openPrayerTime(ref),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 320) {
                  controller.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                key: const Key('qaza_tracker_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.fabClearance,
                ),
                itemCount: state.records.length + (state.loadingMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index >= state.records.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          _TrackerSkeletonRow(),
                          _TrackerSkeletonRow(),
                        ],
                      ),
                    );
                  }
                  final record = state.records[index];
                  final canAct =
                      record.status == QazaStatus.pending && !restricted;
                  return _RecordRow(
                    key: Key('qaza_record_row_${record.id}'),
                    record: record,
                    selected: state.selected.contains(record.id),
                    selectionMode: state.selectionMode,
                    busy: state.completing || state.recordMutating,
                    canAct: canAct,
                    onTap: state.selectionMode
                        ? (record.status == QazaStatus.pending && !restricted
                            ? () => controller.toggleSelection(record.id)
                            : null)
                        : () => _openDetails(
                              context,
                              ref,
                              record,
                              canComplete: canAct &&
                                  !state.completing &&
                                  !state.recordMutating,
                            ),
                    onLongPress:
                        record.status == QazaStatus.pending && !restricted
                            ? () => controller.enterSelectionMode(record.id)
                            : null,
                    onSwipeComplete: state.selectionMode ||
                            record.status != QazaStatus.pending ||
                            !canAct ||
                            state.completing ||
                            state.recordMutating
                        ? null
                        : () => _completeSingle(context, ref, record),
                  );
                },
              ),
            ),
          ),
        ),
        if (state.selected.isNotEmpty)
          _BulkCompletionBar(
            selectedCount: state.selected.length,
            busy: state.completing || state.recordMutating,
            restricted: restricted,
            onComplete: () => _completeSelected(context, ref),
            onClear: controller.exitSelectionMode,
          ),
      ],
    );
  }
}

class _TrackerSkeleton extends StatelessWidget {
  const _TrackerSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('qaza_tracker_loading_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.fabClearance,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _TrackerSkeletonRow(),
    );
  }
}

class _TrackerSkeletonRow extends StatelessWidget {
  const _TrackerSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SkeletonCircle(size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 120, height: 16),
                  SizedBox(height: 8),
                  SkeletonText(width: 180, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonText(
                width: 64,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(999))),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    super.key,
    required this.record,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.busy,
    required this.canAct,
    this.onSwipeComplete,
  });

  static const double _rowHeight = 68;
  static const double _selectionControlWidth = 48;

  final QazaRecord record;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool busy;
  final bool canAct;
  final Future<bool> Function()? onSwipeComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final originalDate =
        DateFormatters.formatGregorianDatePadded(record.originalDate);
    final hijriDate = l10n.formatHijriDate(record.originalDate);
    final selectable =
        record.status == QazaStatus.pending && onTap != null && !busy;

    final tile = Semantics(
      selected: selected,
      button: onTap != null,
      enabled: onTap != null,
      label:
          '${record.prayerType.localizedLabel(l10n)}, $originalDate, $hijriDate',
      hint: record.status == QazaStatus.pending
          ? (selectionMode
              ? l10n.qazaTrackerSelectionHint
              : l10n.qazaTrackerSwipeHint)
          : null,
      child: SizedBox(
        height: _rowHeight,
        child: ListTile(
          key: Key('qaza_record_${record.id}'),
          leading: Icon(
            Icons.pending_actions_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          minVerticalPadding: 8,
          title: Text(
            record.prayerType.localizedLabel(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '$originalDate · $hijriDate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          trailing: SizedBox(
            width: _selectionControlWidth,
            height: _selectionControlWidth,
            child: selectionMode && record.status == QazaStatus.pending
                ? Checkbox(
                    value: selected,
                    onChanged: selectable ? (_) => onTap!() : null,
                  )
                : canAct
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.lock_clock_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );

    final canSwipe = !selectionMode &&
        record.status == QazaStatus.pending &&
        canAct &&
        !busy &&
        onSwipeComplete != null;

    if (!canSwipe) return tile;

    return Dismissible(
      key: Key('qaza_record_swipe_${record.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.32,
        DismissDirection.endToStart: 0.32,
      },
      resizeDuration: const Duration(milliseconds: 120),
      background: const _CompletionSwipeBackground(
        alignment: AlignmentDirectional.centerStart,
      ),
      secondaryBackground: const _CompletionSwipeBackground(
        alignment: AlignmentDirectional.centerEnd,
      ),
      confirmDismiss: (_) => onSwipeComplete!(),
      child: tile,
    );
  }
}

class _PendingRecordDetails extends StatelessWidget {
  const _PendingRecordDetails({
    required this.record,
    required this.canComplete,
    required this.onComplete,
  });

  final QazaRecord record;
  final bool canComplete;
  final Future<void> Function()? onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.prayerType.localizedLabel(l10n),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('qaza_pending_details_close'),
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.qazaOriginalDateLabel,
            style: theme.textTheme.labelMedium,
          ),
          Text(
            DateFormatters.formatGregorianDatePadded(record.originalDate),
          ),
          Text(l10n.formatHijriDate(record.originalDate)),
          const SizedBox(height: 12),
          Text(
            l10n.statusPending,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canComplete && onComplete != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('qaza_pending_mark_completed'),
                onPressed: () => onComplete!(),
                child: Text(l10n.qazaCompleteCount(1)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionSwipeBackground extends StatelessWidget {
  const _CompletionSwipeBackground({required this.alignment});

  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            l10n.qazaCompleteCount(1),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTrackerBody extends StatelessWidget {
  const _CompletedTrackerBody({
    required this.state,
    required this.controller,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _openDetails(
    BuildContext context,
    QazaRecord record,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _CompletedRecordDetails(
        record: record,
        controller: controller,
      ),
    );
  }

  Future<void> _markSelectedPending(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final count = state.selected.length;
    if (count == 0 || state.recordMutating) return;

    final confirmed = await confirmDestructive(
      context,
      title: l10n.qazaMarkSelectedPendingTitle,
      message: l10n.qazaMarkSelectedPendingMessage(count),
      confirmLabel: l10n.qazaMarkAsPending,
    );
    if (!confirmed || !context.mounted) return;

    final changed = await controller.markSelectedCompletedAsPending();
    if (!context.mounted) return;

    if (changed > 0) {
      ref.read(appSnackbarServiceProvider).success(
            l10n.qazaReturnedToPending,
          );
    } else {
      ref.read(appSnackbarServiceProvider).info(
            l10n.qazaSelectedPendingNothingChanged,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.loading && state.records.isEmpty) {
      return const _TrackerSkeleton();
    }
    if (state.error != null) {
      final failure = AppError.from(state.error!);
      return ErrorState(
        key: const Key('qaza_completed_error'),
        message: failure.message(context),
        onRetry: failure.isRetryable ? controller.refresh : null,
      );
    }
    if (state.records.isEmpty) {
      return state.isFiltered
          ? EmptyState(
              key: const Key('qaza_completed_filtered_empty'),
              title: l10n.qazaFilteredEmptyTitle,
              message: l10n.qazaFilteredEmptyMessage,
              child: TextButton(
                onPressed: controller.clearFilters,
                child: Text(l10n.qazaResetFilters),
              ),
            )
          : EmptyState(
              key: const Key('qaza_completed_empty'),
              title: l10n.qazaNoCompletedTitle,
              message: l10n.qazaNoCompletedMessage,
            );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 320) {
                  controller.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                key: const Key('qaza_completed_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.fabClearance + 96,
                ),
                itemCount: state.records.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.records.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final record = state.records[index];
                  final completedAt = record.completedAt;
                  if (completedAt == null) return const SizedBox.shrink();

                  final selecting =
                      state.selectionScope == QazaSelectionScope.completed;
                  return _CompletedRecordRow(
                    record: record,
                    selected: state.selected.contains(record.id),
                    selectionMode: selecting,
                    onTap: selecting
                        ? () => controller.toggleCompletedSelection(record.id)
                        : () => _openDetails(context, record),
                    onLongPress: () =>
                        controller.enterCompletedSelectionMode(record.id),
                  );
                },
              ),
            ),
          ),
        ),
        if (state.selectionScope == QazaSelectionScope.completed &&
            state.selected.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CompletedBatchActionBar(
              selectedCount: state.selected.length,
              busy: state.recordMutating,
              onMarkPending: (ref) => _markSelectedPending(context, ref),
              onClear: controller.exitSelectionMode,
            ),
          ),
      ],
    );
  }
}

class _CompletedRecordRow extends StatelessWidget {
  const _CompletedRecordRow({
    required this.record,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final QazaRecord record;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String _completionDateLabel(
    BuildContext context,
    DateTime completedAt,
  ) {
    final l10n = AppLocalizations.of(context);
    final date = completedAt.toLocal();
    final today = LocalDateService.today();

    if (LocalDateService.compareCalendarDates(date, today) == 0) {
      return l10n.commonToday;
    }

    final yesterday = LocalDateService.addCalendarDays(today, -1);
    if (LocalDateService.compareCalendarDates(date, yesterday) == 0) {
      return l10n.commonYesterday;
    }

    return DateFormatters.formatGregorianDatePadded(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completedAt = record.completedAt!.toLocal();
    final completionDate = _completionDateLabel(context, completedAt);
    final completionTime = DateFormatters.formatClockTime(completedAt);
    final originalDate =
        DateFormatters.formatGregorianDatePadded(record.originalDate);
    final hijriDate = l10n.formatHijriDate(record.originalDate);

    final semanticLabel = '${record.prayerType.localizedLabel(l10n)}, '
        '$completionDate, $completionTime, '
        '$originalDate, $hijriDate';

    return Semantics(
      selected: selected,
      button: false,
      label: semanticLabel,
      child: ListTile(
        key: Key('qaza_completed_record_${record.id}'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        minVerticalPadding: 4,
        leading: Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          record.prayerType.localizedLabel(l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$originalDate · $hijriDate',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  completionDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completionTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (selectionMode) ...[
              const SizedBox(width: 8),
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
              ),
            ],
          ],
        ),
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _CompletedBatchActionBar extends ConsumerWidget {
  const _CompletedBatchActionBar({
    required this.selectedCount,
    required this.busy,
    required this.onMarkPending,
    required this.onClear,
  });

  final int selectedCount;
  final bool busy;
  final Future<void> Function(WidgetRef ref) onMarkPending;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      key: const Key('qaza_completed_batch_action_bar'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              TextButton(
                key: const Key('qaza_completed_clear_selection'),
                onPressed: busy ? null : onClear,
                child: Text(AppLocalizations.of(context).commonClear),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('qaza_completed_mark_pending'),
                  onPressed: busy ? null : () => onMarkPending(ref),
                  child: Text(
                    AppLocalizations.of(context).qazaMarkAsPendingCount(
                      selectedCount,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedRecordDetails extends ConsumerWidget {
  const _CompletedRecordDetails({
    required this.record,
    required this.controller,
  });

  final QazaRecord record;
  final QazaTrackerController controller;

  Future<void> _markPending(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.qazaMarkAsPending,
      message: l10n.qazaMarkAsPendingMessage,
      confirmLabel: l10n.qazaMarkAsPending,
    );
    if (!confirmed || !context.mounted) return;

    final changed = await controller.markCompletedAsPending(record.id);
    if (!context.mounted) return;
    if (!changed) {
      ref.read(appSnackbarServiceProvider).error(
            l10n.qazaCorrectionChanged,
          );
      return;
    }

    Navigator.of(context).pop();
    ref.read(appSnackbarServiceProvider).success(
          l10n.qazaReturnedToPending,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completedAt = record.completedAt?.toLocal();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.prayerType.localizedLabel(l10n),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.qazaOriginalDateLabel, style: theme.textTheme.labelMedium),
          Text(DateFormatters.formatGregorianDatePadded(record.originalDate)),
          Text(l10n.formatHijriDate(record.originalDate)),
          const SizedBox(height: 12),
          if (completedAt != null) ...[
            Text(l10n.statusCompleted, style: theme.textTheme.labelMedium),
            Text(
              '${DateFormatters.formatGregorianDatePadded(completedAt)} · ${DateFormatters.formatClockTime(completedAt)}',
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _markPending(context, ref),
              child: Text(l10n.qazaMarkAsPending),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared Material 3 filter + sorting control for both tracker workspaces.
///
/// Pending is ordered by Qaza date ([QazaRecord.originalDate]); Completed is
/// ordered by completion timestamp ([QazaRecord.completedAt]). The same
/// controller/state is reused for both workspaces.
class _FilterSortBar extends StatelessWidget {
  const _FilterSortBar({
    required this.state,
    required this.controller,
    required this.onFilterTap,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: OutlinedButton.icon(
              key: const Key('qaza_tracker_filter_button'),
              onPressed: onFilterTap,
              icon: const Icon(Icons.filter_list_rounded),
              label: Text(
                state.isFiltered ? 'Filters active' : 'Filter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            fit: FlexFit.loose,
            child: SegmentedButton<QazaSortOrder>(
              key: const Key('qaza_tracker_sort'),
              showSelectedIcon: false,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(
                  Size(0, 40),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: 0,
                ),
                textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
              ),
              segments: [
                ButtonSegment(
                  value: QazaSortOrder.oldestFirst,
                  label: Text(
                    l10n.qazaSortOldestFirst,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                ButtonSegment(
                  value: QazaSortOrder.newestFirst,
                  label: Text(
                    l10n.qazaSortNewestFirst,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
              selected: {state.sortOrder},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                controller.setSortOrder(value.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({this.additionId});

  final String? additionId;

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final state = ref.read(qazaTrackerControllerProvider(additionId));
    final controller =
        ref.read(qazaTrackerControllerProvider(additionId).notifier);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: state.from != null && state.to != null
          ? DateTimeRange(start: state.from!, end: state.to!)
          : null,
      helpText: AppLocalizations.of(context).qazaDateFilterHelp,
    );
    if (picked != null) {
      controller.setDateRange(picked.start, picked.end);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qazaTrackerControllerProvider(additionId));
    final controller =
        ref.read(qazaTrackerControllerProvider(additionId).notifier);
    final enabledPrayers = ref.watch(enabledPrayerTypesProvider);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const Text(
            'Prayer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.filterAll),
                selected: state.prayerFilter == null,
                onSelected: (_) => controller.setPrayerFilter(null),
              ),
              for (final prayer in enabledPrayers)
                FilterChip(
                  label: Text(prayer.localizedLabel(l10n)),
                  selected: state.prayerFilter == prayer,
                  onSelected: (selected) =>
                      controller.setPrayerFilter(selected ? prayer : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            state.statusFilter == QazaStatusFilter.completed
                ? l10n.qazaCompletedDateLabel
                : l10n.qazaOriginalDateLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickRange(context, ref),
            icon: const Icon(Icons.event_rounded),
            label: Text(
              state.hasDateFilter
                  ? l10n.qazaDateFilterRange(
                      DateFormatters.formatGregorianDatePadded(state.from!),
                      DateFormatters.formatGregorianDatePadded(state.to!),
                    )
                  : l10n.qazaDateFilterAny,
            ),
          ),
          if (state.isFiltered)
            TextButton(
              onPressed: () {
                controller.clearFilters();
                Navigator.of(context).pop();
              },
              child: Text(l10n.commonReset),
            ),
        ],
      ),
    );
  }
}

class _BulkCompletionBar extends StatelessWidget {
  const _BulkCompletionBar({
    required this.selectedCount,
    required this.busy,
    required this.restricted,
    required this.onComplete,
    required this.onClear,
  });

  final int selectedCount;
  final bool busy;
  final bool restricted;
  final VoidCallback onComplete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              TextButton(
                key: const Key('qaza_tracker_clear_selection'),
                onPressed: busy ? null : onClear,
                child: Text(l10n.commonClear),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('qaza_tracker_complete_selected'),
                  onPressed: busy || restricted || selectedCount == 0
                      ? null
                      : onComplete,
                  child: Text(l10n.qazaCompleteCount(selectedCount)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
