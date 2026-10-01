import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';

UserProfile makeProfile({
  required DateTime dob,
  required int pubertyAge,
  required int startPrayingAge,
}) => UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: dob,
      pubertyAge: pubertyAge,
      startPrayingAge: startPrayingAge,
      witrIncluded: true,
    );

void main() {
  test('anniversaryDate follows Hijri years rather than Gregorian years', () {
    final dob = DateTime(2018, 11, 12);

    expect(HijriDateService.fromGregorian(dob).year, 1440);
    expect(HijriDateService.fromGregorian(dob).month, 3);
    expect(HijriDateService.fromGregorian(dob).day, 4);

    final anniversary = ProfileRules.anniversaryDate(dob, 5);

    expect(anniversary, DateTime(2023, 9, 19));
    expect(anniversary, isNot(DateTime(2023, 11, 12)));

    final anniversaryHijri = HijriDateService.fromGregorian(anniversary);
    expect(anniversaryHijri.year, 1445);
    expect(anniversaryHijri.month, 3);
    expect(anniversaryHijri.day, 4);
  });

  test('pubertyDate and startPrayingDate share Hijri anniversary logic', () {
    final profile = makeProfile(
      dob: DateTime(2018, 11, 12),
      pubertyAge: 5,
      startPrayingAge: 6,
    );

    expect(
      ProfileRules.pubertyDate(profile),
      ProfileRules.anniversaryDate(profile.dateOfBirth!, 5),
    );
    expect(
      ProfileRules.startPrayingDate(profile),
      ProfileRules.anniversaryDate(profile.dateOfBirth!, 6),
    );

    final pubertyHijri =
        HijriDateService.fromGregorian(ProfileRules.pubertyDate(profile)!);
    final dobHijri = HijriDateService.fromGregorian(profile.dateOfBirth!);
    expect(pubertyHijri.year, dobHijri.year + profile.pubertyAge!);
    expect(pubertyHijri.month, dobHijri.month);
    expect(pubertyHijri.day, dobHijri.day);
  });

  test('currentAge changes on the Hijri birthday, not the Gregorian birthday', () {
    final dob = DateTime(2018, 11, 12);
    final hijriBirthday = ProfileRules.anniversaryDate(dob, 5);

    expect(
      ProfileRules.currentAge(
        dob,
        hijriBirthday.subtract(const Duration(days: 1)),
      ),
      4,
    );
    expect(ProfileRules.currentAge(dob, hijriBirthday), 5);
    expect(
      ProfileRules.currentAge(
        dob,
        hijriBirthday.add(const Duration(days: 1)),
      ),
      5,
    );

    expect(ProfileRules.currentAge(dob, DateTime(2023, 10, 1)), 5);
  });

  test('Ramadan 30th birthday clamps to Ramadan 29th when the next Ramadan is 29 days', () {
    int? sourceYear;
    for (var year = 1400; year < 1499; year++) {
      if (HijriDateService.daysInMonth(year: year, month: 9) == 30 &&
          HijriDateService.daysInMonth(year: year + 1, month: 9) == 29) {
        sourceYear = year;
        break;
      }
    }

    expect(sourceYear, isNotNull);
    final resolvedYear = sourceYear;
    if (resolvedYear == null) {
      fail('Could not find a Ramadan 30-to-29 transition.');
    }

    final dob = HijriDateService.toGregorian(
      year: resolvedYear,
      month: 9,
      day: 30,
    );
    final anniversary = ProfileRules.anniversaryDate(dob, 1);
    final hijri = HijriDateService.fromGregorian(anniversary);

    expect(hijri.year, resolvedYear + 1);
    expect(hijri.month, 9);
    expect(hijri.day, 29);
  });

  test('currentAge handles a Hijri 30th birthday clamped to a 29-day month', () {
    int? sourceYear;
    int? month;

    for (var year = 1400; year < 1499 && sourceYear == null; year++) {
      for (var candidateMonth = 1; candidateMonth <= 12; candidateMonth++) {
        if (HijriDateService.daysInMonth(year: year, month: candidateMonth) == 30 &&
            HijriDateService.daysInMonth(
                  year: year + 1,
                  month: candidateMonth,
                ) ==
                29) {
          sourceYear = year;
          month = candidateMonth;
          break;
        }
      }
    }

    expect(sourceYear, isNotNull);
    expect(month, isNotNull);

    final resolvedSourceYear = sourceYear;
    final resolvedMonth = month;
    if (resolvedSourceYear == null || resolvedMonth == null) {
      fail('Could not find a Hijri 30-to-29 month transition.');
    }

    final dob = HijriDateService.toGregorian(
      year: resolvedSourceYear,
      month: resolvedMonth,
      day: 30,
    );
    final clampedBirthday = HijriDateService.toGregorian(
      year: resolvedSourceYear + 1,
      month: resolvedMonth,
      day: 29,
    );

    expect(ProfileRules.currentAge(dob, clampedBirthday), 1);
    expect(
      ProfileRules.currentAge(
        dob,
        clampedBirthday.subtract(const Duration(days: 1)),
      ),
      0,
    );
  });

  test('profile validation uses Hijri current age for start-praying age', () {
    final dob = DateTime(2018, 11, 12);
    final age12Birthday = ProfileRules.anniversaryDate(dob, 12);
    final age13Birthday = ProfileRules.anniversaryDate(dob, 13);
    final profile = makeProfile(
      dob: dob,
      pubertyAge: 12,
      startPrayingAge: 13,
    );

    final beforeStartBirthday = ProfileRules.validate(
      profile,
      today: age12Birthday.add(const Duration(days: 1)),
    );
    expect(
      beforeStartBirthday.error,
      ProfileValidationError.startPrayingAgeInvalid,
    );

    final onStartBirthday = ProfileRules.validate(
      profile,
      today: age13Birthday,
    );
    expect(onStartBirthday.isValid, isTrue);
  });
}