import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/repositories/drift_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';

void main() {
  late AppDatabase db;
  late DriftQazaRepository repository;
  late QazaService service;
  setUp(() { db = AppDatabase(NativeDatabase.memory()); repository = DriftQazaRepository(db); service = QazaService(repository); });
  tearDown(() => db.close());

  QazaRecord record(int i, {String userId = 'user-a', PrayerType prayer = PrayerType.fajr}) {
    final date = DateTime(2020, 1, 1).add(Duration(days: i));
    return QazaRecord(id: '${userId}_${prayer.name}_$i', userId: userId, prayerType: prayer, originalDate: date, status: QazaStatus.pending, createdAt: date, updatedAt: date);
  }

  test('keyset page remains bounded for a 1001-record ledger', () async {
    await repository.addRecords([for (var i = 0; i < 1001; i++) record(i)]);
    final first = await repository.getPage(userId: 'user-a', limit: 50, status: QazaStatus.pending);
    final second = await repository.getPage(userId: 'user-a', limit: 50, status: QazaStatus.pending, afterOriginalDate: first.nextOriginalDate, afterId: first.nextId);
    expect(first.records, hasLength(50)); expect(first.hasMore, isTrue); expect(second.records, hasLength(50)); expect(second.records.first.id, 'user-a_fajr_50');
  });

  test('oldest pending is resolved directly', () async {
    await repository.addRecords([record(100), record(1), record(50)]);
    expect((await repository.getOldestPending(userId: 'user-a', prayerType: PrayerType.fajr))?.id, 'user-a_fajr_1');
  });

  test('service oldest-pending path delegates to bounded repository query', () async {
    await repository.addRecords([record(10), record(2), record(7)]);
    expect((await service.oldestPending(userId: 'user-a', prayerType: PrayerType.fajr))?.id, 'user-a_fajr_2');
  });

  test('aggregate progress is database-backed', () async {
    await repository.addRecords([record(1), record(2, prayer: PrayerType.zuhr)]);
    await repository.completeRecord(userId: 'user-a', recordId: 'user-a_fajr_1', completedAt: DateTime(2026, 2, 1));
    final summary = await service.getProgressSummary(userId: 'user-a');
    expect(summary.overall.pending, 1); expect(summary.overall.completed, 1);
  });
}
