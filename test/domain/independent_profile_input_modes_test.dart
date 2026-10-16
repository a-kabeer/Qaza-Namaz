import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';

UserProfile makeProfile({
  ProfileInputMode pubertyMode = ProfileInputMode.ageEstimate,
  ProfileInputMode startMode = ProfileInputMode.ageEstimate,
  DateTime? pubertyDate,
  DateTime? startDate,
  int? pubertyAge = 12,
  int? startAge = 13,
}) =>
    UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: pubertyAge,
      startPrayingAge: startAge,
      pubertyInputMode: pubertyMode,
      pubertyDateOverride: pubertyDate,
      startPrayingInputMode: startMode,
      startPrayingDateOverride: startDate,
      witrIncluded: true,
    );

void main() {
  test('all four independent input mode combinations resolve effective dates',
      () {
    final cases = [
      makeProfile(),
      makeProfile(
        startMode: ProfileInputMode.rememberedDate,
        startDate: DateTime(2013, 1, 1),
      ),
      makeProfile(
        pubertyMode: ProfileInputMode.rememberedDate,
        pubertyDate: DateTime(2012, 1, 1),
      ),
      makeProfile(
        pubertyMode: ProfileInputMode.rememberedDate,
        startMode: ProfileInputMode.rememberedDate,
        pubertyDate: DateTime(2012, 1, 1),
        startDate: DateTime(2013, 1, 1),
      ),
    ];

    for (final profile in cases) {
      final puberty = ProfileRules.pubertyDate(profile);
      final start = ProfileRules.startPrayingDate(profile);
      final plan = const QazaPlanService().planFor(profile);
      expect(puberty, isNotNull);
      expect(start, isNotNull);
      expect(plan, isNotNull);
      final expected = LocalDateService.calendarDayDifference(puberty!, start!);
      expect(plan!.totalDays, expected > 0 ? expected : 0);
      expect(plan.totalWithWitr, plan.totalDays * 6);
    }

    expect(const QazaPlanService().planFor(cases.first)!.totalDays, 360);
  });

  test('Namaz Start before or on puberty creates a valid zero-Qaza plan', () {
    final puberty = DateTime(2013, 1, 1);
    for (final start in [DateTime(2012, 12, 31), puberty]) {
      final profile = makeProfile(
        pubertyMode: ProfileInputMode.rememberedDate,
        startMode: ProfileInputMode.rememberedDate,
        pubertyDate: puberty,
        startDate: start,
      );
      final plan = const QazaPlanService().planFor(profile);
      expect(plan, isNotNull);
      expect(plan!.totalDays, 0);
      expect(plan.totalPrayers, 0);
      expect(plan.totalWithWitr, 0);
      expect(plan.startDate, plan.endDate);
    }
  });

  test('Namaz Start age is independent and can be lower than puberty age', () {
    final profile = makeProfile(startAge: 7);
    final plan = const QazaPlanService().planFor(profile);
    expect(plan, isNotNull);
    expect(plan!.totalDays, 0);
    expect(
      ProfileRules.validate(
        profile,
        today: DateTime.now(),
      ).isValid,
      isTrue,
    );
  });

  test('invalid remembered dates are rejected rather than adjusted', () {
    final minimum = ProfileRules.minimumPubertyDate(makeProfile())!;
    final invalidPuberty = makeProfile(
      pubertyMode: ProfileInputMode.rememberedDate,
      pubertyDate: minimum.subtract(const Duration(days: 1)),
    );
    expect(ProfileRules.pubertyDate(invalidPuberty), isNull);
    expect(
      ProfileRules.validate(invalidPuberty, today: DateTime.now()).error,
      isNotNull,
    );

    final minimumStart = ProfileRules.minimumStartPrayingDate(makeProfile())!;
    final invalidStart = makeProfile(
      startMode: ProfileInputMode.rememberedDate,
      startDate: minimumStart.subtract(const Duration(days: 1)),
    );
    expect(ProfileRules.startPrayingDate(invalidStart), isNull);
  });

  test('legacy profiles migrate to age mode without changing calculations', () {
    final legacy = UserProfile.fromJson({
      'schemaVersion': 2,
      'languageCode': 'en',
      'gender': 'male',
      'madhab': 'hanafi',
      'dateOfBirth': DateTime(2000, 1, 1).toIso8601String(),
      'pubertyAge': 12,
      'startPrayingAge': 13,
      'witrIncluded': true,
      'onboardingCompleted': true,
    });
    expect(legacy.schemaVersion, 2);
    expect(legacy.pubertyInputMode, ProfileInputMode.ageEstimate);
    expect(legacy.startPrayingInputMode, ProfileInputMode.ageEstimate);
    expect(const QazaPlanService().planFor(legacy)!.totalDays, 360);

    final restored = UserProfile.fromJson(legacy.toJson());
    expect(restored.pubertyInputMode, ProfileInputMode.ageEstimate);
    expect(restored.startPrayingInputMode, ProfileInputMode.ageEstimate);
    expect(const QazaPlanService().planFor(restored)!.totalDays, 360);
  });

  test('inactive values survive mode switching and serialization', () {
    final profile = makeProfile(
      pubertyDate: DateTime(2012, 1, 1),
      startDate: DateTime(2013, 1, 1),
    );
    final exact = profile.copyWith(
      pubertyInputMode: ProfileInputMode.rememberedDate,
      startPrayingInputMode: ProfileInputMode.rememberedDate,
    );
    final backToAge = exact.copyWith(
      pubertyInputMode: ProfileInputMode.ageEstimate,
      startPrayingInputMode: ProfileInputMode.ageEstimate,
    );
    expect(backToAge.pubertyAge, 12);
    expect(backToAge.startPrayingAge, 13);
    expect(backToAge.pubertyDateOverride, DateTime(2012, 1, 1));
    expect(backToAge.startPrayingDateOverride, DateTime(2013, 1, 1));
    final restored = UserProfile.fromJson(exact.toJson());
    expect(restored.pubertyDateOverride, DateTime(2012, 1, 1));
    expect(restored.startPrayingDateOverride, DateTime(2013, 1, 1));
  });
}
