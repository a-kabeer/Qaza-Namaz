import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
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
  });
}
