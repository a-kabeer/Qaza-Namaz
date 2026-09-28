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

  Future<QazaCompletionReceipt> completeRecordWithReceipt({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    if (state.isWorking) {
      throw StateError('Qaza completion is already in progress.');
    }
    if (ref.read(qazaCompletionRestrictedProvider)) {
      return const QazaCompletionReceipt(
        result: QazaCompletionResult.blockedByRestrictedTime,
      );
    }

    final diagnostics = ref.read(diagnosticsProvider);
    diagnostics.recordEvent(DiagnosticArea.qazaCompletion, 'completion_start');

    state = state.copyWith(isWorking: true);
    try {
      final receipt = await ref
          .read(qazaCompletionServiceProvider)
          .completeRecordWithReceipt(
            userId: userId,
            recordId: recordId,
            completedAt: completedAt,
          );
      if (receipt.result == QazaCompletionResult.completed) {
        diagnostics.recordEvent(
          DiagnosticArea.qazaCompletion,
          'completion_succeeded',
        );
      }
      return receipt;
    } finally {
      state = state.copyWith(isWorking: false);
    }
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
