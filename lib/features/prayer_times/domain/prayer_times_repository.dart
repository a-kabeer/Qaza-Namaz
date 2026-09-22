import 'prayer_times_models.dart';

abstract class PrayerTimesRepository {
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  });

  Future<PrayerLocation?> getSavedLocation();

  Future<void> saveLocation(PrayerLocation location);

  Future<PrayerSettings> getSavedSettings();

  Future<void> saveSettings(PrayerSettings settings);
}
