import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/qaza_completion_result.dart';
import '../../../domain/services/qaza_service.dart';

class QazaCompletionService {
  const QazaCompletionService(this._qazaService);

  final QazaService _qazaService;

  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) {
    return _qazaService.completeRecord(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
  }

  Future<QazaCompletionReceipt> completeRecordWithReceipt({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) {
    return _qazaService.completeRecordWithReceipt(
      userId: userId,
      recordId: recordId,
      completedAt: completedAt,
    );
  }

  Future<QazaCompletionBatchReceipt> completeRecordsWithReceipt({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    return _qazaService.completeRecordsWithReceipt(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }
}

final qazaCompletionServiceProvider = Provider<QazaCompletionService>(
  (ref) => QazaCompletionService(ref.read(qazaServiceProvider)),
);
