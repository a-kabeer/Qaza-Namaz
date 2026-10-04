import '../entities/qaza_record.dart';

/// Optional repository capability for deleting several Qaza records atomically.
///
/// Implementations should keep the operation user-scoped and return only rows
/// actually removed.
abstract interface class QazaBulkDeleteRepository {
  Future<int> deleteRecords({
    required String userId,
    required List<String> recordIds,
  });
}
