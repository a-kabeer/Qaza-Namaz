/// Lifecycle of the offline-first synchronization layer.
enum SyncStatus {
  /// Every local change is confirmed on the remote backend.
  synced,

  /// A sync (flush + pull) is currently running.
  syncing,

  /// The device is known to be offline; writes stay queued.
  offline,

  /// There are local changes not yet confirmed by the backend.
  pendingSync,

  /// The last sync attempt failed with an unexpected (non-offline) error.
  syncError,
}

/// Immutable snapshot of the sync layer, surfaced to the UI.
class SyncState {
  const SyncState({
    this.status = SyncStatus.synced,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.detail,
  });

  final SyncStatus status;

  /// Last time the backend fully confirmed this account's data
  /// (outbox flushed and remote records pulled), or null if never.
  final DateTime? lastSyncAt;

  /// Number of local operations waiting to be confirmed remotely.
  final int pendingCount;

  /// Human-readable detail for [SyncStatus.syncError] states.
  final String? detail;
}
