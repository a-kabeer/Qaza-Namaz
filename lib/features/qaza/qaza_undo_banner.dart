import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/widgets/app_card.dart';
import '../home/home_controller.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_undo_service.dart';
import '../../l10n/app_localizations.dart';
import 'qaza_completion_feedback.dart';

/// Persists and surfaces the currently active completion undo window.
class QazaUndoBanner extends ConsumerStatefulWidget {
  const QazaUndoBanner({
    super.key,
    this.onUndone,
  });

  final Future<void> Function()? onUndone;

  @override
  ConsumerState<QazaUndoBanner> createState() => _QazaUndoBannerState();
}

class _QazaUndoBannerState extends ConsumerState<QazaUndoBanner> {
  Future<QazaUndoBatch?>? _restoreFuture;
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(activeUserIdProvider);
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      _restoreFuture = userId == null
          ? Future<QazaUndoBatch?>.value(null)
          : ref.read(qazaUndoManagerProvider).restore(userId: userId);
    }

    final future = _restoreFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<QazaUndoBatch?>(
      future: future,
      builder: (context, snapshot) {
        final batch = snapshot.data;
        if (!snapshot.hasData || batch == null) {
          return const SizedBox.shrink();
        }

        final count = batch.recordIds.length;
        final l10n = AppLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: AppCard(
            key: const Key('qaza_undo_banner'),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.undo_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.qazaUndoAvailable(count),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  key: const Key('qaza_undo_banner_action'),
                  onPressed: () => _undo(
                    userId,
                    expectedBatch: batch,
                  ),
                  child: Text(l10n.qazaUndoAction),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _undo(
    String? userId, {
    QazaUndoBatch? expectedBatch,
  }) async {
    if (userId == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final diagnostics = ref.read(diagnosticsProvider);

    try {
      final result = await ref.read(qazaUndoManagerProvider).undo(
            userId: userId,
            service: ref.read(qazaServiceProvider),
            expectedBatch: expectedBatch,
          );
      if (!mounted) return;

      try {
        ref.read(homeControllerProvider).invalidateDashboard();
        ref.invalidate(progressSummaryProvider);
        for (final prayer in PrayerType.values) {
          ref.invalidate(oldestPendingProvider(prayer));
        }
        await widget.onUndone?.call();
      } catch (error, stack) {
        diagnostics.recordFailure(
          DiagnosticArea.qazaCompletion,
          'post_undo_refresh_failed',
          error,
          stack: stack,
        );
      }
      if (!mounted) return;

      setState(() {
        _loadedUserId = userId;
        _restoreFuture = Future<QazaUndoBatch?>.value(null);
      });
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              qazaUndoSuccessMessage(
                context,
                result.batch,
                result.count,
              ),
            ),
          ),
        );
    } on QazaUndoException catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'undo_failed_${error.reason.name}',
        error.cause ?? error,
        stack: stack,
      );
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _restoreFuture = Future<QazaUndoBatch?>.value(null);
      });
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(qazaUndoFailureMessage(context, error.reason)),
          ),
        );
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'undo_failed',
        error,
        stack: stack,
      );
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _restoreFuture = Future<QazaUndoBatch?>.value(null);
      });
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              qazaUndoFailureMessage(
                context,
                QazaUndoFailureReason.failed,
              ),
            ),
          ),
        );
    }
  }
}

Future<void> showQazaUndoSnackBar({
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
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(qazaCompletionSuccessMessage(context, batch)),
        action: SnackBarAction(
          label: l10n.qazaUndoAction,
          onPressed: () {
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
        ),
      ),
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
      for (final prayer in PrayerType.values) {
        ref.invalidate(oldestPendingProvider(prayer));
      }
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

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            qazaUndoSuccessMessage(context, result.batch, result.count),
          ),
        ),
      );
  } on QazaUndoException catch (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.qazaCompletion,
      'undo_failed_${error.reason.name}',
      error.cause ?? error,
      stack: stack,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(qazaUndoFailureMessage(context, error.reason)),
        ),
      );
  } catch (error, stack) {
    diagnostics.recordFailure(
      DiagnosticArea.qazaCompletion,
      'undo_failed',
      error,
      stack: stack,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            qazaUndoFailureMessage(
              context,
              QazaUndoFailureReason.failed,
            ),
          ),
        ),
      );
  }
}
