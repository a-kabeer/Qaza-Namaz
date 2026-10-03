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
    return AppScaffold(
      title: 'Qaza Addition',
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (detail) {
          if (detail == null) {
            return const Center(
              child: Text('This Qaza addition could not be found.'),
            );
          }

          final addition = detail.addition;
          final snapshot = addition.currentInputSnapshot;
          final l10n = AppLocalizations.of(context);
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '${requestedSlots > 0 ? requestedSlots : detail.activeCount} '
                              '${l10n.addQazaPrayersLabel}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (dateCount > 1)
                            Text(
                              '${dateCount} Dates',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
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
                        'Prayer Summary',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (orderedPrayers.isEmpty)
                        Text(
                          'No prayers',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: orderedPrayers
                              .map(
                                (prayer) => Chip(
                                  label: Text(
                                    '${prayer.localizedLabel(l10n)} ${dateCount}',
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Created ${MaterialLocalizations.of(context).formatMediumDate(addition.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
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
                label: const Text('View Records'),
              ),
              if (detail.pendingCount > 0) ...[
                const SizedBox(height: 8),
                OverflowBar(
                  spacing: 8,
                  overflowSpacing: 8,
                  alignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddQazaScreen(editAddition: addition),
                          ),
                        );
                        if (context.mounted) {
                          ref.invalidate(
                            qazaAdditionDetailProvider(addition.id),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Addition'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _delete(context, ref, addition.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete Addition'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this Qaza addition?',
      message:
          'Only unchanged pending records will be removed. Completed or modified records are protected and remain active.',
      confirmLabel: 'Delete',
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
              'Nothing eligible was deleted. Protected records remain.',
            );
        return;
      }

      ref.read(appSnackbarServiceProvider).undo(
            message: '${result.deletedCount} Qaza deleted',
            actionLabel: 'Undo',
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
                ? '${result.restoredCount} Qaza restored'
                : '${result.restoredCount} restored; '
                    '${result.conflictCount} skipped due to conflict',
          );
    } catch (error) {
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).error(error.toString());
    }
  }
}


class _SummaryDates extends StatelessWidget {
  const _SummaryDates({
    required this.snapshot,
    required this.l10n,
    required this.textTheme,
  });

  final QazaAdditionInputSnapshot snapshot;
  final AppLocalizations l10n;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final summary = QazaAdditionDateSummary(snapshot);
    if (summary.selectedDates.isEmpty) {
      return Text(
        l10n.qazaHistoryNoDates,
        style: textTheme.bodyMedium,
      );
    }

    switch (snapshot.mode) {
      case QazaAdditionMode.single:
        final date = summary.selectedDates.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.formatGregorian(context, date),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary.formatHijri(l10n, date),
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case QazaAdditionMode.range:
        final start = summary.selectedDates.first;
        final end = summary.selectedDates.last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.formatGregorian(context, start)} → '
              '${summary.formatGregorian(context, end)}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${summary.formatHijri(l10n, start)} → '
              '${summary.formatHijri(l10n, end)}',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case QazaAdditionMode.multiple:
        final dates = List<DateTime>.of(summary.selectedDates)..sort();
        final preview = dates.take(3).toList(growable: false);
        final remaining = dates.length - preview.length;
        final gregorian = preview
            .map((date) => summary.formatGregorian(context, date))
            .join(' · ');
        final hijri = preview
            .map((date) => summary.formatHijri(l10n, date))
            .join(' · ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gregorian,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hijri,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 2),
              Text(
                '+ $remaining more',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
    }
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
