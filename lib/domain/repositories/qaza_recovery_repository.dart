import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';

/// Recovery capability layered onto the existing Qaza repository.
abstract class QazaRecoveryRepository {
  Future<int> softDeleteRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime deletedAt,
    required String operationId,
  });

  Future<int> restoreDeletedRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime restoredAt,
    required String operationId,
  });

  Future<int> undoAddedOperation({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required List<String> candidateIds,
  });

  Future<QazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    int limit = 50,
    DateTime? beforeOriginalDate,
    String? beforeId,
  });

  Future<QazaHistoryPage> getRecentlyDeletedPage({
    required String userId,
    int limit = 50,
    DateTime? beforeDeletedAt,
    String? beforeId,
  });

  Future<int> purgeDeletedBefore({
    required String userId,
    required DateTime cutoff,
  });
}
