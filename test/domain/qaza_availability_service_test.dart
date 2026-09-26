import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) {
  final stamp = DateTime(2026, 9, 26, 12);
  return QazaRecord(
    id: id,
    userId: 'guest',
    prayerType: prayer,
    originalDate: date,
    status: status,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  const service = QazaAvailabilityService();

  test('identity normalizes DateTime to the Gregorian calendar day', () {
    final key = QazaPrayerKey(
      userId: 'guest',
      date: DateTime(2026, 9, 1),
      prayerType: PrayerType.fajr,
    );

    final normalized = QazaPrayerKey.fromRecord(
      _record(
        id: 'a',
        prayer: PrayerType.fajr,
        date: DateTime(2026, 9, 1, 23, 59),
      ),
    );

    expect(normalized, key);
  });

  test('pending and completed records are both already added', () {
    final pending = _record(
      id: 'pending',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 1),
    );
    final completed = _record(
      id: 'completed',
      prayer: PrayerType.zuhr,
      date: DateTime(2026, 9, 1),
      status: QazaStatus.completed,
    );

    expect(
      service.eligibility(
        userId: 'guest',
        date: pending.originalDate,
        prayerType: PrayerType.fajr,
        existingRecords: [pending],
      ),
      QazaEligibility.alreadyRecorded,
    );
    expect(
      service.eligibility(
        userId: 'guest',
        date: completed.originalDate,
        prayerType: PrayerType.zuhr,
        existingRecords: [completed],
      ),
      QazaEligibility.alreadyPrayed,
    );
  });

  test('soft-deleted combination remains occupied for new Add Qaza', () {
    final deleted = _record(
      id: 'deleted',
      prayer: PrayerType.asr,
      date: DateTime(2026, 9, 2),
      status: QazaStatus.deleted,
    );

    expect(
      service.recordedKeys([deleted]).contains(
        QazaPrayerKey(
          userId: 'guest',
          date: DateTime(2026, 9, 2),
          prayerType: PrayerType.asr,
        ),
      ),
      isTrue,
    );
  });

  test('one existing prayer does not make the whole date unavailable', () {
    final existing = _record(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 3),
    );

    expect(
      service.isDateAvailable(
        userId: 'guest',
        date: existing.originalDate,
        existingRecords: [existing],
        prayerTypes: PrayerType.values,
      ),
      isTrue,
    );
  });

  test('analysis counts exact Date + Prayer combinations', () {
    final existing = _record(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 4),
    );

    final result = service.analyze(
      userId: 'guest',
      dates: [
        DateTime(2026, 9, 4, 8),
        DateTime(2026, 9, 4, 22),
      ],
      prayerTypes: [
        PrayerType.fajr,
        PrayerType.zuhr,
      ],
      existingRecords: [existing],
    );

    expect(result.total, 2);
    expect(result.alreadyRecorded, 1);
    expect(result.newCount, 1);
    expect(result.existingCandidates, hasLength(1));
    expect(result.newCandidates, hasLength(1));
  });
}
