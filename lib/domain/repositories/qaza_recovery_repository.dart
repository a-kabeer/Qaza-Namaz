import '../entities/qaza_record.dart';
import '../../core/constants/prayer_types.dart';
import '../repositories/qaza_repository.dart';

/// Database-side counts for one operation.
///
/// The counts are intentionally aggregate values: callers must not materialize
/// thousands of records merely to render History summaries or confirmation
/// counts.
class QazaOperationSummary {
  const QazaOperationSummary({
    this.pending = 0,
    this.completed = 0,
    this.deleted = 0,
    this.unchangedPending = 0,
  });

  final int pending;
  final int completed;
  final int deleted;

  /// Pending records whose creation timestamp is still their last update.
  ///
  /// These are the records the original addition can safely reverse without
  /// overwriting a later user edit or sync mutation.
  final int unchangedPending;

  int get changedPending =>
      pending > unchangedPending ? pending - unchangedPending : 0;

  int get currentCount => pending + completed + deleted;
}

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

  /// Removes the remaining safely removable records from an addition.
  ///
  /// The operation itself stays intact; only eligible pending records are
  /// soft-deleted so the action remains recoverable.
  Future<int> removeAddition({
    required String userId,
    required String operationId,
    required DateTime expectedCreatedAt,
    required DateTime deletedAt,
  });

  Future<QazaOperationSummary> getOperationSummary({
    required String userId,
    required String operationId,
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