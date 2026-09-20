import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/aladhan_provider.dart';
import 'data/location/city_search_provider.dart';
import 'data/location/open_meteo_city_search_provider.dart';
import 'data/location/prayer_location_service.dart';
import 'data/prayer_times_cache.dart';
import 'data/prayer_times_provider.dart';
import 'data/prayer_times_repository_impl.dart';
import 'domain/prayer_times_repository.dart';
import 'presentation/prayer_times_controller.dart';

abstract class PrayerTimesClock {
  DateTime now();
}

class SystemPrayerTimesClock implements PrayerTimesClock {
  const SystemPrayerTimesClock();

  @override
  DateTime now() => DateTime.now();
}

final prayerTimesClockProvider = Provider<PrayerTimesClock>((ref) {
  return const SystemPrayerTimesClock();
});

final prayerTimesHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final prayerCitySearchHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final prayerTimesProvider = Provider<PrayerTimesProvider>((ref) {
  return AlAdhanProvider(client: ref.watch(prayerTimesHttpClientProvider));
});

final prayerTimesCacheProvider = Provider<PrayerTimesCache>((ref) {
  return PrayerTimesCache(SharedPreferences.getInstance());
});

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  return PrayerTimesRepositoryImpl(
    provider: ref.watch(prayerTimesProvider),
    cache: ref.watch(prayerTimesCacheProvider),
  );
});

final prayerLocationServiceProvider = Provider<PrayerLocationService>((ref) {
  return GeolocatorPrayerLocationService();
});

final prayerCitySearchProvider = Provider<CitySearchProvider>((ref) {
  return OpenMeteoCitySearchProvider(
    client: ref.watch(prayerCitySearchHttpClientProvider),
  );
});

final prayerTimesControllerProvider =
    NotifierProvider<PrayerTimesController, PrayerTimesState>(
  PrayerTimesController.new,
);
