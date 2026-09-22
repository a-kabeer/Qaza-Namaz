import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/aladhan_prayer_times_data_source.dart';
import 'data/location/city_search_provider.dart';
import 'data/location/prayer_location_service.dart';
import 'data/offline_city_search_provider.dart';
import 'data/offline_location_data_source.dart';
import 'data/prayer_times_notification_service.dart';
import 'data/prayer_times_preferences.dart';
import 'data/prayer_times_repository_impl.dart';
import 'domain/prayer_time_calculator.dart';
import 'domain/prayer_times_models.dart';
import 'domain/prayer_times_repository.dart';
import 'domain/qaza_restriction_service.dart';
import 'presentation/prayer_times_controller.dart';

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

final prayerTimesConnectivityProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

final prayerTimesHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final prayerTimesCalculatorProvider = Provider<PrayerTimeCalculator>(
  (ref) => const PrayerTimeCalculator(),
);

final prayerTimesAlAdhanDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>((ref) {
  return AlAdhanPrayerTimesDataSource(
    client: ref.watch(prayerTimesHttpClientProvider),
  );
});

final prayerTimesPreferencesProvider = Provider<PrayerTimesPreferences>(
  (ref) => PrayerTimesPreferences(SharedPreferences.getInstance()),
);

final offlineLocationDataSourceProvider =
    Provider<OfflineLocationDataSource>((ref) {
  return OfflineCityDataSource();
});

final prayerCitySearchProvider = Provider<CitySearchProvider>((ref) {
  return OfflineCitySearchProvider(
    dataSource: ref.watch(offlineLocationDataSourceProvider),
  );
});

final prayerCountriesProvider =
    FutureProvider<List<PrayerCountryOption>>((ref) async {
  return ref.watch(offlineLocationDataSourceProvider).getCountries();
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
    remoteDataSource: ref.watch(prayerTimesAlAdhanDataSourceProvider),
    connectivity: ref.watch(prayerTimesConnectivityProvider),
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

final prayerTimesNotificationServiceProvider =
    Provider<PrayerTimesNotificationService>((ref) {
  return PrayerTimesNotificationService(
    repository: ref.watch(prayerTimesRepositoryProvider),
    now: ref.watch(prayerTimesClockProvider).now,
  );
});

final qazaRestrictionEvaluationProvider =
    FutureProvider.autoDispose<QazaRestrictionEvaluation>((ref) {
  return ref.watch(qazaRestrictionServiceProvider).evaluateCurrent();
});
