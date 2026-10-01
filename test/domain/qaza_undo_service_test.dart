import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/repositories/qaza_undo_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
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

class _FakeQazaRepository implements QazaRepository, QazaUndoRepository {
  _FakeQazaRepository(this.records);

  final Map<String, QazaRecord> records;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    return records.values
        .where(
          (record) =>
              record.userId == userId &&
              (prayerType == null || record.prayerType == prayerType) &&
              (status == null || record.status == status),
        )
        .toList(growable: false);
  }

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
    DateTime? toExclusive,
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
      records: values.take(limit).toList(growable: false),
      hasMore: values.length > limit,
    );
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) async {
    final pending = records.values.where(
      (record) =>
          record.userId == userId &&
          record.prayerType == prayerType &&
          record.status == QazaStatus.pending,
    );
    QazaRecord? oldest;
    for (final record in pending) {
      if (oldest == null || record.originalDate.isBefore(oldest.originalDate)) {
        oldest = record;
      }
    }
    return oldest;
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    return recordIds
        .map((id) => records[id])
        .whereType<QazaRecord>()
        .where((record) => record.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async {
    return (await getRecordsByIds(
      userId: userId,
      recordIds: recordIds,
    ))
        .where((record) => record.status == QazaStatus.pending)
        .toList(growable: false);
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({
    required String userId,
  }) async {
    return QazaProgressSummary.fromRecords(
      records.values.where((record) => record.userId == userId),
    );
  }

  @override
  Future<int> countCompletedBetween({
    required String userId,
    required DateTime from,
    required DateTime to,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    final values = await getRecords(
      userId: userId,
      status: QazaStatus.completed,
    );
    return values
        .where(
          (record) =>
              record.completedAt != null &&
              !record.completedAt!.isBefore(from) &&
              record.completedAt!.isBefore(to) &&
              (prayerTypes == null ||
                  prayerTypes.contains(record.prayerType)),
        )
        .length;
  }

  @override
  Future<void> addRecord(QazaRecord record) async {
    records[record.id] = record;
  }

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
    if (record == null || record.userId != userId) {
      return QazaCompletionResult.notFound;
    }
    if (record.status == QazaStatus.completed) {
      return QazaCompletionResult.alreadyCompleted;
    }
    final completed = record.copyWith(
      status: QazaStatus.completed,
      completedAt: completedAt,
      completionId: completionId,
      updatedAt: completedAt,
      recordVersion: record.recordVersion + 1,
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
      if (record == null ||
          record.userId != userId ||
          record.status != QazaStatus.pending) {
        continue;
      }
      final completed = record.copyWith(
        status: QazaStatus.completed,
        completedAt: completedAt,
        completionId: completionIds?[id],
        updatedAt: completedAt,
        recordVersion: record.recordVersion + 1,
      );
      records[id] = completed;
      changed.add(completed);
    }
    return changed;
  }

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({
    required String userId,
    required Map<String, String> expectedCompletionIds,
    required DateTime updatedAt,
  }) async {
    final changed = <QazaRecord>[];
    for (final entry in expectedCompletionIds.entries) {
      final record = records[entry.key];
      if (record == null ||
          record.userId != userId ||
          record.status != QazaStatus.completed ||
          record.completionId != entry.value) {
        continue;
      }
      final pending = record.copyWith(
        status: QazaStatus.pending,
        clearCompletedAt: true,
        clearCompletionId: true,
        recordVersion: record.recordVersion + 1,
        updatedAt: updatedAt,
      );
      records[entry.key] = pending;
      changed.add(pending);
    }
    return changed;
  }

  @override
  Future<void> resetUserRecords({required String userId}) async {
    records.removeWhere((_, record) => record.userId == userId);
  }

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
          record.userId != userId ||
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

void main() {
  test('consecutive registrations aggregate into one active Undo batch',
      () async {
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

  test('register does not duplicate a record already in the active batch',
      () async {
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
  });

  test('partial Undo restores only selected entries and preserves the rest',
      () async {
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
      records.values.where(
        (record) => record.status == QazaStatus.completed,
      ),
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
      records.values.where(
        (record) => record.status == QazaStatus.pending,
      ),
      hasLength(5),
    );
  });

  test('active batch selection remains usable after discovery expiry',
      () async {
    final records = <String, QazaRecord>{
      'fajr': _completedRecord(
        id: 'fajr',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 1),
      ),
      'zuhr': _completedRecord(
        id: 'zuhr',
        prayerType: PrayerType.zuhr,
        originalDate: DateTime(2026, 9, 2),
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
    final active = await manager.beginSelection(
      userId: 'local',
      expectedBatch: batch!,
    );

    now = now.add(const Duration(seconds: 6));
    final result = await manager.undo(
      userId: 'local',
      service: service,
      expectedBatch: active,
    );

    expect(result.count, 2);
    expect(manager.activeSelection(userId: 'local'), isNull);
    expect(store.current, isNull);
    expect(
      records.values.every((record) => record.status == QazaStatus.pending),
      isTrue,
    );
  });

  test('active partial selection remains usable after discovery expiry',
      () async {
    final records = <String, QazaRecord>{
      for (final prayer in PrayerType.values.take(3))
        prayer.name: _completedRecord(
          id: prayer.name,
          prayerType: prayer,
          originalDate: DateTime(2026, 9, 1),
        ),
    };
    final service = QazaService(_FakeQazaRepository(records));
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);

    final batch = await manager.register(
      userId: 'local',
      records: records.values,
    );
    final active = await manager.beginSelection(
      userId: 'local',
      expectedBatch: batch!,
    );
    final selectedId = active.entries.first.recordId;

    now = now.add(const Duration(seconds: 6));
    final partial = await manager.undoSelected(
      userId: 'local',
      service: service,
      expectedBatch: active,
      selectedIds: {selectedId},
    );

    expect(partial.count, 1);
    expect(partial.remainingBatch, isNotNull);
    expect(manager.activeSelection(userId: 'local'), same(partial.remainingBatch));

    now = now.add(const Duration(minutes: 1));
    final remainder = await manager.undo(
      userId: 'local',
      service: service,
      expectedBatch: partial.remainingBatch,
    );

    expect(remainder.count, 2);
    expect(manager.activeSelection(userId: 'local'), isNull);
    expect(store.current, isNull);
  });

  test('starting batch Undo after discovery expiry is rejected', () async {
    final record = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);
    final batch = await manager.register(
      userId: 'local',
      records: [record],
    );

    now = now.add(QazaUndoStore.window);
    await expectLater(
      manager.beginSelection(
        userId: 'local',
        expectedBatch: batch!,
      ),
      throwsA(
        isA<QazaUndoException>().having(
          (error) => error.reason,
          'reason',
          QazaUndoFailureReason.expired,
        ),
      ),
    );
    expect(manager.activeSelection(userId: 'local'), isNull);
    expect(store.current, isNull);
  });

  test('dismissing active selection cancels only that temporary session',
      () async {
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
    final records = <String, QazaRecord>{
      firstRecord.id: firstRecord,
      secondRecord.id: secondRecord,
    };
    final store = _MemoryUndoStore();
    var now = DateTime(2026, 9, 26, 11);
    final manager = QazaUndoManager(store: store, now: () => now);

    final first = await manager.register(
      userId: 'local',
      records: [firstRecord],
    );
    final active = await manager.beginSelection(
      userId: 'local',
      expectedBatch: first!,
    );

    now = now.add(const Duration(seconds: 1));
    final second = await manager.register(
      userId: 'local',
      records: [secondRecord],
    );

    expect(second!.entries, hasLength(1));
    expect(second.entries.single.recordId, 'zuhr');
    expect(manager.activeSelection(userId: 'local'), same(active));
    expect(store.current, same(second));

    await manager.cancelSelection(
      userId: 'local',
      expectedBatch: active,
    );

    expect(manager.activeSelection(userId: 'local'), isNull);
    expect(store.current, same(second));
  });

  test('expired Undo is unavailable while the record remains completed',
      () async {
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
    final records = <String, QazaRecord>{
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

  test('shared service assigns one completion marker per changed record',
      () async {
    final timestamp = DateTime(2026, 9, 26, 11);
    final records = <String, QazaRecord>{
      for (final prayer in PrayerType.values.take(2))
        prayer.name: QazaRecord(
          id: prayer.name,
          userId: 'local',
          prayerType: prayer,
          originalDate: DateTime(2026, 9, 1),
          status: QazaStatus.pending,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
    };
    final repository = _FakeQazaRepository(records);
    final service = QazaService(
      repository,
      tartib: _NoopTartibService(),
    );

    final receipt = await service.completeRecordsWithReceipt(
      userId: 'local',
      recordIds: records.keys.toList(),
      completedAt: timestamp,
    );

    expect(receipt.entries, hasLength(2));
    expect(
      receipt.entries.map((entry) => entry.recordId).toSet(),
      hasLength(2),
    );
    expect(
      receipt.entries.map((entry) => entry.completionId).toSet(),
      hasLength(2),
    );
  });

  test('Mark as Pending clears completion state permanently', () async {
    final record = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );
    final records = {'fajr': record};
    final service = QazaService(
      _FakeQazaRepository(records),
      tartib: _NoopTartibService(),
    );

    final changed = await service.markCompletedAsPending(
      userId: 'local',
      recordId: 'fajr',
    );

    expect(changed, isTrue);
    expect(records['fajr']!.status, QazaStatus.pending);
    expect(records['fajr']!.completedAt, isNull);
    expect(records['fajr']!.completionId, isNull);
    expect(records['fajr']!.recordVersion, 2);
  });
  test('stale Completed correction marker is ignored and version increments once',
      () async {
    final completed = _completedRecord(
      id: 'fajr',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 1),
    );
    final records = {'fajr': completed};
    final service = QazaService(
      _FakeQazaRepository(records),
      tartib: _NoopTartibService(),
    );

    final stale = await service.markCompletedRecordsAsPending(
      userId: 'local',
      expectedCompletionIds: const {'fajr': 'stale-completion'},
    );
    expect(stale, isEmpty);
    expect(records['fajr']!.status, QazaStatus.completed);
    expect(records['fajr']!.recordVersion, 1);

    final changed = await service.markCompletedRecordsAsPending(
      userId: 'local',
      expectedCompletionIds: {
        'fajr': completed.completionId!,
      },
    );
    expect(changed, hasLength(1));
    expect(records['fajr']!.status, QazaStatus.pending);
    expect(records['fajr']!.completedAt, isNull);
    expect(records['fajr']!.completionId, isNull);
    expect(records['fajr']!.recordVersion, 2);
  });

}

/// This test-only tartib stub is never used for Undo itself; it keeps the
/// shared completion service focused on persistence/receipt behavior.
class _NoopTartibService extends SahibAlTartibService {
  _NoopTartibService() : super(_NeverCalledRepository());

  @override
  Future<SahibAlTartibState> evaluate({
    required String userId,
    DateTime? currentDate,
    PrayerType? currentPrayer,
  }) =>
      Future.value(
        const SahibAlTartibState(
          pendingFarzCount: 6,
          requiresOrder: false,
          nextPending: null,
        ),
      );

  @override
  Future<bool> canCompleteRecordIds({
    required String userId,
    required Iterable<String> recordIds,
    DateTime? currentDate,
    PrayerType? currentPrayer,
    SahibAlTartibState? evaluatedState,
  }) =>
      Future.value(true);
}

class _NeverCalledRepository implements QazaRepository {
  Never _fail() => throw StateError('Should not be called');

  @override
  dynamic noSuchMethod(Invocation invocation) => _fail();
}
