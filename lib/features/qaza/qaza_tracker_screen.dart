import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prayer_time/application/prayer_time_providers.dart';
import '../prayer_time/presentation/prayer_timeline_row.dart';

import '../../app/providers.dart';
import '../../core/calendar/hijri_date_service.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_messages.dart';
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
        ? '${state.selected.length} selected'
        : state.additionId == null
            ? l10n.qazaTitle
            : 'Addition Records';

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
              tooltip: 'Qaza History',
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
        floatingActionButton:
            state.selectionMode ? null : const AddQazaFab(),
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
                    segments: const [
                      ButtonSegment(
                        value: QazaStatusFilter.pending,
                        label: Text('Pending'),
                      ),
                      ButtonSegment(
                        value: QazaStatusFilter.completed,
                        label: Text('Completed'),
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

  final String? additionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (additionId != null) {
      final detailAsync = ref.watch(qazaAdditionDetailProvider(additionId!));
      return detailAsync.when(
        loading: () =>
            const SizedBox(height: 3, child: LinearProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (detail) {
          if (detail == null) return const SizedBox.shrink();
          final total = detail.pendingCount + detail.completedCount;
          final percentage =
              total == 0 ? 0.0 : detail.completedCount / total;
          return _buildProgress(
            context,
            label: 'Addition progress',
            percentage: percentage,
            completed: detail.completedCount,
            pending: detail.pendingCount,
          );
        },
      );
    }

    return ref.watch(progressSummaryProvider).when(
      loading: () =>
          const SizedBox(height: 3, child: LinearProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) => _buildProgress(
        context,
        label: AppLocalizations.of(context).qazaProgressLabel,
        percentage: summary.overall.percentage,
        completed: summary.overall.completed,
        pending: summary.overall.pending,
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
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
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
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        if (state.statusFilter == QazaStatusFilter.completed)
          const _CompletedHeader()
        else
          _ProgressHeader(additionId: additionId),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('qaza_tracker_filter_button'),
              onPressed: () => _openFilters(context),
              icon: const Icon(Icons.filter_list_rounded),
              label: Text(
                state.isFiltered ? 'Filters active' : 'Filter',
              ),
            ),
          ),
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

class _CompletedHeader extends ConsumerWidget {
  const _CompletedHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(progressSummaryProvider).valueOrNull?.overall.completed;
    final count = completed ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Completed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            '${DateFormatters.formatCount(count)} Qaza completed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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
    final l10n = AppLocalizations.of(context);
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
    final tartib = ref.read(sahibAlTartibProvider).valueOrNull;
    if (tartib?.requiresOrder == true && tartib?.nextPrayer != null) {
      ref.read(appSnackbarServiceProvider).warning(
            l10n.qazaTartibBlocked(
              tartib!.nextPrayer!.localizedLabel(l10n),
            ),
          );
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tartib = ref.watch(sahibAlTartibProvider).valueOrNull;
    final restricted = ref.watch(qazaCompletionRestrictedProvider);
    final lockedRecordId =
        tartib?.requiresOrder == true ? tartib?.nextPending?.id : null;

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
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: RestrictedTimeTimelineRow(),
          ),
        if (tartib?.requiresOrder == true && tartib?.nextPrayer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.qazaTartibRequiredMessage(
                  tartib!.pendingFarzCount,
                  tartib.nextPrayer!.localizedLabel(l10n),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                itemCount: state.records.length + (state.hasMore ? 1 : 0),
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
                  final canAct = record.status == QazaStatus.pending &&
                      !restricted &&
                      (lockedRecordId == null ||
                          record.id == lockedRecordId ||
                          record.prayerType == PrayerType.witr);
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
                        : null,
                    onLongPress: record.status == QazaStatus.pending &&
                            !restricted &&
                            (lockedRecordId == null ||
                                record.id == lockedRecordId ||
                                record.prayerType == PrayerType.witr)
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
          _BulkCompletionBar(state: state, controller: controller),
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
      button: false,
      label:
          '${record.prayerType.localizedLabel(l10n)}, $originalDate, $hijriDate',
      hint: record.status == QazaStatus.pending
          ? (selectionMode
              ? 'Tap to select or unselect.'
              : 'Swipe left or right to complete. Long press to select.')
          : null,
      child: SizedBox(
        height: _rowHeight,
        child: ListTile(
          key: Key('qaza_record_${record.id}'),
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
    final count = state.selected.length;
    if (count == 0 || state.recordMutating) return;

    final confirmed = await confirmDestructive(
      context,
      title: 'Mark selected as Pending?',
      message:
          '$count completed Qaza records will return to Pending and will no longer count as completed.',
      confirmLabel: 'Mark as Pending',
    );
    if (!confirmed || !context.mounted) return;

    final changed = await controller.markSelectedCompletedAsPending();
    if (!context.mounted) return;

    if (changed > 0) {
      ref.read(appSnackbarServiceProvider).success(
            '$changed Qaza returned to Pending.',
          );
    } else {
      ref.read(appSnackbarServiceProvider).info(
            'No selected Qaza records were changed.',
          );
    }
  }

  String _groupLabel(DateTime completedAt) {
    final date = completedAt.toLocal();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final dateKey = DateTime(date.year, date.month, date.day);
    if (dateKey == todayKey) return 'Today';
    if (dateKey == todayKey.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormatters.formatGregorianDatePadded(date);
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
          : const EmptyState(
              key: Key('qaza_completed_empty'),
              title: 'No completed Qaza',
              message: 'Completed Qaza will appear here.',
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

                  final showGroup = index == 0 ||
                      state.records[index - 1].completedAt == null ||
                      state.records[index - 1].completedAt!.toLocal().year !=
                          completedAt.toLocal().year ||
                      state.records[index - 1].completedAt!.toLocal().month !=
                          completedAt.toLocal().month ||
                      state.records[index - 1].completedAt!.toLocal().day !=
                          completedAt.toLocal().day;

                  final selecting =
                      state.selectionScope == QazaSelectionScope.completed;
                  return Column(
                    children: [
                      if (showGroup)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            4,
                            index == 0 ? AppSpacing.xs : AppSpacing.md,
                            4,
                            AppSpacing.xs,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _groupLabel(completedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      _CompletedRecordRow(
                        record: record,
                        selected: state.selected.contains(record.id),
                        selectionMode: selecting,
                        onTap: selecting
                            ? () =>
                                controller.toggleCompletedSelection(record.id)
                            : () => _openDetails(context, record),
                        onLongPress: () =>
                            controller.enterCompletedSelectionMode(record.id),
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completedAt = record.completedAt!.toLocal();
    final originalDate =
        DateFormatters.formatGregorianDatePadded(record.originalDate);
    final hijriDate = l10n.formatHijriDate(record.originalDate);

    return ListTile(
      key: Key('qaza_completed_record_${record.id}'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minVerticalPadding: 4,
      leading: Icon(
        Icons.check_circle_rounded,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              record.prayerType.localizedLabel(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormatters.formatClockTime(completedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '$originalDate · $hijriDate',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
            )
          : null,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
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
                child: const Text('Clear'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('qaza_completed_mark_pending'),
                  onPressed: busy ? null : () => onMarkPending(ref),
                  child: Text('Mark as Pending ($selectedCount)'),
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
    final confirmed = await confirmDestructive(
      context,
      title: 'Mark as Pending?',
      message:
          'This Qaza will return to Pending and will no longer count as completed.',
      confirmLabel: 'Mark as Pending',
    );
    if (!confirmed || !context.mounted) return;

    final changed = await controller.markCompletedAsPending(record.id);
    if (!context.mounted) return;
    if (!changed) {
      ref.read(appSnackbarServiceProvider).error(
            'This Qaza could not be corrected because it has changed.',
          );
      return;
    }

    Navigator.of(context).pop();
    ref.read(appSnackbarServiceProvider).success(
          'Qaza returned to Pending.',
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
          Text('Qaza Date', style: theme.textTheme.labelMedium),
          Text(DateFormatters.formatGregorianDatePadded(record.originalDate)),
          Text(l10n.formatHijriDate(record.originalDate)),
          const SizedBox(height: 12),
          if (completedAt != null) ...[
            Text('Completed', style: theme.textTheme.labelMedium),
            Text(
              '${DateFormatters.formatGregorianDatePadded(completedAt)} · ${DateFormatters.formatClockTime(completedAt)}',
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _markPending(context, ref),
              child: const Text('Mark as Pending'),
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
    final controller = ref.read(qazaTrackerControllerProvider(additionId).notifier);
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
    final controller = ref.read(qazaTrackerControllerProvider(additionId).notifier);
    final enabledPrayers = ref.watch(enabledPrayerTypesProvider);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text(
            state.statusFilter == QazaStatusFilter.completed
                ? 'Completed Date'
                : 'Qaza Date',
            style: Theme.of(context).textTheme.titleMedium,
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
                ? 'Completed Date'
                : 'Qaza Date',
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


class _BulkCompletionBar extends ConsumerWidget {
  const _BulkCompletionBar({
    required this.state,
    required this.controller,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
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

    final batch = await controller.completeSelectedWithUndo();
    if (!context.mounted) return;
    if (batch == null) {
      final tartib = ref.read(sahibAlTartibProvider).valueOrNull;
      if (tartib?.requiresOrder == true && tartib?.nextPrayer != null) {
        ref.read(appSnackbarServiceProvider).warning(
              l10n.qazaTartibBlocked(
                tartib!.nextPrayer!.localizedLabel(l10n),
              ),
            );
      }
      return;
    }

    await showQazaUndoFeedback(
      context: context,
      ref: ref,
      userId: ref.read(requiredUserIdProvider),
      entries: batch.entries,
      onUndone: controller.refresh,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = state.completing || state.recordMutating;
    final restricted = ref.watch(qazaCompletionRestrictedProvider);
    final count = state.selected.length;

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
                onPressed: busy ? null : controller.exitSelectionMode,
                child: Text(l10n.commonClear),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('qaza_tracker_complete_selected'),
                  onPressed:
                      busy || restricted || count == 0
                          ? null
                          : () => _complete(context, ref),
                  child: Text(l10n.qazaCompleteCount(count)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
