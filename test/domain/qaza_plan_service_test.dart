import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

void main() {
  test('equal puberty and prayer-start dates produce a valid zero-day plan', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 12,
      witrIncluded: true,
    );

    final plan = const QazaPlanService().planFor(profile);

    expect(plan, isNotNull);
    expect(plan!.totalDays, 0);
    expect(plan.totalPrayers, 0);
    expect(plan.witrCount, 0);
    expect(plan.totalWithWitr, 0);
    expect(
      plan.prayerBreakdown.values.every((count) => count == 0),
      isTrue,
    );
    expect(
      plan.prayerBreakdown.keys.where((prayer) => prayer != PrayerType.witr),
      hasLength(5),
    );
  });
}
