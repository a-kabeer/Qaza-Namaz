import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/repositories/qaza_activity_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_activity_service.dart';

class _FakeActivityRepository implements QazaActivityRepository {
  _FakeActivityRepository([this.rows = const []]);

  final List<QazaActivityRow> rows;
  DateTime? from;
  DateTime? toExclusive;

  @override
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    this.from = from;
    this.toExclusive = toExclusive;
    return rows;
  }
}

void main() {
  group('QazaActivityService aggregation', () {
    test('fills missing days and aggregates by prayer using local completion date', () {
      final completion = DateTime(2026, 9, 28, 23, 30);
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: completion,
            prayerType: PrayerType.fajr,
          ),
          QazaActivityRow(
            completedAt: completion.add(const Duration(minutes: 5)),
            prayerType: PrayerType.zuhr,
          ),
          QazaActivityRow(
            completedAt: completion.add(const Duration(minutes: 10)),
            prayerType: PrayerType.fajr,
          ),
        ],
        from: DateTime(2026, 9, 28),
        toExclusive: DateTime(2026, 9, 30),
        today: DateTime(2026, 9, 29),
        dailyTarget: 2,
        enabledPrayerTypes: const [
          PrayerType.fajr,
          PrayerType.zuhr,
        ],
      );

      expect(period.days, hasLength(2));
      expect(period.days[0].date, DateTime(2026, 9, 28));
      expect(period.days[0].completed, 3);
      expect(period.days[0].byPrayer[PrayerType.fajr], 2);
      expect(period.days[0].byPrayer[PrayerType.zuhr], 1);
      expect(period.days[0].goalReached, isTrue);
      expect(period.days[0].remaining, 0);
      expect(period.days[0].progress, 1.0);

      expect(period.days[1].completed, 0);
      expect(period.days[1].byPrayer[PrayerType.fajr], 0);
      expect(period.days[1].byPrayer[PrayerType.zuhr], 0);
    });

    test('buildRolling keeps the existing rolling seven-day semantics', () async {
      final repository = _FakeActivityRepository();
      final service = QazaActivityService(
        repository,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      final period = await service.buildRolling(
        userId: 'local',
        today: DateTime(2026, 9, 30),
        days: 7,
        dailyTarget: 5,
      );

      expect(period.days, hasLength(7));
      expect(period.days.first.date, DateTime(2026, 9, 24));
      expect(period.days.last.date, DateTime(2026, 9, 30));
      expect(repository.from, DateTime(2026, 9, 24));
      expect(repository.toExclusive, DateTime(2026, 10, 1));
    });

    test('calendar week starts on Sunday for every day Monday through Saturday', () {
      for (final date in [
        DateTime(2026, 9, 27), // Sunday
        DateTime(2026, 9, 28), // Monday
        DateTime(2026, 9, 29), // Tuesday
        DateTime(2026, 9, 30), // Wednesday
        DateTime(2026, 10, 1), // Thursday
        DateTime(2026, 10, 2), // Friday
        DateTime(2026, 10, 3), // Saturday
      ]) {
        expect(
          QazaActivityService.calendarWeekStartForDate(date),
          DateTime(2026, 9, 27),
        );
        expect(
          QazaActivityService.calendarWeekEndExclusiveForDate(date),
          DateTime(2026, 10, 4),
        );
      }
    });

    test('Sunday starts a new calendar week', () {
      expect(
        QazaActivityService.calendarWeekStartForDate(DateTime(2026, 10, 4)),
        DateTime(2026, 10, 4),
      );
      expect(
        QazaActivityService.calendarWeekEndExclusiveForDate(DateTime(2026, 10, 4)),
        DateTime(2026, 10, 11),
      );
    });

    test('calendar week contains exactly seven dates across month boundary', () {
      final repository = _FakeActivityRepository();
      final service = QazaActivityService(
        repository,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      final period = await service.buildCurrentCalendarWeek(
        userId: 'local',
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
      );

      expect(period.from, DateTime(2026, 9, 27));
      expect(period.toExclusive, DateTime(2026, 10, 4));
      expect(period.days, hasLength(7));
      expect(period.days.first.date, DateTime(2026, 9, 27));
      expect(period.days.last.date, DateTime(2026, 10, 3));
      expect(repository.from, DateTime(2026, 9, 27));
      expect(repository.toExclusive, DateTime(2026, 10, 4));
    });

    test('calendar week handles year boundary', () {
      final start = QazaActivityService.calendarWeekStartForDate(
        DateTime(2027, 1, 1),
      );
      final end = QazaActivityService.calendarWeekEndExclusiveForDate(
        DateTime(2027, 1, 1),
      );

      expect(start, DateTime(2026, 12, 27));
      expect(end, DateTime(2027, 1, 3));
      expect(end.difference(start).inDays, 7);
    });

    test('weekly target is daily target times seven and never negative', () {
      expect(QazaActivityService.weeklyTargetFromDailyTarget(5), 35);
      expect(QazaActivityService.weeklyTargetFromDailyTarget(0), 0);
      expect(QazaActivityService.weeklyTargetFromDailyTarget(-1), 0);
    });

    test('completed activity counts only records inside Sunday through Saturday', () async {
      final repository = _FakeActivityRepository([
        QazaActivityRow(
          completedAt: DateTime(2026, 9, 26, 23, 59),
          prayerType: PrayerType.fajr,
        ),
        QazaActivityRow(
          completedAt: DateTime(2026, 9, 27, 0, 0),
          prayerType: PrayerType.fajr,
        ),
        QazaActivityRow(
          completedAt: DateTime(2026, 10, 3, 23, 59),
          prayerType: PrayerType.fajr,
        ),
        QazaActivityRow(
          completedAt: DateTime(2026, 10, 4, 0, 0),
          prayerType: PrayerType.fajr,
        ),
      ]);
      final service = QazaActivityService(
        repository,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      final period = await service.buildCurrentCalendarWeek(
        userId: 'local',
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
      );

      expect(period.totalCompleted, 2);
      expect(period.dayFor(DateTime(2026, 9, 27))?.completed, 1);
      expect(period.dayFor(DateTime(2026, 10, 3))?.completed, 1);
      expect(period.dayFor(DateTime(2026, 9, 26)), isNull);
      expect(repository.from, DateTime(2026, 9, 27));
      expect(repository.toExclusive, DateTime(2026, 10, 4));
    });

    test('future days remain part of the seven-day period for weekly targeting', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      expect(period.days, hasLength(7));
      expect(period.days.where((day) => day.isFuture), hasLength(3));
      expect(period.days.map((day) => day.target), everyElement(5));
      expect(period.totalTarget, 20);
      expect(QazaActivityService.weeklyTargetFromDailyTarget(5), 35);
    });

    test('filters disabled prayer types without deleting the underlying completion projection', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 29, 10),
            prayerType: PrayerType.fajr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 29, 11),
            prayerType: PrayerType.witr,
          ),
        ],
        from: DateTime(2026, 9, 29),
        toExclusive: DateTime(2026, 9, 30),
        today: DateTime(2026, 9, 29),
        dailyTarget: 1,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      expect(period.totalCompleted, 1);
      expect(period.days.single.byPrayer.containsKey(PrayerType.witr), isFalse);
    });

    test('does not treat zero target as a reached goal', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2026, 9, 29),
        toExclusive: DateTime(2026, 9, 30),
        today: DateTime(2026, 9, 29),
        dailyTarget: 0,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      expect(period.days.single.hasGoal, isFalse);
      expect(period.days.single.goalReached, isFalse);
      expect(period.days.single.progress, 0);
      expect(period.totalTarget, 0);
    });

    test('future days do not contribute to target or goal failures', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2026, 9, 29),
        toExclusive: DateTime(2026, 10, 2),
        today: DateTime(2026, 9, 29),
        dailyTarget: 5,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      expect(period.days[0].isFuture, isFalse);
      expect(period.days[0].hasGoal, isTrue);
      expect(period.days[1].isFuture, isTrue);
      expect(period.days[1].hasGoal, isFalse);
      expect(period.days[1].goalReached, isFalse);
      expect(period.days[1].remaining, 0);
      expect(period.totalTarget, 5);
      expect(period.remaining, 5);
    });

    test('activity date follows completedAt local calendar date', () {
      final completedAt = DateTime.utc(2026, 9, 28, 23, 30);
      final localDate = completedAt.toLocal();
      final expected = DateTime(localDate.year, localDate.month, localDate.day);

      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: completedAt,
            prayerType: PrayerType.fajr,
          ),
        ],
        from: DateTime(expected.year, expected.month, expected.day),
        toExclusive: DateTime(expected.year, expected.month, expected.day + 1),
        today: expected,
        dailyTarget: 1,
        enabledPrayerTypes: const [PrayerType.fajr],
      );

      expect(period.days.single.date, expected);
      expect(period.days.single.completed, 1);
    });

    test('rejects an invalid period', () {
      expect(
        () => QazaActivityService.buildPeriodFromRows(
          rows: const [],
          from: DateTime(2026, 9, 30),
          toExclusive: DateTime(2026, 9, 30),
          today: DateTime(2026, 9, 30),
          dailyTarget: 5,
          enabledPrayerTypes: const [PrayerType.fajr],
        ),
        throwsArgumentError,
      );
    });
  });
}
