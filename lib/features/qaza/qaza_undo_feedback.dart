import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/utils/date_formatters.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../../domain/services/qaza_undo_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../home/home_controller.dart';
import 'qaza_completion_feedback.dart';

Future<void> showQazaUndoFeedback({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required Iterable<QazaCompletionEntry> entries,
  Future<void> Function()? onUndone,
}) async {
  final batch = await ref.read(qazaUndoManagerProvider).registerEntries(
        userId: userId,
        entries: entries,
      );
  if (batch == null || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  ref.read(appSnackbarServiceProvider).undo(
        message: qazaCompletionSuccessMessage(context, batch),
        actionLabel: l10n.qazaUndoAction,
        onUndo: () {
          unawaited(
            _undoFromSnack(
              context: context,
              ref: ref,
              userId: userId,
              batch: batch,
              onUndone: onUndone,
            ),
          );
        },
      );
}

Future<void> _undoFromSnack({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required QazaUndoBatch batch,
  Future<void> Function()? onUndone,
}) async {
  if (batch.entries.length == 1) {
    await _undoAll(
      context: context,
      ref: ref,
      userId: userId,
      batch: batch,
      onUndone: onUndone,
    );
    return;
  }

  final manager = ref.read(qazaUndoManagerProvider);
  late final QazaUndoBatch activeBatch;
  try {
    activeBatch = await manager.beginSelection(
      userId: userId,
      expectedBatch: batch,
    );
  } on QazaUndoException catch (error, stack) {
    ref.read(diagnosticsProvider).recordFailure(
      DiagnosticArea.qazaCompletion,
      'batch_undo_start_failed',
      error.cause ?? error,
      stack: stack,
    );
    if (!context.mounted) return;
    ref.read(appSnackbarServiceProvider).error(
      qazaUndoFailureMessage(context, error.reason),
    );
    return;
  } catch (error, stack) {
    ref.read(diagnosticsProvider).recordFailure(
      DiagnosticArea.qazaCompletion,
      'batch_undo_start_failed',
      error,
      stack: stack,
    );
    if (!context.mounted) return;
    ref.read(appSnackbarServiceProvider).error(
      qazaUndoFailureMessage(
        context,
        QazaUndoFailureReason.failed,
      ),
    );
    return;
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _QazaUndoSelectionSheet(
        userId: userId,
        initialBatch: activeBatch,
        onUndone: onUndone,
      ),
    );
  } finally {
    await manager.cancelSelection(
      userId: userId,
      expectedBatch: activeBatch,
    );
  }
}

Future<void> _undoAll({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required QazaUndoBatch batch,
  Future<void> Function()? onUndone,
}) async {
  final diagnostics = ref.read(diagnosticsProvider);
  try {
    final result = await ref.read(qazaUndoManagerProvider).undo(
          userId: userId,
          service: ref.read(qazaServiceProvider),
          expectedBatch: batch,
        );
    try {
      ref.read(homeControllerProvider).invalidateDashboard();
      ref.invalidate(progressSummaryProvider);
      await onUndone?.call();
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'post_undo_refresh_failed',
        error,
        stack: stack,
      );
    }
    if (!context.mounted) return;
    ref.read(appSnackbarServiceProvider).success(
          qazaUndoSuccessMessage(context, result.batch, result.count),
        );
  } on QazaUndoException catch (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.qazaCompletion,
      'undo_failed',
      error.cause ?? error,
      stack: stack,
    );
    if (!context.mounted) return;
    ref.read(appSnackbarServiceProvider).error(
          qazaUndoFailureMessage(context, error.reason),
        );
  } catch (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.qazaCompletion,
      'undo_failed',
      error,
      stack: stack,
    );
    if (!context.mounted) return;
    ref.read(appSnackbarServiceProvider).error(
          qazaUndoFailureMessage(
            context,
            QazaUndoFailureReason.failed,
          ),
        );
  }
}

class _QazaUndoSelectionSheet extends ConsumerStatefulWidget {
  const _QazaUndoSelectionSheet({
    required this.userId,
    required this.initialBatch,
    this.onUndone,
  });

  final String userId;
  final QazaUndoBatch initialBatch;
  final Future<void> Function()? onUndone;

  @override
  ConsumerState<_QazaUndoSelectionSheet> createState() =>
      _QazaUndoSelectionSheetState();
}

