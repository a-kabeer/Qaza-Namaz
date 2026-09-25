import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/diagnostics/diagnostics.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import 'qaza_completion_policy.dart';
import 'qaza_completion_service.dart';
import 'qaza_completion_state.dart';

class QazaCompletionController extends Notifier<QazaCompletionState> {
  final QazaCompletionPolicy _policy = const QazaCompletionPolicy();

  @override
  QazaCompletionState build() => const QazaCompletionState();

  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    if (state.isWorking) {
      throw StateError('Qaza completion is already in progress.');
    }

    final diagnostics = ref.read(diagnosticsProvider);
    // Recorded before anything can fail, so a report that stops here tells
    // you the attempt was made and where it stopped.
    diagnostics.recordEvent(DiagnosticArea.qazaCompletion, 'completion_start');

    state = state.copyWith(isWorking: true);
    try {
      final result =
          await ref.read(qazaCompletionServiceProvider).completeRecord(
                userId: userId,
                recordId: recordId,
                completedAt: completedAt,
              );
      if (result == QazaCompletionResult.completed) {
        diagnostics.recordEvent(
          DiagnosticArea.qazaCompletion,
          'completion_succeeded',
        );
      }
      return result;
    } finally {
      state = state.copyWith(isWorking: false);
    }
  }
}

final qazaCompletionControllerProvider =
    NotifierProvider<QazaCompletionController, QazaCompletionState>(
  QazaCompletionController.new,
);
