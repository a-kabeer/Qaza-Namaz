import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/services/qaza_activity_service.dart';

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
