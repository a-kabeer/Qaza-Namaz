import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  late AppDatabase database;
  late DriftQazaLocalStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    store = DriftQazaLocalStore(database: database);
  });

  tearDown(() => database.close());

  QazaRecord record(String id, String userId) {
    final date = DateTime(2026, 1, 1);
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('persists records and outbox independently per user', () async {
    final a = record('a1', 'user-a');
    final b = record('b1', 'user-b');
    final op = PendingSyncOp(
      id: 'add_a1',
      type: SyncOpType.add,
      userId: 'user-a',
      queuedAt: DateTime(2026, 1, 1),
      record: a,
    );

    await store.saveRecordsAndOutbox('user-a', [a], [op]);
    await store.saveRecords('user-b', [b]);

    final snapshot = await store.load();
    expect(snapshot.recordsByUser['user-a']!.single.id, 'a1');
    expect(snapshot.recordsByUser['user-b']!.single.id, 'b1');
    expect(snapshot.outboxByUser['user-a']!.single.id, 'add_a1');
    expect(snapshot.outboxByUser['user-b'], isEmpty);
  });

  test('atomic snapshot replaces only the selected user namespace', () async {
    final a1 = record('a1', 'user-a');
    final a2 = record('a2', 'user-a');
    final b1 = record('b1', 'user-b');

    await store.saveRecords('user-a', [a1]);
    await store.saveRecords('user-b', [b1]);
    await store.saveRecordsAndOutbox('user-a', [a2], []);

    final snapshot = await store.load();
    expect(snapshot.recordsByUser['user-a']!.map((r) => r.id), ['a2']);
    expect(snapshot.recordsByUser['user-b']!.map((r) => r.id), ['b1']);
    expect(snapshot.outboxByUser['user-a'], isEmpty);
  });
}
