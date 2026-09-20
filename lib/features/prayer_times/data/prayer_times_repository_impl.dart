import '../domain/prayer_times_models.dart';
import '../domain/prayer_times_repository.dart';
import 'prayer_times_cache.dart';
import 'prayer_times_provider.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  PrayerTimesRepositoryImpl({
    required PrayerTimesProvider provider,
    required PrayerTimesCache cache,
  })  : _provider = provider,
        _cache = cache;

  final PrayerTimesProvider _provider;
  final PrayerTimesCache _cache;

  @override
  Future<PrayerDay?> getCachedPrayerTimes(PrayerTimesRequest request) async {
    return _cache.getDay(request);
  }

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
  }) async {
    _validateCoordinates(latitude, longitude);

    final request = PrayerTimesRequest(
      latitude: latitude,
      longitude: longitude,
      date: date,
      method: method,
      asrMethod: asrMethod,
    );
    final day = await _provider.fetch(request);
    await _cache.saveDay(request, day);
    return day;
  }

  @override
  PrayerLocation? getSavedLocation() => _cache.getLocation();

  @override
  Future<void> saveLocation(PrayerLocation location) async {
    _validateCoordinates(location.latitude, location.longitude);
    await _cache.saveLocation(location);
  }

  @override
  PrayerSettings getSavedSettings() => _cache.getSettings();

  @override
  Future<void> saveSettings(PrayerSettings settings) =>
      _cache.saveSettings(settings);

  void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid prayer-time coordinates.');
    }
  }
}
