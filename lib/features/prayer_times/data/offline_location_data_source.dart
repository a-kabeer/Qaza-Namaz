import 'package:flutter_countries/flutter_countries.dart';
import 'package:timezone_country/timezone_country.dart';

import '../domain/prayer_times_models.dart';
import 'location/city_search_provider.dart';

abstract class OfflineLocationDataSource {
  Future<List<CitySearchResult>> searchCities(
    String query, {
    String? countryCode,
  });
  Future<List<PrayerCountryOption>> getCountries();
  Future<CitySearchResult?> findNearestCity({
    required double latitude,
    required double longitude,
  });
}

class OfflineCityDataSource implements OfflineLocationDataSource {
  const OfflineCityDataSource();

  @override
  Future<List<PrayerCountryOption>> getCountries() async {
    final countries = await Countries.all;
    final options = <PrayerCountryOption>[];
    for (final country in countries) {
      final name = country.name?.trim();
      final iso2 = country.iso2?.trim();
      if (name == null || name.isEmpty || iso2 == null || iso2.isEmpty) {
        continue;
      }
      options.add(
        PrayerCountryOption(
          name: name,
          iso2: iso2,
          nativeName: country.native?.trim(),
          emoji: country.emoji?.trim(),
        ),
      );
    }
    options.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(options);
  }

  @override
  Future<List<CitySearchResult>> searchCities(
    String query, {
    String? countryCode,
  }) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const <CitySearchResult>[];

    final results = await Cities.byName(normalized);
    final cities = <CitySearchResult>[];

    for (final city in results) {
      final lat = double.tryParse(city.latitude ?? '');
      final lon = double.tryParse(city.longitude ?? '');
      if (lat == null || lon == null) continue;

      final cityCountryCode = city.countryCode;
      if (countryCode != null &&
          countryCode.isNotEmpty &&
          cityCountryCode?.toUpperCase() != countryCode.toUpperCase()) {
        continue;
      }

      final timezone = TimezoneConvert.nearestTimezone(
        lat,
        lon,
        countryCode: cityCountryCode,
      );

      cities.add(
        CitySearchResult(
          name: city.name ?? '',
          country: city.countryName ?? '',
          latitude: lat,
          longitude: lon,
          region: city.stateName,
          countryCode: cityCountryCode,
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
    final results = await Cities.byCoords(
      latitude.toStringAsFixed(4),
      longitude.toStringAsFixed(4),
    );

    CitySearchResult? nearest;
    var nearestDistance = double.infinity;

    for (final city in results) {
      final lat = double.tryParse(city.latitude ?? '');
      final lon = double.tryParse(city.longitude ?? '');
      if (lat == null || lon == null) continue;

      final distance = _distanceSquared(latitude, longitude, lat, lon);
      if (distance >= nearestDistance) continue;

      final countryCode = city.countryCode;
      final timezone = TimezoneConvert.nearestTimezone(
        lat,
        lon,
        countryCode: countryCode,
      );

      nearestDistance = distance;
      nearest = CitySearchResult(
        name: city.name ?? '',
        country: city.countryName ?? '',
        latitude: lat,
        longitude: lon,
        region: city.stateName,
        countryCode: countryCode,
        timezone: timezone,
      );
    }

    return nearest;
  }

  double _distanceSquared(
    double aLat,
    double aLon,
    double bLat,
    double bLon,
  ) {
    final dLat = aLat - bLat;
    final dLon = aLon - bLon;
    return (dLat * dLat) + (dLon * dLon);
  }
}
