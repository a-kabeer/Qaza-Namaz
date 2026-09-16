import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calculator/calculator_tracker.dart';
import 'package:qaza_namaz/features/calculator/qaza_calculation.dart';

QazaRecord _record({required PrayerType prayer, required DateTime date}) {
  return QazaRecord(
    id: 'u1_${prayer.name}_${date.year}-${date.month}-${date.day}',
    userId: 'u1',
    prayerType: prayer,
    originalDate: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final calculation = calculateQaza(
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 4),
  );

  test('tracker expansion matches calculated days and five daily prayers', () {
    expect(trackerDates(calculation).toList(), [
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 2),
      DateTime(2024, 1, 3),
    ]);
    expect(trackerPrayerTypes(includeWitr: false), [
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ]);
    expect(trackerRecordCount(calculation), 15);
  });

  test('calculator overlap analysis counts only genuinely new combinations', () {
    final existing = [
      _record(prayer: PrayerType.fajr, date: DateTime(2024, 1, 1)),
      _record(prayer: PrayerType.zuhr, date: DateTime(2024, 1, 2)),
      _record(prayer: PrayerType.isha, date: DateTime(2024, 1, 3)),
    ];

    final analysis = analyzeTrackerCandidates(
      userId: 'u1',
      calculation: calculation,
      existingRecords: existing,
    );

    expect(analysis.total, 15);
    expect(analysis.alreadyRecorded, 3);
    expect(analysis.newCount, 12);
  });

  test('Witr expands as a separate tracker prayer when enabled', () {
    final withWitr = calculateQaza(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 3),
      includeWitr: true,
    );

    expect(trackerRecordCount(withWitr), 12);
    expect(trackerPrayerTypes(includeWitr: true).last, PrayerType.witr);

    final analysis = analyzeTrackerCandidates(
      userId: 'u1',
      calculation: withWitr,
      existingRecords: [
        _record(prayer: PrayerType.witr, date: DateTime(2024, 1, 1)),
      ],
    );

    expect(analysis.total, 12);
    expect(analysis.alreadyRecorded, 1);
    expect(analysis.newCount, 11);
  });
}
