import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord _record(String userId, PrayerType prayer, int day) => QazaRecord(
      id: '${userId}_${prayer.name}_2024-01-${day.toString().padLeft(2, '0')}',
      userId: userId,
      prayerType: prayer,
      originalDate: DateTime(2024, 1, day),
      status: QazaStatus.pending,
      createdAt: DateTime(2024, 1, day),
      updatedAt: DateTime(2024, 1, day),
    );

void main() {
  group('QazaRepository history pagination', () {
    late InMemoryQazaRepository repository;

    setUp(() async {
      repository = InMemoryQazaRepository();
      await repository.addRecords([
        for (var day = 1; day <= 30; day++)
          _record('u1', day.isEven ? PrayerType.isha : PrayerType.fajr, day),
      ]);
    });

    test('returns bounded pages and advances with cursor', () async {
      final first = await repository.getHistoryPage(userId: 'u1', limit: 10);
      expect(first.records, hasLength(10));
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, first.records.last.id);

      final second = await repository.getHistoryPage(
        userId: 'u1',
        limit: 10,
        cursor: first.nextCursor,
      );
      expect(second.records, hasLength(10));
      expect(second.records.first.id, isNot(first.records.last.id));
      expect(second.records.map((r) => r.id).toSet().intersection(first.records.map((r) => r.id).toSet()), isEmpty);
    });

    test('newest-first ordering is deterministic by date then id', () async {
      final page = await repository.getHistoryPage(userId: 'u1', limit: 5);
      expect(page.records.map((r) => r.originalDate.day), [30, 29, 28, 27, 26]);
    });

    test('oldest-first ordering is supported', () async {
      final page = await repository.getHistoryPage(
        userId: 'u1',
        limit: 5,
        ascending: true,
      );
      expect(page.records.map((r) => r.originalDate.day), [1, 2, 3, 4, 5]);
    });

    test('prayer and date filters are applied before pagination', () async {
      final page = await repository.getHistoryPage(
        userId: 'u1',
        prayerType: PrayerType.isha,
        originalDateFrom: DateTime(2024, 1, 10),
        originalDateTo: DateTime(2024, 1, 20),
        limit: 25,
      );
      expect(page.records.map((r) => r.originalDate.day), [20, 18, 16, 14, 12, 10]);
      expect(page.hasMore, isFalse);
    });

    test('invalid page size is rejected', () async {
      expect(
        () => repository.getHistoryPage(userId: 'u1', limit: 0),
        throwsArgumentError,
      );
    });
  });
}
