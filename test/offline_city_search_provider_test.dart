import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/data/location/city_search_provider.dart';
import '../lib/features/prayer_times/data/offline_city_search_provider.dart';
import '../lib/features/prayer_times/data/offline_location_data_source.dart';

class _FakeDataSource implements OfflineLocationDataSource {
  @override
  Future<List<CitySearchResult>> searchCities(String query) async => const [
        CitySearchResult(
          name: 'Karachi',
          country: 'Pakistan',
          countryCode: 'PK',
          latitude: 24.8607,
          longitude: 67.0011,
          region: 'Sindh',
          timezone: 'Asia/Karachi',
        ),
      ];

  @override
  Future<List<CitySearchResult>> searchCitiesInCountry(
    String query, {
    String? countryCode,
  }) async {
    final results = await searchCities(query);
    if (countryCode == null || countryCode.isEmpty) return results;
    return results
        .where((city) => city.countryCode == countryCode)
        .toList(growable: false);
  }

  @override
  Future<List<PrayerCountryOption>> getCountries() async => const [];

  @override
  Future<CitySearchResult?> findNearestCity({
    required double latitude,
    required double longitude,
  }) async =>
      const CitySearchResult(
        name: 'Karachi',
        country: 'Pakistan',
        countryCode: 'PK',
        latitude: 24.8607,
        longitude: 67.0011,
        region: 'Sindh',
        timezone: 'Asia/Karachi',
      );
}

void main() {
  test('offline city provider delegates to local data source', () async {
    final provider = OfflineCitySearchProvider(
      dataSource: _FakeDataSource(),
    );

    final result = await provider.search('Karachi');

    expect(result.single.name, 'Karachi');
    expect(result.single.countryCode, 'PK');
    expect(result.single.timezone, 'Asia/Karachi');
  });
}
