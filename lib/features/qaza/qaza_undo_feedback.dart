import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_undo_service.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_controller.dart';
import '../qaza/qaza_completion_feedback.dart';

/// Registers the latest completion as the single active Qaza Undo action and
/// presents that action through the application-wide Snackbar service.
Future<void> showQazaUndoFeedback({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required Iterable<QazaRecord> records,
  Future<void> Function()? onUndone,
}) async {
  final batch = await ref.read(qazaUndoManagerProvider).register(
        userId: userId,
        records: records,
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
  final diagnostics = ref.read(diagnosticsProvider);
  try {
    final result = await ref.read(qazaUndoManagerProvider).undo(
          userId: userId,
          service: ref.read(qazaServiceProvider),
          expectedBatch: batch,
        );
    if (!context.mounted) return;

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
      'undo_failed_${error.reason.name}',
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
