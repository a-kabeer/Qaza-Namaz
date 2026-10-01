import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';

class _MemoryUndoStore extends QazaUndoStore {
  QazaUndoBatch? current;

  @override
  Future<void> save({
    required String userId,
    required QazaUndoBatch batch,
  }) async {
    current = batch;
  }

  @override
  Future<QazaUndoBatch?> load({
    required String userId,
    required DateTime now,
  }) async {
    final batch = current;
    if (batch == null) return null;
    if (batch.isExpired(now)) {
      current = null;
      return null;
    }
    return batch;
  }

  @override
  Future<void> clear({required String userId}) async {
    current = null;
  }
}

QazaRecord _completedRecord({
  required String id,
  required PrayerType prayerType,
  required DateTime originalDate,
}) {
  final timestamp = DateTime(2026, 9, 26, 11, 0);
  return QazaRecord(
    id: id,
    userId: 'local',
    prayerType: prayerType,
    originalDate: originalDate,
    status: QazaStatus.completed,
    completedAt: timestamp,
    completionId: 'completion-$id',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeQazaRepository implements QazaRepository, QazaUndoRepository {
  _FakeQazaRepository(this.records);

  final Map<String, QazaRecord> records;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async =>
      records.values.where((record) =>
        record.userId == userId &&
        (prayerType == null || record.prayerType == prayerType) &&
        (status == null || record.status == status),
      ).toList();

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    Iterable<PrayerType>? prayerTypes,
    QazaStatus? status,
    String? additionId,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
    DateTime? beforeOriginalDate,
    String? beforeId,
    DateTime? afterCompletedAt,
    DateTime? beforeCompletedAt,
    bool descending = false,
  }) async {
    final values = await getRecords(
      userId: userId,
      prayerType: prayerType,
      status: status,
    );
    return QazaPage(
      records: values.take(limit).toList(),
      hasMore: values.length > limit,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async =>
      records.values
          .where((record) =>
              record.userId == userId &&
              record.prayerType == prayerType &&
              record.status == QazaStatus.pending)
          .fold<QazaRecord?>(null, (oldest, record) {
        if (oldest == null ||
            record.originalDate.isBefore(oldest.originalDate)) {
          return record;
        }
        return oldest;
      });

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async =>
      recordIds
          .map((id) => records[id])
          .whereType<QazaRecord>()
          .where((record) => record.userId == userId)
          .toList();

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async =>
      (await getRecordsByIds(userId: userId, recordIds: recordIds))
          .where((record) => record.status == QazaStatus.pending)
          .toList();

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) =>
      Future.value(
        QazaProgressSummary.fromRecords(
          records.values.where((record) => record.userId == userId),
        ),
      );

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) async =>
      (await getRecords(userId: userId, status: QazaStatus.completed))
          .where((record) =>
              record.completedAt != null &&
              !record.completedAt!.isBefore(from) &&
              record.completedAt!.isBefore(to) &&
              (prayerTypes == null ||
                  prayerTypes.contains(record.prayerType)))
          .length;

  @override
  Future<void> addRecord(QazaRecord record) async => records[record.id] = record;

  @override
  Future<void> addRecords(List<QazaRecord> values) async {
    for (final record in values) {
      records[record.id] = record;
    }
  }

  @override
  Future<bool> updateRecord({required QazaRecord record}) async {
    if (!records.containsKey(record.id)) return false;
    records[record.id] = record;
    return true;
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String recordId,
  }) async {
    records.remove(recordId);
  }

  @override
  Future<QazaCompletionResult> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
    String? completionId,
  }) async {
    final record = records[recordId];
    if (record == null) return QazaCompletionResult.notFound;
    if (record.status == QazaStatus.completed) {
      return QazaCompletionResult.alreadyCompleted;
    }
    final completed = record.copyWith(
      status: QazaStatus.completed,
      completedAt: completedAt,
      completionId: completionId,
      updatedAt: completedAt,
    );
    records[recordId] = completed;
    return QazaCompletionResult.completed;
  }

  @override
  Future<List<QazaRecord>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
    Map<String, String>? completionIds,
  }) async {
    final changed = <QazaRecord>[];
    for (final id in recordIds) {
      final record = records[id];
      if (record == null || record.status != QazaStatus.pending) continue;
      final completed = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: completionIds?[id],
        updatedAt: completedAt,
      );
      records[id] = completed;
      changed.add(completed);
    }
    return changed;
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    records.removeWhere((_, record) => record.userId == userId);
  }

  @override
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) async =>
      const [];

  @override
  Future<List<String>> undoCompletions({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime undoneAt,
  }) async {
    final changed = <String>[];
    for (final entry in expectedCompletionIds.entries) {
      final record = records[entry.key];
      if (record == null ||
          record.status != QazaStatus.completed ||
          record.completionId != entry.value) {
        continue;
      }
      records[entry.key] = record.copyWith(
        status: QazaStatus.pending,
        clearCompletedAt: true,
        clearCompletionId: true,
        recordVersion: record.recordVersion + 1,
        updatedAt: undoneAt,
      );
      changed.add(entry.key);
    }
    return changed;
  }
}

