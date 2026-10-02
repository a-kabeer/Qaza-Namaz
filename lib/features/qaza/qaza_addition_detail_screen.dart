import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'add_qaza_screen.dart';
import 'qaza_navigation.dart';
import 'qaza_addition_history_screen.dart';

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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${detail.activeCount}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      const Text('Current active Qaza'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              label: 'Pending',
                              value: detail.pendingCount,
                            ),
                          ),
                          Expanded(
                            child: _Stat(
                              label: 'Completed',
                              value: detail.completedCount,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Mode'),
                      subtitle: Text(_modeLabel(snapshot.mode)),
                    ),
                    ListTile(
                      title: const Text('Dates'),
                      subtitle: Text(_dateSummary(context, snapshot)),
                    ),
                    ListTile(
                      title: const Text('Prayers'),
                      subtitle: Text(
                        snapshot.selectedPrayers
                            .map((prayer) => prayer.localizedLabel(
                                  AppLocalizations.of(context),
                                ))
                            .join(', '),
                      ),
                    ),
                    ListTile(
                      title: const Text('Created'),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(addition.createdAt),
                      ),
                    ),
                    ListTile(
                      title: const Text('Revision'),
                      subtitle: Text('${addition.revision}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  openQazaForAddition(ref, addition.id);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.view_list_rounded),
                label: const Text('View Records'),
              ),
              if (detail.pendingCount > 0) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddQazaScreen(editAddition: addition),
                      ),
                    );
                    if (context.mounted) {
                      ref.invalidate(qazaAdditionDetailProvider(addition.id));
                    }
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Addition'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _delete(context, ref, addition.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete Addition'),
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

  String _modeLabel(QazaAdditionMode mode) => switch (mode) {
        QazaAdditionMode.single => 'Single',
        QazaAdditionMode.range => 'Range',
        QazaAdditionMode.multiple => 'Multiple',
      };

  String _dateSummary(
    BuildContext context,
    QazaAdditionInputSnapshot snapshot,
  ) {
    if (snapshot.selectedDates.isEmpty) return 'No dates';
    if (snapshot.mode == QazaAdditionMode.range &&
        snapshot.selectedDates.length == 2) {
      return '${MaterialLocalizations.of(context).formatMediumDate(snapshot.selectedDates.first)} – '
          '${MaterialLocalizations.of(context).formatMediumDate(snapshot.selectedDates.last)}';
    }
    return snapshot.selectedDates
        .map(
          (date) =>
              MaterialLocalizations.of(context).formatMediumDate(date),
        )
        .join(', ');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(label),
        ],
      );
}
