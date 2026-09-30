import '../entities/qaza_addition.dart';
import '../entities/qaza_record.dart';

abstract interface class QazaAdditionRepository {
  Future<QazaAddition?> getAddition({
    required String userId,
    required String additionId,
  });

  Future<QazaAdditionDetail?> getAdditionDetail({
    required String userId,
    required String additionId,
  });

  Future<QazaAdditionListPage> getRecentAdditions({
    required String userId,
    int limit = 30,
    DateTime? afterCreatedAt,
    String? afterId,
  });

  Future<QazaDeletionActionPage> getRecentDeletionActions({
    required String userId,
    int limit = 30,
    DateTime? afterCreatedAt,
    String? afterId,
  });

  Future<List<QazaRecord>> getRecordsForAddition({
    required String userId,
    required String additionId,
  });

  Future<QazaAdditionMutationResult> createAddition({
    required QazaAddition addition,
    required List<QazaRecord> records,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  });

  Future<QazaAdditionMutationResult> editAddition({
    required String userId,
    required String additionId,
    required int expectedRevision,
    required QazaAdditionInputSnapshot snapshot,
    required Set<QazaRecordKey> requestedKeys,
    required List<QazaRecord> recordsToAdd,
    bool Function()? isCancellationRequested,
    void Function(int processed, int total, int added)? onProgress,
  });

  Future<QazaDeletionResult> deleteAddition({
    required String userId,
    required String additionId,
  });

  Future<QazaRestoreResult> restoreDeletionAction({
    required String userId,
    required String deletionActionId,
  });
}
