import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/migration/user_profile_migration.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const legacyDailyTargetKey = 'qaza_home_daily_target_guest';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy Home Daily Qaza Target migrates into UserProfile', () async {
    final existingJson = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1990, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      witrIncluded: true,
      onboardingCompleted: true,
    ).toJson()
      ..remove('dailyQazaTarget');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UserProfile.storageKey, jsonEncode(existingJson));
    await prefs.setInt(legacyDailyTargetKey, 15);

    await const UserProfileMigration().migrateLegacyProfileData(
      preferences: prefs,
    );

    final loaded = UserProfile.fromJson(
      jsonDecode(prefs.getString(UserProfile.storageKey)!)
          as Map<String, dynamic>,
    );
    expect(loaded.dailyQazaTarget, 15);
    expect(prefs.getInt(legacyDailyTargetKey), isNull);
    expect(
      loaded.schemaVersion,
      UserProfile.currentSchemaVersion,
    );
  });

  test('customized profile target is preserved over legacy Home target', () async {
    const profile = UserProfile(
      dailyQazaTarget: 20,
      onboardingCompleted: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      UserProfile.storageKey,
      jsonEncode(profile.toJson()),
    );
    await prefs.setInt(legacyDailyTargetKey, 7);

    await const UserProfileMigration().migrateLegacyProfileData(
      preferences: prefs,
    );

    final loaded = UserProfile.fromJson(
      jsonDecode(prefs.getString(UserProfile.storageKey)!)
          as Map<String, dynamic>,
    );
    expect(loaded.dailyQazaTarget, 20);
    expect(prefs.getInt(legacyDailyTargetKey), isNull);
  });

  test('legacy Home target defaults to 5 when no target exists', () async {
    const profile = UserProfile(onboardingCompleted: true);
    final json = profile.toJson()..remove('dailyQazaTarget');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UserProfile.storageKey, jsonEncode(json));

    await const UserProfileMigration().migrateLegacyProfileData(
      preferences: prefs,
    );

    final loaded = UserProfile.fromJson(
      jsonDecode(prefs.getString(UserProfile.storageKey)!)
          as Map<String, dynamic>,
    );
    expect(loaded.dailyQazaTarget, 5);
  });
}
