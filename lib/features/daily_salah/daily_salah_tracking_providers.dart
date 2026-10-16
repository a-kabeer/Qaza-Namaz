import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import 'daily_salah_tracking_service.dart';

final dailySalahTrackingServiceProvider =
    Provider<DailySalahTrackingService>((ref) {
  return DailySalahTrackingService(
    database: ref.watch(appDatabaseProvider),
    qazaService: ref.watch(qazaServiceProvider),
  );
});

final dailySalahTrackingEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(dailySalahTrackingServiceProvider).isEnabled();
});

final dailySalahTrackingLogsProvider = FutureProvider.family<
    Map<PrayerType, DailySalahLog>, DateTime>((ref, date) async {
  final userId = ref.watch(activeUserIdProvider);
  if (userId == null) return const <PrayerType, DailySalahLog>{};
  return ref.watch(dailySalahTrackingServiceProvider).logsForDate(
        userId: userId,
        date: date,
        includeWitr: ref.watch(effectiveWitrProvider),
      );
});
