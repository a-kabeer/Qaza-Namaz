import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
import 'package:qaza_namaz/features/home/home_controller.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

class _TestHomePrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _TestHomePrayerSelectionNotifier(this.initial);

  final HomePrayerSelectionState initial;

  @override
  HomePrayerSelectionState build() => initial;
}

ProviderContainer _containerFor({
  required HomePrayerSelectionMode mode,
  required void Function() onDailyProgressRead,
}) {
  return ProviderContainer(
    overrides: [
      enabledPrayerTypesProvider.overrideWith(
        (ref) => const [PrayerType.fajr],
      ),
      homePrayerSelectionProvider.overrideWith(
        () => _TestHomePrayerSelectionNotifier(
          HomePrayerSelectionState(mode: mode),
        ),
      ),
      progressSummaryProvider.overrideWith(
        (ref) async => QazaProgressSummary.empty(),
      ),
      homeDailyProgressProvider.overrideWith(
        (ref) => () {
          onDailyProgressRead();
          return Future.value(
            const HomeDailyProgress(completed: 2, target: 5),
          );
        }(),
      ),
      sahibAlTartibProvider.overrideWith(
        (ref) async => const SahibAlTartibState(
          pendingFarzCount: 0,
          requiresOrder: false,
          nextPending: null,
        ),
      ),
      homeSelectedPrayerProvider.overrideWith(
        (ref) => const HomeSelectedPrayerState(
          mode: HomePrayerSelectionMode.autoSequence,
          prayer: PrayerType.fajr,
          source: HomePrayerSelectionSource.autoSequence,
        ),
      ),
      oldestPendingProvider(PrayerType.fajr).overrideWith(
        (ref) async => null,
      ),
      homeFallbackPendingProvider.overrideWith(
        (ref) async => null,
      ),
    ],
  );
}

void main() {
  for (final mode in HomePrayerSelectionMode.values) {
    test(
      'HomeController.refresh reads daily progress in ' + mode.name,
      () async {
        var dailyProgressReads = 0;
        final container = _containerFor(
          mode: mode,
          onDailyProgressRead: () => dailyProgressReads++,
        );
        addTearDown(container.dispose);

        await container.read(homeControllerProvider).refresh();

        expect(dailyProgressReads, 1);
      },
    );
  }
}
