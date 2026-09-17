import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';

QazaRecord _record(PrayerType prayer, DateTime date) => QazaRecord(
      id: 'u1_${prayer.name}_${date.millisecondsSinceEpoch}',
      userId: 'u1',
      prayerType: prayer,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  test('month availability disables only dates with every prayer recorded', () {
    const service = QazaAvailabilityService();
    final january = DateTime(2026, 1, 1);

    final allSixForSecond = [
      for (final prayer in PrayerType.values)
        _record(prayer, DateTime(2026, 1, 2)),
    ];
    final partial = [
      _record(PrayerType.fajr, DateTime(2026, 1, 3)),
      _record(PrayerType.zuhr, DateTime(2026, 1, 3)),
    ];

    final unavailable = service.unavailableDatesForMonth(
      userId: 'u1',
      month: january,
      existingRecords: [...allSixForSecond, ...partial],
    );

    expect(unavailable, contains(DateTime(2026, 1, 2)));
    expect(unavailable, isNot(contains(DateTime(2026, 1, 3))));
    expect(unavailable, isNot(contains(DateTime(2026, 1, 4))));
  });
}
