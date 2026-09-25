import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';

void main() {
  group('puberty age', () {
    test('male only allows 12 through 15', () {
      expect(ProfileRules.pubertyAgeOptions(Gender.male), [12, 13, 14, 15]);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.male, 11), isFalse);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.male, 12), isTrue);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.male, 15), isTrue);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.male, 16), isFalse);
    });

    test('female only allows 9 through 15', () {
      expect(
        ProfileRules.pubertyAgeOptions(Gender.female),
        [9, 10, 11, 12, 13, 14, 15],
      );
      expect(ProfileRules.isPubertyAgeAllowed(Gender.female, 8), isFalse);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.female, 9), isTrue);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.female, 15), isTrue);
      expect(ProfileRules.isPubertyAgeAllowed(Gender.female, 16), isFalse);
    });
  });

  group('Witr', () {
    test('fixed Madhab rules are authoritative', () {
      expect(
        ProfileRules.effectiveWitr(const UserProfile(madhab: Madhab.hanafi)),
        isTrue,
      );
      expect(
        ProfileRules.effectiveWitr(const UserProfile(madhab: Madhab.shafi)),
        isFalse,
      );
      expect(
        ProfileRules.effectiveWitr(const UserProfile(madhab: Madhab.maliki)),
        isFalse,
      );
      expect(
        ProfileRules.effectiveWitr(const UserProfile(madhab: Madhab.hanbali)),
        isFalse,
      );
    });

    test('Other is user-controlled', () {
      expect(
        ProfileRules.effectiveWitr(
          const UserProfile(madhab: Madhab.other, witrIncluded: true),
        ),
        isTrue,
      );
      expect(
        ProfileRules.effectiveWitr(
          const UserProfile(madhab: Madhab.other, witrIncluded: false),
        ),
        isFalse,
      );
    });
  });

  group('validation', () {
    final today = DateTime(2026, 9, 25);

    UserProfile base() => UserProfile(
          languageCode: 'en',
          gender: Gender.male,
          madhab: Madhab.hanafi,
          dateOfBirth: DateTime(2000, 1, 1),
          pubertyAge: 12,
          startPrayingAge: 18,
          witrIncluded: true,
          onboardingCompleted: true,
        );

    test('accepts a complete valid profile', () {
      expect(ProfileRules.validate(base(), today: today).isValid, isTrue);
    });

    test('rejects future DOB', () {
      expect(
        ProfileRules.validate(
          base().copyWith(dateOfBirth: DateTime(2027, 1, 1)),
          today: today,
        ).error,
        ProfileValidationError.dobFuture,
      );
    });

    test('rejects invalid gender/puberty combinations', () {
      expect(
        ProfileRules.validate(
          base().copyWith(
            gender: Gender.female,
            pubertyAge: 8,
          ),
          today: today,
        ).error,
        ProfileValidationError.pubertyInvalid,
      );
    });

    test('rejects praying age before puberty or beyond current age', () {
      expect(
        ProfileRules.validate(
          base().copyWith(startPrayingAge: 11),
          today: today,
        ).error,
        ProfileValidationError.startPrayingAgeInvalid,
      );
      expect(
        ProfileRules.validate(
          base().copyWith(startPrayingAge: 40),
          today: today,
        ).error,
        ProfileValidationError.startPrayingAgeInvalid,
      );
    });
  });

  test('anniversary dates use the last valid day for 29 February births', () {
    expect(
      ProfileRules.anniversaryDate(DateTime(2000, 2, 29), 1),
      DateTime(2001, 2, 28),
    );
  });
}
