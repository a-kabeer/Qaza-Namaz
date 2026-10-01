import '../../core/calendar/hijri_date_service.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/time/local_date_service.dart';
import '../entities/user_profile.dart';

enum ProfileValidationError {
  languageMissing,
  genderMissing,
  madhabMissing,
  dobMissing,
  dobFuture,
  pubertyMissing,
  pubertyInvalid,
  startPrayingAgeMissing,
  startPrayingAgeInvalid,
  witrInvalid,
}

class ProfileValidation {
  const ProfileValidation({this.error});
  final ProfileValidationError? error;
  bool get isValid => error == null;
}

class ProfileRules {
  const ProfileRules._();

  static const int maleMinPubertyAge = 12;
  static const int maleMaxPubertyAge = 15;
  static const int femaleMinPubertyAge = 9;
  static const int femaleMaxPubertyAge = 15;

  static bool isPubertyAgeAllowed(Gender gender, int age) {
    final min = gender == Gender.male ? maleMinPubertyAge : femaleMinPubertyAge;
    final max = gender == Gender.male ? maleMaxPubertyAge : femaleMaxPubertyAge;
    return age >= min && age <= max;
  }

  static List<int> pubertyAgeOptions(Gender? gender) {
    if (gender == null) return const <int>[];
    final min = gender == Gender.male ? maleMinPubertyAge : femaleMinPubertyAge;
    final max = gender == Gender.male ? maleMaxPubertyAge : femaleMaxPubertyAge;
    return List<int>.generate(max - min + 1, (index) => min + index);
  }

  static bool isWitrEditable(Madhab? madhab) => madhab == Madhab.other;

  static bool effectiveWitr(UserProfile profile) {
    switch (profile.madhab) {
      case Madhab.hanafi:
        return true;
      case Madhab.shafi:
      case Madhab.maliki:
      case Madhab.hanbali:
        return false;
      case Madhab.other:
      case null:
        return profile.witrIncluded ?? false;
    }
  }

  /// Returns the prayer types that are active for the profile.
  ///
  /// Fard prayers are always available. Witr is included only when the
  /// profile's effective Witr rule allows it.
  static List<PrayerType> enabledPrayerTypes(UserProfile profile) =>
      prayerTypesForWitr(effectiveWitr(profile));

  /// Profile-independent helper used by services that only have the resolved
  /// Witr flag available.
  static List<PrayerType> prayerTypesForWitr(bool witrEnabled) => [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        if (witrEnabled) PrayerType.witr,
      ];

  /// Returns the Gregorian date on which [age] whole Hijri calendar years
  /// have elapsed from the supplied Gregorian DOB.
  static DateTime anniversaryDate(DateTime dob, int age) =>
      HijriDateService.addHijriYears(dob, age);

  /// Returns completed age measured in Hijri calendar years.
  ///
  /// The current year's anniversary is calculated with the same Hijri
  /// month/day preservation and target-month clamping used by [anniversaryDate].
  static int currentAge(DateTime dob, DateTime today) {
    final birth = HijriDateService.fromGregorian(dob);
    final now = LocalDateService.dateOnly(today);
    final nowHijri = HijriDateService.fromGregorian(now);

    var age = nowHijri.year - birth.year;
    if (age < 0) return age;

    final anniversary = HijriDateService.toGregorian(
      year: nowHijri.year,
      month: birth.month,
      day: birth.day
          .clamp(
            1,
            HijriDateService.daysInMonth(
              year: nowHijri.year,
              month: birth.month,
            ),
          )
          .toInt(),
    );

    if (LocalDateService.compareCalendarDates(anniversary, now) > 0) {
      age--;
    }
    return age;
  }

  static DateTime? pubertyDate(UserProfile profile) {
    final dob = profile.dateOfBirth;
    final age = profile.pubertyAge;
    if (dob == null || age == null) return null;
    return anniversaryDate(dob, age);
  }

  static DateTime? startPrayingDate(UserProfile profile) {
    final dob = profile.dateOfBirth;
    final age = profile.startPrayingAge;
    if (dob == null || age == null) return null;
    return anniversaryDate(dob, age);
  }

