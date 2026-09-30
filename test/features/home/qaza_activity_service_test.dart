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
  Iterable<PrayerType>? prayerTypes;

  @override
  Future<List<QazaActivityRow>> getCompletedActivityRows({
    required String userId,
    required DateTime from,
    required DateTime toExclusive,
    Iterable<PrayerType>? prayerTypes,
  }) async {
    this.from = from;
    this.toExclusive = toExclusive;
    this.prayerTypes = prayerTypes;
    return rows;
  }
}

const _allPrayers = PrayerType.values;

void main() {
  group('QazaActivityService', () {
    test('week is Sunday through Saturday', () async {
      for (final date in [
        DateTime(2026, 9, 27),
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 3),
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

      final repo = _FakeActivityRepository();
      final service = QazaActivityService(
        repo,
        enabledPrayerTypes: _allPrayers,
      );
      final period = await service.buildWeek(
        userId: 'local',
        selectedDate: DateTime(2026, 9, 30),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: true,
      );

      expect(period.days, hasLength(7));
      expect(period.fullTarget, 35);
      expect(period.remainingTarget, 35);
      expect(period.progress, 0);
      expect(repo.from, DateTime(2026, 9, 27));
      expect(repo.toExclusive, DateTime(2026, 10, 4));
    });

    test('week handles year boundary', () {
      expect(
        QazaActivityService.calendarWeekStartForDate(DateTime(2027, 1, 1)),
        DateTime(2026, 12, 27),
      );
      expect(
        QazaActivityService.calendarWeekEndExclusiveForDate(
          DateTime(2027, 1, 1),
        ),
        DateTime(2027, 1, 3),
      );
    });

    test('weekly target is daily target times seven', () {
      expect(QazaActivityService.weeklyTargetFromDailyTarget(5), 35);
      expect(QazaActivityService.weeklyTargetFromDailyTarget(0), 0);
      expect(QazaActivityService.weeklyTargetFromDailyTarget(-1), 0);
    });

    test('future dates remain visible but are excluded from activity and target-to-date', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: true,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.days, hasLength(7));
      expect(period.days.where((day) => day.isFuture), hasLength(3));
      expect(period.days.map((day) => day.target), everyElement(5));
      expect(period.fullTarget, 35);
      expect(period.remainingTarget, 35);
      expect(period.progress, 0);
      expect(period.days[4].remaining, 5);
    });

    test('completed records after today cannot create future activity', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 10, 1, 8),
            prayerType: PrayerType.fajr,
          ),
        ],
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: true,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.totalCompleted, 0);
      expect(period.dayFor(DateTime(2026, 10, 1))?.isFuture, isTrue);
    });

    test('historical period has activity but no reconstructed target', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 20, 10),
            prayerType: PrayerType.fajr,
          ),
        ],
        from: DateTime(2026, 9, 20),
        toExclusive: DateTime(2026, 9, 27),
        today: DateTime(2026, 9, 30),
        dailyTarget: 10,
        targetAvailable: false,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.totalCompleted, 1);
      expect(period.targetAvailable, isFalse);
      expect(period.fullTarget, isNull);
      expect(period.remainingTarget, isNull);
      expect(period.days.every((day) => day.target == 0), isTrue);
    });

    test('period remaining uses full target, not elapsed days', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 30, 9),
            prayerType: PrayerType.fajr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 30, 10),
            prayerType: PrayerType.zuhr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 30, 11),
            prayerType: PrayerType.asr,
          ),
        ],
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: true,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.totalCompleted, 3);
      expect(period.fullTarget, 35);
      expect(period.remainingTarget, 32);
      expect(period.progress, closeTo(3 / 35, 0.0001));
    });

    test('period remaining clamps at zero when completed exceeds target', () {
      final rows = List.generate(
        40,
        (_) => QazaActivityRow(
          completedAt: DateTime(2026, 9, 30, 9),
          prayerType: PrayerType.fajr,
        ),
      );
      final period = QazaActivityService.buildPeriodFromRows(
        rows: rows,
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: true,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.fullTarget, 35);
      expect(period.remainingTarget, 0);
    });

    test('monthly period uses calendar month lengths', () {
      for (final month in [
        DateTime(2026, 2),
        DateTime(2028, 2),
        DateTime(2026, 4),
        DateTime(2026, 1),
      ]) {
        final period = QazaActivityService.buildPeriodFromRows(
          rows: const [],
          from: month,
          toExclusive: DateTime(month.year, month.month + 1),
          today: DateTime(2028, 12, 31),
          dailyTarget: 5,
          targetAvailable: true,
          enabledPrayerTypes: _allPrayers,
        );

        expect(
          period.days,
          hasLength(DateTime(month.year, month.month + 1, 0).day),
        );
      }

      final feb2028 = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2028, 2),
        toExclusive: DateTime(2028, 3),
        today: DateTime(2028, 2, 15),
        dailyTarget: 5,
        targetAvailable: true,
        enabledPrayerTypes: _allPrayers,
      );
      expect(feb2028.fullTarget, 145);
      expect(feb2028.remainingTarget, 75);
    });

    test('year is exactly twelve monthly buckets with active metrics', () {
      final period = QazaActivityService.buildYearFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 1, 3),
            prayerType: PrayerType.fajr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 1, 4),
            prayerType: PrayerType.zuhr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 3, 10),
            prayerType: PrayerType.witr,
          ),
          QazaActivityRow(
            completedAt: DateTime(2026, 10, 1),
            prayerType: PrayerType.fajr,
          ),
        ],
        from: DateTime(2026, 1, 1),
        toExclusive: DateTime(2027, 1, 1),
        today: DateTime(2026, 9, 30),
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.days, hasLength(12));
      expect(period.days[0].completed, 2);
      expect(period.days[2].completed, 1);
      expect(period.days[9].completed, 0);
      expect(period.days[9].isFuture, isTrue);
      expect(period.activeDays, 3);
      expect(period.activeMonths, 2);
      expect(period.targetAvailable, isFalse);
    });

    test('historical Witr activity remains visible', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: DateTime(2026, 9, 20, 10),
            prayerType: PrayerType.witr,
          ),
        ],
        from: DateTime(2026, 9, 20),
        toExclusive: DateTime(2026, 9, 21),
        today: DateTime(2026, 9, 30),
        dailyTarget: 5,
        targetAvailable: false,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.days.single.byPrayer[PrayerType.witr], 1);
    });

    test('completion activity follows completedAt local date', () {
      final completedAt = DateTime.utc(2026, 9, 28, 23, 30);
      final local = completedAt.toLocal();
      final expected = DateTime(local.year, local.month, local.day);

      final period = QazaActivityService.buildPeriodFromRows(
        rows: [
          QazaActivityRow(
            completedAt: completedAt,
            prayerType: PrayerType.fajr,
          ),
        ],
        from: expected,
        toExclusive: DateTime(expected.year, expected.month, expected.day + 1),
        today: expected,
        dailyTarget: 1,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.days.single.date, expected);
      expect(period.days.single.completed, 1);
    });

    test('zero target does not create goals', () {
      final period = QazaActivityService.buildPeriodFromRows(
        rows: const [],
        from: DateTime(2026, 9, 30),
        toExclusive: DateTime(2026, 10, 1),
        today: DateTime(2026, 9, 30),
        dailyTarget: 0,
        enabledPrayerTypes: _allPrayers,
      );

      expect(period.days.single.hasGoal, isFalse);
      expect(period.days.single.goalReached, isFalse);
      expect(period.fullTarget, isNull);
      expect(period.remainingTarget, isNull);
    });
  });
}
