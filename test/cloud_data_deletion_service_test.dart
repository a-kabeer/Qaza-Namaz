import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/cloud_data_deletion_service.dart';

import 'support/in_memory_qaza_repository.dart';

void main() {
  QazaRecord record(String id, String userId) {
    final date = DateTime(2020, 1, 1);
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('deletes only cloud data and preserves local records', () async {
    final remote = InMemoryQazaRepository();
    await remote.addRecord(record('cloud-user-1', 'user-1'));
    await remote.addRecord(record('cloud-user-2', 'user-2'));

    final local = _FakeLocalStore(
      records: {
        'user-1': [record('local-user-1', 'user-1')],
      },
      outbox: {
        'user-1': [
          PendingSyncOp(
            id: 'pending-1',
            type: SyncOpType.add,
            userId: 'user-1',
            queuedAt: DateTime(2026, 1, 1),
            record: record('local-user-1', 'user-1'),
          ),
        ],
      },
    );

    var syncCalls = 0;
    final service = CloudDataDeletionService(
      remote: remote,
      localStore: local,
      syncBeforeDelete: () async => syncCalls++,
    );

    await service.deleteCloudData(userId: 'user-1');

    expect(syncCalls, 1);
    expect(await remote.getRecords(userId: 'user-1'), isEmpty);
    expect(await remote.getRecords(userId: 'user-2'), hasLength(1));

    final snapshot = await local.load();
    expect(snapshot.recordsByUser['user-1'], hasLength(1));
    expect(await local.countPendingOutbox('user-1'), 0);
  });
}

class _FakeLocalStore extends QazaLocalStore {
  _FakeLocalStore({
    Map<String, List<QazaRecord>>? records,
    Map<String, List<PendingSyncOp>>? outbox,
  })  : _records = records ?? {},
        _outbox = outbox ?? {};

  final Map<String, List<QazaRecord>> _records;
  final Map<String, List<PendingSyncOp>> _outbox;

  @override
  Future<OfflineCacheSnapshot> load() async => OfflineCacheSnapshot(
        recordsByUser: {
          for (final entry in _records.entries)
            entry.key: List<QazaRecord>.of(entry.value),
        },
        outboxByUser: {
          for (final entry in _outbox.entries)
            entry.key: List<PendingSyncOp>.of(entry.value),
        },
      );

  @override
  Future<void> saveRecords(
      String userId, List<QazaRecord> records) async {
    _records[userId] = List<QazaRecord>.of(records);
  }

  @override
  Future<void> saveOutbox(
      String userId, List<PendingSyncOp> ops) async {
    _outbox[userId] = List<PendingSyncOp>.of(ops);
  }

  @override
  Future<void> saveLastSync(
      String userId, DateTime? lastSync) async {}

  @override
  Future<void> retireUserData({required String userId}) async {
    _records.remove(userId);
    _outbox.remove(userId);
  }
}
