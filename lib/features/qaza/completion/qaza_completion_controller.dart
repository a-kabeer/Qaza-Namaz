import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../daily_salah/daily_salah_tracking_providers.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../prayer_time/application/prayer_time_providers.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import 'qaza_completion_service.dart';
import 'qaza_completion_state.dart';

class QazaCompletionController extends Notifier<QazaCompletionState> {
  @override
  QazaCompletionState build() => const QazaCompletionState();

  Future<QazaCompletionBatchReceipt> completeRecordsWithReceipt({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) async {
    if (state.isWorking) {
      throw StateError('Qaza completion is already in progress.');
    }
    if (ref.read(qazaCompletionRestrictedProvider)) {
      return const QazaCompletionBatchReceipt(
        result: QazaCompletionResult.blockedByRestrictedTime,
        entries: [],
      );
    }

    final diagnostics = ref.read(diagnosticsProvider);
    diagnostics.recordEvent(
      DiagnosticArea.qazaCompletion,
      'completion_batch_start',
    );

    state = state.copyWith(isWorking: true);
    try {
      final receipt = await ref
          .read(qazaCompletionServiceProvider)
          .completeRecordsWithReceipt(
            userId: userId,
            recordIds: recordIds,
            completedAt: completedAt,
          );
      if (receipt.result == QazaCompletionResult.completed) {
        diagnostics.recordEvent(
          DiagnosticArea.qazaCompletion,
          'completion_batch_succeeded',
        );
        unawaited(_maybeRequestGuestConnectPrompt());
        // All Qaza completion entry points use this controller, so Daily
        // Salah history is synchronized once at the shared boundary.
        for (final entry in receipt.entries) {
          try {
            await ref.read(dailySalahTrackingServiceProvider).syncQazaCompleted(
                  userId: userId,
                  entry: entry,
                );
          } catch (error, stack) {
            // Qaza completion is already committed. Log sync failures; the
            // tracking service also has a guarded read-time recovery path.
            diagnostics.recordFailure(
              DiagnosticArea.qazaCompletion,
              'daily_salah_completion_sync_failed',
              error,
              stack: stack,
            );
          } finally {
            ref.invalidate(dailySalahTrackingLogsProvider(entry.originalDate));
          }
        }
      }
      return receipt;
    } finally {
      state = state.copyWith(isWorking: false);
    }
  }

  Future<void> _maybeRequestGuestConnectPrompt() async {
    try {
      final cloudAccount = ref.read(cloudAccountProvider);
      if (!cloudAccount.isSupported) return;
      final database = ref.read(appDatabaseProvider);
      if (await database.hasShownGuestGooglePrompt()) return;

      // This is a non-interactive restore/status check. A saved profile alone
      // never counts as a verified connected Google account.
      final account = await cloudAccount.restore();
      if (account.isConnected) return;

      // The app-level host marks the prompt shown only after initiating
      // dialog presentation, avoiding a lost request when the host is absent.
      ref.read(guestConnectPromptRequestProvider.notifier).state++;
    } catch (_) {
      // Prompt failures must never affect the Qaza completion that just saved.
    }
  }

  Future<QazaCompletionReceipt> completeRecordWithReceipt({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final batch = await completeRecordsWithReceipt(
      userId: userId,
      recordIds: [recordId],
      completedAt: completedAt,
    );
    return QazaCompletionReceipt(
      result: batch.result,
      completionId:
          batch.entries.isEmpty ? null : batch.entries.single.completionId,
    );
  }

  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    final receipt = await completeRecordWithReceipt(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
    return receipt.result;
  }
}

final qazaCompletionControllerProvider =
    NotifierProvider<QazaCompletionController, QazaCompletionState>(
  QazaCompletionController.new,
);
