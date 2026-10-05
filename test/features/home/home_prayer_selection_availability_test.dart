import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/services/qaza_targeting_service.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';

QazaProgressSummary summaryFor(Map<PrayerType, int> pending) {
  final byPrayer = <PrayerType, PrayerProgress>{
    for (final prayer in PrayerType.values)
      prayer: PrayerProgress(
        prayerType: prayer,
        progress: QazaProgress(
          pending: pending[prayer] ?? 0,
          completed: 0,
        ),
      ),
  };
  final totalPending = byPrayer.values.fold<int>(
    0,
    (sum, item) => sum + item.progress.pending,
  );
  return QazaProgressSummary(
    overall: QazaProgress(pending: totalPending, completed: 0),
    byPrayer: byPrayer,
  );
}

void main() {
  test(
    'Prayer Selection disables prayers with zero pending Qaza in canonical order',
    () async {
      final container = ProviderContainer(
        overrides: [
          progressSummaryProvider.overrideWith(
            (ref) => Future.value(
              summaryFor({
                PrayerType.zuhr: 2,
                PrayerType.maghrib: 1,
                PrayerType.witr: 3,
              }),
            ),
          ),
          effectiveWitrProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await container.read(progressSummaryProvider.future);

      expect(
        container.read(homePrayerSelectionDisabledPrayersProvider),
        {
          PrayerType.fajr,
          PrayerType.asr,
          PrayerType.isha,
        },
      );
    },
  );

  test(
    'Prayer Selection respects disabled Witr and keeps enabled prayers available',
    () async {
      final container = ProviderContainer(
        overrides: [
          progressSummaryProvider.overrideWith(
            (ref) => Future.value(
              summaryFor({
                PrayerType.fajr: 1,
                PrayerType.witr: 5,
              }),
            ),
          ),
          effectiveWitrProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(progressSummaryProvider.future);

      final disabled =
          container.read(homePrayerSelectionDisabledPrayersProvider);

      expect(disabled, contains(PrayerType.witr));
      expect(disabled, contains(PrayerType.zuhr));
      expect(disabled, contains(PrayerType.asr));
      expect(disabled, contains(PrayerType.maghrib));
      expect(disabled, contains(PrayerType.isha));
      expect(disabled, isNot(contains(PrayerType.fajr)));
    },
  );

  test(
    'Prayer Selection target becomes unavailable when selected prayer loses pending Qaza',
    () async {
      final summaryStateProvider =
          StateProvider<QazaProgressSummary>(
        (ref) => summaryFor({
          PrayerType.fajr: 2,
          PrayerType.isha: 1,
        }),
      );
      final container = ProviderContainer(
        overrides: [
          progressSummaryProvider.overrideWith(
            (ref) async => ref.watch(summaryStateProvider),
          ),
          effectiveWitrProvider.overrideWith((ref) => true),
          currentQazaPrayerTypeProvider.overrideWith(
            (ref) => PrayerType.asr,
          ),
          sahibAlTartibProvider.overrideWith(
            (ref) => Future.value(
              const SahibAlTartibState(
                pendingFarzCount: 0,
                requiresOrder: false,
                nextPending: null,
              ),
            ),
          ),
          homePrayerSelectionProvider.overrideWith(
            () => _FixedPrayerSelectionNotifier(PrayerType.isha),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(progressSummaryProvider.future);

      final initiallySelected = container.read(homeSelectedPrayerProvider);
      expect(initiallySelected.prayer, PrayerType.isha);

      container.read(summaryStateProvider.notifier).state = summaryFor({
        PrayerType.fajr: 2,
      });

      expect(
        container.read(homeSelectedPrayerProvider).prayer,
        isNull,
      );
      expect(
        container.read(homeSelectedPrayerProvider).source,
        HomePrayerSelectionSource.unavailable,
      );
    },
  );
}

class _FixedPrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _FixedPrayerSelectionNotifier(this.prayer);

  final PrayerType prayer;

  @override
  HomePrayerSelectionState build() => HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: prayer,
      );
}
