import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../features/daily_salah/daily_salah_tracking_providers.dart';
import '../features/home/home_controller.dart';
import '../features/home/providers/home_providers.dart';
import '../features/qaza/qaza_addition_history_screen.dart';
import '../features/qaza/qaza_tracker_controller.dart';
import '../features/prayer_time/application/prayer_time_providers.dart';

/// Refreshes data derived from the persisted active workspace after a full
/// database import or cloud restore. Refresh the session before scoped data.
Future<void> refreshWorkspaceAfterRestore(WidgetRef ref) async {
  await ref.read(accountSessionManagerProvider).refresh();

  ref.invalidate(appRouteProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(progressSummaryProvider);
  ref.invalidate(qazaRepositoryProvider);
  ref.invalidate(qazaAdditionRepositoryProvider);
  ref.invalidate(qazaPlanRevisionRepositoryProvider);
  ref.invalidate(qazaTrackerControllerProvider);
  ref.invalidate(qazaAdditionHistoryControllerProvider);
  ref.invalidate(prayerTimeControllerProvider);
  ref.invalidate(hijriDateAdjustmentProvider);
  ref.invalidate(homePrayerSelectionProvider);

  ref.invalidate(dailySalahTrackingEnabledProvider);
  ref.invalidate(dailySalahTrackingLogsProvider);
  ref.invalidate(enabledPrayerTypesProvider);
  ref.invalidate(effectiveWitrProvider);

  ref.read(homeControllerProvider).invalidateDashboard();
  ref.invalidate(homeDailyProgressProvider);
  ref.invalidate(homeQazaActivityCurrentWeekProvider);
  ref.invalidate(homeQazaActivityDailyGoalsProvider);
  ref.invalidate(homeFallbackPendingProvider);
}


/// Container variant for recovery that may complete after its initiating route
/// has been disposed. The application ProviderContainer remains alive.
Future<void> refreshWorkspaceAfterRestoreContainer(
  ProviderContainer container,
) async {
  await container.read(accountSessionManagerProvider).refresh();

  container.invalidate(appRouteProvider);
  container.invalidate(userProfileProvider);
  container.invalidate(progressSummaryProvider);
  container.invalidate(qazaRepositoryProvider);
  container.invalidate(qazaAdditionRepositoryProvider);
  container.invalidate(qazaPlanRevisionRepositoryProvider);
  container.invalidate(qazaTrackerControllerProvider);
  container.invalidate(qazaAdditionHistoryControllerProvider);
  container.invalidate(prayerTimeControllerProvider);
  container.invalidate(hijriDateAdjustmentProvider);
  container.invalidate(homePrayerSelectionProvider);

  container.invalidate(dailySalahTrackingEnabledProvider);
  container.invalidate(dailySalahTrackingLogsProvider);
  container.invalidate(enabledPrayerTypesProvider);
  container.invalidate(effectiveWitrProvider);

  container.read(homeControllerProvider).invalidateDashboard();
  container.invalidate(homeDailyProgressProvider);
  container.invalidate(homeQazaActivityCurrentWeekProvider);
  container.invalidate(homeQazaActivityDailyGoalsProvider);
  container.invalidate(homeFallbackPendingProvider);
}
