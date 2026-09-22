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
  Future<List<CitySearchResult>> search(
    String query, {
    String? countryCode,
  });
}
