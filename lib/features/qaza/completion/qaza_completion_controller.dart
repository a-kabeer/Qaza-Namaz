import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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
      }
      return receipt;
    } finally {
      state = state.copyWith(isWorking: false);
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
