import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prayer Time uses the Zuhr user-facing label', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    final generated =
        File('lib/l10n/app_localizations_en.dart').readAsStringSync();

    expect(arb, contains('"prayerTimeDhuhr": "Zuhr"'));
    expect(generated, contains("String get prayerTimeDhuhr => 'Zuhr';"));
    expect(arb, isNot(contains('"prayerTimeDhuhr": "Dhuhr"')));
    expect(generated, isNot(contains("String get prayerTimeDhuhr => 'Dhuhr';")));
  });
}
