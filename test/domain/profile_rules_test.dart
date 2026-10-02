import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/calendar/fixed_hijri_arithmetic_service.dart';
import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';

UserProfile makeProfile({
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
  final target =
      age * FixedHijriArithmeticService.daysPerYear;
  for (var offset = 0; offset <= 2500; offset++) {
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
  test('fixedMilestoneDate is a fixed Gregorian projection, not a Hijri anniversary', () {
    final dob = DateTime(2018, 11, 12);
    final projected = ProfileRules.fixedMilestoneDate(dob, 5);

    expect(
      projected,
      FixedHijriArithmeticService.projectFromBirth(
        dob: dob,
        fixedDayOffset: 5 * FixedHijriArithmeticService.daysPerYear,
      ),
    );
    expect(
      projected,
      DateTime(
        dob.year,
        dob.month,
        dob.day,
      ).add(const Duration(days: 1800)),
    );
  });

  test('pubertyDate and startPrayingDate use the same fixed arithmetic projection', () {
    final profile = makeProfile(
      dob: DateTime(2018, 11, 12),
      pubertyAge: 5,
      startPrayingAge: 6,
    );

    expect(
      ProfileRules.pubertyDate(profile),
      FixedHijriArithmeticService.projectFromBirth(
        dob: profile.dateOfBirth!,
        fixedDayOffset: 5 * 360,
      ),
    );
    expect(
      ProfileRules.startPrayingDate(profile),
      FixedHijriArithmeticService.projectFromBirth(
        dob: profile.dateOfBirth!,
        fixedDayOffset: 6 * 360,
      ),
    );
  });

  test('currentAge follows the fixed Hijri arithmetic day index', () {
    final dob = DateTime(2018, 11, 12);
    final birthIndex = FixedHijriArithmeticService.dayIndexForGregorian(dob);
    final boundary = firstGregorianDateAtOrAfterFixedAge(dob, 5);

    final boundaryIndex =
        FixedHijriArithmeticService.dayIndexForGregorian(boundary);
    final previous = boundary.subtract(const Duration(days: 1));
    final previousIndex =
        FixedHijriArithmeticService.dayIndexForGregorian(previous);

    expect(boundaryIndex - birthIndex, greaterThanOrEqualTo(5 * 360));
    expect(previousIndex - birthIndex, lessThan(5 * 360));
    expect(ProfileRules.currentAge(dob, previous), 4);
    expect(ProfileRules.currentAge(dob, boundary), 5);
  });

  test('real Hijri month length changes do not affect fixed age', () {
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
    final clampedBirthday = HijriDateService.toGregorian(
      year: sourceYear + 1,
      month: 9,
      day: 29,
    );

    expect(ProfileRules.currentAge(dob, clampedBirthday), 0);
    expect(
      ProfileRules.currentAge(
        dob,
        clampedBirthday.add(const Duration(days: 1)),
      ),
      1,
    );
  });

  test('30th Hijri DOB stays valid without target-month clamping changing Qaza age', () {
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
    final profile = makeProfile(
      dob: dob,
      pubertyAge: 1,
      startPrayingAge: 2,
    );

    expect(ProfileRules.fixedMilestoneDate(dob, 1), isNot(dob));
    expect(ProfileRules.pubertyDate(profile), isNotNull);
    expect(ProfileRules.startPrayingDate(profile), isNotNull);
    expect(
      ProfileRules.startPrayingDate(profile),
      ProfileRules.pubertyDate(profile)!.add(const Duration(days: 360)),
    );
  });

  test('integer ages map to exactly (startAge - pubertyAge) × 360 days', () {
    for (final ages in const [
      (12, 12),
      (12, 13),
      (12, 15),
      (9, 18),
    ]) {
      final duration = FixedHijriArithmeticService.durationForAges(
        pubertyAge: ages.$1,
        startPrayingAge: ages.$2,
      );
      expect(
        duration,
        (ages.$2 - ages.$1) * FixedHijriArithmeticService.daysPerYear,
      );
    }
  });

  test('profile validation rejects a start-praying age before fixed current age is reached', () {
    final dob = DateTime(2018, 11, 12);
    final profile = makeProfile(
      dob: dob,
      pubertyAge: 1,
      startPrayingAge: 2,
    );
    final beforeStart = firstGregorianDateAtOrAfterFixedAge(dob, 1)
        .subtract(const Duration(days: 1));

    final validation = ProfileRules.validate(
      profile,
      today: beforeStart,
    );

    expect(
      validation.error,
      ProfileValidationError.startPrayingAgeInvalid,
    );
  });

  test('available age controls only expose reached, materializable milestones', () {
    final today = DateTime(2026, 10, 1);
    final dob = DateTime(2000, 1, 1);
    final profile = makeProfile(
      dob: dob,
      pubertyAge: 12,
      startPrayingAge: 15,
    );

    expect(
      ProfileRules.availablePubertyAgeOptions(profile, today: today),
      isNotEmpty,
    );
    expect(
      ProfileRules.startPrayingAgeOptions(profile, today: today),
      contains(15),
    );
    expect(
      ProfileRules.startPrayingAgeOptions(profile, today: today),
      everyElement(isA<int>()),
    );
  });

  test('normalization clears invalid fixed-arithmetic milestone ages', () {
    final profile = makeProfile(
      dob: DateTime(2026, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
    );

    final normalized = ProfileRules.normalize(profile);
    expect(normalized.pubertyAge, isNull);
    expect(normalized.startPrayingAge, isNull);
  });
}
