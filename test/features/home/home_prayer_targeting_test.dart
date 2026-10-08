import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
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

    test(
        'successful Auto Sequence completion does not advance its legacy cursor',
        () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.fajr,
      );

      final otherTarget = state.afterSuccessfulCompletion(PrayerType.zuhr);
      expect(otherTarget.mode, HomePrayerSelectionMode.autoSequence);
      expect(otherTarget.autoSequencePrayer, PrayerType.fajr);

      final next = state.afterSuccessfulCompletion(PrayerType.fajr);
      expect(next.autoSequencePrayer, PrayerType.fajr);
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

    test(
        'Completion of a non-cursor target does not mutate Auto Sequence cursor',
        () {
      const state = HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
        autoSequencePrayer: PrayerType.asr,
      );

      final next = state.afterSuccessfulCompletion(PrayerType.zuhr);

      expect(next.autoSequencePrayer, PrayerType.asr);
      expect(next.selectedPrayer, isNull);
    });

    test(
      'Auto Sequence completion ignores the resolved prayer for cursor changes',
      () {
        const state = HomePrayerSelectionState(
          mode: HomePrayerSelectionMode.autoSequence,
          autoSequencePrayer: PrayerType.isha,
        );

        final next = state.afterSuccessfulCompletion(
          PrayerType.fajr,
          targetWasAutoSequence: true,
        );

        expect(next.autoSequencePrayer, PrayerType.isha);
      },
    );

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

    test('Auto Sequence cursor remains stable across completions', () {
      var state = const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.autoSequence,
      );

      for (final prayer in PrayerTypeX.qazaSequence) {
        state = state.afterSuccessfulCompletion(prayer);
        expect(state.autoSequencePrayer, PrayerType.fajr);
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
    test('new state starts in Auto Sequence and persists mode changes',
        () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      expect(
        container.read(homePrayerSelectionProvider).mode,
        HomePrayerSelectionMode.autoSequence,
      );

      notifier.useAutoSequence();
      notifier.selectPrayer(PrayerType.zuhr);
      await Future<void>.delayed(Duration.zero);

      final modeRows = await database
          .customSelect(
            "SELECT value FROM meta_store WHERE key = 'qaza_home_completion_mode'",
          )
          .get();
      final selectedRows = await database
          .customSelect(
            "SELECT value FROM meta_store WHERE key = 'qaza_home_selected_prayer'",
          )
          .get();
      expect(
        modeRows.single.read<String>('value'),
        HomePrayerSelectionMode.prayerSelection.name,
      );
      expect(
        selectedRows.single.read<String>('value'),
        PrayerType.zuhr.name,
      );
    });

    test('switching modes preserves the legacy Auto Sequence cursor', () {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);

      notifier.usePrayerTime();
      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.fajr,
      );

      notifier.usePrayerSelection();
      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.fajr,
      );
      expect(
        container.read(homePrayerSelectionProvider).selectedPrayer,
        PrayerType.fajr,
      );
    });

    test('Undo leaves the non-authoritative Auto Sequence cursor unchanged',
        () {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);

      expect(
        container.read(homePrayerSelectionProvider).autoSequencePrayer,
        PrayerType.fajr,
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
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homePrayerSelectionProvider.notifier);
      notifier.useAutoSequence();
      notifier.afterSuccessfulCompletion(PrayerType.fajr);
      notifier.selectPrayer(PrayerType.maghrib);

      notifier.restoreAfterUndo();

      final state = container.read(homePrayerSelectionProvider);
      expect(state.mode, HomePrayerSelectionMode.prayerSelection);
      expect(state.selectedPrayer, PrayerType.maghrib);
      expect(state.autoSequencePrayer, PrayerType.fajr);
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
}
