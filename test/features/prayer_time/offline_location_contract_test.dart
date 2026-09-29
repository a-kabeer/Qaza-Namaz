import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonames_offline/geonames_offline.dart';
import 'package:qaza_namaz/features/prayer_time/data/offline_city_resolver.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_location.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time.dart';
import 'package:qaza_namaz/features/prayer_time/domain/prayer_time_calculator.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
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

    const pakistanCities = [
      ('Karachi', 'Asia/Karachi'),
      ('Hyderabad', 'Asia/Karachi'),
      ('Lahore', 'Asia/Karachi'),
      ('Islamabad', 'Asia/Karachi'),
      ('Peshawar', 'Asia/Karachi'),
      ('Quetta', 'Asia/Karachi'),
    ];
    for (final (name, timezoneId) in pakistanCities) {
      final results = catalog.citiesForCountry('PK', query: name);
      expect(results, isNotEmpty, reason: 'Missing $name');
      final city = results.first;
      expect(city.geonameId, greaterThan(0));
      expect(city.region, isNotEmpty, reason: 'Missing region for $name');
      expect(city.country, 'Pakistan');
      expect(city.countryCode, 'PK');
      expect(city.timezoneId, timezoneId);
      expect(tz.getLocation(city.timezoneId), isNotNull);
    }

    const internationalCities = [
      ('Tokyo', 'JP', 'Asia/Tokyo'),
      ('London', 'GB', 'Europe/London'),
      ('New York', 'US', 'America/New_York'),
      ('Cairo', 'EG', 'Africa/Cairo'),
      ('Sydney', 'AU', 'Australia/Sydney'),
      ('Jakarta', 'ID', 'Asia/Jakarta'),
    ];
    for (final (name, countryCode, timezoneId) in internationalCities) {
      final results = catalog.citiesForCountry(countryCode, query: name);
      expect(results, isNotEmpty, reason: 'Missing $name ($countryCode)');
      final city = results.first;
      expect(city.countryCode, countryCode);
      expect(city.timezoneId, timezoneId);
      expect(city.latitude.isFinite, isTrue);
      expect(city.longitude.isFinite, isTrue);
      expect(tz.getLocation(city.timezoneId), isNotNull);
    }
  });


  test('city search is case-insensitive and trims whitespace', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    final exact = catalog.citiesForCountry('PK', query: 'Karachi');
    final lower = catalog.citiesForCountry('PK', query: 'karachi');
    final mixed = catalog.citiesForCountry('PK', query: 'KaRaChI');
    final padded = catalog.citiesForCountry('PK', query: '  Karachi  ');

    expect(exact, isNotEmpty);
    expect(lower, isNotEmpty);
    expect(mixed, isNotEmpty);
    expect(padded, isNotEmpty);
    expect(
      lower.map((city) => city.geonameId),
      contains(exact.first.geonameId),
    );
    expect(
      mixed.map((city) => city.geonameId),
      contains(exact.first.geonameId),
    );
    expect(
      padded.map((city) => city.geonameId),
      contains(exact.first.geonameId),
    );
  });

  test('city search is diacritic-insensitive', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    final results = catalog.citiesForCountry('AF', query: 'Herat');

    expect(
      results.any((city) => city.city == 'Herāt'),
      isTrue,
      reason: 'ASCII Herat should match the catalog entry Herāt.',
    );
  });

  test('city search matches region while preserving country restriction', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    final sindh = catalog.citiesForCountry('PK', query: 'Sindh');
    final japan = catalog.citiesForCountry('JP', query: 'Sindh');
    final emptyCountry = catalog.citiesForCountry('PK', query: 'Tokyo');

    expect(sindh, isNotEmpty);
    expect(sindh.any((city) => city.city == 'Karachi'), isTrue);
    expect(japan, isEmpty);
    expect(emptyCountry, isEmpty);
  });

  test('empty and whitespace-only city queries preserve the initial city list', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    final allCities = catalog.citiesForCountry('PK');
    final emptyQuery = catalog.citiesForCountry('PK', query: '');
    final whitespaceQuery = catalog.citiesForCountry('PK', query: '   ');

    expect(allCities, isNotEmpty);
    expect(
      emptyQuery.map((city) => city.geonameId),
      orderedEquals(allCities.map((city) => city.geonameId)),
    );
    expect(
      whitespaceQuery.map((city) => city.geonameId),
      orderedEquals(allCities.map((city) => city.geonameId)),
    );
  });

  test('nonexistent city query returns no results', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();

    expect(
      catalog.citiesForCountry('PK', query: 'DefinitelyNotACity'),
      isEmpty,
    );
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

    expect(page, isNot(contains('WidgetsBindingObserver')));
    expect(page, isNot(contains('didChangeAppLifecycleState')));
    expect(page, isNot(contains('WidgetsBinding.instance.addObserver')));

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
    final header = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n').first;

    expect(
      header,
      'geonameId\tcity\tregion\tcountry\tcountryCode\tlatitude\tlongitude\ttimezoneId',
    );
  });


  test('manual city coordinates drive distinct prayer calculations', () async {
    final catalog = OfflineCityCatalog();
    await catalog.load();
    final karachi = catalog.citiesForCountry('PK', query: 'Karachi').first;
    final tokyo = catalog.citiesForCountry('JP', query: 'Tokyo').first;
    const calculator = PrayerTimeCalculator();
    final date = DateTime(2026, 9, 29);
  
    const madhab = Madhab.hanafi;
    final karachiSchedule = calculator.calculate(
      location: PrayerLocation(
        latitude: karachi.latitude,
        longitude: karachi.longitude,
        city: karachi.city,
        region: karachi.region,
        country: karachi.country,
        countryCode: karachi.countryCode,
        timezoneId: karachi.timezoneId,
        source: PrayerLocationSource.city,
        geonameId: karachi.geonameId,
      ),
      madhab: madhab,
      localDate: date,
    );
    final tokyoSchedule = calculator.calculate(
      location: PrayerLocation(
        latitude: tokyo.latitude,
        longitude: tokyo.longitude,
        city: tokyo.city,
        region: tokyo.region,
        country: tokyo.country,
        countryCode: tokyo.countryCode,
        timezoneId: tokyo.timezoneId,
        source: PrayerLocationSource.city,
        geonameId: tokyo.geonameId,
      ),
      madhab: madhab,
      localDate: date,
    );
  
    expect(
      karachiSchedule.utcFor(PrayerSlot.fajr),
      isNot(tokyoSchedule.utcFor(PrayerSlot.fajr)),
    );
  });
}
