
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/migration/user_profile_migration.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

void main() {
  test('migrates legacy calculator values without inventing gender or madhab',
      () async {
    const key = 'qaza_calculator_v1_anonymous';
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'schemaVersion': 1,
        'dob': '2000-05-10T00:00:00.000',
        'balighAge': 12,
        'prayerStartAge': 18,
        'includeWitr': true,
      }),
    });

    final prefs = await SharedPreferences.getInstance();
    await const UserProfileMigration().migrateLegacyCalculatorData(
      preferences: prefs,
    );

    final raw = prefs.getString(UserProfile.storageKey);
    expect(raw, isNotNull);
    final profile =
        UserProfile.fromJson(jsonDecode(raw!) as Map<String, dynamic>);

    expect(profile.dateOfBirth, DateTime(2000, 5, 10));
    expect(profile.pubertyAge, 12);
    expect(profile.startPrayingAge, 18);
    expect(profile.gender, isNull);
    expect(profile.madhab, Madhab.other);
    expect(profile.witrIncluded, isTrue);
    expect(profile.onboardingCompleted, isFalse);
    expect(prefs.getString(key), isNull);
  });


  test('does not invent ages from exact-date legacy calculator mode', () async {
    const key = 'qaza_calculator_v1_anonymous';
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'schemaVersion': 1,
        'dob': '2000-05-10T00:00:00.000',
        'balighMode': 'exactDate',
        'balighAge': 12,
        'balighDate': '2012-05-11T00:00:00.000',
        'prayerStartMode': 'exactDate',
        'prayerStartAge': 18,
        'prayerStartDate': '2018-06-01T00:00:00.000',
        'includeWitr': false,
      }),
    });

    final prefs = await SharedPreferences.getInstance();
    await const UserProfileMigration().migrateLegacyCalculatorData(
      preferences: prefs,
    );

    final raw = prefs.getString(UserProfile.storageKey)!;
    final profile =
        UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(profile.dateOfBirth, DateTime(2000, 5, 10));
    expect(profile.pubertyAge, isNull);
    expect(profile.startPrayingAge, isNull);
    expect(profile.gender, isNull);
    expect(profile.madhab, Madhab.other);
    expect(profile.witrIncluded, isFalse);
  });

  test('does not overwrite an existing partial profile', () async {
    const key = 'qaza_calculator_v1_anonymous';
    SharedPreferences.setMockInitialValues({
      UserProfile.storageKey: jsonEncode(
        const UserProfile(
          languageCode: 'ur',
          gender: Gender.female,
          onboardingCompleted: false,
        ).toJson(),
      ),
      key: jsonEncode({
        'schemaVersion': 1,
        'dob': '2001-01-01T00:00:00.000',
        'balighAge': 10,
        'prayerStartAge': 15,
        'includeWitr': false,
      }),
    });

    final prefs = await SharedPreferences.getInstance();
    await const UserProfileMigration().migrateLegacyCalculatorData(
      preferences: prefs,
    );

    final raw = prefs.getString(UserProfile.storageKey)!;
    final profile =
        UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(profile.languageCode, 'ur');
    expect(profile.gender, Gender.female);
    expect(profile.dateOfBirth, DateTime(2001, 1, 1));
    expect(profile.pubertyAge, 10);
    expect(profile.startPrayingAge, 15);
    expect(profile.madhab, Madhab.other);
    expect(profile.witrIncluded, isFalse);
    expect(prefs.getString(key), isNull);
  });
}