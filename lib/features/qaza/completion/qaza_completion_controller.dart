import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/qaza_completion_result.dart';

import '../../prayer_times/domain/qaza_restriction_service.dart';
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
    required QazaRestrictionEvaluation? restriction,
  }) async {
    if (state.isWorking) return;

    state = state.copyWith(isWorking: true);
    try {
      _policy.ensureAllowed(restriction);
      return await ref.read(qazaCompletionServiceProvider).completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );
    } finally {
      state = state.copyWith(isWorking: false);
    }
  }
}

final qazaCompletionControllerProvider =
    NotifierProvider<QazaCompletionController, QazaCompletionState>(
  QazaCompletionController.new,
);
