import 'package:flutter_countries/flutter_countries.dart';
import 'package:timezone_country/timezone_country.dart';

import '../domain/prayer_times_models.dart';
import 'location/city_search_provider.dart';

abstract class OfflineLocationDataSource {
  Future<List<CitySearchResult>> searchCities(String query);

  Future<List<CitySearchResult>> searchCitiesInCountry(
    String query, {
    String? countryCode,
  }) async {
    final results = await searchCities(query);
    if (countryCode == null || countryCode.isEmpty) return results;
    return results
        .where(
          (result) =>
              result.countryCode?.toUpperCase() == countryCode.toUpperCase(),
        )
        .toList(growable: false);
  }

  Future<List<PrayerCountryOption>> getCountries() async =>
      const <PrayerCountryOption>[];

  Future<List<CitySearchResult>> popularCitiesInCountry(
    String countryCode,
  ) => searchCitiesInCountry('', countryCode: countryCode);

  Future<CitySearchResult?> findNearestCity({
    required double latitude,
    required double longitude,
  });
}

class OfflineCityDataSource implements OfflineLocationDataSource {
  OfflineCityDataSource();

  static const _maxResults = 12;
  static final Map<String, Future<List<CitySearchResult>>> _countryCache = {};

  static const _featuredCityNamesByCountry = <String, List<String>>{
    'PK': <String>[
      'Karachi',
      'Lahore',
      'Islamabad',
      'Rawalpindi',
      'Faisalabad',
      'Multan',
      'Hyderabad',
      'Peshawar',
      'Quetta',
      'Sialkot',
      'Gujranwala',
      'Abbottabad',
    ],
  };

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
  Future<List<CitySearchResult>> searchCities(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      return const <CitySearchResult>[];
    }

    final results = await Cities.byName(normalized);
    return _mapAndSort(results).take(_maxResults).toList(growable: false);
  }

  @override
  Future<List<CitySearchResult>> searchCitiesInCountry(
    String query, {
    String? countryCode,
  }) async {
    final code = countryCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return searchCities(query);
    }

    final cities = await _citiesForCountry(code);
    final normalized = query.trim().toLowerCase();

    final filtered = normalized.isEmpty
        ? _sortForInitialCountryView(cities, code)
        : cities.where((city) {
            final name = city.name.toLowerCase();
            final region = city.region?.toLowerCase() ?? '';
            return name.contains(normalized) ||
                region.contains(normalized);
          }).toList(growable: false);

    return _sortMatches(filtered, normalized)
        .take(_maxResults)
        .toList(growable: false);
  }

  Future<List<CitySearchResult>> _citiesForCountry(String countryCode) {
    return _countryCache.putIfAbsent(
      countryCode,
      () async {
        final results = await Cities.byCountryCode(countryCode);
        return List.unmodifiable(_mapAndSort(results));
      },
    );
  }

  List<CitySearchResult> _mapAndSort(Iterable<dynamic> results) {
    final cities = <CitySearchResult>[];
    for (final city in results) {
      final name = (city.name ?? '').toString().trim();
      final country = (city.countryName ?? '').toString().trim();
      final countryCode = city.countryCode?.toString().trim();
      final lat = double.tryParse(city.latitude?.toString() ?? '');
      final lon = double.tryParse(city.longitude?.toString() ?? '');

      if (name.isEmpty ||
          lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite) {
        continue;
      }

      final region = city.stateName?.toString().trim();

      cities.add(
        CitySearchResult(
          name: name,
          country: country,
          latitude: lat,
          longitude: lon,
          region: region == null || region.isEmpty ? null : region,
          countryCode: countryCode == null || countryCode.isEmpty
              ? null
              : countryCode,
        ),
      );
    }

    cities.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return cities;
  }

  List<CitySearchResult> _sortForInitialCountryView(
    List<CitySearchResult> cities,
    String countryCode,
  ) {
    final priorities = _featuredCityNamesByCountry[countryCode];
    if (priorities == null || priorities.isEmpty) {
      return List<CitySearchResult>.from(cities);
    }

    final rank = <String, int>{
      for (var index = 0; index < priorities.length; index++)
        priorities[index].toLowerCase(): index,
    };

    final sorted = List<CitySearchResult>.from(cities);
    sorted.sort((a, b) {
      final aRank = rank[a.name.toLowerCase()] ?? priorities.length;
      final bRank = rank[b.name.toLowerCase()] ?? priorities.length;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  List<CitySearchResult> _sortMatches(
    List<CitySearchResult> cities,
    String query,
  ) {
    if (query.isEmpty) return cities;

    final sorted = List<CitySearchResult>.from(cities);
    sorted.sort((a, b) {
      int score(CitySearchResult city) {
        final name = city.name.toLowerCase();
        if (name == query) return 0;
        if (name.startsWith(query)) return 1;
        return 2;
      }

      final scoreCompare = score(a).compareTo(score(b));
      if (scoreCompare != 0) return scoreCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
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
