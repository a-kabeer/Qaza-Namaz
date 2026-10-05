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

    final selection = ref.read(homePrayerSelectionProvider);
    if (selection.mode == HomePrayerSelectionMode.autoSequence) {
      ref.invalidate(homeFallbackPendingProvider);
      return;
    }

    final selected = ref.read(homeSelectedPrayerProvider);
    if (selected.prayer != null) {
      ref.invalidate(oldestPendingProvider(selected.prayer!));
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
    final selection = ref.read(homePrayerSelectionProvider);
    if (selection.mode == HomePrayerSelectionMode.autoSequence) {
      await _refreshOptional(
        homeFallbackPendingProvider,
        'home_auto_sequence_qaza_refresh_failed',
      );
    } else {
      final selected = ref.read(homeSelectedPrayerProvider);
      if (selected.prayer != null) {
        await _refreshOptional(
          oldestPendingProvider(selected.prayer!),
          'home_next_qaza_refresh_failed',
        );
      }
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
    // Auto Sequence is record-first; the completed record is already
    // removed by the completion pipeline. Recompute from the pending ledger.
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
