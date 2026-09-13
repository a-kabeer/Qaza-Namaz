import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';

void main() {
  group('QazaService', () {
    late QazaService service;

    setUp(() {
      service = QazaService(InMemoryQazaRepository());
    });

    test('supports exactly six prayer types including separate Witr', () {
      expect(allPrayerTypes.length, 6);
      expect(allPrayerTypes, contains(PrayerType.witr));
      expect(PrayerType.witr, isNot(PrayerType.isha));
    });

    test('does not create duplicate qaza for same user/prayer/date', () async {
      final date = DateTime(2024, 1, 1);

      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: date,
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: date,
      );

      final progress = await service.overallProgress('u1');
      expect(progress.total, 1);
      expect(progress.pending, 1);
    });

    test('oldest pending record is completed first', () async {
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2024, 1, 3),
      );
      await service.recordQaza(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2024, 1, 1),
      );

      final completed = await service.completeOldestPending(
        userId: 'u1',
        prayerType: PrayerType.fajr,
        completedAt: DateTime(2026, 9, 13, 10),
      );

      expect(completed, isTrue);

      final records = await service.repository.getRecords(userId: 'u1');
      final oldest = records.firstWhere(
        (r) => r.originalDate.day == 1,
      );
      expect(oldest.status, QazaStatus.completed);
      expect(oldest.originalDate, DateTime(2024, 1, 1));
      expect(oldest.completedAt, DateTime(2026, 9, 13, 10));
    });

    test('bulk completion changes only selected pending records', () async {
      for (var day = 1; day <= 5; day++) {
        await service.recordQaza(
          userId: 'u1',
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2024, 1, day),
        );
      }

      final records = await service.repository.getRecords(userId: 'u1');
      final selected = records.take(3).map((r) => r.id).toList();

      final count = await service.completeSelected(
        userId: 'u1',
        recordIds: selected,
        completedAt: DateTime(2026, 9, 13),
      );

      expect(count, 3);

      final progress = await service.prayerProgress(
        'u1',
        PrayerType.fajr,
      );
      expect(progress.progress.pending, 2);
      expect(progress.progress.completed, 3);
    });

    test('completed count never becomes negative', () async {
      final progress = await service.overallProgress('u1');
      expect(progress.pending, 0);
      expect(progress.completed, 0);
      expect(progress.percentage, 0);
    });
  });
}