  static ProfileValidation validate(
    UserProfile profile, {
    required DateTime today,
  }) {
    if (profile.languageCode.trim().isEmpty) {
      return const ProfileValidation(
          error: ProfileValidationError.languageMissing);
    }
    final gender = profile.gender;
    if (gender == null) {
      return const ProfileValidation(
          error: ProfileValidationError.genderMissing);
    }
    if (profile.madhab == null) {
      return const ProfileValidation(
          error: ProfileValidationError.madhabMissing);
    }
    final dob = profile.dateOfBirth;
    if (dob == null) {
      return const ProfileValidation(error: ProfileValidationError.dobMissing);
    }
    if (_compareCalendarDates(dob, today) > 0) {
      return const ProfileValidation(error: ProfileValidationError.dobFuture);
    }

    final puberty = profile.pubertyAge;
    if (puberty == null) {
      return const ProfileValidation(
          error: ProfileValidationError.pubertyMissing);
    }
    if (!isPubertyAgeAllowed(gender, puberty)) {
      return const ProfileValidation(
          error: ProfileValidationError.pubertyInvalid);
    }

    // Integer age and calculated Gregorian milestone date must agree. This
    // protects the domain against a future Hijri birthday (for example when
    // a user edits DOB after selecting an age) rather than relying only on
    // the UI's available options.
    final pubertyDateValue = pubertyDate(profile);
    if (pubertyDateValue == null ||
        _compareCalendarDates(pubertyDateValue, today) > 0) {
      return const ProfileValidation(
        error: ProfileValidationError.pubertyInvalid,
      );
    }

    final startAge = profile.startPrayingAge;
    if (startAge == null) {
      return const ProfileValidation(
        error: ProfileValidationError.startPrayingAgeMissing,
      );
    }

    final currentAgeValue = currentAge(dob, today);
    final startDateValue = startPrayingDate(profile);
    if (startDateValue == null ||
        startAge < puberty ||
        startAge > currentAgeValue ||
        _compareCalendarDates(startDateValue, pubertyDateValue) < 0 ||
        _compareCalendarDates(startDateValue, today) > 0) {
      return const ProfileValidation(
        error: ProfileValidationError.startPrayingAgeInvalid,
      );
    }

    final witr = profile.witrIncluded;
    if (witr == null || witr != effectiveWitr(profile)) {
      return const ProfileValidation(error: ProfileValidationError.witrInvalid);
    }

    return const ProfileValidation();
  }

  static UserProfile normalize(UserProfile profile) {
    var next = profile;
    final normalizedDailyTarget =
        UserProfile.normalizeDailyQazaTarget(next.dailyQazaTarget);
    if (normalizedDailyTarget != next.dailyQazaTarget) {
      next = next.copyWith(dailyQazaTarget: normalizedDailyTarget);
    }
    final gender = next.gender;
    final puberty = next.pubertyAge;
    if (gender != null &&
        puberty != null &&
        !isPubertyAgeAllowed(gender, puberty)) {
      next = next.copyWith(clearPubertyAge: true, clearStartPrayingAge: true);
    }

    final madhab = next.madhab;
    if (madhab != null && !isWitrEditable(madhab)) {
      next = next.copyWith(witrIncluded: effectiveWitr(next));
    }

    final dob = next.dateOfBirth;
    final start = next.startPrayingAge;
    final validGender = next.gender;
    final validPuberty = next.pubertyAge;
    if (dob != null && validPuberty != null) {
      final today = LocalDateService.today();
      final maxAge = currentAge(dob, today);
      final pubertyDateValue = pubertyDate(next);
      if (pubertyDateValue == null ||
          _compareCalendarDates(pubertyDateValue, today) > 0 ||
          validGender == null ||
          !isPubertyAgeAllowed(validGender, validPuberty) ||
          validPuberty > maxAge) {
        next = next.copyWith(clearPubertyAge: true, clearStartPrayingAge: true);
      }
    }

    final normalizedDob = next.dateOfBirth;
    final normalizedStart = next.startPrayingAge;
    final normalizedPuberty = next.pubertyAge;
    if (normalizedDob != null &&
        normalizedStart != null &&
        normalizedPuberty != null) {
      final today = LocalDateService.today();
      final maxStart = currentAge(normalizedDob, today);
      final pubertyDateValue = pubertyDate(next);
      final startDateValue = startPrayingDate(next);
      if (startDateValue == null ||
          pubertyDateValue == null ||
          normalizedStart < normalizedPuberty ||
          normalizedStart > maxStart ||
          _compareCalendarDates(startDateValue, pubertyDateValue) < 0 ||
          _compareCalendarDates(startDateValue, today) > 0) {
        next = next.copyWith(clearStartPrayingAge: true);
      }
    }

    return next;
  }

  static int _compareCalendarDates(DateTime a, DateTime b) =>
      LocalDateService.compareCalendarDates(a, b);
}
