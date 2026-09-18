/// Lifecycle of the offline-first synchronization layer.
enum SyncStatus {
  /// A signed-in account has been detected and its local database is being
  /// opened. Nothing is known about local completeness yet.
  bootstrapping,

  /// The local database was empty for this account, so remote data is being
  /// pulled down before the ledger can be treated as complete.
  hydrating,

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

  /// True once initial hydration has finished and the local database can be
  /// treated as the complete picture for this account.
  ///
  /// Availability and duplicate calculations must not assume local
  /// completeness while this is false.
  bool get isReady =>
      status != SyncStatus.bootstrapping && status != SyncStatus.hydrating;
}