void main() {
  test('consecutive registrations aggregate into one active Undo batch', () async {
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11, 0);
    final manager = QazaUndoManager(
      store: store,
      now: () => now,
    );

    final first = await manager.register(
      userId: 'local',
      records: [
        _completedRecord(
          id: 'fajr',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2026, 9, 1),
        ),
      ],
    );
    expect(first!.entries, hasLength(1));

    now = now.add(const Duration(seconds: 2));
    final second = await manager.register(
      userId: 'local',
      records: [
        _completedRecord(
          id: 'zuhr',
          prayerType: PrayerType.zuhr,
          originalDate: DateTime(2026, 9, 2),
        ),
      ],
    );

    expect(second!.entries.map((entry) => entry.recordId), ['fajr', 'zuhr']);
    expect(second.expiresAt, now.add(QazaUndoStore.window));
    expect(store.current, same(second));
  });

  test('register does not duplicate a record already in the active batch', () async {
    final store = _MemoryUndoStore();
    final now = DateTime(2026, 9, 26, 11, 0);
    final manager = QazaUndoManager(store: store, now: () => now);
    final record = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );

    await manager.register(userId: 'local', records: [record]);
    final batch = await manager.register(userId: 'local', records: [record]);

    expect(batch!.entries, hasLength(1));
    expect(batch.entries.single.recordId, 'fajr');
    test('partial Undo restores only selected entries and preserves the rest', () async {
    final records = <String, QazaRecord>{
      for (final prayer in PrayerType.values.take(5))
        prayer.name: _completedRecord(
          id: prayer.name,
          prayerType: prayer,
          originalDate: DateTime(2026, 9, 1),
        ),
    };
    final repository = _FakeQazaRepository(records);
    final service = QazaService(repository);
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);

    final batch = await manager.register(
      userId: 'local',
      records: records.values,
    );
    final selectedId = batch!.entries.first.recordId;

    final result = await manager.undoSelected(
      userId: 'local',
      service: service,
      expectedBatch: batch,
      selectedIds: {selectedId},
    );

    expect(result.count, 1);
    expect(result.remainingBatch, isNotNull);
    expect(result.remainingBatch!.entries, hasLength(4));
    expect(records[selectedId]!.status, QazaStatus.pending);
    expect(
      records.values.where((record) => record.status == QazaStatus.completed),
      hasLength(4),
    );

    now = now.add(const Duration(seconds: 1));
    final remaining = await manager.undo(
      userId: 'local',
      service: service,
      expectedBatch: result.remainingBatch,
    );
    expect(remaining.count, 4);
    expect(store.current, isNull);
    expect(
      records.values.where((record) => record.status == QazaStatus.pending),
      hasLength(5),
    );
  });

  test('expired Undo is unavailable while completed records remain completed', () async {
    final record = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );
    final records = {'fajr': record};
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);
    final service = QazaService(_FakeQazaRepository(records));

    final batch = await manager.register(
      userId: 'local',
      records: [record],
    );
    now = now.add(const Duration(seconds: 6));

    await expectLater(
      manager.undo(
        userId: 'local',
        service: service,
        expectedBatch: batch,
      ),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.expired,
        ),
      ),
    );
    expect(records['fajr']!.status, QazaStatus.completed);
    expect(store.current, isNull);
  });

  test('stale Undo callback never clears a newer active session', () async {
    final firstRecord = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );
    final secondRecord = _completedRecord(
      id: 'zuhr',
      prayerType: PrayerType.zuhr,
      originalDate: DateTime(2026, 9, 2),
    );
    final records = {
      firstRecord.id: firstRecord,
      secondRecord.id: secondRecord,
    };
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);
    final service = QazaService(_FakeQazaRepository(records));

    final first = await manager.register(
      userId: 'local',
      records: [firstRecord],
    );
    now = now.add(const Duration(seconds: 1));
    final second = await manager.register(
      userId: 'local',
      records: [secondRecord],
    );

    await expectLater(
      manager.undo(
        userId: 'local',
        service: service,
        expectedBatch: first,
      ),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.staleBatch,
        ),
      ),
    );
    expect(store.current, same(second));
  });

});

