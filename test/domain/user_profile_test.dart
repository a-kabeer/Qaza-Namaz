import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/user_profile_repository.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new profile defaults Daily Qaza Target to 5', () {
    const profile = UserProfile();
    expect(profile.dailyQazaTarget, UserProfile.defaultDailyQazaTarget);
    expect(profile.dailyQazaTarget, 5);
  });

  test('missing Daily Qaza Target in saved JSON resolves to 5', () {
    final json = const UserProfile().toJson()..remove('dailyQazaTarget');
    final profile = UserProfile.fromJson(json);

    expect(profile.dailyQazaTarget, 5);
  });

  test('changed Daily Qaza Target persists through UserProfile repository', () async {
    final repository = SharedPreferencesUserProfileRepository();
    final profile = UserProfile().copyWith(dailyQazaTarget: 12);

    await repository.save(profile);
    final loaded = await repository.load();

    expect(loaded?.dailyQazaTarget, 12);
    expect(
      jsonDecode(
        (await SharedPreferences.getInstance())
            .getString(UserProfile.storageKey)!,
      )['dailyQazaTarget'],
      12,
    );
  });

  test('Daily Qaza Target is normalized to the supported range', () {
    expect(UserProfile.normalizeDailyQazaTarget(0), 1);
    expect(UserProfile.normalizeDailyQazaTarget(51), 50);
    expect(UserProfile.normalizeDailyQazaTarget(25), 25);
  });
}
