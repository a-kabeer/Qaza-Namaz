class CitySearchResult {
  const CitySearchResult({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.region,
    this.countryCode,
    this.timezone,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String? region;
  final String? countryCode;
  final String? timezone;
}

abstract class CitySearchProvider {
  Future<List<CitySearchResult>> search(String query);

  Future<List<CitySearchResult>> searchInCountry(
    String query, {
    String? countryCode,
  }) async {
    final results = await search(query);
    if (countryCode == null || countryCode.isEmpty) return results;
    return results
        .where(
          (result) =>
              result.countryCode?.toUpperCase() == countryCode.toUpperCase(),
        )
        .toList(growable: false);
  }
}
