import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord _record(int index) => QazaRecord(
      id: 'record-${index.toString().padLeft(4, '0')}',
      userId: 'u1',
      prayerType: PrayerType.values[index % PrayerType.values.length],
      originalDate: DateTime(2020, 1, 1).add(Duration(days: index)),
      status: index.isEven ? QazaStatus.pending : QazaStatus.completed,
      completedAt: index.isEven ? null : DateTime(2025, 1, 1),
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

void main() {
  test('large ledger returns only the requested page', () async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([for (var i = 0; i < 2000; i++) _record(i)]);

    final first = await repository.getHistoryPage(userId: 'u1', limit: 25);
    expect(first.records, hasLength(25));
    expect(first.hasMore, isTrue);

    final second = await repository.getHistoryPage(
      userId: 'u1',
      limit: 25,
      cursor: first.nextCursor,
    );
    expect(second.records, hasLength(25));
    expect(second.records.map((r) => r.id).toSet().intersection(first.records.map((r) => r.id).toSet()), isEmpty);
  });

  test('filtered large ledger remains bounded', () async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([for (var i = 0; i < 2000; i++) _record(i)]);

    final page = await repository.getHistoryPage(
      userId: 'u1',
      prayerType: PrayerType.fajr,
      status: QazaStatus.pending,
      limit: 25,
    );

    expect(page.records.length, lessThanOrEqualTo(25));
    expect(page.records.every((r) => r.prayerType == PrayerType.fajr), isTrue);
    expect(page.records.every((r) => r.status == QazaStatus.pending), isTrue);
  });
}
