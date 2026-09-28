import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';

UserProfile makeProfile(Madhab madhab, {bool? witr}) => UserProfile(
      madhab: madhab,
      witrIncluded: witr ?? (madhab == Madhab.hanafi),
    );

void main() {
  group('ProfileRules.enabledPrayerTypes', () {
    test('Hanafi includes Witr', () {
      expect(
        ProfileRules.enabledPrayerTypes(makeProfile(Madhab.hanafi)),
        PrayerType.values,
      );
    });

    test('Shafi, Maliki and Hanbali exclude Witr', () {
      for (final madhab in <Madhab>[
        Madhab.shafi,
        Madhab.maliki,
        Madhab.hanbali,
      ]) {
        final prayers = ProfileRules.enabledPrayerTypes(makeProfile(madhab));
        expect(prayers, isNot(contains(PrayerType.witr)));
        expect(prayers, hasLength(5));
      }
    });

    test('Other follows explicit Witr choice', () {
      expect(
        ProfileRules.enabledPrayerTypes(makeProfile(Madhab.other, witr: false)),
        isNot(contains(PrayerType.witr)),
      );
      expect(
        ProfileRules.enabledPrayerTypes(makeProfile(Madhab.other, witr: true)),
        contains(PrayerType.witr),
      );
    });

    test('resolved Witr helper returns the six or five supported prayers', () {
      expect(ProfileRules.prayerTypesForWitr(false), hasLength(5));
      expect(ProfileRules.prayerTypesForWitr(false), isNot(contains(PrayerType.witr)));
      expect(ProfileRules.prayerTypesForWitr(true), hasLength(6));
      expect(ProfileRules.prayerTypesForWitr(true), contains(PrayerType.witr));
    });
  });

  test('canonical Qaza sequence can skip Witr without removing it from the enum', () {
    expect(
      PrayerType.isha.nextInQazaSequenceSkippingWitr(witrEnabled: false),
      PrayerType.fajr,
    );
    expect(
      PrayerType.isha.nextInQazaSequenceSkippingWitr(witrEnabled: true),
      PrayerType.witr,
    );
    expect(PrayerType.witr.nextInQazaSequenceSkippingWitr(witrEnabled: false), PrayerType.fajr);
  });
}
