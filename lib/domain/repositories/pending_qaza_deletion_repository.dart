/// Optional capability for deleting only a still-pending Qaza record.
///
/// Tracker-created Qaza entries use this capability so an asynchronous
/// completion cannot race a confirmation dialog and be deleted afterwards.
abstract interface class PendingQazaRecordDeletionRepository {
  Future<bool> deletePendingRecord({
    required String userId,
    required String recordId,
  });
}
