import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/location/city_search_provider.dart';
import 'data/location/prayer_location_service.dart';
import 'data/offline_city_search_provider.dart';
import 'data/offline_location_data_source.dart';
import 'data/prayer_times_preferences.dart';
import 'data/prayer_times_repository_impl.dart';
import 'domain/prayer_time_calculator.dart';
import 'domain/prayer_times_repository.dart';
import 'presentation/prayer_times_controller.dart';
import 'domain/qaza_restriction_service.dart';

abstract class PrayerTimesClock {
  DateTime now();
}

class SystemPrayerTimesClock implements PrayerTimesClock {
  const SystemPrayerTimesClock();

  @override
  DateTime now() => DateTime.now();
}

final prayerTimesClockProvider = Provider<PrayerTimesClock>(
  (ref) => const SystemPrayerTimesClock(),
);

final prayerTimesCalculatorProvider = Provider<PrayerTimeCalculator>(
  (ref) => const PrayerTimeCalculator(),
);

final prayerTimesPreferencesProvider = Provider<PrayerTimesPreferences>(
  (ref) => PrayerTimesPreferences(SharedPreferences.getInstance()),
);

final offlineLocationDataSourceProvider =
    Provider<OfflineLocationDataSource>((ref) {
  return GeodbOfflineLocationDataSource();
});

final prayerCitySearchProvider = Provider<CitySearchProvider>((ref) {
  return OfflineCitySearchProvider(
    dataSource: ref.watch(offlineLocationDataSourceProvider),
  );
});

final prayerLocationServiceProvider = Provider<PrayerLocationService>((ref) {
  return GeolocatorPrayerLocationService(
    dataSource: ref.watch(offlineLocationDataSourceProvider),
  );
});

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  return PrayerTimesRepositoryImpl(
    calculator: ref.watch(prayerTimesCalculatorProvider),
    preferences: ref.watch(prayerTimesPreferencesProvider),
  );
});

final prayerTimesControllerProvider =
    NotifierProvider<PrayerTimesController, PrayerTimesState>(
  PrayerTimesController.new,
);

final qazaRestrictionServiceProvider = Provider<QazaRestrictionService>((ref) {
  return QazaRestrictionService(
    repository: ref.watch(prayerTimesRepositoryProvider),
    now: ref.watch(prayerTimesClockProvider).now,
  );
});

final qazaRestrictionEvaluationProvider =
    FutureProvider.autoDispose<QazaRestrictionEvaluation>((ref) {
  return ref.watch(qazaRestrictionServiceProvider).evaluateCurrent();
});
