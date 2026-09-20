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

  test('PrayerTimesRequest cache key includes all cache dimensions', () {
    final base = PrayerTimesRequest(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.standard,
    );

    final hanafi = PrayerTimesRequest(
      latitude: base.latitude,
      longitude: base.longitude,
      date: base.date,
      method: base.method,
      asrMethod: AsrMethod.hanafi,
    );

    final differentMethod = PrayerTimesRequest(
      latitude: base.latitude,
      longitude: base.longitude,
      date: base.date,
      method: CalculationMethod.mwl,
      asrMethod: base.asrMethod,
    );

    expect(hanafi.cacheKey, isNot(base.cacheKey));
    expect(differentMethod.cacheKey, isNot(base.cacheKey));
  });
}
