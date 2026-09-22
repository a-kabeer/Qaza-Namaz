import 'city_search_provider.dart';
import 'offline_location_data_source.dart';

class OfflineCitySearchProvider implements CitySearchProvider {
  const OfflineCitySearchProvider({
    required OfflineLocationDataSource dataSource,
  }) : _dataSource = dataSource;

  final OfflineLocationDataSource _dataSource;

  @override
  Future<List<CitySearchResult>> search(String query) {
    return _dataSource.searchCities(query);
  }
}
