import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_settings.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time_calculator.dart';

void main() {
  const location = PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    city: 'Karachi',
    region: 'Sindh',
    country: 'Pakistan',
    countryCode: 'PK',
    timezoneId: 'Asia/Karachi',
    source: PrayerLocationSource.city,
  );

  test('Prayer Time no longer exposes a settings page or navigation', () {
    final prayerPage = File(
      'lib/features/prayer_time/presentation/prayer_time_page.dart',
    ).readAsStringSync();
    final settingsPage = File(
      'lib/features/settings/settings_screen.dart',
    ).readAsStringSync();
    final barrel = File('lib/features/prayer_time/prayer_time.dart')
        .readAsStringSync();

    expect(prayerPage, isNot(contains('PrayerSettingsPage')));
    expect(prayerPage, isNot(contains('prayer_time_settings')));
    expect(settingsPage, isNot(contains('settings_prayer_time')));
    expect(settingsPage, isNot(contains('PrayerSettingsPage')));
    expect(barrel, isNot(contains('prayer_settings_page.dart')));
  });

  test('Prayer Time always formats clock times as 12-hour values', () {
    final source = File(
      'lib/features/prayer_time/presentation/prayer_time_page.dart',
    ).readAsStringSync();

    expect(source, contains('intl.DateFormat.jm(locale).format(local)'));
    expect(source, isNot(contains('intl.DateFormat.Hm(locale)')));
    expect(source, isNot(contains('use24HourFormat')));
  });

  test('legacy settings fields are ignored and are not serialized', () {
    const legacy = <String, dynamic>{
      'calculationMethod': 'custom',
      'asrMethod': 'standard',
      'highLatitudeRule': 'twilightAngle',
      'fajrAngle': 15.0,
      'ishaAngle': 17.0,
      'adjustments': {'asr': 7},
      'use24HourFormat': true,
    };

    final settings = PrayerSettings.fromJson(legacy);

    expect(settings.calculationMethod, PrayerCalculationMethod.custom);
    expect(settings.highLatitudeRule, PrayerHighLatitudeRule.twilightAngle);
    expect(settings.fajrAngle, 15.0);
    expect(settings.ishaAngle, 17.0);
    expect(settings.adjustments, {'asr': 7});

    final serialized = settings.toJson();
    expect(serialized.containsKey('asrMethod'), isFalse);
    expect(serialized.containsKey('use24HourFormat'), isFalse);
  });

  test('Asr calculation follows Profile Madhab mapping', () {
    const calculator = PrayerTimeCalculator();
    final date = DateTime(2026, 9, 28);

    final hanafi = calculator.calculate(
      location: location,
      madhab: Madhab.hanafi,
      localDate: date,
    );
    final standard = calculator.calculate(
      location: location,
      madhab: Madhab.shafi,
      localDate: date,
    );
    final maliki = calculator.calculate(
      location: location,
      madhab: Madhab.maliki,
      localDate: date,
    );
    final hanbali = calculator.calculate(
      location: location,
      madhab: Madhab.hanbali,
      localDate: date,
    );
    final other = calculator.calculate(
      location: location,
      madhab: Madhab.other,
      localDate: date,
    );

    expect(
      hanafi.utcFor(PrayerSlot.asr),
      isNot(standard.utcFor(PrayerSlot.asr)),
    );
    expect(maliki.utcFor(PrayerSlot.asr), standard.utcFor(PrayerSlot.asr));
    expect(hanbali.utcFor(PrayerSlot.asr), standard.utcFor(PrayerSlot.asr));
    expect(other.utcFor(PrayerSlot.asr), standard.utcFor(PrayerSlot.asr));
  });

  test('legacy cached snapshots without settings still parse safely', () {
    final times = <String, String>{
      for (final slot in PrayerSlot.values)
        slot.name: '2026-09-28T00:00:00.000Z',
    };
    const locationJson = <String, dynamic>{
      'latitude': 24.8607,
      'longitude': 67.0011,
      'city': 'Karachi',
      'region': 'Sindh',
      'country': 'Pakistan',
      'countryCode': 'PK',
      'timezoneId': 'Asia/Karachi',
      'source': 'city',
    };
    final schedule = <String, dynamic>{
      'date': '2026-09-28',
      'timesUtc': times,
      'astronomicalSunriseUtc': '2026-09-28T00:00:00.000Z',
      'astronomicalDhuhrUtc': '2026-09-28T00:00:00.000Z',
      'astronomicalSunsetUtc': '2026-09-28T00:00:00.000Z',
    };
    final snapshot = PrayerTimeSnapshot.fromJson({
      'location': locationJson,
      'today': schedule,
      'tomorrow': schedule,
      'updatedAt': '2026-09-28T00:00:00.000Z',
    });

    expect(snapshot, isNotNull);
    expect(snapshot!.settings.calculationMethod, PrayerCalculationMethod.karachi);
    expect(snapshot.calculationMadhab, isNull);
  });
}
