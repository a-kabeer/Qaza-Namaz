import '../../domain/entities/qaza_record.dart';
import 'qaza_local_store.dart';

/// Ephemeral [QazaLocalStore] used by widget/unit tests and as a deterministic
/// reference implementation. Data lives only for the current process.
class InMemoryQazaLocalStore implements QazaLocalStore {
  final Map<String, List<QazaRecord>> _recordsByUser = {};
  final Map<String, List<PendingSyncOp>> _outboxByUser = {};
  final Map<String, DateTime> _lastSyncByUser = {};

  @override
  Future<OfflineCacheSnapshot> load() async {
    return OfflineCacheSnapshot(
      recordsByUser: {
        for (final entry in _recordsByUser.entries)
          entry.key: List<QazaRecord>.of(entry.value),
      },
      outboxByUser: {
        for (final entry in _outboxByUser.entries)
          entry.key: List<PendingSyncOp>.of(entry.value),
      },
      lastSyncByUser: Map<String, DateTime>.of(_lastSyncByUser),
    );
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    _recordsByUser[userId] = List<QazaRecord>.of(records);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    _outboxByUser[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    if (lastSync == null) {
      _lastSyncByUser.remove(userId);
    } else {
      _lastSyncByUser[userId] = lastSync;
    }
  }
}