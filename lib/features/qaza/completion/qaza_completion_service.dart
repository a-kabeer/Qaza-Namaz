import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/qaza_completion_result.dart';

import '../../../domain/services/qaza_service.dart';

class QazaCompletionService {
  const QazaCompletionService(this._qazaService);

  final QazaService _qazaService;

  Future<void> completeRecord({
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
}

final qazaCompletionServiceProvider = Provider<QazaCompletionService>(
  (ref) => QazaCompletionService(ref.read(qazaServiceProvider)),
);
