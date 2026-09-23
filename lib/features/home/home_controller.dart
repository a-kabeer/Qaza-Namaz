import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../prayer_times/prayer_times_providers.dart';
import 'home_providers.dart';
import 'home_state.dart';

class HomeController {
  const HomeController(this.ref);

  final Ref ref;

  void invalidateDashboard() {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeDailyProgressProvider);
    for (final prayer in PrayerType.values) {
      ref.invalidate(oldestPendingProvider(prayer));
    }
    for (final range in HomeProgressRange.values) {
      ref.invalidate(homeProgressHistoryProvider(range));
    }
  }

  Future<void> refresh() async {
    invalidateDashboard();
    await ref.read(progressSummaryProvider.future);
  }

  void afterCompletion({
    required int pendingBefore,
  }) {
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);
    ref.invalidate(qazaRestrictionEvaluationProvider);
    if (pendingBefore <= 1) {
      ref.read(homePrayerSelectionProvider.notifier).useAutomatic();
    }
  }

  void afterUndo(PrayerType prayer) {
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);
    ref.invalidate(qazaRestrictionEvaluationProvider);
    ref.invalidate(oldestPendingProvider(prayer));
  }
}

final homeControllerProvider = Provider<HomeController>(
  (ref) => HomeController(ref),
);
