import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/features/prayer_times/data/aladhan_provider.dart';
import '../lib/features/prayer_times/data/prayer_times_provider.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

void main() {
  Map<String, dynamic> responseBody() => {
        'code': 200,
        'status': 'OK',
        'data': {
          'timings': {
            'Fajr': '2026-09-20T04:52:00+05:00',
            'Sunrise': '2026-09-20T06:08:00+05:00',
            'Dhuhr': '2026-09-20T12:20:00+05:00',
            'Asr': '2026-09-20T16:45:00+05:00',
            'Maghrib': '2026-09-20T18:28:00+05:00',
            'Isha': '2026-09-20T19:44:00+05:00',
          },
          'date': {
            'hijri': {
              'day': '18',
              'month': {'en': 'Rabi al-Thani'},
              'year': '1448',
            },
          },
          'meta': {
            'timezone': 'Asia/Karachi',
            'method': {'id': 1, 'name': 'University of Islamic Sciences, Karachi'},
          },
        },
      };

  test('parses ISO prayer times, Hijri date, timezone and method', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['school'], '1');
      expect(request.url.queryParameters['method'], '1');
      expect(request.url.queryParameters['iso8601'], 'true');
      return http.Response(jsonEncode(responseBody()), 200);
    });

    final provider = AlAdhanProvider(client: client);
    final day = await provider.fetch(
      PrayerTimesRequest(
        latitude: 24.8607,
        longitude: 67.0011,
        date: DateTime(2026, 9, 20),
        method: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
      ),
    );

    expect(day.times[PrayerName.fajr]!.formatted, '04:52');
    expect(day.times[PrayerName.isha]!.formatted, '19:44');
    expect(day.timezone, 'Asia/Karachi');
    expect(day.hijriDate.year, 1448);
    expect(day.resolvedCalculationMethodName, contains('Karachi'));
  });

  test('omits explicit method for recommended calculation', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters.containsKey('method'), isFalse);
      return http.Response(jsonEncode(responseBody()), 200);
    });

    final provider = AlAdhanProvider(client: client);
    await provider.fetch(
      PrayerTimesRequest(
        latitude: 24.8607,
        longitude: 67.0011,
        date: DateTime(2026, 9, 20),
        method: CalculationMethod.recommended,
        asrMethod: AsrMethod.standard,
      ),
    );
  });

  test('rejects invalid coordinates', () async {
    final provider = AlAdhanProvider(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => provider.fetch(
        PrayerTimesRequest(
          latitude: 200,
          longitude: 0,
          date: DateTime(2026, 9, 20),
          method: CalculationMethod.karachi,
          asrMethod: AsrMethod.standard,
        ),
      ),
      throwsA(isA<PrayerApiException>()),
    );
  });
}
