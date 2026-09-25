import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';

QazaRecord _record({
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) =>
    QazaRecord(
      id: 'u1_${prayer.name}_${date.year}-${date.month}-${date.day}',
      userId: 'u1',
      prayerType: prayer,
      originalDate: date,
      status: status,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  const service = QazaAvailabilityService();

  test('availability is evaluated at date + prayer level', () {
    final records = [
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 1)),
    ];
    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayerType: PrayerType.fajr,
        existingRecords: records,
      ),
      QazaEligibility.alreadyRecorded,
    );
    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayerType: PrayerType.asr,
        existingRecords: records,
      ),
      QazaEligibility.available,
    );
  });

  test('completed Qaza remains unavailable for duplicate creation', () {
    final records = [
      _record(
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1),
        status: QazaStatus.completed,
      ),
    ];
    expect(
      service.isDateAvailable(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        existingRecords: records,
        prayerTypes: [PrayerType.fajr],
      ),
      isFalse,
    );
  });

  test('date remains available when some prayers are recorded', () {
    final records = [
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.zuhr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.asr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.maghrib, date: DateTime(2024, 1, 1)),
    ];
    expect(
      service.availablePrayers(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        existingRecords: records,
      ),
      [PrayerType.isha, PrayerType.witr],
    );
    expect(
      service.isDateAvailable(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        existingRecords: records,
      ),
      isTrue,
    );
  });

  test('date is unavailable only when every prayer is unavailable', () {
    final records = [
      for (final prayer in PrayerType.values)
        _record(prayer: prayer, date: DateTime(2024, 1, 1)),
    ];
    expect(
      service.isDateAvailable(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        existingRecords: records,
      ),
      isFalse,
    );
  });

  test('analysis counts overlap by date + prayer', () {
    final records = [
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.zuhr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 2)),
    ];
    final analysis = service.analyze(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1), DateTime(2024, 1, 2)],
      prayerTypes: [PrayerType.fajr, PrayerType.zuhr, PrayerType.asr],
      existingRecords: records,
    );
    expect(analysis.total, 6);
    expect(analysis.alreadyRecorded, 3);
    expect(analysis.alreadyPrayed, 0);
    expect(analysis.newCount, 3);
  });

  test('already-prayed remains distinct from already-recorded', () {
    final key = QazaPrayerKey(
      userId: 'u1',
      date: DateTime(2024, 1, 1),
      prayerType: PrayerType.fajr,
    );
    final analysis = service.analyze(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1)],
      prayerTypes: [PrayerType.fajr, PrayerType.asr],
      existingRecords: const [],
      prayedKeys: {key},
    );
    expect(analysis.total, 2);
    expect(analysis.alreadyPrayed, 1);
    expect(analysis.alreadyRecorded, 0);
    expect(analysis.newCount, 1);
    expect(analysis.newCandidates.single.prayerType, PrayerType.asr);
  });

  test('completed records are counted as already completed, not recorded', () {
    final records = [
      _record(
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1),
        status: QazaStatus.completed,
      ),
      _record(prayer: PrayerType.zuhr, date: DateTime(2024, 1, 1)),
    ];
    final analysis = service.analyze(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1)],
      prayerTypes: [PrayerType.fajr, PrayerType.zuhr, PrayerType.asr],
      existingRecords: records,
    );
    expect(analysis.requestedCount, 3);
    expect(analysis.alreadyCompleted, 1);
    expect(analysis.alreadyRecorded, 1);
    expect(analysis.newCount, 1);
    expect(analysis.existingCandidates.length, 2);
    expect(analysis.newCandidates.single.prayerType, PrayerType.asr);
  });

  test('eligibility reports a completed record as already prayed', () {
    final records = [
      _record(
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1),
        status: QazaStatus.completed,
      ),
    ];
    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayerType: PrayerType.fajr,
        existingRecords: records,
      ),
      QazaEligibility.alreadyPrayed,
    );
  });


  test('blocked dates are the dates with no eligible prayer left', () {
    final records = [
      for (final prayer in PrayerType.values)
        _record(prayer: prayer, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 2)),
    ];
    final analysis = service.analyze(
      userId: 'u1',
      dates: [DateTime(2024, 1, 1), DateTime(2024, 1, 2), DateTime(2024, 1, 3)],
      prayerTypes: PrayerType.values,
      existingRecords: records,
    );
    expect(analysis.blockedDateCount, 1);
    expect(analysis.newCount, 5 + 6);
  });
}
