import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

void main() {
  late AppDatabase database;
  late DriftQazaRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftQazaRepository(database);
  });

  tearDown(() => database.close());

  QazaRecord record({
    required String id,
    required String userId,
    required PrayerType prayer,
    required DateTime date,
    QazaStatus status = QazaStatus.pending,
  }) {
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: date,
      status: status,
      completedAt: status == QazaStatus.completed ? date : null,
      createdAt: date,
      updatedAt: date,
    );
  }

  test('maps Drift rows to domain records and preserves user isolation', () async {
    await repository.addRecords([
      record(id: 'a1', userId: 'a', prayer: PrayerType.fajr, date: DateTime(2026, 1, 1)),
      record(id: 'a2', userId: 'a', prayer: PrayerType.zuhr, date: DateTime(2026, 1, 2)),
      record(id: 'b1', userId: 'b', prayer: PrayerType.fajr, date: DateTime(2026, 1, 1)),
    ]);

    final rows = await repository.getRecords(userId: 'a');
    expect(rows.map((row) => row.id), ['a1', 'a2']);
    expect(rows.every((row) => row.userId == 'a'), isTrue);
  });

  test('filters through DAO and handles more than one database page', () async {
    await repository.addRecords([
      for (var i = 0; i < 1001; i++)
        record(
          id: 'f$i',
          userId: 'a',
          prayer: PrayerType.fajr,
          date: DateTime(2020, 1, 1).add(Duration(days: i)),
        ),
    ]);
    await repository.addRecord(
      record(
        id: 'z1',
        userId: 'a',
        prayer: PrayerType.zuhr,
        date: DateTime(2020, 1, 1),
      ),
    );

    final fajr = await repository.getRecords(
      userId: 'a',
      prayerType: PrayerType.fajr,
      status: QazaStatus.pending,
    );

    expect(fajr, hasLength(1001));
    expect(fajr.first.id, 'f0');
    expect(fajr.last.id, 'f1000');
  });

  test('completion is transactional and does not complete another user record', () async {
    await repository.addRecords([
      record(id: 'a1', userId: 'a', prayer: PrayerType.fajr, date: DateTime(2026, 1, 1)),
      record(id: 'b1', userId: 'b', prayer: PrayerType.fajr, date: DateTime(2026, 1, 1)),
    ]);

    await repository.completeRecords(
      userId: 'a',
      recordIds: ['a1', 'b1'],
      completedAt: DateTime(2026, 2, 1),
    );

    final a = await repository.getRecords(userId: 'a');
    final b = await repository.getRecords(userId: 'b');
    expect(a.single.status, QazaStatus.completed);
    expect(b.single.status, QazaStatus.pending);
  });
}
