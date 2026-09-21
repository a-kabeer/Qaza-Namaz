import '../../data/local/qaza_local_store.dart';
import '../../data/sync/qaza_sync_remote_data_source.dart';

/// Deletes a user's cloud ledger while deliberately preserving local records.
///
/// The local outbox is cleared after the remote deletion so already-pending
/// writes cannot immediately recreate the cloud copy that the user just
/// deleted. Future local edits may be backed up again normally.
class CloudDataDeletionService {
  const CloudDataDeletionService({
    required QazaSyncRemoteDataSource remote,
    required QazaLocalStore localStore,
    Future<void> Function()? syncBeforeDelete,
  })  : _remote = remote,
        _localStore = localStore,
        _syncBeforeDelete = syncBeforeDelete;

  final QazaSyncRemoteDataSource _remote;
  final QazaLocalStore _localStore;
  final Future<void> Function()? _syncBeforeDelete;

  Future<void> deleteCloudData({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }

    // Finish any active/pending sync before deleting the cloud copy. This
    // prevents an in-flight upload from racing the destructive action.
    await _syncBeforeDelete?.call();

    // Delete the authoritative cloud copy first. Local data is intentionally
    // untouched by the remote operation.
    await _remote.deleteCloudData(userId: userId);

    // Prevent queued offline writes from recreating the deleted cloud ledger.
    while (true) {
      final batch = await _localStore.loadOutboxBatch(userId, limit: 500);
      if (batch.isEmpty) break;
      await _localStore.removeOutboxBatch(
        userId,
        [for (final operation in batch) operation.id],
      );
    }
  }
}
