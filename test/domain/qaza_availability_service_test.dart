import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/current_day_qaza_eligibility_service.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';

QazaRecord _record({
  required String id,
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
  String? additionId,
  int recordVersion = 1,
}) {
  final stamp = DateTime(2026, 9, 26, 12);
  return QazaRecord(
    id: id,
    userId: 'guest',
    prayerType: prayer,
    originalDate: date,
    status: status,
    additionId: additionId,
    recordVersion: recordVersion,
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

  test(
      'edit context distinguishes editable, protected, and other-addition records',
      () {
    final date = DateTime(2026, 9, 10);
    final currentPending = _record(
      id: 'current-pending',
      prayer: PrayerType.fajr,
      date: date,
      additionId: 'current',
    );
    final currentCompleted = _record(
      id: 'current-completed',
      prayer: PrayerType.zuhr,
      date: date,
      status: QazaStatus.completed,
      additionId: 'current',
    );
    final currentVersioned = _record(
      id: 'current-versioned',
      prayer: PrayerType.asr,
      date: date,
      additionId: 'current',
      recordVersion: 2,
    );
    final other = _record(
      id: 'other',
      prayer: PrayerType.maghrib,
      date: date,
      additionId: 'other',
    );

    final result = service.analyze(
      userId: 'guest',
      dates: [date],
      prayerTypes: [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ],
      existingRecords: [
        currentPending,
        currentCompleted,
        currentVersioned,
        other,
      ],
      editingAdditionId: 'current',
    );

    final pendingKey = QazaPrayerKey.fromRecord(currentPending);
    final completedKey = QazaPrayerKey.fromRecord(currentCompleted);
    final versionedKey = QazaPrayerKey.fromRecord(currentVersioned);
    final otherKey = QazaPrayerKey.fromRecord(other);

    expect(result.currentAdditionEditableCandidates, contains(pendingKey));
    expect(result.currentAdditionProtectedCandidates, contains(completedKey));
    expect(result.currentAdditionProtectedCandidates, contains(versionedKey));
    expect(result.currentAdditionEditableCandidates, isNot(contains(otherKey)));
    expect(
        result.currentAdditionProtectedCandidates, isNot(contains(otherKey)));
    expect(
        result.newCandidates,
        contains(
          QazaPrayerKey(
            userId: 'guest',
            date: date,
            prayerType: PrayerType.isha,
          ),
        ));
  });
  CurrentDayQazaPrayerTimeContext context({
    required DateTime now,
    bool hasSchedule = true,
  }) =>
      CurrentDayQazaPrayerTimeContext(
        localNow: now,
        localToday: DateTime(2026, 10, 3),
        cutoffByPrayer: {
          PrayerType.fajr: DateTime(2026, 10, 3, 6),
          PrayerType.zuhr: DateTime(2026, 10, 3, 15, 30),
          PrayerType.asr: DateTime(2026, 10, 3, 18),
          PrayerType.maghrib: DateTime(2026, 10, 3, 19, 30),
          PrayerType.isha: DateTime(2026, 10, 4, 5),
          PrayerType.witr: DateTime(2026, 10, 4, 5),
        },
        hasSchedule: hasSchedule,
      );

  test('time-blocked current-day combinations are unavailable, not new', () {
    final result = service.analyze(
      userId: 'guest',
      dates: [DateTime(2026, 10, 3)],
      prayerTypes: [PrayerType.fajr],
      existingRecords: const [],
      prayerTimeContext: context(
        now: DateTime(2026, 10, 3, 5, 59),
      ),
    );

    expect(result.newCount, 0);
    expect(result.existingCandidates, isEmpty);
    expect(result.unavailableCount, 1);
    expect(result.newCandidates, isEmpty);
  });

  test('already-recorded prayer remains existing even when its time is blocked',
      () {
    final existing = _record(
      id: 'fajr-today',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 10, 3),
    );

    final result = service.analyze(
      userId: 'guest',
      dates: [DateTime(2026, 10, 3)],
      prayerTypes: [PrayerType.fajr],
      existingRecords: [existing],
      prayerTimeContext: context(
        now: DateTime(2026, 10, 3, 5, 59),
      ),
    );

    expect(result.alreadyRecorded + result.alreadyPrayed, 1);
    expect(result.unavailableCount, 1);
    expect(result.newCount, 0);
    expect(
      service.eligibility(
        userId: 'guest',
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.fajr,
        existingRecords: [existing],
        prayerTimeContext: context(
          now: DateTime(2026, 10, 3, 5, 59),
        ),
      ),
      QazaEligibility.alreadyRecorded,
    );
  });

  test('historical date remains available with current-day context', () {
    expect(
      service.eligibility(
        userId: 'guest',
        date: DateTime(2026, 10, 2),
        prayerType: PrayerType.fajr,
        prayerTimeContext: context(
          now: DateTime(2026, 10, 3, 5),
        ),
      ),
      QazaEligibility.available,
    );
  });

  test('missing current-day schedule is never treated as available', () {
    expect(
      service.eligibility(
        userId: 'guest',
        date: DateTime(2026, 10, 3),
        prayerType: PrayerType.fajr,
        prayerTimeContext: context(
          now: DateTime(2026, 10, 3, 12),
          hasSchedule: false,
        ),
      ),
      QazaEligibility.timeDataUnavailable,
    );
  });
}
