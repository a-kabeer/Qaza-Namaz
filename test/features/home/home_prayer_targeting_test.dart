import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';

void main() {
  group('PrayerType Qaza sequence', () {
    test('follows Fajr, Zuhr, Asr, Maghrib, Isha, Witr and wraps', () {
      expect(PrayerType.fajr.nextInQazaSequence, PrayerType.zuhr);
      expect(PrayerType.zuhr.nextInQazaSequence, PrayerType.asr);
      expect(PrayerType.asr.nextInQazaSequence, PrayerType.maghrib);
      expect(PrayerType.maghrib.nextInQazaSequence, PrayerType.isha);
      expect(PrayerType.isha.nextInQazaSequence, PrayerType.witr);
      expect(PrayerType.witr.nextInQazaSequence, PrayerType.fajr);
    });
  });

  group('HomePrayerSelectionState', () {
    test('defaults to Prayer Time with Fajr as the Auto Sequence cursor', () {
      const state = HomePrayerSelectionState();

      expect(state.mode, HomePrayerSelectionMode.prayerTime);
      expect(state.manualPrayer, isNull);
      expect(state.autoSequencePrayer, PrayerType.fajr);
    });

    test('successful Auto Sequence completion advances from the completed prayer', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.fajr,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.mode, HomePrayerSelectionMode.autoSequence);
      expect(next.autoSequencePrayer, PrayerType.asr);
      expect(next.manualPrayer, isNull);
    });

    test('Sahib override does not skip the Auto Sequence cursor', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.fajr,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.autoSequencePrayer, PrayerType.fajr);
    });

    test(
        'manual Auto Sequence override is preserved when Sahib forces another prayer',
        () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.fajr,
        manualPrayer: PrayerType.maghrib,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.autoSequencePrayer, PrayerType.fajr);
      expect(next.manualPrayer, PrayerType.maghrib);
    });

    test('successful Prayer Time completion clears a manual target', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerTime,
        manualPrayer: PrayerType.maghrib,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.maghrib);

      expect(next.mode, HomePrayerSelectionMode.prayerTime);
      expect(next.manualPrayer, isNull);
    });
  });

  group('Prayer Time slot mapping', () {
    test('maps every completable Prayer Time slot', () {
      expect(prayerTypeFromPrayerSlot(PrayerSlot.fajr), PrayerType.fajr);
      expect(prayerTypeFromPrayerSlot(PrayerSlot.dhuhr), PrayerType.zuhr);
      expect(prayerTypeFromPrayerSlot(PrayerSlot.asr), PrayerType.asr);
      expect(prayerTypeFromPrayerSlot(PrayerSlot.maghrib), PrayerType.maghrib);
      expect(prayerTypeFromPrayerSlot(PrayerSlot.isha), PrayerType.isha);
      expect(prayerTypeFromPrayerSlot(PrayerSlot.sunrise), isNull);
      expect(prayerTypeFromPrayerSlot(null), isNull);
    });
  });
}
