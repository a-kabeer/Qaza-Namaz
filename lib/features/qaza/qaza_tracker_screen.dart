import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_messages.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/services/qaza_service.dart';
import 'qaza_record_editor.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../prayer_times/prayer_times_providers.dart';
import '../prayer_times/presentation/prayer_times_localizations.dart';
import 'qaza_tracker_controller.dart';
import 'qaza_undo_banner.dart';
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
        ? state.selected.length.toString() + ' selected'
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
                    tabs: [
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
        floatingActionButton: state.selectionMode
            ? null
            : FloatingActionButton(
                key: const Key('qaza_tracker_add_fab'),
                tooltip: l10n.qazaAddTooltip,
                onPressed: () {
                  Navigator.of(context).pushNamed('/qaza/add');
                },
                child: const Icon(Icons.add_rounded),
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
      loading: () => const SizedBox(height: 3, child: LinearProgressIndicator()),
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
                  (summary.overall.percentage * 100).round().toString() + '%',
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
    final l10n = AppLocalizations.of(context);
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


class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SegmentedButton<QazaStatusFilter>(
        key: const Key('qaza_tracker_status_filter'),
        segments: [
          for (final filter in QazaStatusFilter.values)
            ButtonSegment(
              value: filter,
              label: Text(filter.localizedLabel(l10n)),
            ),
        ],
        selected: {state.statusFilter},
        onSelectionChanged: (value) => controller.setStatusFilter(value.first),
      ),
    );
  }
}

class _PrayerFilterBar extends StatelessWidget {
  const _PrayerFilterBar({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        key: const Key('qaza_tracker_prayer_filter'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        children: [
          FilterChip(
            label: Text(l10n.filterAll),
            selected: state.prayerFilter == null,
            onSelected: (_) => controller.setPrayerFilter(null),
          ),
          for (final prayer in PrayerType.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: FilterChip(
                label: Text(prayer.localizedLabel(l10n)),
                selected: state.prayerFilter == prayer,
                onSelected: (selected) =>
                    controller.setPrayerFilter(selected ? prayer : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which end of the ledger to read from.
///
/// Two choices rather than a menu: Qaza is owed oldest-first, and the only
/// other question a user asks of this list is what they missed most recently.
class _SortBar extends StatelessWidget {
  const _SortBar({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(l10n.qazaSortLabel,
              style: Theme.of(context).textTheme.bodySmall),
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
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _pickRange(BuildContext context, AppLocalizations l10n) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: l10n.qazaDateFilterHelp,
      initialDateRange: state.from != null && state.to != null
          ? DateTimeRange(start: state.from!, end: state.to!)
          : null,
    );
    if (picked != null) controller.setDateRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
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
              key: const Key('qaza_tracker_date_filter'),
              onPressed: () => _pickRange(context, l10n),
              icon: const Icon(Icons.event_rounded),
              label: Text(
                state.hasDateFilter
                    ? l10n.qazaDateFilterRange(
                        DateFormatters.formatGregorianDatePadded(state.from!),
                        DateFormatters.formatGregorianDatePadded(state.to!),
                      )
                    : l10n.qazaDateFilterAny,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (state.isFiltered) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              key: const Key('qaza_tracker_clear_filters'),
              onPressed: controller.clearFilters,
              child: Text(l10n.commonReset),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _editTrackerRecord(
  BuildContext context,
  QazaTrackerController controller,
  QazaRecord record,
  AppLocalizations l10n,
) async {
  final edited = await showQazaRecordEditor(context, record: record);
  if (edited == null) return;
  try {
    await controller.updateRecord(edited);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qazaRecordUpdated)),
    );
  } on QazaDuplicateRecordException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.qazaDuplicateRecord(
            edited.prayerType.localizedLabel(l10n),
            DateFormatters.formatGregorianDatePadded(edited.originalDate),
          ),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qazaRecordUpdateFailed)),
    );
  }
}

Future<void> _deleteTrackerRecord(
  BuildContext context,
  QazaTrackerController controller,
  QazaRecord record,
  AppLocalizations l10n,
) async {
  final confirmed = await confirmDestructive(
    context,
    title: l10n.qazaDeleteRecordTitle,
    message: l10n.qazaDeleteRecordMessage(
      DateFormatters.formatGregorianDatePadded(record.originalDate),
      record.prayerType.localizedLabel(l10n),
    ),
    confirmLabel: l10n.qazaDeleteRecord,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await controller.deleteRecord(record.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qazaRecordDeleted)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.qazaRecordDeleteFailed)),
    );
  }
}

class _TrackerBody extends ConsumerWidget {
  const _TrackerBody({required this.state, required this.controller});
  final QazaTrackerState state;
  final QazaTrackerController controller;

