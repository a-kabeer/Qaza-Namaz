import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qaza_namaz/features/prayer_times/data/aladhan_prayer_times_data_source.dart';
import 'package:qaza_namaz/features/prayer_times/domain/prayer_times_models.dart';

void main() {
  test('parses AlAdhan timings and Hijri date', () async {
    Uri? requestedUri;

    final client = _MockClient((request) {
      requestedUri = request.url;
      return http.Response(
        jsonEncode(_responseJson()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = AlAdhanPrayerTimesDataSource(client: client);

    final day = await source.getPrayerTimes(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 22),
      method: CalculationMethod.recommended,
      asrMethod: AsrMethod.hanafi,
      timezone: 'Asia/Karachi',
    );

    expect(requestedUri?.host, 'api.aladhan.com');
    expect(requestedUri?.path, '/v1/timings/22-09-2026');
    expect(requestedUri?.queryParameters['method'], '3');
    expect(requestedUri?.queryParameters['school'], '1');

    expect(day.timezone, 'Asia/Karachi');
    expect(day.times[PrayerName.fajr]?.formatted, '04:32');
    expect(day.times[PrayerName.dhuhr]?.formatted, '12:00');
    expect(day.times[PrayerName.asr]?.formatted, '15:29');
    expect(day.times[PrayerName.isha]?.formatted, '19:28');
    expect(day.hijriDate.day, 11);
    expect(day.hijriDate.year, 1448);
    expect(day.hijriDate.month, 'Rabīʿ al-thānī');
    expect(
      day.resolvedCalculationMethodName,
      'University of Islamic Sciences, Karachi',
    );
  });

  test('uses standard school when Asr method is standard', () async {
    Uri? requestedUri;

    final client = _MockClient((request) {
      requestedUri = request.url;
      return http.Response(
        jsonEncode(_responseJson()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = AlAdhanPrayerTimesDataSource(client: client);

    await source.getPrayerTimes(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 22),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.standard,
    );

    expect(requestedUri?.queryParameters['method'], '1');
    expect(requestedUri?.queryParameters['school'], '0');
  });

  test('throws when AlAdhan returns a failed status', () async {
    final client = _MockClient((request) {
      return http.Response(
        jsonEncode({
          'code': 500,
          'status': 'ERROR',
          'data': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final source = AlAdhanPrayerTimesDataSource(client: client);

    expect(
      () => source.getPrayerTimes(
        latitude: 24.8607,
        longitude: 67.0011,
        date: DateTime(2026, 9, 22),
        method: CalculationMethod.karachi,
        asrMethod: AsrMethod.standard,
      ),
      throwsA(isA<StateError>()),
    );
  });
}

Map<String, dynamic> _responseJson() => {
      'code': 200,
      'status': 'OK',
      'data': {
        'timings': {
          'Fajr': '04:32 (+05)',
          'Sunrise': '05:56 (+05)',
          'Dhuhr': '12:00 (+05)',
          'Asr': '15:29 (+05)',
          'Sunset': '18:05 (+05)',
          'Maghrib': '18:05 (+05)',
          'Isha': '19:28 (+05)',
        },
        'date': {
          'hijri': {
            'day': '11',
            'month': {
              'en': 'Rabīʿ al-thānī',
            },
            'year': '1448',
          },
        },
        'meta': {
          'timezone': 'Asia/Karachi',
          'method': {
            'name': 'University of Islamic Sciences, Karachi',
          },
        },
      },
    };

typedef _RequestHandler = http.Response Function(http.Request);

class _MockClient extends http.BaseClient {
  _MockClient(this._handler);

  final _RequestHandler _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _handler(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
