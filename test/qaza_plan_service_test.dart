
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

void main() {
  final service = const QazaPlanService();

  test('builds a Qaza plan from the authoritative profile', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 14,
      witrIncluded: true,
      onboardingCompleted: true,
    );

    final plan = service.planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.startDate, DateTime(2012, 1, 1));
    expect(plan.endDate, DateTime(2014, 1, 1));
    expect(plan.totalDays, 731);
    expect(plan.includeWitr, isTrue);
    expect(plan.totalPrayers, 3655);
    expect(plan.witrCount, 731);
    expect(plan.totalWithWitr, 4386);
  });

  test('fixed Madhab Witr rules flow into the Qaza plan', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.female,
      madhab: Madhab.shafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 9,
      startPrayingAge: 12,
      witrIncluded: false,
      onboardingCompleted: true,
    );

    final plan = service.planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.includeWitr, isFalse);
    expect(plan.witrCount, 0);
  });
}