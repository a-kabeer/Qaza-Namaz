import 'package:geodb_flutter/geodb_flutter.dart';

import 'location/city_search_provider.dart';
import 'package:timezone_country/timezone_country.dart';

abstract class OfflineLocationDataSource {
  Future<List<CitySearchResult>> searchCities(String query);
  Future<CitySearchResult?> findNearestCity({
    required double latitude,
    required double longitude,
  });
}

class GeodbOfflineLocationDataSource implements OfflineLocationDataSource {
  GeodbOfflineLocationDataSource({GeodbFlutter? database})
      : _database = database ?? GeodbFlutter();

  final GeodbFlutter _database;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _database.initialize();
    _initialized = true;
  }

  @override
  Future<List<CitySearchResult>> searchCities(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const <CitySearchResult>[];

    await _ensureInitialized();
    final results = await _database.smartSearch(normalized);

    final cities = <CitySearchResult>[];
    for (final city in results) {
      // GeoDB uses an empty geoid for countries/states; cities have a geoid.
      if (city.geoid.isEmpty) continue;

      final timezone = TimezoneConvert.nearestTimezone(
        city.lat,
        city.lng,
        countryCode: city.iso2,
      );
      cities.add(
        CitySearchResult(
          name: city.name,
          country: city.country,
          latitude: city.lat,
          longitude: city.lng,
          region: city.state.isEmpty ? null : city.state,
          countryCode: city.iso2,
          timezone: timezone,
        ),
      );
      if (cities.length == 8) break;
    }
    return List.unmodifiable(cities);
  }

  @override
  Future<CitySearchResult?> findNearestCity({
    required double latitude,
    required double longitude,
  }) async {
    await _ensureInitialized();
    final results = await _database.findNearest(
      lat: latitude,
      lng: longitude,
      count: 1,
    );
    if (results.isEmpty) return null;

    final city = results.first;
    final timezone = TimezoneConvert.nearestTimezone(
      city.lat,
      city.lng,
      countryCode: city.iso2,
    );

    return CitySearchResult(
      name: city.name,
      country: city.country,
      latitude: city.lat,
      longitude: city.lng,
      region: city.state.isEmpty ? null : city.state,
      countryCode: city.iso2,
      timezone: timezone,
    );
  }
}
