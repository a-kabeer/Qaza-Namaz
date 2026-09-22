import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/domain/prayer_times_models.dart';

void main() {
  test('PrayerLocation and settings round trip through JSON', () {
    const location = PrayerLocation(
      latitude: 24.8607,
      longitude: 67.0011,
      country: 'Pakistan',
      city: 'Karachi',
      region: 'Sindh',
      countryCode: 'PK',
      timezone: 'Asia/Karachi',
      source: LocationSource.manualCity,
      accuracyMeters: 45,
      accuracyKind: LocationAccuracyKind.precise,
    );
    const settings = PrayerSettings(
      calculationMethod: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
    );

    expect(
      PrayerLocation.fromJson(location.toJson()).cacheIdentity,
      location.cacheIdentity,
    );
    expect(
      PrayerLocation.fromJson(location.toJson()).displayName,
      'Karachi, Sindh, Pakistan',
    );

    final restoredSettings = PrayerSettings.fromJson(settings.toJson());
    expect(restoredSettings.calculationMethod, CalculationMethod.karachi);
    expect(restoredSettings.asrMethod, AsrMethod.hanafi);
  });

  test('PrayerDay round trips its solar restriction anchors', () {
    final day = PrayerDay(
      date: DateTime(2026, 9, 20),
      timezone: 'Asia/Karachi',
      times: const {
        PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
        PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
        PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
        PrayerName.asr: PrayerTime(hour: 16, minute: 45),
        PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
        PrayerName.isha: PrayerTime(hour: 19, minute: 44),
      },
      solarNoon: DateTime(2026, 9, 20, 12, 20),
      sunset: DateTime(2026, 9, 20, 18, 28),
      hijriDate: const HijriDate(day: 18, month: 'Rabi al-Thani', year: 1448),
      fetchedAt: DateTime.utc(2026, 9, 20),
    );

    final restored = PrayerDay.fromJson(day.toJson());
    expect(restored.solarNoon, day.solarNoon);
    expect(restored.sunset, day.sunset);
  });
}
