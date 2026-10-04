import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import 'providers/home_providers.dart';

class HomeController {
  const HomeController(this.ref);

  final Ref ref;

  void invalidateDashboard() {
    ref.invalidate(homeNowProvider);
    ref.invalidate(homeLocalDateProvider);
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeDashboardActivityProvider);
    for (final prayer in ref.read(enabledPrayerTypesProvider)) {
      ref.invalidate(oldestPendingProvider(prayer));
    }
  }

  Future<void> refresh() async {
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);

    await Future.wait<void>([
      _refreshRequired(
        progressSummaryProvider,
        'home_summary_refresh_failed',
      ),
      _refreshOptional(
        homeDashboardActivityProvider,
        'home_dashboard_activity_refresh_failed',
      ),
      _refreshOptional(
        sahibAlTartibProvider,
        'home_sahib_al_tartib_refresh_failed',
      ),
    ]);
    final selected = ref.read(homeSelectedPrayerProvider);
    if (selected.prayer != null) {
      await _refreshOptional(
        oldestPendingProvider(selected.prayer!),
        'home_next_qaza_refresh_failed',
      );
    } else {
      await _refreshOptional(
        homeFallbackPendingProvider,
        'home_fallback_qaza_refresh_failed',
      );
    }
  }

  Future<void> _refreshRequired<T>(
    AutoDisposeFutureProvider<T> provider,
    String code,
  ) async {
    try {
      await ref.read(provider.future);
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            code,
            error,
            stack: stack,
          );
      rethrow;
    }
  }

  Future<void> _refreshOptional<T>(
    AutoDisposeFutureProvider<T> provider,
    String code,
  ) async {
    try {
      await ref.read(provider.future);
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.uncaught,
            code,
            error,
            stack: stack,
          );
    }
  }

  void afterCompletion({
    required PrayerType completedPrayer,
  }) {
    final witrEnabled = ref.read(effectiveWitrProvider);
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);
    ref
        .read(homePrayerSelectionProvider.notifier)
        .afterSuccessfulCompletion(
          completedPrayer,
          witrEnabled: witrEnabled,
        );
  }

  void afterStaleCompletion() {
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);
  }

  void afterUndo() {
    ref.read(homePrayerSelectionProvider.notifier).restoreAfterUndo();
    invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(homeFallbackPendingProvider);
    for (final prayer in PrayerType.values) {
      ref.invalidate(oldestPendingProvider(prayer));
    }
  }
}

final homeControllerProvider = Provider<HomeController>(
  (ref) => HomeController(ref),
);
