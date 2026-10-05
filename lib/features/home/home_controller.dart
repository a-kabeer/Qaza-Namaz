import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import 'home_state.dart';
import 'providers/home_providers.dart';

class HomeController {
  const HomeController(this.ref);

  final Ref ref;

  void invalidateDashboard() {
    ref.invalidate(homeNowProvider);
    ref.invalidate(homeLocalDateProvider);
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeDashboardActivityProvider);

    final selected = ref.read(homeSelectedPrayerProvider);
    if (selected.prayer != null) {
      ref.invalidate(oldestPendingProvider(selected.prayer!));
    } else {
      ref.invalidate(homeFallbackPendingProvider);
    }
  }

  Future<void> refresh() async {
    invalidateDashboard();
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
    required HomePrayerSelectionSource selectionSource,
  }) {
    final witrEnabled = ref.read(effectiveWitrProvider);
    if (selectionSource == HomePrayerSelectionSource.autoSequence) {
      ref
          .read(homePrayerSelectionProvider.notifier)
          .afterSuccessfulCompletion(
            completedPrayer,
            witrEnabled: witrEnabled,
            targetWasAutoSequence: true,
          );
    }
    invalidateDashboard();
  }

  void afterStaleCompletion() {
    invalidateDashboard();
  }

  void afterUndo() {
    ref.read(homePrayerSelectionProvider.notifier).restoreAfterUndo();
    invalidateDashboard();
  }
}

final homeControllerProvider = Provider<HomeController>(
  (ref) => HomeController(ref),
);
