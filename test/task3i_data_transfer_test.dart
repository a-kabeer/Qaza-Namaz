import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/app_metadata.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/qaza_data_transfer_service.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  const userA = 'user-a';
  const userB = 'user-b';
  final created = DateTime.utc(2026, 1, 1, 10);
  final updated = DateTime.utc(2026, 1, 2, 10);
  final completed = DateTime.utc(2026, 1, 3, 10);

  QazaRecord record({String userId = userA, String id = 'user-a_fajr_2026-01-01', PrayerType prayer = PrayerType.fajr, QazaStatus status = QazaStatus.pending, DateTime? completedAt}) {
    return QazaRecord(id: id, userId: userId, prayerType: prayer, originalDate: DateTime.utc(2026, 1, 1), status: status, completedAt: completedAt, createdAt: created, updatedAt: updated);
  }

  String exportDocument(List<QazaRecord> records, {int schema = 1}) => jsonEncode({'schemaVersion': schema, 'exportedAt': DateTime.utc(2026, 2, 1).toIso8601String(), 'appVersion': appVersion, 'records': records.map((item) => item.toJson()).toList()});

  test('exports a valid versioned document', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final service = QazaDataTransferService(repo);
    final decoded = jsonDecode(await service.exportJson(userId: userA, appVersion: appVersion, exportedAt: DateTime.utc(2026, 2, 1))) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 1);
    expect(decoded['appVersion'], appVersion);
    expect(decoded['records'], hasLength(1));
    expect((decoded['records'] as List).single['originalDate'], '2026-01-01T00:00:00.000Z');
  });

  test('exports an empty dataset', () async {
    final json = await QazaDataTransferService(InMemoryQazaRepository()).exportJson(userId: userA, appVersion: appVersion);
    expect((jsonDecode(json) as Map<String, dynamic>)['records'], isEmpty);
  });

  test('round trip preserves ledger semantics', () async {
    final source = InMemoryQazaRepository();
    await source.addRecords([record(), record(id: 'user-a_witr_2026-01-01', prayer: PrayerType.witr, status: QazaStatus.completed, completedAt: completed)]);
    final exported = await QazaDataTransferService(source).exportJson(userId: userA, appVersion: appVersion);
    final target = InMemoryQazaRepository();
    final service = QazaDataTransferService(target);
    final analysis = await service.analyzeImport(jsonText: exported, userId: userB);
    await service.applyImport(analysis);
    final records = await target.getRecords(userId: userB);
    expect(records, hasLength(2));
    expect(records[0].prayerType, PrayerType.fajr);
    expect(records[0].status, QazaStatus.pending);
    expect(records[1].prayerType, PrayerType.witr);
    expect(records[1].status, QazaStatus.completed);
    expect(records[1].completedAt, completed);
    expect(records.every((item) => item.userId == userB), isTrue);
  });

  test('rejects malformed JSON and invalid schema without writes', () async {
    final repo = InMemoryQazaRepository();
    final service = QazaDataTransferService(repo);
    expect(() => service.analyzeImport(jsonText: '{bad', userId: userA), throwsA(isA<QazaDataTransferException>()));
    expect(() => service.analyzeImport(jsonText: exportDocument([record()], schema: 2), userId: userA), throwsA(isA<QazaDataTransferException>()));
    expect(await repo.getRecords(userId: userA), isEmpty);
  });

  test('rejects duplicate IDs and duplicate prayer/date combinations', () async {
    final service = QazaDataTransferService(InMemoryQazaRepository());
    expect(() => service.analyzeImport(jsonText: exportDocument([record(), record()]), userId: userA), throwsA(isA<QazaDataTransferException>()));
    expect(() => service.analyzeImport(jsonText: exportDocument([record(), record(id: 'another-id', prayer: PrayerType.fajr)]), userId: userA), throwsA(isA<QazaDataTransferException>()));
  });

  test('re-importing the same file is idempotent', () async {
    final repo = InMemoryQazaRepository();
    final service = QazaDataTransferService(repo);
    final json = exportDocument([record()]);
    await service.applyImport(await service.analyzeImport(jsonText: json, userId: userA));
    final second = await service.analyzeImport(jsonText: json, userId: userA);
    expect(second.newCount, 0);
    expect(second.completionCount, 0);
    expect(second.unchangedCount, 1);
    expect(await repo.getRecords(userId: userA), hasLength(1));
  });

  test('existing completed record is preserved against imported pending', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record(status: QazaStatus.completed, completedAt: completed));
    final service = QazaDataTransferService(repo);
    final analysis = await service.analyzeImport(jsonText: exportDocument([record()]), userId: userA);
    final result = await service.applyImport(analysis);
    final current = (await repo.getRecords(userId: userA)).single;
    expect(result.unchangedCount, 1);
    expect(current.status, QazaStatus.completed);
    expect(current.completedAt, completed);
    expect(current.createdAt, created);
  });

  test('pending record is promoted by imported completed state', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final service = QazaDataTransferService(repo);
    final imported = record(status: QazaStatus.completed, completedAt: completed);
    await service.applyImport(await service.analyzeImport(jsonText: exportDocument([imported]), userId: userA));
    final current = (await repo.getRecords(userId: userA)).single;
    expect(current.status, QazaStatus.completed);
    expect(current.completedAt, completed);
    expect(current.originalDate, DateTime.utc(2026, 1, 1));
  });

  test('foreign ownership is remapped to the current account', () async {
    final service = QazaDataTransferService(InMemoryQazaRepository());
    final analysis = await service.analyzeImport(jsonText: exportDocument([record(userId: userA)]), userId: userB);
    expect(analysis.newRecords.single.userId, userB);
    expect(analysis.newRecords.single.id, 'user-b_fajr_2026-01-01');
  });

  test('invalid record never causes partial writes', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final invalid = record(id: 'user-a_zuhr_2026-01-01', prayer: PrayerType.zuhr).toJson()..['status'] = 'not-a-status';
    final valid = record(id: 'user-a_asr_2026-01-01', prayer: PrayerType.asr).toJson();
    final json = jsonEncode({'schemaVersion': 1, 'exportedAt': DateTime.utc(2026, 2, 1).toIso8601String(), 'appVersion': appVersion, 'records': [valid, invalid]});
    expect(() => QazaDataTransferService(repo).analyzeImport(jsonText: json, userId: userA), throwsA(isA<QazaDataTransferException>()));
    final records = await repo.getRecords(userId: userA);
    expect(records, hasLength(1));
    expect(records.single.prayerType, PrayerType.fajr);
  });
}
