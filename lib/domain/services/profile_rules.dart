import '../../core/calendar/fixed_hijri_arithmetic_service.dart';
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

  /// Returns puberty ages that have both been reached by [today] under the
  /// fixed arithmetic model and can be materialized as non-future Gregorian
  /// ledger boundaries.
  static List<int> availablePubertyAgeOptions(
    UserProfile profile, {
    required DateTime today,
  }) {
    final options = pubertyAgeOptions(profile.gender);
    final dob = profile.dateOfBirth;
    if (dob == null) return options;
    return [
      for (final age in options)
        if (_milestoneReachedAndMaterialized(
          dob: dob,
          age: age,
          today: today,
        ))
          age,
    ];
  }

  /// Returns start-praying ages that remain mutually consistent with the
  /// selected puberty age and today's fixed arithmetic age.
  static List<int> startPrayingAgeOptions(
    UserProfile profile, {
    required DateTime today,
  }) {
    final dob = profile.dateOfBirth;
    final puberty = profile.pubertyAge;
    if (dob == null || puberty == null) return const <int>[];

    final maxAge = currentAge(dob, today);
    if (maxAge < puberty) return const <int>[];

    return [
      for (var age = puberty; age <= maxAge; age++)
        if (_milestoneReachedAndMaterialized(
          dob: dob,
          age: age,
          today: today,
        ))
          age,
    ];
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

  /// Returns the deterministic Gregorian projection of a fixed-arithmetic
  /// birth milestone. This is not a real Hijri calendar anniversary.
  static DateTime fixedMilestoneDate(DateTime dob, int age) =>
      FixedHijriArithmeticService.projectFromBirth(
        dob: dob,
        fixedDayOffset: age * FixedHijriArithmeticService.daysPerYear,
      );

  /// Backward-compatible alias retained for existing callers.
  @Deprecated('Use fixedMilestoneDate instead.')
  static DateTime anniversaryDate(DateTime dob, int age) =>
      fixedMilestoneDate(dob, age);

  /// Returns completed age from the fixed Hijri arithmetic day index.
  static int currentAge(DateTime dob, DateTime today) =>
      FixedHijriArithmeticService.currentAge(dob, today);

  static DateTime? pubertyDate(UserProfile profile) {
    final dob = profile.dateOfBirth;
    final age = profile.pubertyAge;
    if (dob == null || age == null) return null;
    return fixedMilestoneDate(dob, age);
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

    final pubertyDateValue = pubertyDate(profile);
    if (pubertyDateValue == null ||
        !_milestoneReachedAndMaterialized(
          dob: dob,
          age: puberty,
          today: today,
        )) {
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
        !_milestoneReachedAndMaterialized(
          dob: dob,
          age: startAge,
          today: today,
        ) ||
        _compareCalendarDates(startDateValue, pubertyDateValue) < 0) {
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
    final validGender = next.gender;
    final validPuberty = next.pubertyAge;
    if (dob != null && validGender != null && validPuberty != null) {
      final today = LocalDateService.today();
      final maxAge = currentAge(dob, today);
      if (!isPubertyAgeAllowed(validGender, validPuberty) ||
          validPuberty > maxAge ||
          !_milestoneReachedAndMaterialized(
            dob: dob,
            age: validPuberty,
            today: today,
          )) {
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
      if (normalizedStart < normalizedPuberty ||
          normalizedStart > maxStart ||
          !_milestoneReachedAndMaterialized(
            dob: normalizedDob,
            age: normalizedStart,
            today: today,
          )) {
        next = next.copyWith(clearStartPrayingAge: true);
      }
    }

    return next;
  }

  static bool _milestoneReachedAndMaterialized({
    required DateTime dob,
    required int age,
    required DateTime today,
  }) {
    final birthIndex = FixedHijriArithmeticService.dayIndexForGregorian(dob);
    final todayIndex = FixedHijriArithmeticService.dayIndexForGregorian(today);
    final milestoneIndex =
        birthIndex + age * FixedHijriArithmeticService.daysPerYear;
    if (milestoneIndex > todayIndex) return false;

    final projected = fixedMilestoneDate(dob, age);
    return _compareCalendarDates(projected, today) <= 0;
  }

  static int _compareCalendarDates(DateTime a, DateTime b) =>
      LocalDateService.compareCalendarDates(a, b);
}
