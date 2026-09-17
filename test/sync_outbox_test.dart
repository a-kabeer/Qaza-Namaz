import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  PendingSyncOp addOp(String id) {
    final now = DateTime(2026, 1, 1);
    return PendingSyncOp(
      id: id,
      type: SyncOpType.add,
      userId: 'user-a',
      queuedAt: now,
      record: QazaRecord(
        id: 'record-$id',
        userId: 'user-a',
        prayerType: PrayerType.fajr,
        originalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('outbox survives as structured SQLite rows and remains user-scoped', () async {
    final store = DriftQazaLocalStore(database: database);
    final ops = [addOp('op-1'), addOp('op-2')];

    await store.saveOutbox('user-a', ops);

    final rows = await database.syncOutboxDao.getPending(userId: 'user-a');
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.id), ['op-1', 'op-2']);
    expect(await database.syncOutboxDao.countPending(userId: 'user-b'), 0);

    final snapshot = await store.load();
    expect(snapshot.outboxByUser['user-a'], hasLength(2));
    expect(snapshot.outboxByUser['user-a']!.first.record!.id, 'record-op-1');
  });

  test('outbox replacement is atomic at the DAO transaction level', () async {
    final store = DriftQazaLocalStore(database: database);
    await store.saveOutbox('user-a', [addOp('old')]);
    await store.saveOutbox('user-a', [addOp('new')]);

    final rows = await database.syncOutboxDao.getPending(userId: 'user-a');
    expect(rows, hasLength(1));
    expect(rows.single.id, 'new');
  });

  test('attempt and error metadata round-trip', () async {
    final store = DriftQazaLocalStore(database: database);
    final op = PendingSyncOp(
      id: 'failed',
      type: SyncOpType.complete,
      userId: 'user-a',
      queuedAt: DateTime(2026, 1, 1),
      targetRecordId: 'record-1',
      completedAt: DateTime(2026, 1, 2),
      attempts: 3,
      lastError: 'network failure',
    );

    await store.saveOutbox('user-a', [op]);
    final loaded = (await store.load()).outboxByUser['user-a']!.single;

    expect(loaded.attempts, 3);
    expect(loaded.lastError, 'network failure');
    expect(loaded.targetRecordId, 'record-1');
    expect(loaded.completedAt, DateTime(2026, 1, 2));
  });
}
