import '../entities/qaza_record.dart';
import '../../core/constants/prayer_types.dart';
import '../repositories/qaza_repository.dart';

/// Recovery capability layered onto the existing Qaza repository.
///
/// Recovery remains bounded and local-first; it never requires materializing
/// the complete Qaza ledger or storing record-id arrays in preferences.
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
  });

  Future<QazaPage> getOperationPage({
    required String userId,
    required String operationId,
    required bool matchLastAction,
    required DateTime operationAt,
    QazaStatus? status,
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