  Future<void> _completeSingle(BuildContext context, WidgetRef ref, QazaRecord record) async {
    final batch = await controller.completeRecordWithUndo(record.id);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    if (batch != null) {
      await showQazaUndoSnackBar(context: context, ref: ref, userId: ref.read(requiredUserIdProvider), recordIds: batch.recordIds, completedAt: batch.completedAt, onUndone: controller.refresh);
      return;
    }
    final tartib = ref.read(sahibAlTartibProvider).valueOrNull;
    if (tartib?.requiresOrder == true && tartib?.nextPrayer != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.qazaTartibBlocked(tartib!.nextPrayer!.localizedLabel(l10n)))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tartib = ref.watch(sahibAlTartibProvider).valueOrNull;
    final lockedRecordId = tartib?.requiresOrder == true ? tartib?.nextPending?.id : null;
    if (state.loading && state.records.isEmpty) return const _TrackerSkeleton();
    if (state.error != null) {
      final failure = AppError.from(state.error!);
      return ErrorState(key: const Key('qaza_tracker_error'), message: failure.message(context), onRetry: failure.isRetryable ? controller.refresh : null);
    }
    if (state.records.isEmpty) {
      return state.isFiltered
          ? EmptyState(key: const Key('qaza_tracker_filtered_empty'), title: l10n.qazaFilteredEmptyTitle, message: l10n.qazaFilteredEmptyMessage, child: TextButton(onPressed: controller.clearFilters, child: Text(l10n.qazaResetFilters)))
          : EmptyState(key: const Key('qaza_tracker_empty'), title: l10n.qazaEmptyTitle, message: l10n.qazaEmptyMessage);
    }
    return Column(
      children: [
        if (tartib?.requiresOrder == true && tartib?.nextPrayer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l10n.qazaTartibRequiredMessage(tartib!.pendingFarzCount, tartib.nextPrayer!.localizedLabel(l10n)), style: Theme.of(context).textTheme.bodySmall)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) { if (notification.metrics.extentAfter < 320) controller.loadMore(); return false; },
              child: ListView.builder(
                key: const Key('qaza_tracker_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.fabClearance),
                itemCount: state.records.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.records.length) return const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm), child: Column(children: [_TrackerSkeletonRow(), _TrackerSkeletonRow(), _TrackerSkeletonRow()]));
                  final record = state.records[index];
                  final canAct = record.status == QazaStatus.pending && (lockedRecordId == null || record.id == lockedRecordId);
                  return _RecordRow(
                    key: Key('qaza_record_row_' + record.id),
                    record: record,
                    selected: state.selected.contains(record.id),
                    selectionMode: state.selectionMode,
                    busy: state.completing || state.recordMutating,
                    canAct: canAct,
                    onTap: state.selectionMode
                        ? (record.status == QazaStatus.pending ? () => controller.toggleSelection(record.id) : null)
                        : (record.status == QazaStatus.pending ? () => _completeSingle(context, ref, record) : null),
                    onLongPress: record.status == QazaStatus.pending && (lockedRecordId == null || record.id == lockedRecordId) ? () => controller.enterSelectionMode(record.id) : null,
                    onEdit: () => _editTrackerRecord(context, controller, record, l10n),
                    onDelete: () => _deleteTrackerRecord(context, controller, record, l10n),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SkeletonCircle(size: 40),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 120, height: 16),
                  SizedBox(height: 8),
                  SkeletonText(width: 180, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonText(
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
    required this.onEdit,
    required this.onDelete,
  });
  final QazaRecord record;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool busy;
  final bool canAct;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final completed = record.status == QazaStatus.completed;
    final originalDate = DateFormatters.formatGregorianDatePadded(record.originalDate);
    return Semantics(
      selected: selected,
      button: record.status == QazaStatus.pending,
      label: '$originalDate, ${record.prayerType.localizedLabel(l10n)}, ${record.status.localizedLabel(l10n)}',
      hint: record.status == QazaStatus.pending
          ? (selectionMode ? 'Tap to select or unselect.' : 'Tap to complete. Long press to select.')
          : null,
      child: ListTile(
        key: Key('qaza_record_' + record.id),
        contentPadding: EdgeInsets.zero,
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: onTap == null || busy ? null : (_) => onTap!(),
              )
            : IconButton(
                key: Key('qaza_record_complete_' + record.id),
                tooltip: completed ? l10n.statusCompleted : l10n.qazaCompleteCount(1),
                onPressed: completed || !canAct || busy ? null : onTap,
                icon: Icon(
                  completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: completed ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
        title: Text(originalDate),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.prayerType.localizedLabel(l10n), style: theme.textTheme.titleSmall),
            Text(DateFormatters.hijriLabel(record.originalDate), style: theme.textTheme.bodySmall),
            Text(record.status.localizedLabel(l10n), style: theme.textTheme.bodySmall),
            if (completed && record.completedAt != null)
              Text(l10n.qazaCompletedOn(DateFormatters.formatGregorianDatePadded(record.completedAt!)), style: theme.textTheme.bodySmall),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_RecordAction>(
          key: Key('qaza_record_actions_' + record.id),
          enabled: !busy,
          tooltip: l10n.qazaRecordActions,
          onSelected: (action) {
            switch (action) {
              case _RecordAction.edit: onEdit(); break;
              case _RecordAction.delete: onDelete(); break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: _RecordAction.edit, child: Text(l10n.qazaEditRecord)),
            PopupMenuItem(value: _RecordAction.delete, child: Text(l10n.qazaDeleteRecord)),
          ],
        ),
        onTap: selectionMode ? onTap : null,
        onLongPress: onLongPress,
      ),
    );
  }
}
enum _RecordAction { edit, delete }

class _BulkCompletionBar extends ConsumerStatefulWidget {
  const _BulkCompletionBar({required this.state, required this.controller});
  final QazaTrackerState state;
  final QazaTrackerController controller;
  @override
  ConsumerState<_BulkCompletionBar> createState() => _BulkCompletionBarState();
}

class _BulkCompletionBarState extends ConsumerState<_BulkCompletionBar> {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) ref.invalidate(qazaRestrictionEvaluationProvider);
    });
  }
  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  Future<void> _complete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final count = widget.state.selected.length;
    final _urdu = Localizations.localeOf(context).languageCode == 'ur';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.qazaTartibBlocked(tartib!.nextPrayer!.localizedLabel(l10n)))));
      }
      return;
    }
    await showQazaUndoSnackBar(
      context: context,
      ref: ref,
      userId: ref.read(requiredUserIdProvider),
      recordIds: batch.recordIds,
      completedAt: batch.completedAt,
      onUndone: widget.controller.refresh,
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final count = widget.state.selected.length;
    final confirmed = await confirmDestructive(
      context,
      title: _urdu ? count.toString() + ' قضا حذف کریں؟' : 'Delete ' + count.toString() + ' Qaza records?',
      message: _urdu ? 'یہ ریکارڈ History سے 30 دن تک بحال کیے جا سکتے ہیں۔' : 'These records can be restored from History for 30 days.',
      confirmLabel: l10n.qazaDeleteRecord,
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await widget.controller.deleteSelectedWithRecovery();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_urdu ? deleted.toString() + ' ریکارڈ حذف ہوئے۔ History سے بحال کر سکتے ہیں۔' : deleted.toString() + ' deleted. You can restore from History.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final evaluation = ref.watch(qazaRestrictionEvaluationProvider).valueOrNull;
    final restricted = evaluation?.isRestricted == true;
    final busy = widget.state.completing || widget.state.recordMutating;
    final count = widget.state.selected.length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (restricted && evaluation?.type != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text('${PrayerTimesStrings.qazaRestricted(context, evaluation!.type!)}\n${PrayerTimesStrings.restrictionRemaining(context, evaluation.remaining)}', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              Row(
                children: [
                  TextButton(
                    key: const Key('qaza_tracker_clear_selection'),
                    onPressed: busy ? null : widget.controller.exitSelectionMode,
                    child: Text(l10n.commonClear),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('qaza_tracker_complete_selected'),
                      onPressed: busy || restricted ? null : () => _complete(context),
                      child: Text(l10n.qazaCompleteCount(count)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('qaza_tracker_delete_selected'),
                      onPressed: busy ? null : () => _delete(context),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l10n.qazaDeleteRecord),
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
