import 'dart:math' as math;

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

  static DateTime anniversaryDate(DateTime dob, int age) {
    final year = dob.year + age;
    final lastDay = DateTime(year, dob.month + 1, 0).day;
    return DateTime(year, dob.month, math.min(dob.day, lastDay));
  }

  static int currentAge(DateTime dob, DateTime today) {
    final birth = _dateOnly(dob);
    final now = _dateOnly(today);
    var age = now.year - birth.year;
    if (anniversaryDate(birth, age).isAfter(now)) age--;
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
    if (_dateOnly(dob).isAfter(_dateOnly(today))) {
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

    final startAge = profile.startPrayingAge;
    if (startAge == null) {
      return const ProfileValidation(
        error: ProfileValidationError.startPrayingAgeMissing,
      );
    }

    final currentAgeValue = currentAge(dob, today);
    if (startAge < puberty || startAge > currentAgeValue) {
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
    if (dob != null &&
        start != null &&
        validGender != null &&
        validPuberty != null) {
      final maxStart = currentAge(dob, DateTime.now());
      if (start < validPuberty || start > maxStart) {
        next = next.copyWith(clearStartPrayingAge: true);
      }
    }

    return next;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
