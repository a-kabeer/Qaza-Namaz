import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';

QazaRecord _record({
  required String userId,
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) => QazaRecord(
      id: '${userId}_${prayer.name}_${date.year}-${date.month}-${date.day}',
      userId: userId,
      prayerType: prayer,
      originalDate: date,
      status: status,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  const service = QazaAvailabilityService();

  test('normalizes timestamps so the same calendar date cannot duplicate', () {
    final records = [
      _record(
        userId: 'u1',
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1, 23, 59),
      ),
    ];

    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1, 0, 1),
        prayerType: PrayerType.fajr,
        existingRecords: records,
      ),
      QazaEligibility.alreadyRecorded,
    );
  });

  test('records belonging to another user do not block eligibility', () {
    final records = [
      _record(
        userId: 'other-user',
        prayer: PrayerType.fajr,
        date: DateTime(2024, 1, 1),
      ),
    ];

    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayerType: PrayerType.fajr,
        existingRecords: records,
      ),
      QazaEligibility.available,
    );
  });

  test('Witr remains independently eligible when other prayers are recorded', () {
    final records = [
      for (final prayer in [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ])
        _record(
          userId: 'u1',
          prayer: prayer,
          date: DateTime(2024, 1, 1),
        ),
    ];

    expect(
      service.availablePrayers(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        existingRecords: records,
      ),
      [PrayerType.witr],
    );
  });

  test('duplicate input dates and prayers produce one candidate per combination', () {
    final analysis = service.analyze(
      userId: 'u1',
      dates: [
        DateTime(2024, 1, 1, 1),
        DateTime(2024, 1, 1, 23),
        DateTime(2024, 1, 2),
      ],
      prayerTypes: [
        PrayerType.fajr,
        PrayerType.fajr,
        PrayerType.zuhr,
      ],
      existingRecords: const [],
    );

    expect(analysis.total, 4);
    expect(analysis.newCount, 4);
  });

  test('date is unavailable only when all configured prayers are unavailable', () {
    final records = [
      for (final prayer in PrayerType.values)
        _record(
          userId: 'u1',
          prayer: prayer,
          date: DateTime(2024, 1, 1),
          status: prayer == PrayerType.witr
              ? QazaStatus.completed
              : QazaStatus.pending,
        ),
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

  test('already-prayed takes precedence over recorded state', () {
    final key = QazaPrayerKey(
      userId: 'u1',
      date: DateTime(2024, 1, 1),
      prayerType: PrayerType.fajr,
    );

    expect(
      service.eligibility(
        userId: 'u1',
        date: DateTime(2024, 1, 1),
        prayerType: PrayerType.fajr,
        existingRecords: [
          _record(
            userId: 'u1',
            prayer: PrayerType.fajr,
            date: DateTime(2024, 1, 1),
          ),
        ],
        prayedKeys: {key},
      ),
      QazaEligibility.alreadyPrayed,
    );
  });
}
