import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/features/prayer_times/data/location/open_meteo_city_search_provider.dart';

void main() {
  test('parses city search results with coordinates and timezone', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['name'], 'Karachi');
      expect(request.url.queryParameters['count'], '8');
      return http.Response(
        jsonEncode({
          'results': [
            {
              'name': 'Karachi',
              'country': 'Pakistan',
              'country_code': 'PK',
              'admin1': 'Sindh',
              'latitude': 24.8607,
              'longitude': 67.0011,
              'timezone': 'Asia/Karachi',
            },
          ],
        }),
        200,
      );
    });

    final provider = OpenMeteoCitySearchProvider(client: client);
    final results = await provider.search('Karachi');

    expect(results, hasLength(1));
    expect(results.first.name, 'Karachi');
    expect(results.first.countryCode, 'PK');
    expect(results.first.timezone, 'Asia/Karachi');
  });

  test('does not call the API for one-character queries', () async {
    var called = false;
    final provider = OpenMeteoCitySearchProvider(
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    expect(await provider.search('K'), isEmpty);
    expect(called, isFalse);
  });
}
