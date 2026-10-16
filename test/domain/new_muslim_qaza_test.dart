import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

UserProfile newMuslimProfile({
  DateTime? dob,
  required DateTime acceptedDate,
  int? pubertyAge,
  DateTime? pubertyDate,
  PubertyInputMode pubertyInputMode = PubertyInputMode.estimateAge,
  required DateTime startPrayingDate,
  Gender gender = Gender.male,
}) =>
    UserProfile(
      languageCode: 'en',
      gender: gender,
      madhab: Madhab.hanafi,
      dateOfBirth: dob ?? DateTime(2000, 1, 1),
      isNewMuslim: true,
      islamAcceptanceDate: acceptedDate,
      pubertyAge: pubertyAge,
      pubertyDate: pubertyDate,
      pubertyInputMode: pubertyInputMode,
      startPrayingDate: startPrayingDate,
      witrIncluded: true,
    );

void main() {
  const planService = QazaPlanService();
  final dob = DateTime(2000, 1, 1);
  final today = DateTime(2026, 10, 1);

  test('puberty input cutoff uses the existing maximum age boundary', () {
    for (final gender in Gender.values) {
      final maxAge = gender == Gender.male
          ? ProfileRules.maleMaxPubertyAge
          : ProfileRules.femaleMaxPubertyAge;
      final cutoff = ProfileRules.fixedMilestoneDate(dob, maxAge);
      expect(
        ProfileRules.requiresPubertyInput(
          newMuslimProfile(
            dob: dob,
            acceptedDate: cutoff.subtract(const Duration(days: 1)),
            startPrayingDate: cutoff,
            gender: gender,
          ),
        ),
        isTrue,
        reason: '$gender: acceptance before maximum-age cutoff',
      );
      expect(
        ProfileRules.requiresPubertyInput(
          newMuslimProfile(
            dob: dob,
            acceptedDate: cutoff,
            startPrayingDate: cutoff,
            gender: gender,
          ),
        ),
        isFalse,
        reason: '$gender: acceptance on maximum-age cutoff',
      );
      expect(
        ProfileRules.requiresPubertyInput(
          newMuslimProfile(
            dob: dob,
            acceptedDate: cutoff.add(const Duration(days: 1)),
            startPrayingDate: cutoff.add(const Duration(days: 2)),
            gender: gender,
          ),
        ),
        isFalse,
        reason: '$gender: acceptance after maximum-age cutoff',
      );
    }
  });

  test('Qaza starts at puberty when puberty follows Islam acceptance', () {
    final profile = newMuslimProfile(
      dob: dob,
      acceptedDate: DateTime(2005, 1, 1),
      pubertyAge: 12,
      startPrayingDate: DateTime(2014, 1, 1),
    );
    final plan = planService.planFor(profile)!;
    final expectedStart = ProfileRules.pubertyDate(profile)!;

    expect(ProfileRules.qazaEligibilityStartDate(profile), expectedStart);
    expect(plan.startDate, expectedStart);
    expect(
      plan.totalDays,
      expectedStart.isBefore(profile.startPrayingDate!)
          ? DateTime.utc(
              profile.startPrayingDate!.year,
              profile.startPrayingDate!.month,
              profile.startPrayingDate!.day,
            ).difference(DateTime.utc(
              expectedStart.year,
              expectedStart.month,
              expectedStart.day,
            )).inDays
          : 0,
    );
    expect(plan.endDate, profile.startPrayingDate);
  });

  test('Qaza starts at Islam acceptance when it follows puberty', () {
    final profile = newMuslimProfile(
      dob: dob,
      acceptedDate: DateTime(2013, 1, 1),
      pubertyAge: 12,
      startPrayingDate: DateTime(2014, 1, 1),
    );
    final plan = planService.planFor(profile)!;

    expect(
      ProfileRules.qazaEligibilityStartDate(profile),
      DateTime(2013, 1, 1),
    );
    expect(plan.startDate, DateTime(2013, 1, 1));
    expect(plan.totalDays, 365);
    expect(plan.endDate, DateTime(2014, 1, 1));
  });

  test('hidden puberty input uses Islam acceptance as Qaza eligibility start', () {
    final cutoff = ProfileRules.fixedMilestoneDate(
      dob,
      ProfileRules.maleMaxPubertyAge,
    );
    final accepted = cutoff.add(const Duration(days: 1));
    final profile = newMuslimProfile(
      dob: dob,
      acceptedDate: accepted,
      startPrayingDate: accepted.add(const Duration(days: 10)),
    );
    final plan = planService.planFor(profile)!;

    expect(ProfileRules.requiresPubertyInput(profile), isFalse);
    expect(ProfileRules.qazaEligibilityStartDate(profile), accepted);
    expect(plan.startDate, accepted);
    expect(plan.totalDays, 10);
    expect(plan.endDate, accepted.add(const Duration(days: 10)));
  });

  test('remembered puberty date independently determines eligibility', () {
    final rememberedPubertyDate = DateTime(2012, 1, 1);
    final profile = newMuslimProfile(
      acceptedDate: DateTime(2005, 1, 1),
      pubertyInputMode: PubertyInputMode.rememberDate,
      pubertyDate: rememberedPubertyDate,
      startPrayingDate: DateTime(2014, 1, 1),
    );
    final plan = planService.planFor(profile)!;

    expect(ProfileRules.requiresPubertyInput(profile), isTrue);
    expect(ProfileRules.pubertyDate(profile), rememberedPubertyDate);
    expect(ProfileRules.qazaEligibilityStartDate(profile), rememberedPubertyDate);
    expect(plan.startDate, rememberedPubertyDate);
    expect(plan.totalDays, 731);
    expect(
      ProfileRules.validate(profile, today: today).isValid,
      isTrue,
    );
  });

  test('remembered puberty date respects existing puberty-age limits', () {
    final tooEarly = newMuslimProfile(
      acceptedDate: DateTime(2005, 1, 1),
      pubertyInputMode: PubertyInputMode.rememberDate,
      pubertyDate: DateTime(2010, 1, 1),
      startPrayingDate: DateTime(2014, 1, 1),
    );

    expect(
      ProfileRules.validate(tooEarly, today: today).error,
      ProfileValidationError.pubertyInvalid,
    );
  });

  test('praying before Salah becomes obligatory produces a zero-day plan', () {
    final profile = newMuslimProfile(
      dob: dob,
      acceptedDate: DateTime(2005, 1, 1),
      pubertyAge: 12,
      startPrayingDate: DateTime(2010, 1, 1),
    );
    final plan = planService.planFor(profile)!;
    final puberty = ProfileRules.pubertyDate(profile)!;

    expect(ProfileRules.qazaEligibilityStartDate(profile), puberty);
    expect(plan.totalDays, 0);
    expect(plan.totalPrayers, 0);
    expect(plan.totalWithWitr, 0);
    expect(plan.startDate, puberty);
    expect(plan.endDate, puberty);
  });

  test('validation requires puberty only before the maximum-age cutoff', () {
    final cutoff = ProfileRules.fixedMilestoneDate(
      dob,
      ProfileRules.maleMaxPubertyAge,
    );
    final beforeCutoff = newMuslimProfile(
      dob: dob,
      acceptedDate: cutoff.subtract(const Duration(days: 1)),
      startPrayingDate: cutoff,
    );
    expect(
      ProfileRules.validate(beforeCutoff, today: today).error,
      ProfileValidationError.pubertyMissing,
    );

    final atCutoff = newMuslimProfile(
      dob: dob,
      acceptedDate: cutoff,
      startPrayingDate: cutoff.add(const Duration(days: 1)),
    );
    expect(ProfileRules.validate(atCutoff, today: today).isValid, isTrue);
  });

  test('acceptance date cannot precede birth or be in the future', () {
    final beforeBirth = newMuslimProfile(
      dob: dob,
      acceptedDate: DateTime(1999, 12, 31),
      pubertyAge: 12,
      startPrayingDate: DateTime(2001, 1, 1),
    );
    expect(
      ProfileRules.validate(beforeBirth, today: today).error,
      ProfileValidationError.islamAcceptanceDateInvalid,
    );

    final futureAcceptance = newMuslimProfile(
      dob: dob,
      acceptedDate: DateTime(2026, 10, 2),
      pubertyAge: 12,
      startPrayingDate: DateTime(2026, 10, 3),
    );
    expect(
      ProfileRules.validate(futureAcceptance, today: today).error,
      ProfileValidationError.islamAcceptanceDateInvalid,
    );
  });

  test('new Muslim fields round-trip and missing legacy fields default safely', () {
    final profile = newMuslimProfile(
      acceptedDate: DateTime(2013, 1, 1),
      pubertyInputMode: PubertyInputMode.rememberDate,
      pubertyDate: DateTime(2012, 1, 1),
      startPrayingDate: DateTime(2014, 1, 1),
    );
    final restored = UserProfile.fromJson(profile.toJson());

    expect(restored.isNewMuslim, isTrue);
    expect(restored.islamAcceptanceDate, DateTime(2013, 1, 1));
    expect(restored.pubertyInputMode, PubertyInputMode.rememberDate);
    expect(restored.pubertyDate, DateTime(2012, 1, 1));
    expect(restored.startPrayingDate, DateTime(2014, 1, 1));

    final legacy = UserProfile.fromJson({
      'dateOfBirth': DateTime(2000, 1, 1).toIso8601String(),
      'pubertyAge': 12,
      'startPrayingAge': 15,
    });
    expect(legacy.isNewMuslim, isFalse);
    expect(legacy.islamAcceptanceDate, isNull);
    expect(legacy.startPrayingDate, isNull);
    expect(legacy.pubertyInputMode, PubertyInputMode.estimateAge);
    expect(legacy.pubertyDate, isNull);
    expect(legacy.pubertyAge, 12);
    expect(legacy.startPrayingAge, 15);
  });
}