class _QazaUndoSelectionSheetState
    extends ConsumerState<_QazaUndoSelectionSheet> {
  late QazaUndoBatch _batch = widget.initialBatch;
  final Set<String> _selected = <String>{};
  bool _working = false;


  String _title(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ur'
        ? 'مکمل کی گئی نمازیں واپس کریں'
        : 'Undo completions';
  }

  String _undoSelectedLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ur'
        ? 'منتخب واپس کریں'
        : 'Undo Selected';
  }

  String _undoAllLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ur'
        ? 'سب واپس کریں'
        : 'Undo All';
  }

  Future<void> _undoSelected() async {
    if (_selected.isEmpty || _working) {
      return;
    }
    setState(() => _working = true);
    try {
      final result = await ref.read(qazaUndoManagerProvider).undoSelected(
            userId: widget.userId,
            service: ref.read(qazaServiceProvider),
            expectedBatch: _batch,
            selectedIds: Set<String>.of(_selected),
          );
      _selected.clear();
      await _refreshAfterUndo();
      if (!mounted) return;

      final remaining = result.remainingBatch;
      if (remaining == null || remaining.entries.isEmpty) {
        Navigator.of(context).pop();
        ref.read(appSnackbarServiceProvider).success(
              qazaUndoSuccessMessage(context, result.batch, result.count),
            );
      } else {
        setState(() {
          _batch = remaining;
          _working = false;
        });
        ref.read(appSnackbarServiceProvider).success(
              qazaUndoSuccessMessage(context, result.batch, result.count),
            );
      }
    } on QazaUndoException catch (error) {
      await _recoverCurrentBatch();
      if (!mounted) return;
      setState(() => _working = false);
      ref.read(appSnackbarServiceProvider).error(
            qazaUndoFailureMessage(context, error.reason),
          );
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.qazaCompletion,
            'undo_selected_failed',
            error,
            stack: stack,
          );
      if (!mounted) return;
      setState(() => _working = false);
      ref.read(appSnackbarServiceProvider).error(
            qazaUndoFailureMessage(
              context,
              QazaUndoFailureReason.failed,
            ),
          );
    }
  }

  Future<void> _undoAll() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await ref.read(qazaUndoManagerProvider).undo(
            userId: widget.userId,
            service: ref.read(qazaServiceProvider),
            expectedBatch: _batch,
          );
      await _refreshAfterUndo();
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.read(appSnackbarServiceProvider).success(
            qazaUndoSuccessMessage(context, result.batch, result.count),
          );
    } on QazaUndoException catch (error) {
      await _recoverCurrentBatch();
      if (!mounted) return;
      setState(() => _working = false);
      ref.read(appSnackbarServiceProvider).error(
            qazaUndoFailureMessage(context, error.reason),
          );
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.qazaCompletion,
            'undo_all_failed',
            error,
            stack: stack,
          );
      if (!mounted) return;
      setState(() => _working = false);
      ref.read(appSnackbarServiceProvider).error(
            qazaUndoFailureMessage(
              context,
              QazaUndoFailureReason.failed,
            ),
          );
    }
  }

  Future<void> _refreshAfterUndo() async {
    ref.read(homeControllerProvider).invalidateDashboard();
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(sahibAlTartibProvider);
    await widget.onUndone?.call();
  }

  Future<void> _recoverCurrentBatch() async {
    final current = await ref
        .read(qazaUndoManagerProvider)
        .restore(userId: widget.userId);
    if (!mounted || current == null) return;
    setState(() {
      _batch = current;
      _selected.removeWhere(
        (id) => !_batch.entries.any((entry) => entry.recordId == id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _title(context),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_batch.entries.length} Qaza',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _batch.entries.length,
              itemBuilder: (context, index) {
                final entry = _batch.entries[index];
                final selected = _selected.contains(entry.recordId);
                return CheckboxListTile(
                  value: selected,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: _working
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(entry.recordId);
                            } else {
                              _selected.remove(entry.recordId);
                            }
                          });
                        },
                  title: Text(entry.prayerType.localizedLabel(l10n)),
                  subtitle: Text(
                    DateFormatters.formatGregorianDatePadded(entry.originalDate),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : _undoAll,
                  child: Text(_undoAllLabel(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _working || _selected.isEmpty
                      ? null
                      : _undoSelected,
                  child: Text(_undoSelectedLabel(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
