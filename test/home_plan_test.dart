import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/home/home_state.dart';

void main() {
  group('Home Qaza plan estimates', () {
    test('default daily target is five', () {
      expect(HomeQazaPlanState.defaultDailyTarget, 5);
    });

    test('uses remaining capacity today before future days', () {
      final now = DateTime(2026, 9, 21);

      expect(
        homeDaysUntilCompletion(
          pending: 1,
          dailyTarget: 5,
          completedToday: 0,
        ),
        0,
      );

      expect(
        homeDaysUntilCompletion(
          pending: 6,
          dailyTarget: 5,
          completedToday: 0,
        ),
        1,
      );

      expect(
        homeDaysUntilCompletion(
          pending: 6,
          dailyTarget: 5,
          completedToday: 4,
        ),
        1,
      );

      expect(
        homeDaysUntilCompletion(
          pending: 6,
          dailyTarget: 5,
          completedToday: 5,
        ),
        2,
      );

      expect(
        homeDaysUntilCompletion(
          pending: 4,
          dailyTarget: 5,
          completedToday: 0,
        ),
        0,
      );

      expect(
        homeDaysUntilCompletion(
          pending: 0,
          dailyTarget: 5,
          completedToday: 0,
        ),
        0,
      );

      expect(
        homeEstimatedCompletionDate(
          now: now,
          pending: 11,
          dailyTarget: 5,
          completedToday: 0,
        ),
        DateTime(2026, 9, 23),
      );

      expect(
        homeEstimatedCompletionDate(
          now: DateTime(2026, 9, 21, 23, 45),
          pending: 6,
          dailyTarget: 5,
          completedToday: 5,
        ),
        DateTime(2026, 9, 23),
      );
    });
  });
}
