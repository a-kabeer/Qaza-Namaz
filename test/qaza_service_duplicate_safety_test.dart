import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord _record({
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) {
  return QazaRecord(
    id: 'u1_${prayer.name}_${date.year}-${date.month}-${date.day}',
    userId: 'u1',
    prayerType: prayer,
    originalDate: date,
    status: status,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('repeating the same Add Qaza submission is idempotent', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final dates = [DateTime(2024, 1, 1), DateTime(2024, 1, 2)];

    await service.recordQazaForDates(
      userId: 'u1',
      dates: dates,
      prayerTypes: [PrayerType.fajr, PrayerType.asr],
    );
    await service.recordQazaForDates(
      userId: 'u1',
      dates: dates,
      prayerTypes: [PrayerType.fajr, PrayerType.asr],
    );

    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(4));
    expect(
      records.map((record) => '${record.originalDate.toIso8601String()}_${record.prayerType.name}').toSet(),
      hasLength(4),
    );
  });

  test('existing completed Qaza is preserved and never recreated', () async {
    final repository = InMemoryQazaRepository();
    await repository.addRecord(
      _record(
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1),
        status: QazaStatus.completed,
      ),
    );
    final service = QazaService(repository);

    await service.recordQazaForDates(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1)],
      prayerTypes: [PrayerType.fajr, PrayerType.isha],
    );

    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(2));
    final fajr = records.singleWhere((record) => record.prayerType == PrayerType.fajr);
    expect(fajr.status, QazaStatus.completed);
    expect(records.any((record) => record.prayerType == PrayerType.isha), isTrue);
  });

  test('already-prayed candidates are excluded at save time', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    final prayed = {
      const _prayerKey(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayer: PrayerType.fajr,
      ),
    };

    await service.recordQazaForDates(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1)],
      prayerTypes: [PrayerType.fajr, PrayerType.asr],
      prayedKeys: prayed,
    );

    final records = await repository.getRecords(userId: 'u1');
    expect(records, hasLength(1));
    expect(records.single.prayerType, PrayerType.asr);
  });
}

class _prayerKey extends QazaPrayerKey {
  const _prayerKey({
    required super.userId,
    required super.date,
    required PrayerType prayer,
  }) : super(prayerType: prayer);
}
