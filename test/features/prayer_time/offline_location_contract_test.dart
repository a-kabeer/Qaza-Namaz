import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonames_offline/geonames_offline.dart';
import 'package:qaza_namaz/features/prayer_time/data/offline_city_resolver.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('PrayerLocation persists GeoNames identifier without changing legacy fields', () {
    const original = PrayerLocation(
      latitude: 24.861234,
      longitude: 67.002345,
      city: 'Karachi',
      region: 'Sindh',
      country: 'Pakistan',
      countryCode: 'PK',
      timezoneId: 'Asia/Karachi',
      source: PrayerLocationSource.current,
      geonameId: 1174872,
    );

    final restored = PrayerLocation.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.latitude, original.latitude);
    expect(restored.longitude, original.longitude);
    expect(restored.geonameId, 1174872);
    expect(restored.source, PrayerLocationSource.current);
  });

  test('offline city catalog is bundled and contains worldwide city records', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    expect(catalog.countryCodes(), contains('PK'));
    expect(catalog.countryCodes(), contains('US'));
    expect(catalog.countryCodes(), contains('JP'));

    final karachi = catalog.citiesForCountry('PK', query: 'Karachi');
    final tokyo = catalog.citiesForCountry('JP', query: 'Tokyo');
    final london = catalog.citiesForCountry('GB', query: 'London');

    expect(karachi, isNotEmpty);
    expect(karachi.first.geonameId, greaterThan(0));
    expect(karachi.first.region, isNotEmpty);
    expect(karachi.first.country, isNotEmpty);
    expect(karachi.first.timezoneId, 'Asia/Karachi');
    expect(tokyo, isNotEmpty);
    expect(tokyo.first.timezoneId, 'Asia/Tokyo');
    expect(london, isNotEmpty);
    expect(london.first.timezoneId, 'Europe/London');

    expect(tz.getLocation(karachi.first.timezoneId), isNotNull);
    expect(tz.getLocation(tokyo.first.timezoneId), isNotNull);
    expect(tz.getLocation(london.first.timezoneId), isNotNull);
  });

  test('reverse GeoNames lookup keeps the actual requested GPS coordinates', () {
    final resolver = OfflineCityResolver(
      geocoder: GeonamesReverseGeocoder.cities15000(),
    );

    const latitude = 24.861234;
    const longitude = 67.002345;

    final location = resolver.resolveCurrent(
      latitude: latitude,
      longitude: longitude,
      deviceTimezoneId: 'Asia/Karachi',
    );

    expect(location.latitude, latitude);
    expect(location.longitude, longitude);
    expect(location.source, PrayerLocationSource.current);
    expect(location.geonameId, greaterThan(0));
    expect(location.city.toLowerCase(), contains('karachi'));
    expect(location.timezoneId, 'Asia/Karachi');
  });

  test('invalid GPS timezone fails instead of selecting a country fallback', () {
    final resolver = OfflineCityResolver(
      geocoder: GeonamesReverseGeocoder.cities15000(),
    );

    expect(
      () => resolver.resolveCurrent(
        latitude: 24.861234,
        longitude: 67.002345,
        deviceTimezoneId: 'Not/A/RealTimezone',
      ),
      throwsA(isA<PrayerLocationException>()),
    );
  });

  test('automatic GPS acquisition is absent from refresh and lifecycle paths', () {
    final controller = File(
      'lib/features/prayer_time/application/prayer_time_controller.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/prayer_time/data/prayer_location_repository.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/prayer_time/presentation/prayer_time_page.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/features/prayer_time/data/offline_city_resolver.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(controller, isNot(contains('getLastKnown')));
    expect(controller, isNot(contains('_silentRefresh')));
    expect(repository, isNot(contains('getLastKnownPosition')));

    final lifecycleStart = page.indexOf('void didChangeAppLifecycleState');
    final lifecycleEnd = page.indexOf(
      'void _openAppSettings()',
      lifecycleStart,
    );
    expect(lifecycleStart, greaterThanOrEqualTo(0));
    expect(lifecycleEnd, greaterThan(lifecycleStart));
    final lifecycle = page.substring(lifecycleStart, lifecycleEnd);
    expect(lifecycle, isNot(contains('useCurrentLocation')));

    expect(resolver, isNot(contains('timezone_country')));
    expect(resolver, isNot(contains('TimezoneConvert')));
    expect(resolver, isNot(contains('countryToTimezones')));
    expect(resolver, isNot(contains('timezoneCoordinatesMap')));
    expect(pubspec, isNot(contains('timezone_country:')));
  });

  test('catalog has the required eight fields in its header', () async {
    final raw = await rootBundle.loadString(
      'assets/data/geonames_cities15000.tsv',
    );
    final header = raw.split('\n').first;

    expect(
      header,
      'geonameId\tcity\tregion\tcountry\tcountryCode\tlatitude\tlongitude\ttimezoneId',
    );
  });
}
