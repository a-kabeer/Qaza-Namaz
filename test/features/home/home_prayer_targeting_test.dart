import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    test('defaults to Auto Sequence with Fajr cursor', () {
      const state = HomePrayerSelectionState();

      expect(state.mode, HomePrayerSelectionMode.autoSequence);
      expect(state.selectedPrayer, isNull);
      expect(state.autoSequencePrayer, PrayerType.fajr);
    });

    test('successful Auto Sequence completion advances only its cursor prayer', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.fajr,
      );

      final forcedByTartib = state.afterSuccessfulCompletion(PrayerType.zuhr);
      expect(forcedByTartib.mode, HomePrayerSelectionMode.autoSequence);
      expect(forcedByTartib.autoSequencePrayer, PrayerType.fajr);

      final next = state.afterSuccessfulCompletion(PrayerType.fajr);
      expect(next.autoSequencePrayer, PrayerType.zuhr);
    });

    test('Prayer Selection remains sticky after successful completion', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: PrayerType.zuhr,
        autoSequencePrayer: PrayerType.asr,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.mode, HomePrayerSelectionMode.prayerSelection);
      expect(next.selectedPrayer, PrayerType.zuhr);
      expect(next.autoSequencePrayer, PrayerType.asr);
    });

    test('Tartib completion does not mutate Auto Sequence cursor', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.asr,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.autoSequencePrayer, PrayerType.asr);
      expect(next.selectedPrayer, isNull);
    });

    test('Prayer Time completion does not mutate targeting state', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerTime,
        selectedPrayer: null,
        autoSequencePrayer: PrayerType.maghrib,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.fajr);

      expect(next.mode, HomePrayerSelectionMode.prayerTime);
      expect(next.selectedPrayer, isNull);
      expect(next.autoSequencePrayer, PrayerType.maghrib);
    });

    test('Auto Sequence follows the complete canonical cycle', () {
      var state = const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
      );

      for (final prayer in PrayerTypeX.qazaSequence) {
        state = state.afterSuccessfulCompletion(prayer);
        expect(state.autoSequencePrayer, prayer.nextInQazaSequence);
      }
    });

    test('copyWith can clear Prayer Selection', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: PrayerType.isha,
      );

      final next = state.copyWith(clearSelectedPrayer: true);

      expect(next.selectedPrayer, isNull);
      expect(next.mode, HomePrayerSelectionMode.prayerSelection);
    });
  });

  group('HomePrayerSelectionNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('new state starts in Auto Sequence and persists mode changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      expect(
        container.read(homePrayerSelectionProvider).mode,
        HomePrayerSelectionMode.autoSequence,
      );

      notifier.useAutoSequence();
      notifier.selectPrayer(PrayerType.zuhr);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('qaza_home_completion_mode'),
        HomePrayerSelectionMode.prayerSelection.name,
      );
      expect(
        prefs.getString('qaza_home_selected_prayer'),
        PrayerType.zuhr.name,
      );
    });

    test('switching modes preserves the Auto Sequence cursor', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);

      notifier.usePrayerTime();
      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.zuhr,
      );

      notifier.usePrayerSelection();
      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.zuhr,
      );
      expect(
        container.read(homePrayerSelectionProvider).selectedPrayer,
        PrayerType.zuhr,
      );
    });

    test('Undo restores an Auto Sequence cursor changed by completion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);

      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.zuhr,
      );

      notifier.restoreAfterUndo();

      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.fajr,
      );
      expect(
        container.read(homePrayerSelectionProvider).mode,
        HomePrayerSelectionMode.autoSequence,
      );
    });

    test('Undo does not overwrite a newer explicit target change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);
      notifier.selectPrayer(PrayerType.maghrib);

      notifier.restoreAfterUndo();

      final state = container.read(homePrayerSelectionProvider);
      expect(state.mode, HomePrayerSelectionMode.prayerSelection);
      expect(state.selectedPrayer, PrayerType.maghrib);
      expect(state.autoSequencePrayer, PrayerType.zuhr);
    });
  });

  group('Prayer Time slot mapping', () {
    test('maps every completable Prayer Time slot', () {
      expect(PrayerSlot.fajr.qazaPrayerType, PrayerType.fajr);
      expect(PrayerSlot.dhuhr.qazaPrayerType, PrayerType.zuhr);
      expect(PrayerSlot.asr.qazaPrayerType, PrayerType.asr);
      expect(PrayerSlot.maghrib.qazaPrayerType, PrayerType.maghrib);
      expect(PrayerSlot.isha.qazaPrayerType, PrayerType.isha);
      expect(PrayerSlot.sunrise.qazaPrayerType, isNull);
    });
  });


    test('Qaza sequence skips Witr when Witr is disabled', () {
      expect(
        PrayerType.isha.nextInQazaSequenceSkippingWitr(witrEnabled: false),
        PrayerType.fajr,
      );
      expect(
        PrayerType.witr.nextInQazaSequenceSkippingWitr(witrEnabled: false),
        PrayerType.fajr,
      );
    });


    test('Auto Sequence skips disabled Witr in Home state', () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.isha,
      );

      expect(
        state.afterSuccessfulCompletion(
          PrayerType.isha,
          witrEnabled: false,
        ).autoSequencePrayer,
        PrayerType.fajr,
      );

      expect(
        state.afterSuccessfulCompletion(
          PrayerType.isha,
          witrEnabled: true,
        ).autoSequencePrayer,
        PrayerType.witr,
      );
    });

}
