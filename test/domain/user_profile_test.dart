import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

void main() {
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

  test('business profile JSON excludes presentation language', () {
    final json = const UserProfile(languageCode: 'ur').toJson();

    expect(json.containsKey('languageCode'), isFalse);
  });

  test('Daily Qaza Target is normalized to the supported range', () {
    expect(UserProfile.normalizeDailyQazaTarget(0), 1);
    expect(UserProfile.normalizeDailyQazaTarget(51), 50);
    expect(UserProfile.normalizeDailyQazaTarget(25), 25);
  });
}
