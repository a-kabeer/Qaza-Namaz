import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/prayer_times_models.dart';
import '../domain/prayer_times_repository.dart';
import '../domain/prayer_time_calculator.dart';
import 'aladhan_prayer_times_data_source.dart';
import 'prayer_times_preferences.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  const PrayerTimesRepositoryImpl({
    required PrayerTimeCalculator calculator,
    required PrayerTimesPreferences preferences,
    required PrayerTimesRemoteDataSource remoteDataSource,
    required Connectivity connectivity,
  })  : _calculator = calculator,
        _preferences = preferences,
        _remoteDataSource = remoteDataSource,
        _connectivity = connectivity;

  final PrayerTimeCalculator _calculator;
  final PrayerTimesPreferences _preferences;
  final PrayerTimesRemoteDataSource _remoteDataSource;
  final Connectivity _connectivity;

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async {
    _validateCoordinates(latitude, longitude);

    final connectivity = await _connectivity.checkConnectivity();
    final hasNetwork = connectivity.any(
      (result) => result != ConnectivityResult.none,
    );

    if (hasNetwork) {
      try {
        return await _remoteDataSource.getPrayerTimes(
          latitude: latitude,
          longitude: longitude,
          date: date,
          method: method,
          asrMethod: asrMethod,
          timezone: timezone,
        );
      } catch (_) {
        // Connectivity does not guarantee usable internet access. Falling
        // back to the local calculator keeps prayer times available.
      }
    }

    return _calculator.calculate(
      latitude: latitude,
      longitude: longitude,
      date: date,
      method: method,
      asrMethod: asrMethod,
      timezone: timezone,
    );
  }

  @override
  Future<PrayerLocation?> getSavedLocation() => _preferences.getLocation();

  @override
  Future<void> saveLocation(PrayerLocation location) async {
    _validateCoordinates(location.latitude, location.longitude);
    await _preferences.saveLocation(location);
  }

  @override
  Future<PrayerSettings> getSavedSettings() => _preferences.getSettings();

  @override
  Future<void> saveSettings(PrayerSettings settings) =>
      _preferences.saveSettings(settings);

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
