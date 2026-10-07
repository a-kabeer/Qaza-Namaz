import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'add_qaza_screen.dart';
import 'qaza_addition_history_screen.dart';
import 'qaza_tracker_screen.dart';
import 'widgets/qaza_addition_date_summary.dart';

class QazaAdditionDetailScreen extends ConsumerWidget {
  const QazaAdditionDetailScreen({
    super.key,
    required this.additionId,
  });

  final String additionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(qazaAdditionDetailProvider(additionId));
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.qazaAdditionTitle,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) {
          return Center(
            child: Text(l10n.homeProgressError),
          );
        },
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Text(l10n.qazaAdditionNotFound),
            );
          }

          final addition = detail.addition;
          final snapshot = addition.currentInputSnapshot;
          final theme = Theme.of(context);
          final orderedPrayers = _orderedPrayers(snapshot.selectedPrayers);
          final dateCount = _dateCount(snapshot);
          final requestedSlots = dateCount * orderedPrayers.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        label: l10n.qazaAdditionRecordsCount(detail.activeCount),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                l10n.qazaAdditionRecordsCount(detail.activeCount),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ],
                        ),
                      ),
                      if (detail.pendingCount > 0 || detail.completedCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${detail.pendingCount} ${l10n.statusPending} · '
                          '${detail.completedCount} ${l10n.statusCompleted}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (detail.isDeleted) ...[
                        const SizedBox(height: 8),
                        Chip(
                          key: const Key('qaza-addition-deleted-status'),
                          avatar: const Icon(Icons.delete_outline_rounded),
                          label: Text(l10n.qazaHistoryDeletedStatus),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      _SummaryDates(
                        snapshot: snapshot,
                        l10n: l10n,
                        textTheme: theme.textTheme,
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Text(
                        orderedPrayers.isEmpty
                            ? l10n.addQazaPrayersLabel
                            : '${orderedPrayers.length} ${l10n.addQazaPrayersLabel}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (orderedPrayers.isEmpty)
                        Text(
                          l10n.qazaAdditionNoPrayers,
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: orderedPrayers
                              .map(
                                (prayer) => Chip(
                                  label: Text(prayer.localizedLabel(l10n)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      if (requestedSlots > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.qazaRequestedSlots(requestedSlots),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        l10n.qazaHistoryAdded(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(addition.createdAt),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => QazaTrackerScreen(
                              additionId: addition.id,
                            ),
                          ),
                        );
                        if (context.mounted) {
                          ref.invalidate(
                            qazaAdditionDetailProvider(addition.id),
                          );
                        }
                      },
                      icon: const Icon(Icons.view_list_rounded),
                      label: Text(l10n.qazaAdditionViewRecords),
                    ),
                  ),
                  if (!detail.isDeleted && detail.pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<_AdditionAction>(
                      key: const Key('qaza-addition-more-actions'),
                      tooltip: l10n.qazaAdditionMoreActions,
                      onSelected: (action) {
                        switch (action) {
                          case _AdditionAction.edit:
                            unawaited(_edit(context, ref, addition));
                          case _AdditionAction.delete:
                            unawaited(_delete(context, ref, addition.id));
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<_AdditionAction>(
                          value: _AdditionAction.edit,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.edit_rounded),
                            title: Text(l10n.qazaAdditionEdit),
                          ),
                        ),
                        PopupMenuItem<_AdditionAction>(
                          value: _AdditionAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            title: Text(l10n.qazaAdditionDelete),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    QazaAddition addition,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddQazaScreen(editAddition: addition),
      ),
    );
    if (context.mounted) {
      ref.invalidate(
        qazaAdditionDetailProvider(addition.id),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.qazaAdditionDeleteConfirmTitle,
      message: l10n.qazaAdditionDeleteConfirmMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final result =
          await ref.read(qazaAdditionRepositoryProvider).deleteAddition(
                userId: ref.read(requiredUserIdProvider),
                additionId: id,
              );
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaAdditionDetailProvider(id));
      ref.invalidate(qazaAdditionHistoryControllerProvider);
      if (!context.mounted) return;

      if (!result.createdAction) {
        ref.read(appSnackbarServiceProvider).info(
              l10n.qazaAdditionDeletedNothing,
            );
        return;
      }

      ref.read(appSnackbarServiceProvider).undo(
            message: l10n.qazaAdditionDeletedCount(result.deletedCount),
            actionLabel: l10n.qazaUndoAction,
            onUndo: () {
              unawaited(_restore(
                context,
                ref,
                result.deletionActionId!,
              ));
            },
          );
    } catch (error) {
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).error(error.toString());
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    String actionId,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result =
          await ref.read(qazaAdditionRepositoryProvider).restoreDeletionAction(
                userId: ref.read(requiredUserIdProvider),
                deletionActionId: actionId,
              );
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaAdditionDetailProvider(additionId));
      ref.invalidate(qazaAdditionHistoryControllerProvider);
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).success(
            result.conflictCount == 0
                ? l10n.qazaAdditionRestoredCount(result.restoredCount)
                : l10n.qazaHistoryRestoreConflict(
                    result.restoredCount,
                    result.conflictCount,
                  ),
          );
    } catch (error) {
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).error(error.toString());
    }
  }
}


