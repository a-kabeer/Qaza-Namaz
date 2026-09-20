/// Lifecycle of the offline-first synchronization layer.
enum SyncStatus {
  idle,
  bootstrapping,
  hydrating,
  syncing,
  retrying,
  partiallySynced,
  synced,
  pendingSync,
  offline,
  syncError,
}

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.processedCount = 0,
    this.totalCount = 0,
    this.retryCount = 0,
    this.currentBatch = 0,
    this.totalBatches = 0,
    this.detail,
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final int processedCount;
  final int totalCount;
  final int retryCount;
  final int currentBatch;
  final int totalBatches;
  final String? detail;

  double get progress =>
      totalCount <= 0 ? 0 : (processedCount / totalCount).clamp(0, 1).toDouble();

  bool get isReady =>
      status != SyncStatus.bootstrapping && status != SyncStatus.hydrating;

  bool get isSyncing =>
      status == SyncStatus.syncing || status == SyncStatus.retrying;
}
