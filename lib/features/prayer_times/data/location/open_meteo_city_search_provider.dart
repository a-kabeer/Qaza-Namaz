import 'dart:convert';

import 'package:http/http.dart' as http;

import 'city_search_provider.dart';

class OpenMeteoCitySearchProvider implements CitySearchProvider {
  OpenMeteoCitySearchProvider({
    required http.Client client,
    this.baseUri = 'https://geocoding-api.open-meteo.com/v1/search',
  }) : _client = client;

  final http.Client _client;
  final String baseUri;

  @override
  Future<List<CitySearchResult>> search(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const <CitySearchResult>[];

    final uri = Uri.parse(baseUri).replace(
      queryParameters: <String, String>{
        'name': normalized,
        'count': '8',
        'language': 'en',
        'format': 'json',
      },
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) {
      throw const CitySearchException('City search failed.');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['results'] is! List) {
        return const <CitySearchResult>[];
      }

      return [
        for (final item in decoded['results'])
          if (item is Map && _isValid(item)) _toResult(item),
      ];
    } on CitySearchException {
      rethrow;
    } catch (_) {
      throw const CitySearchException('City search response was invalid.');
    }
  }

  static bool _isValid(Map item) {
    return item['name'] is String &&
        item['country'] is String &&
        item['latitude'] is num &&
        item['longitude'] is num;
  }

  static CitySearchResult _toResult(Map item) {
    return CitySearchResult(
      name: item['name'] as String,
      country: item['country'] as String,
      latitude: (item['latitude'] as num).toDouble(),
      longitude: (item['longitude'] as num).toDouble(),
      region: item['admin1'] as String?,
      countryCode: item['country_code'] as String?,
      timezone: item['timezone'] as String?,
    );
  }
}

class CitySearchException implements Exception {
  const CitySearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
