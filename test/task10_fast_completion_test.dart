import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required DateTime originalDate}) {
  final now = DateTime(2026, 9, 16, 10);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: PrayerType.fajr,
    originalDate: originalDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('repeated completion of the same record is idempotent', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    await service.recordQaza(
      userId: 'test-user',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 2),
    );

    expect(
      await service.completeOldestPending(
        userId: 'test-user',
        prayerType: PrayerType.fajr,
        completedAt: DateTime(2026, 9, 16, 10),
      ),
      isTrue,
    );
    expect(
      await service.completeOldestPending(
        userId: 'test-user',
        prayerType: PrayerType.fajr,
        completedAt: DateTime(2026, 9, 16, 10, 1),
      ),
      isFalse,
    );

    final records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(1));
    expect(records.single.status, QazaStatus.completed);
    expect(records.single.completedAt, DateTime(2026, 9, 16, 10));
  });
}
