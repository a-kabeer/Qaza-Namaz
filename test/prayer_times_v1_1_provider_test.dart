import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/features/prayer_times/data/aladhan_provider.dart';
import '../lib/features/prayer_times/data/prayer_times_provider.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

Map<String, dynamic> _response({
  String timezone = 'Asia/Karachi',
  Map<String, dynamic>? method,
  Map<String, dynamic>? timings,
}) =>
    {
      'code': 200,
      'status': 'OK',
      'data': {
        'timings': timings ??
            {
              'Fajr': '04:50',
              'Sunrise': '06:08',
              'Dhuhr': '12:20',
              'Asr': '16:45',
              'Maghrib': '18:28',
              'Isha': '19:44',
            },
        'date': {
          'hijri': {
            'day': '18',
            'month': {'en': 'Rabi al-Thani'},
            'year': '1448',
          },
        },
        'meta': {
          'timezone': timezone,
          'method': method ?? {'id': 1, 'name': 'University of Islamic Sciences, Karachi'},
        },
      },
    };

PrayerTimesRequest _request({
  double latitude = 24.8607,
  double longitude = 67.0011,
  CalculationMethod method = CalculationMethod.karachi,
}) =>
    PrayerTimesRequest(
      latitude: latitude,
      longitude: longitude,
      date: DateTime(2026, 9, 20),
      method: method,
      asrMethod: AsrMethod.hanafi,
    );

void main() {
  test('requests explicit high-latitude adjustment and Hanafi school', () async {
    final client = MockClient((request) async {
      expect(
        request.url.queryParameters['latitudeAdjustmentMethod'],
        '3',
      );
      expect(request.url.queryParameters['school'], '1');
      expect(request.url.queryParameters['method'], '1');
      expect(request.url.queryParameters['iso8601'], 'true');
      return http.Response(jsonEncode(_response()), 200);
    });

    await AlAdhanProvider(client: client).fetch(_request());
  });

  test('automatic calculation omits method and preserves resolved provider method',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters.containsKey('method'), isFalse);
      return http.Response(
        jsonEncode(
          _response(
            method: {
              'id': 3,
              'name': 'Muslim World League',
            },
          ),
        ),
        200,
      );
    });

    final day = await AlAdhanProvider(client: client).fetch(
      _request(method: CalculationMethod.recommended),
    );

    expect(day.resolvedCalculationMethodName, 'Muslim World League');
  });

  test('rejects a missing timezone instead of silently using UTC', () async {
    final payload = _response();
    (payload['data']['meta'] as Map<String, dynamic>).remove('timezone');

    final client = MockClient(
      (_) async => http.Response(jsonEncode(payload), 200),
    );

    expect(
      () => AlAdhanProvider(client: client).fetch(_request()),
      throwsA(isA<PrayerApiException>()),
    );
  });

  test('rejects an unknown timezone', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(_response(timezone: 'Not/A_Timezone')),
        200,
      ),
    );

    expect(
      () => AlAdhanProvider(client: client).fetch(_request()),
      throwsA(isA<PrayerApiException>()),
    );
  });

  test('maps request timeout to a user-safe API exception', () async {
    final client = MockClient(
      (_) => Future<http.Response>.error(
        TimeoutException('simulated timeout'),
      ),
    );

    expect(
      () => AlAdhanProvider(client: client).fetch(_request()),
      throwsA(isA<PrayerApiException>()),
    );
  });
}
