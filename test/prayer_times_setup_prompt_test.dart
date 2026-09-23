import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/features/prayer_times/presentation/prayer_times_setup_prompt.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('setup prompt preference starts unseen and persists seen state', () async {
    final preferences = PrayerTimesSetupPromptPreferences(
      SharedPreferences.getInstance(),
    );

    expect(await preferences.hasSeen(), isFalse);

    await preferences.markSeen();

    expect(await preferences.hasSeen(), isTrue);
  });
}
