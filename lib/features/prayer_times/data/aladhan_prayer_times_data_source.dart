import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/prayer_times_models.dart';

abstract class PrayerTimesRemoteDataSource {
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  });
}

class AlAdhanPrayerTimesDataSource implements PrayerTimesRemoteDataSource {
  AlAdhanPrayerTimesDataSource({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async {
    final datePath =
        '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year.toString().padLeft(4, '0')}';

    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/timings/$datePath',
      <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': _methodId(method).toString(),
        'school': asrMethod == AsrMethod.hanafi ? '1' : '0',
      },
    );

    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'AlAdhan request failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('AlAdhan returned an invalid response.');
    }

    if (decoded['code'] != 200) {
      throw StateError(
        'AlAdhan returned status ${decoded['status'] ?? 'error'}.',
      );
    }

    final data = decoded['data'];
    if (data is! Map) {
      throw StateError('AlAdhan returned no prayer-time data.');
    }

    final timings = Map<String, dynamic>.from(data['timings'] as Map);
    final hijri = Map<String, dynamic>.from(
      Map<String, dynamic>.from(data['date'] as Map)['hijri'] as Map,
    );

    final resolvedTimezone =
        (Map<String, dynamic>.from(data['meta'] as Map)['timezone']
                ?.toString() ??
            timezone ??
            '')
            .trim();

    if (resolvedTimezone.isEmpty) {
      throw StateError('AlAdhan returned no timezone.');
    }

    final fajr = _parseTime(timings, 'Fajr');
    final sunrise = _parseTime(timings, 'Sunrise');
    final dhuhr = _parseTime(timings, 'Dhuhr');
    final asr = _parseTime(timings, 'Asr');
    final maghrib = _parseTime(timings, 'Maghrib');
    final isha = _parseTime(timings, 'Isha');
    final sunset = _parseTime(timings, 'Sunset');

    final hijriMonth =
        Map<String, dynamic>.from(hijri['month'] as Map)['en']?.toString() ??
        '';

    if (hijriMonth.isEmpty) {
      throw StateError('AlAdhan returned no Hijri month.');
    }

    final methodName =
        Map<String, dynamic>.from(
          Map<String, dynamic>.from(data['meta'] as Map)['method'] as Map,
        )['name']?.toString();

    return PrayerDay(
      date: DateTime(date.year, date.month, date.day),
      timezone: resolvedTimezone,
      times: <PrayerName, PrayerTime>{
        PrayerName.fajr: fajr,
        PrayerName.sunrise: sunrise,
        PrayerName.dhuhr: dhuhr,
        PrayerName.asr: asr,
        PrayerName.maghrib: maghrib,
        PrayerName.isha: isha,
      },
      // AlAdhan does not expose solar noon as a separate timing. Dhuhr is
      // the API's daily noon prayer time and is the closest available wall
      // time for the existing restricted-zawal calculation.
      solarNoon: DateTime(
        date.year,
        date.month,
        date.day,
        dhuhr.hour,
        dhuhr.minute,
      ),
      sunset: DateTime(
        date.year,
        date.month,
        date.day,
        sunset.hour,
        sunset.minute,
      ),
      hijriDate: HijriDate(
        day: int.parse(hijri['day'].toString()),
        month: hijriMonth,
        year: int.parse(hijri['year'].toString()),
      ),
      fetchedAt: DateTime.now().toUtc(),
      resolvedCalculationMethodName: methodName,
    );
  }

  int _methodId(CalculationMethod method) => switch (method) {
        CalculationMethod.recommended => 1,
        CalculationMethod.jafari => 0,
        CalculationMethod.karachi => 1,
        CalculationMethod.isna => 2,
        CalculationMethod.mwl => 3,
        CalculationMethod.makkah => 4,
        CalculationMethod.egyptian => 5,
        CalculationMethod.tehran => 7,
        CalculationMethod.gulf => 8,
        CalculationMethod.kuwait => 9,
        CalculationMethod.qatar => 10,
        CalculationMethod.singapore => 11,
        CalculationMethod.france => 12,
        CalculationMethod.turkey => 13,
        CalculationMethod.russia => 14,
        CalculationMethod.moonsighting => 15,
        CalculationMethod.dubai => 16,
        CalculationMethod.jakim => 17,
        CalculationMethod.tunisia => 18,
        CalculationMethod.algeria => 19,
        CalculationMethod.kemenag => 20,
        CalculationMethod.morocco => 21,
        CalculationMethod.portugal => 22,
        CalculationMethod.jordan => 23,
      };

  PrayerTime _parseTime(Map<String, dynamic> timings, String key) {
    final raw = timings[key];
    if (raw is! String) {
      throw StateError('AlAdhan response is missing $key.');
    }

    final match = RegExp(r'^(\\d{1,2}):(\\d{2})').firstMatch(raw.trim());
    if (match == null) {
      throw StateError('Invalid AlAdhan time for $key: $raw');
    }

    return PrayerTime(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }
}
