import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
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
import 'qaza_tracker_controller.dart';

/// The canonical Qaza workspace: progress, bounded paging, status/prayer/date
/// filters, and bulk completion. The full ledger is never loaded.
class QazaTrackerScreen extends ConsumerWidget {
  const QazaTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qazaTrackerControllerProvider);
    final controller = ref.read(qazaTrackerControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      // Adding is offered by the workspace action button, not the header.
      title: l10n.qazaTitle,
      body: SafeArea(
        child: Column(
          children: [
            const _ProgressHeader(),
            _StatusFilterBar(state: state, controller: controller),
            _PrayerFilterBar(state: state, controller: controller),
            _DateFilterBar(state: state, controller: controller),
            // Subtle, in place, and reserving its own height so the list
            // never jumps when a filter changes.
            SizedBox(
              height: 3,
              child: state.refreshing
                  ? const LinearProgressIndicator(
                      key: Key('qaza_tracker_refreshing'), minHeight: 3)
                  : null,
            ),
            Expanded(child: _TrackerBody(state: state, controller: controller)),
            if (state.selected.isNotEmpty)
              _BulkCompletionBar(state: state, controller: controller),
          ],
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
          const SizedBox(height: 4, child: LinearProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          key: const Key('qaza_tracker_progress'),
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.qazaProgressLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.progressPendingCompleted(
                      DateFormatters.formatCount(summary.overall.pending),
                      DateFormatters.formatCount(summary.overall.completed),
                    ),
                  ),
                ],
              ),
            ),
            ProgressRing(
              progress: summary.overall.percentage,
              size: 52,
              strokeWidth: 5,
            ),
          ],
        ),
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
class _TrackerBody extends StatelessWidget {
  const _TrackerBody({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The full state belongs to the first load only; a filter change keeps
    // the page that is already there.
    if (state.loading && state.records.isEmpty) {
      return const _TrackerSkeleton();
    }
    if (state.error != null) {
      return ErrorState(
        key: const Key('qaza_tracker_error'),
        message: l10n.qazaLoadError(state.error!),
        onRetry: controller.refresh,
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

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 320) controller.loadMore();
          return false;
        },
        child: ListView.builder(
          key: const Key('qaza_tracker_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          // Keep the final prayer row (including Witr) above the
          // workspace FAB. AppSpacing.fabClearance matches the FAB's
          // occupied footprint and keeps the last row fully reachable.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.fabClearance,
          ),
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
            return _RecordRow(
              record: record,
              selected: state.selected.contains(record.id),
              busy: state.recordMutating,
              onToggle: record.status == QazaStatus.pending
                  ? () => controller.toggleSelection(record.id)
                  : null,
              onEdit: () => _editTrackerRecord(
                context,
                controller,
                record,
                l10n,
              ),
              onDelete: () => _deleteTrackerRecord(
                context,
                controller,
                record,
                l10n,
              ),
            );
          },
        ),
      ),
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
            const SkeletonText(width: 64, height: 28,
                borderRadius: BorderRadius.all(Radius.circular(999))),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.selected,
    required this.onToggle,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final QazaRecord record;
  final bool selected;
  final VoidCallback? onToggle;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final completed = record.status == QazaStatus.completed;
    final originalDate =
        DateFormatters.formatGregorianDatePadded(record.originalDate);

    return Semantics(
      selected: selected,
      label: '$originalDate, ${record.prayerType.localizedLabel(l10n)}, '
          '${record.status.localizedLabel(l10n)}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: onToggle == null
            ? Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
              )
            : Checkbox(
                value: selected,
                onChanged: (_) => onToggle!(),
              ),
        title: Text(originalDate),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.prayerType.localizedLabel(l10n),
              style: theme.textTheme.titleSmall,
            ),
            Text(
              DateFormatters.hijriLabel(record.originalDate),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              record.status.localizedLabel(l10n),
              style: theme.textTheme.bodySmall,
            ),
            if (completed && record.completedAt != null)
              Text(
                l10n.qazaCompletedOn(
                  DateFormatters.formatGregorianDatePadded(record.completedAt!),
                ),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_RecordAction>(
          key: Key('qaza_record_actions_\${record.id}'),
          enabled: !busy,
          tooltip: l10n.qazaRecordActions,
          onSelected: (action) {
            switch (action) {
              case _RecordAction.edit:
                onEdit();
                break;
              case _RecordAction.delete:
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _RecordAction.edit,
              child: Text(l10n.qazaEditRecord),
            ),
            PopupMenuItem(
              value: _RecordAction.delete,
              child: Text(l10n.qazaDeleteRecord),
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

enum _RecordAction { edit, delete }
class _BulkCompletionBar extends StatelessWidget {
  const _BulkCompletionBar({required this.state, required this.controller});

  final QazaTrackerState state;
  final QazaTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = state.selected.length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        // Sits above the FAB rather than under it, so both stay tappable.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.fabClearance,
        ),
        child: Row(
          children: [
            TextButton(
              key: const Key('qaza_tracker_clear_selection'),
              onPressed: state.completing ? null : controller.clearSelection,
              child: Text(l10n.commonClear),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                key: const Key('qaza_tracker_complete_selected'),
                onPressed: state.completing
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final completed = await controller.completeSelected();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.qazaCompletedCount(completed)),
                          ),
                        );
                      },
                child: Text(l10n.qazaCompleteCount(count)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