enum _AdditionAction { edit, delete }

class _SummaryDates extends StatefulWidget {
  const _SummaryDates({
    required this.snapshot,
    required this.l10n,
    required this.textTheme,
  });

  final QazaAdditionInputSnapshot snapshot;
  final AppLocalizations l10n;
  final TextTheme textTheme;

  @override
  State<_SummaryDates> createState() => _SummaryDatesState();
}

class _SummaryDatesState extends State<_SummaryDates> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = QazaAdditionDateSummary(widget.snapshot);
    if (summary.selectedDates.isEmpty) {
      return Text(
        widget.l10n.qazaHistoryNoDates,
        style: widget.textTheme.bodyMedium,
      );
    }

    switch (widget.snapshot.mode) {
      case QazaAdditionMode.single:
        final date = summary.selectedDates.first;
        return _datePair(
          context,
          summary.formatGregorian(context, date),
          summary.formatHijri(widget.l10n, date),
        );

      case QazaAdditionMode.range:
        final start = summary.selectedDates.first;
        final end = summary.selectedDates.last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.l10n.addQazaDateCount(summary.dayCount),
              style: widget.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _datePair(
              context,
              '${summary.formatGregorian(context, start)} → '
                  '${summary.formatGregorian(context, end)}',
              '${summary.formatHijri(widget.l10n, start)} → '
                  '${summary.formatHijri(widget.l10n, end)}',
            ),
          ],
        );

      case QazaAdditionMode.multiple:
        return _multipleDates(context, summary);
    }
  }

  Widget _datePair(
    BuildContext context,
    String primary,
    String secondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          style: widget.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          secondary,
          style: widget.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _multipleDates(
    BuildContext context,
    QazaAdditionDateSummary summary,
  ) {
    final dates = List<DateTime>.of(summary.selectedDates)..sort();
    final preview = dates.take(3).toList(growable: false);
    final remaining = dates.length - preview.length;
    final gregorian = preview
        .map((date) => summary.formatGregorian(context, date))
        .join(' · ');
    final hijri = preview
        .map((date) => summary.formatHijri(widget.l10n, date))
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.l10n.qazaHistorySelectedDates(dates.length),
          style: widget.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: kThemeAnimationDuration,
          curve: Curves.easeInOut,
          child: _expanded
              ? _expandedDateList(context, summary, dates)
              : Column(
                  key: const ValueKey('collapsed-qaza-addition-dates'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gregorian,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: widget.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hijri,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: widget.textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+ $remaining more',
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('qaza-addition-toggle-dates'),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _expanded
                  ? widget.l10n.qazaHistoryHideDates
                  : widget.l10n.qazaHistoryShowAllDates,
            ),
          ),
        ),
      ],
    );
  }

  Widget _expandedDateList(
    BuildContext context,
    QazaAdditionDateSummary summary,
    List<DateTime> dates,
  ) {
    return ConstrainedBox(
      key: const ValueKey('expanded-qaza-addition-dates'),
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final date in dates)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        summary.formatGregorian(context, date),
                        style: widget.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summary.formatHijri(widget.l10n, date),
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<PrayerType> _orderedPrayers(List<PrayerType> prayers) {
  final ordered = prayers.toList(growable: false)
    ..sort(
      (a, b) => a.qazaSequenceIndex.compareTo(b.qazaSequenceIndex),
    );
  return ordered;
}

int _dateCount(QazaAdditionInputSnapshot snapshot) =>
    QazaAdditionDateSummary(snapshot).dayCount;
