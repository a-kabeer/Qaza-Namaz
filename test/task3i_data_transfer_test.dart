import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../core/constants/app_metadata.dart';
import '../core/constants/prayer_types.dart';
import '../data/data_transfer/qaza_data_transfer_service.dart';
import '../data/repositories/in_memory_qaza_repository.dart';
import '../domain/entities/qaza_record.dart';

void main() {
  const userA = 'user-a';
  const userB = 'user-b';
  final created = DateTime.utc(2026, 1, 1, 10);
  final updated = DateTime.utc(2026, 1, 2, 10);
  final completed = DateTime.utc(2026, 1, 3, 10);

  QazaRecord record({
    String userId = userA,
    String id = 'user-a_fajr_2026-01-01',
    PrayerType prayer = PrayerType.fajr,
    QazaStatus status = QazaStatus.pending,
    DateTime? completedAt,
  }) {
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayer,
      originalDate: DateTime.utc(2026, 1, 1),
      status: status,
      completedAt: completedAt,
      createdAt: created,
      updatedAt: updated,
    );
  }

  String exportDocument(List<QazaRecord> records, {int schema = 1}) =>
      jsonEncode({
        'schemaVersion': schema,
        'exportedAt': DateTime.utc(2026, 2, 1).toIso8601String(),
        'appVersion': appVersion,
        'records': records.map((item) => item.toJson()).toList(),
      });

  test('exports a valid versioned document', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final service = QazaDataTransferService(repo);

    final decoded = jsonDecode(
      await service.exportJson(
        userId: userA,
        appVersion: appVersion,
        exportedAt: DateTime.utc(2026, 2, 1),
      ),
    ) as Map<String, dynamic>;

    expect(decoded['schemaVersion'], 1);
    expect(decoded['appVersion'], appVersion);
    expect(decoded['records'], hasLength(1));
    expect((decoded['records'] as List).single['originalDate'],
        '2026-01-01T00:00:00.000Z');
  });

  test('exports an empty dataset without inventing records', () async {
    final json = await QazaDataTransferService(InMemoryQazaRepository())
        .exportJson(userId: userA, appVersion: appVersion);
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['records'], isEmpty);
  });

  test('round trip preserves ledger semantics', () async {
    final source = InMemoryQazaRepository();
    await source.addRecords([
      record(),
      record(
        id: 'user-a_witr_2026-01-01',
        prayer: PrayerType.witr,
        status: QazaStatus.completed,
        completedAt: completed,
      ),
    ]);
    final exported = await QazaDataTransferService(source).exportJson(
      userId: userA,
      appVersion: appVersion,
    );

    final target = InMemoryQazaRepository();
    final service = QazaDataTransferService(target);
    final analysis = await service.analyzeImport(
      jsonText: exported,
      userId: userB,
    );
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

    expect(
      () => service.analyzeImport(jsonText: '{bad', userId: userA),
      throwsA(isA<QazaDataTransferException>()),
    );
    expect(
      () => service.analyzeImport(
        jsonText: exportDocument([record()], schema: 2),
        userId: userA,
      ),
      throwsA(isA<QazaDataTransferException>()),
    );
    expect(await repo.getRecords(userId: userA), isEmpty);
  });

  test('rejects duplicate ids and duplicate prayer/date combinations', () async {
    final service = QazaDataTransferService(InMemoryQazaRepository());
    final one = record();
    final duplicateId = record(
      id: 'another-id',
      prayer: PrayerType.fajr,
    );

    expect(
      () => service.analyzeImport(
        jsonText: exportDocument([one, one]),
        userId: userA,
      ),
      throwsA(isA<QazaDataTransferException>()),
    );
    expect(
      () => service.analyzeImport(
        jsonText: exportDocument([one, duplicateId]),
        userId: userA,
      ),
      throwsA(isA<QazaDataTransferException>()),
    );
  });

  test('same file is idempotent on repeated import', () async {
    final repo = InMemoryQazaRepository();
    final service = QazaDataTransferService(repo);
    final json = exportDocument([record()]);

    final first = await service.analyzeImport(jsonText: json, userId: userA);
    await service.applyImport(first);
    final second = await service.analyzeImport(jsonText: json, userId: userA);

    expect(second.newCount, 0);
    expect(second.completionCount, 0);
    expect(second.unchangedCount, 1);
    expect(await repo.getRecords(userId: userA), hasLength(1));
  });

  test('preserves an existing completed record against imported pending data',
      () async {
    final repo = InMemoryQazaRepository();
    final existing = record(status: QazaStatus.completed, completedAt: completed);
    await repo.addRecord(existing);
    final imported = record(status: QazaStatus.pending);
    final service = QazaDataTransferService(repo);

    final analysis = await service.analyzeImport(
      jsonText: exportDocument([imported]),
      userId: userA,
    );
    final result = await service.applyImport(analysis);

    expect(result.unchangedCount, 1);
    final current = (await repo.getRecords(userId: userA)).single;
    expect(current.status, QazaStatus.completed);
    expect(current.completedAt, completed);
    expect(current.createdAt, created);
  });

  test('promotes existing pending record to imported completed state', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final imported = record(status: QazaStatus.completed, completedAt: completed);
    final service = QazaDataTransferService(repo);

    final analysis = await service.analyzeImport(
      jsonText: exportDocument([imported]),
      userId: userA,
    );
    expect(analysis.completionCount, 1);
    await service.applyImport(analysis);

    final current = (await repo.getRecords(userId: userA)).single;
    expect(current.status, QazaStatus.completed);
    expect(current.completedAt, completed);
    expect(current.originalDate, DateTime.utc(2026, 1, 1));
  });

  test('remaps foreign exported ownership to the current account', () async {
    final service = QazaDataTransferService(InMemoryQazaRepository());
    final foreign = record(userId: userA);
    final analysis = await service.analyzeImport(
      jsonText: exportDocument([foreign]),
      userId: userB,
    );

    expect(analysis.newRecords.single.userId, userB);
    expect(analysis.newRecords.single.id, 'user-b_fajr_2026-01-01');
    expect(analysis.newRecords.single.prayerType, foreign.prayerType);
    expect(analysis.newRecords.single.originalDate, foreign.originalDate);
  });

  test('invalid records never partially write existing data', () async {
    final repo = InMemoryQazaRepository();
    await repo.addRecord(record());
    final invalid = record(
      id: 'user-a_zuhr_2026-01-01',
      prayer: PrayerType.zuhr,
    ).toJson()..['status'] = 'not-a-status';
    final valid = record(
      id: 'user-a_asr_2026-01-01',
      prayer: PrayerType.asr,
    ).toJson();
    final badDocument = jsonEncode({
      'schemaVersion': 1,
      'exportedAt': DateTime.utc(2026, 2, 1).toIso8601String(),
      'appVersion': appVersion,
      'records': [valid, invalid],
    });

    expect(
      () => QazaDataTransferService(repo).analyzeImport(
        jsonText: badDocument,
        userId: userA,
      ),
      throwsA(isA<QazaDataTransferException>()),
    );
    expect(await repo.getRecords(userId: userA), hasLength(1));
    expect((await repo.getRecords(userId: userA)).single.prayerType,
        PrayerType.fajr);
  });
}
