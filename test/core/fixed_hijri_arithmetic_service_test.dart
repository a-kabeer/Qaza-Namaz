import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/calendar/fixed_hijri_arithmetic_service.dart';
import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

UserProfile _profile({
  required DateTime dob,
  required int pubertyAge,
  required int startPrayingAge,
}) =>
    UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: dob,
      pubertyAge: pubertyAge,
      startPrayingAge: startPrayingAge,
      witrIncluded: true,
    );

DateTime firstGregorianDateAtOrAfterFixedAge(
  DateTime dob,
  int age,
) {
  final target = age * FixedHijriArithmeticService.daysPerYear;
  for (var offset = 0; offset <= 6000; offset++) {
    final candidate = dob.add(Duration(days: offset));
    if (FixedHijriArithmeticService.dayIndexForGregorian(candidate) -
            FixedHijriArithmeticService.dayIndexForGregorian(dob) >=
        target) {
      return candidate;
    }
  }
  throw StateError('Could not find a fixed arithmetic age boundary.');
}

void main() {
  test('fixed arithmetic uses 30-day months and 360-day years', () {
    expect(
      FixedHijriArithmeticService.dayIndex(
        year: 1445,
        month: 10,
        day: 1,
      ) -
          FixedHijriArithmeticService.dayIndex(
            year: 1444,
            month: 10,
            day: 1,
          ),
      360,
    );

    final duration = FixedHijriArithmeticService.splitElapsedDays(725);
    expect(duration.years, 2);
    expect(duration.months, 0);
    expect(duration.remainingDays, 5);
    expect(duration.totalDays, 725);
  });

  test('30-to-29 real Hijri month transition does not change fixed age or Qaza count', () {
    int? sourceYear;
    for (var year = 1400; year < 1499; year++) {
      if (HijriDateService.daysInMonth(year: year, month: 9) == 30 &&
          HijriDateService.daysInMonth(year: year + 1, month: 9) == 29) {
        sourceYear = year;
        break;
      }
    }

    expect(sourceYear, isNotNull);
    final year = sourceYear!;
    final dob = HijriDateService.toGregorian(
      year: year,
      month: 9,
      day: 30,
    );
    final clampedBirthday = HijriDateService.toGregorian(
      year: year + 1,
      month: 9,
      day: 29,
    );

    expect(ProfileRules.currentAge(dob, clampedBirthday), 0);
    expect(ProfileRules.currentAge(
      dob,
      clampedBirthday.add(const Duration(days: 1)),
    ), 1);

    final profile = _profile(
      dob: dob,
      pubertyAge: 12,
      startPrayingAge: 15,
    );
    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.totalDays, 3 * FixedHijriArithmeticService.daysPerYear);
  });

  test('30th Hijri DOB remains valid without target-month clamping', () {
    int? sourceYear;
    for (var year = 1400; year < 1499; year++) {
      if (HijriDateService.daysInMonth(year: year, month: 9) == 30 &&
          HijriDateService.daysInMonth(year: year + 1, month: 9) == 29) {
        sourceYear = year;
        break;
      }
    }

    expect(sourceYear, isNotNull);
    final dob = HijriDateService.toGregorian(
      year: sourceYear!,
      month: 9,
      day: 30,
    );
    final profile = _profile(
      dob: dob,
      pubertyAge: 12,
      startPrayingAge: 13,
    );

    expect(ProfileRules.pubertyDate(profile), isNotNull);
    expect(ProfileRules.startPrayingDate(profile), isNotNull);

    final plan = const QazaPlanService().planFor(profile);
    expect(plan, isNotNull);
    expect(plan!.totalDays, FixedHijriArithmeticService.daysPerYear);
    expect(plan.totalPrayers, 5 * FixedHijriArithmeticService.daysPerYear);
    expect(plan.witrCount, FixedHijriArithmeticService.daysPerYear);
    expect(plan.totalWithWitr, 6 * FixedHijriArithmeticService.daysPerYear);
    expect(
      plan.prayerBreakdown.values.fold<int>(0, (sum, value) => sum + value),
      5 * FixedHijriArithmeticService.daysPerYear,
    );

    expect(
      plan.startDate,
      ProfileRules.pubertyDate(profile),
    );
  });

  test('Qaza duration is fixed 360-day arithmetic, not Gregorian elapsed years', () {
    final dob = DateTime(2000, 1, 1);
    final profile = _profile(
      dob: dob,
      pubertyAge: 12,
      startPrayingAge: 15,
    );
    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.totalDays, 1080);
    expect(
      plan.endDate,
      plan.startDate.add(const Duration(days: 1080)),
    );
    expect(
      FixedHijriArithmeticService.durationForAges(
        pubertyAge: 12,
        startPrayingAge: 15,
      ),
      1080,
    );
  });

  test('current-age validation uses the fixed Hijri day index', () {
    final dob = DateTime(2018, 11, 12);

    final birthIndex = FixedHijriArithmeticService.dayIndexForGregorian(dob);
    final oneYearBoundary = birthIndex +
        FixedHijriArithmeticService.daysPerYear;
    final boundaryDifference = oneYearBoundary - birthIndex;
    expect(boundaryDifference, 360);

    final profile = _profile(
      dob: dob,
      pubertyAge: 1,
      startPrayingAge: 2,
    );

    final beforeStart =
        firstGregorianDateAtOrAfterFixedAge(dob, 13).subtract(
      const Duration(days: 1),
    );
    final onStart = firstGregorianDateAtOrAfterFixedAge(dob, 2);

    expect(
      FixedHijriArithmeticService.dayIndexForGregorian(beforeStart) -
          FixedHijriArithmeticService.dayIndexForGregorian(dob),
      lessThan(2 * 360),
    );
    expect(
      FixedHijriArithmeticService.dayIndexForGregorian(onStart) -
          FixedHijriArithmeticService.dayIndexForGregorian(dob),
      greaterThanOrEqualTo(2 * 360),
    );
    expect(ProfileRules.currentAge(dob, beforeStart), lessThan(2));
    expect(ProfileRules.currentAge(dob, onStart), greaterThanOrEqualTo(2));
  });

  test('changing DOB, puberty age, or start-praying age recalculates consistently', () {
    final base = _profile(
      dob: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 15,
    );
    final service = const QazaPlanService();

    final first = service.planFor(base)!;
    final changedDob = service.planFor(
      base.copyWith(dateOfBirth: DateTime(1995, 1, 1)),
    )!;
    final changedPuberty = service.planFor(
      base.copyWith(pubertyAge: 13),
    )!;
    final changedStart = service.planFor(
      base.copyWith(startPrayingAge: 16),
    )!;

    expect(first.totalDays, 1080);
    expect(changedDob.totalDays, first.totalDays);
    expect(changedPuberty.totalDays, 720);
    expect(changedStart.totalDays, 1440);
    expect(changedPuberty.endDate,
        changedPuberty.startDate.add(const Duration(days: 720)));
    expect(changedStart.endDate,
        changedStart.startDate.add(const Duration(days: 1440)));
  });

  test('all Fard and Witr plan counts match exactly totalDays', () {
    final profile = _profile(
      dob: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 13,
    );
    final plan = const QazaPlanService().planFor(profile)!;

    expect(plan.totalDays, 360);
    for (final prayer in PrayerType.values) {
      final expected = prayer == PrayerType.witr ? 0 : plan.totalDays;
      expect(plan.prayerBreakdown[prayer] ?? 0, expected);
    }
    expect(plan.witrCount, plan.totalDays);
    expect(plan.totalWithWitr, plan.totalDays * 6);
  });
}
