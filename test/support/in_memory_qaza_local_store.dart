import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';

/// Ephemeral QazaLocalStore used by tests as a deterministic local-store double.
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
