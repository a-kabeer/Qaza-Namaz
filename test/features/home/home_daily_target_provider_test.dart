import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

void main() {
  test('Home daily target is derived from UserProfile', () async {
    const profile = UserProfile(dailyQazaTarget: 17);
    final container = ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith((ref) async => profile),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userProfileProvider.future);
    expect(container.read(dailyQazaTargetProvider), 17);
  });

  test('Home daily target defaults to 5 without a loaded profile', () {
    final container = ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(dailyQazaTargetProvider),
      UserProfile.defaultDailyQazaTarget,
    );
  });
}
