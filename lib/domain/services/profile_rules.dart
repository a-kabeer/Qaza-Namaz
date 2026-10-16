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
  islamAcceptanceDateMissing,
  islamAcceptanceDateInvalid,
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
    if (profile.isNewMuslim) return const <int>[];
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

  /// Whether the user must provide a puberty age for Qaza calculation.
  ///
  /// The existing maximum puberty-age threshold is a cutoff only; puberty is
  /// never assumed to occur at that age.
  static bool requiresPubertyInput(UserProfile profile) {
    if (!profile.isNewMuslim) return true;
    final dob = profile.dateOfBirth;
    final acceptedDate = profile.islamAcceptanceDate;
    final gender = profile.gender;
    if (dob == null || acceptedDate == null || gender == null) return true;
    final maximumAge =
        gender == Gender.male ? maleMaxPubertyAge : femaleMaxPubertyAge;
    final threshold = fixedMilestoneDate(dob, maximumAge);
    return _compareCalendarDates(acceptedDate, threshold) < 0;
  }

  /// Earliest date from which Qaza may be counted for this profile.
  ///
  /// New Muslims are never assigned Qaza for prayers missed before accepting
  /// Islam. If puberty input is not applicable, acceptance is the start date.
  static DateTime? qazaEligibilityStartDate(UserProfile profile) {
    final puberty = pubertyDate(profile);
    if (!profile.isNewMuslim) return puberty;
    final acceptedDate = profile.islamAcceptanceDate;
    if (acceptedDate == null) return null;
    if (requiresPubertyInput(profile) && puberty == null) return null;
    if (puberty == null || _compareCalendarDates(acceptedDate, puberty) > 0) {
      return LocalDateService.dateOnly(acceptedDate);
    }
    return LocalDateService.dateOnly(puberty);
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
    if (profile.pubertyInputMode == PubertyInputMode.rememberDate) {
      final date = profile.pubertyDate;
      return date == null ? null : LocalDateService.dateOnly(date);
    }
    final dob = profile.dateOfBirth;
    final age = profile.pubertyAge;
    if (dob == null || age == null) return null;
    return fixedMilestoneDate(dob, age);
  }

  static DateTime? minimumPubertyDate(Gender? gender, DateTime? dob) {
    if (gender == null || dob == null) return null;
    final age =
        gender == Gender.male ? maleMinPubertyAge : femaleMinPubertyAge;
    return fixedMilestoneDate(dob, age);
  }

  static DateTime? maximumPubertyDate(Gender? gender, DateTime? dob) {
    if (gender == null || dob == null) return null;
    final age =
        gender == Gender.male ? maleMaxPubertyAge : femaleMaxPubertyAge;
    return fixedMilestoneDate(dob, age);
  }

  static bool isPubertyDateAllowed({
    required Gender gender,
    required DateTime dob,
    required DateTime date,
    required DateTime today,
  }) {
    final minimum = minimumPubertyDate(gender, dob)!;
    final maximum = maximumPubertyDate(gender, dob)!;
    return _compareCalendarDates(date, minimum) >= 0 &&
        _compareCalendarDates(date, maximum) <= 0 &&
        _compareCalendarDates(date, today) <= 0;
  }

  static DateTime? startPrayingDate(UserProfile profile) {
    if (profile.isNewMuslim) {
      final date = profile.startPrayingDate;
      return date == null ? null : LocalDateService.dateOnly(date);
    }
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

    if (profile.isNewMuslim) {
      final acceptedDate = profile.islamAcceptanceDate;
      if (acceptedDate == null) {
        return const ProfileValidation(
          error: ProfileValidationError.islamAcceptanceDateMissing,
        );
      }
      if (_compareCalendarDates(acceptedDate, dob) < 0 ||
          _compareCalendarDates(acceptedDate, today) > 0) {
        return const ProfileValidation(
          error: ProfileValidationError.islamAcceptanceDateInvalid,
        );
      }
    }

    final puberty = profile.pubertyAge;
    final pubertyRequired = requiresPubertyInput(profile);
    DateTime? pubertyDateValue;
    if (pubertyRequired) {
      if (profile.isNewMuslim &&
          profile.pubertyInputMode == PubertyInputMode.rememberDate) {
        final exactDate = profile.pubertyDate;
        if (exactDate == null) {
          return const ProfileValidation(
            error: ProfileValidationError.pubertyMissing,
          );
        }
        if (_compareCalendarDates(exactDate, today) > 0 ||
            _compareCalendarDates(exactDate, dob) < 0 ||
            !isPubertyDateAllowed(
              gender: gender,
              dob: dob,
              date: exactDate,
              today: today,
            )) {
          return const ProfileValidation(
            error: ProfileValidationError.pubertyInvalid,
          );
        }
        pubertyDateValue = LocalDateService.dateOnly(exactDate);
      } else {
        if (puberty == null) {
          return const ProfileValidation(
              error: ProfileValidationError.pubertyMissing);
        }
        if (!isPubertyAgeAllowed(gender, puberty)) {
          return const ProfileValidation(
              error: ProfileValidationError.pubertyInvalid);
        }
        pubertyDateValue = fixedMilestoneDate(dob, puberty);
        if (!_milestoneReachedAndMaterialized(
          dob: dob,
          age: puberty,
          today: today,
        )) {
          return const ProfileValidation(
            error: ProfileValidationError.pubertyInvalid,
          );
        }
      }
    }

    final startDateValue = startPrayingDate(profile);
    if (profile.isNewMuslim) {
      if (startDateValue == null) {
        return const ProfileValidation(
          error: ProfileValidationError.startPrayingAgeMissing,
        );
      }
      if (_compareCalendarDates(startDateValue, profile.islamAcceptanceDate!) <
              0 ||
          _compareCalendarDates(startDateValue, today) > 0) {
        return const ProfileValidation(
          error: ProfileValidationError.startPrayingAgeInvalid,
        );
      }
    } else {
      final startAge = profile.startPrayingAge;
      if (startAge == null) {
        return const ProfileValidation(
            error: ProfileValidationError.startPrayingAgeMissing);
      }

      final currentAgeValue = currentAge(dob, today);
      if (startDateValue == null ||
          pubertyDateValue == null ||
          startAge < puberty! ||
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
    }

    final witr = profile.witrIncluded;
    if (witr == null || witr != effectiveWitr(profile)) {
      return const ProfileValidation(error: ProfileValidationError.witrInvalid);
    }

    return const ProfileValidation();
  }

  static UserProfile normalize(UserProfile profile) {
    var next = profile;

    if (!next.isNewMuslim) {
      if (next.islamAcceptanceDate != null ||
          next.startPrayingDate != null ||
          next.pubertyDate != null ||
          next.pubertyInputMode != PubertyInputMode.estimateAge) {
        next = next.copyWith(
          clearIslamAcceptanceDate: true,
          clearStartPrayingDate: true,
          clearPubertyDate: true,
          pubertyInputMode: PubertyInputMode.estimateAge,
        );
      }
    } else {
      if (next.startPrayingAge != null) {
        next = next.copyWith(clearStartPrayingAge: true);
      }
      final dob = next.dateOfBirth;
      final acceptedDate = next.islamAcceptanceDate;
      if (dob != null &&
          acceptedDate != null &&
          _compareCalendarDates(acceptedDate, dob) < 0) {
        next = next.copyWith(clearIslamAcceptanceDate: true);
      } else if (acceptedDate != null &&
          next.startPrayingDate != null &&
          _compareCalendarDates(next.startPrayingDate!, acceptedDate) < 0) {
        next = next.copyWith(clearStartPrayingDate: true);
      }

      if (next.pubertyInputMode == PubertyInputMode.rememberDate) {
        if (next.pubertyAge != null) {
          next = next.copyWith(clearPubertyAge: true);
        }
        final exactDate = next.pubertyDate;
        if (exactDate != null &&
            dob != null &&
            next.gender != null &&
            !isPubertyDateAllowed(
              gender: next.gender!,
              dob: dob,
              date: exactDate,
              today: LocalDateService.today(),
            )) {
          next = next.copyWith(clearPubertyDate: true);
        }
      } else if (next.pubertyDate != null) {
        next = next.copyWith(clearPubertyDate: true);
      }
    }

    if (next.isNewMuslim &&
        next.dateOfBirth != null &&
        next.startPrayingDate != null &&
        _compareCalendarDates(next.startPrayingDate!, next.dateOfBirth!) < 0) {
      next = next.copyWith(clearStartPrayingDate: true);
    }

    if (next.isNewMuslim &&
        next.islamAcceptanceDate != null &&
        !requiresPubertyInput(next)) {
      next = next.copyWith(
        clearPubertyAge: true,
        clearPubertyDate: true,
      );
    }

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

    if (next.isNewMuslim &&
        next.islamAcceptanceDate != null &&
        !requiresPubertyInput(next) &&
        next.pubertyAge != null) {
      next = next.copyWith(clearPubertyAge: true);
    }

    final dob = next.dateOfBirth;
    final validGender = next.gender;
    final validPuberty = next.pubertyAge;
    if (next.pubertyInputMode == PubertyInputMode.estimateAge &&
        dob != null &&
        validGender != null &&
        validPuberty != null) {
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
    if (!next.isNewMuslim &&
        normalizedDob != null &&
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
