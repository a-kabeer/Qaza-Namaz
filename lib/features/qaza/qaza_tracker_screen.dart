import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'history/qaza_history_screen.dart';

/// The canonical Qaza workspace: progress, bounded paging, status/prayer/date
/// filters, and bulk completion. The full ledger is never loaded.
class QazaTrackerScreen extends ConsumerWidget {
  const QazaTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qazaTrackerControllerProvider);
    final controller = ref.read(qazaTrackerControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final title = state.selectionMode
        ? '${state.selected.length} selected'
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
          if (state.selectionMode)
            IconButton(
              key: const Key('qaza_tracker_exit_selection'),
              tooltip: l10n.commonClose,
              onPressed: controller.exitSelectionMode,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        body: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                if (!state.selectionMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const TabBar(
                    tabs: const [
                      Tab(text: 'Pending'),
                      Tab(text: 'History'),
                    ],
                  ),
                ],
                Expanded(
                  child: TabBarView(
                    physics: state.selectionMode
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    children: [
                      _PendingTrackerContent(
                        state: state,
                        controller: controller,
                      ),
                      const QazaHistoryScreen(embedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aggregate progress. Reads the database summary, never the record list.
class _ProgressHeader extends ConsumerWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);
    return summaryAsync.when(
      loading: () =>
          const SizedBox(height: 3, child: LinearProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) => Padding(
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
                    l10n.qazaProgressLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${(summary.overall.percentage * 100).round()}%',
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
                value: summary.overall.percentage,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.progressCompletedPending(
                DateFormatters.formatCount(summary.overall.completed),
                DateFormatters.formatCount(summary.overall.pending),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTrackerContent extends StatelessWidget {
  const _PendingTrackerContent({
    required this.state,
    required this.controller,
  });

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _FilterSheet(state: state, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const _ProgressHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('qaza_tracker_filter_button'),
                  onPressed: () => _openFilters(context),
                  icon: const Icon(Icons.filter_list_rounded),
                  label: Text(
                    state.isFiltered ? 'Filters active' : 'Filter',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SegmentedButton<QazaSortOrder>(
                  key: const Key('qaza_tracker_sort'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: QazaSortOrder.oldestFirst,
                      label: Text(l10n.qazaSortOldestFirst),
                    ),
                    ButtonSegment(
                      value: QazaSortOrder.newestFirst,
                      label: Text(l10n.qazaSortNewestFirst),
                    ),
                  ],
                  selected: {state.sortOrder},
                  onSelectionChanged: (value) =>
                      controller.setSortOrder(value.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _TrackerBody(state: state, controller: controller)),
        if (state.selected.isNotEmpty)
          _BulkCompletionBar(state: state, controller: controller),
      ],
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _pickRange(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text(l10n.qazaDateFilterHelp,
              style: Theme.of(context).textTheme.titleMedium),
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
              for (final prayer in PrayerType.values)
                FilterChip(
                  label: Text(prayer.localizedLabel(l10n)),
                  selected: state.prayerFilter == prayer,
                  onSelected: (selected) =>
                      controller.setPrayerFilter(selected ? prayer : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.qazaDateFilterHelp,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickRange(context),
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

class _TrackerBody extends ConsumerWidget {
  const _TrackerBody({required this.state, required this.controller});
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
        records: batch.completedRecords,
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
    final lockedRecordId =
        tartib?.requiresOrder == true ? tartib?.nextPending?.id : null;
    if (state.loading && state.records.isEmpty) return const _TrackerSkeleton();
    if (state.error != null) {
      final failure = AppError.from(state.error!);
      return ErrorState(
          key: const Key('qaza_tracker_error'),
          message: failure.message(context),
          onRetry: failure.isRetryable ? controller.refresh : null);
    }
    if (state.records.isEmpty) {
      return state.isFiltered
          ? EmptyState(
              key: const Key('qaza_tracker_filtered_empty'),
              title: l10n.qazaFilteredEmptyTitle,
              message: l10n.qazaFilteredEmptyMessage,
              child: TextButton(
                  onPressed: controller.clearFilters,
                  child: Text(l10n.qazaResetFilters)))
          : EmptyState(
              key: const Key('qaza_tracker_empty'),
              title: l10n.qazaEmptyTitle,
              message: l10n.qazaEmptyMessage);
    }
    return Column(
      children: [
        if (tartib?.requiresOrder == true && tartib?.nextPrayer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    l10n.qazaTartibRequiredMessage(tartib!.pendingFarzCount,
                        tartib.nextPrayer!.localizedLabel(l10n)),
                    style: Theme.of(context).textTheme.bodySmall)),
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
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.fabClearance),
                itemCount: state.records.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
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
                          _TrackerSkeletonRow(),
                        ],
                      ),
                    );
                  }
                  final record = state.records[index];
                  final canAct = record.status == QazaStatus.pending &&
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
                        ? (record.status == QazaStatus.pending
                            ? () => controller.toggleSelection(record.id)
                            : null)
                        : null,
                    onLongPress: record.status == QazaStatus.pending &&
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
      ],
    );
  }
}

/// One ledger row: original Qaza date, prayer, status and completion date are
/// each distinguishable.
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
                : const SizedBox.shrink(),
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
class _BulkCompletionBar extends ConsumerStatefulWidget {
  const _BulkCompletionBar({required this.state, required this.controller});
  final QazaTrackerState state;
  final QazaTrackerController controller;
  @override
  ConsumerState<_BulkCompletionBar> createState() => _BulkCompletionBarState();
}

class _BulkCompletionBarState extends ConsumerState<_BulkCompletionBar> {
  Future<void> _complete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final count = widget.state.selected.length;
    if (widget.state.selectionNeedsConfirmation) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.qazaConfirmBulkTitle('$count'),
        message: l10n.qazaConfirmBulkMessage('$count'),
        confirmLabel: l10n.qazaConfirmBulkAction,
      );
      if (!confirmed || !context.mounted) return;
    }
    final batch = await widget.controller.completeSelectedWithUndo();
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
      records: batch.completedRecords,
      onUndone: widget.controller.refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = widget.state.completing || widget.state.recordMutating;
    final count = widget.state.selected.length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    key: const Key('qaza_tracker_clear_selection'),
                    onPressed:
                        busy ? null : widget.controller.exitSelectionMode,
                    child: Text(l10n.commonClear),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('qaza_tracker_complete_selected'),
                      onPressed: busy ? null : () => _complete(context),
                      child: Text(l10n.qazaCompleteCount(count)),
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
}
