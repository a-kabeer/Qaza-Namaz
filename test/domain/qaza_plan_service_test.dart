import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

void main() {
  test('equal puberty and prayer-start ages produce a valid zero-day plan', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 12,
      witrIncluded: true,
    );

    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.totalDays, 0);
    expect(plan.totalPrayers, 0);
    expect(plan.witrCount, 0);
    expect(plan.totalWithWitr, 0);
    expect(
      plan.prayerBreakdown.values.every((count) => count == 0),
      isTrue,
    );
    expect(
      plan.prayerBreakdown.keys.where((prayer) => prayer != PrayerType.witr),
      hasLength(5),
    );
    expect(plan.startDate, plan.endDate);
  });

  test('Qaza plan duration uses exactly 360 arithmetic days per year', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2018, 11, 12),
      pubertyAge: 5,
      startPrayingAge: 6,
      witrIncluded: true,
    );

    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.totalDays, 360);
    expect(
      plan.totalDays,
      LocalDateService.calendarDayDifference(plan.startDate, plan.endDate),
    );
    expect(
      plan.endDate,
      LocalDateService.addCalendarDays(plan.startDate, plan.totalDays),
    );
    expect(plan.startDate, ProfileRules.pubertyDate(profile));
    expect(plan.endDate, ProfileRules.startPrayingDate(profile));
  });

  test('planDateAt and datesFor produce exactly totalDays consecutive dates', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
    );
    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    final dates = QazaPlanService.datesFor(plan!).toList();
    expect(dates, hasLength(plan.totalDays));
    if (dates.isNotEmpty) {
      expect(dates.first, plan.startDate);
      expect(dates.last, QazaPlanService.planDateAt(plan, plan.totalDays - 1));
      expect(
        dates.every(
          (date) => !date.isBefore(plan.startDate) &&
              date.isBefore(plan.endDate),
        ),
        isTrue,
      );
    }

    final expectedFard = plan.totalDays * 5;
    final expectedWitr = plan.includeWitr ? plan.totalDays : 0;
    expect(
      plan.prayerBreakdown.values.fold<int>(0, (sum, value) => sum + value),
      expectedFard,
    );
    expect(plan.totalPrayers, expectedFard);
    expect(plan.witrCount, expectedWitr);
    expect(plan.totalWithWitr, expectedFard + expectedWitr);
  });

  test('planDateAt rejects offsets outside startDate/endDate range', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      witrIncluded: true,
    );
    final plan = const QazaPlanService().planFor(profile)!;

    expect(() => QazaPlanService.planDateAt(plan, -1), throwsRangeError);
    expect(
      () => QazaPlanService.planDateAt(plan, plan.totalDays),
      throwsRangeError,
    );
  });
}
