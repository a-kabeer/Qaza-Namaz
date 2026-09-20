import 'prayer_times_models.dart';

abstract class PrayerTimesRepository {
  Future<PrayerDay?> getCachedPrayerTimes(PrayerTimesRequest request);

  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
  });

  PrayerLocation? getSavedLocation();

  Future<void> saveLocation(PrayerLocation location);

  PrayerSettings getSavedSettings();

  Future<void> saveSettings(PrayerSettings settings);
}
