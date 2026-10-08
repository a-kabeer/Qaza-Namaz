import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
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
  required void Function() onDashboardActivityRead,
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
      homeDashboardActivityProvider.overrideWith(
        (ref) {
          onDashboardActivityRead();
          final period = QazaActivityPeriod(
            from: DateTime(2026, 9, 27),
            toExclusive: DateTime(2026, 10, 4),
            today: DateTime(2026, 9, 30),
            days: const [],
          );
          return Future.value(
            HomeDashboardActivity(
              dailyProgress: const HomeDailyProgress(completed: 2, target: 5),
              currentWeek: period,
              dailyGoals: period,
            ),
          );
        },
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
  test(
    'dashboard invalidation refreshes the current Home calendar-week '
    'activity provider',
    () async {
      var reads = 0;
      final period = QazaActivityPeriod(
        from: DateTime(2026, 9, 27),
        toExclusive: DateTime(2026, 10, 4),
        today: DateTime(2026, 9, 30),
        days: const [],
      );
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeDashboardActivityProvider.overrideWith((ref) async {
            reads++;
            return HomeDashboardActivity(
              dailyProgress: const HomeDailyProgress(completed: 2, target: 5),
              currentWeek: period,
              dailyGoals: period,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeDashboardActivityProvider.future);
      expect(reads, 1);

      container.read(homeControllerProvider).afterStaleCompletion();

      await container.read(homeDashboardActivityProvider.future);
      expect(reads, 2);
    },
  );

  for (final mode in HomePrayerSelectionMode.values) {
    test(
      'HomeController.refresh reads consolidated Home activity in ${mode.name}',
      () async {
        var dailyProgressReads = 0;
        final container = _containerFor(
          mode: mode,
          onDashboardActivityRead: () => dailyProgressReads++,
        );
        addTearDown(container.dispose);

        await container.read(homeControllerProvider).refresh();

        expect(dailyProgressReads, greaterThanOrEqualTo(1));
      },
    );
  }
}
