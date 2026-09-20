import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/prayer_schedule.dart';
import '../domain/prayer_times_models.dart';
import 'prayer_times_provider.dart';

class AlAdhanProvider implements PrayerTimesProvider {
  AlAdhanProvider({
    required http.Client client,
    this.baseUri = 'https://api.aladhan.com/v1',
  }) : _client = client;

  final http.Client _client;
  final String baseUri;

  @override
  Future<PrayerDay> fetch(PrayerTimesRequest request) async {
    _validateCoordinates(request.latitude, request.longitude);

    final dateKey =
        '${request.date.year.toString().padLeft(4, '0')}-'
        '${request.date.month.toString().padLeft(2, '0')}-'
        '${request.date.day.toString().padLeft(2, '0')}';

    final query = <String, String>{
      'latitude': request.latitude.toString(),
      'longitude': request.longitude.toString(),
      'school': request.asrMethod.apiValue.toString(),
      // Keep high-latitude behavior deterministic while V1 intentionally
      // exposes no user-facing astronomical adjustment controls.
      'latitudeAdjustmentMethod': '3',
      'iso8601': 'true',
    };

    final methodId = request.method.apiId;
    if (methodId != null) {
      query['method'] = methodId.toString();
    }

    final uri = Uri.parse('$baseUri/timings/$dateKey').replace(
      queryParameters: query,
    );

    http.Response response;
    try {
      response = await _client.get(uri).timeout(
            const Duration(seconds: 12),
          );
    } on TimeoutException {
      throw const PrayerApiException(
        'Prayer times service timed out. Please try again.',
      );
    } on http.ClientException {
      throw const PrayerApiException(
        'Prayer times service is unavailable. Please try again.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const PrayerApiException('Prayer times response was invalid.');
    }

    if (response.statusCode != 200 || body['code'] != 200) {
      final status = body['status'];
      throw PrayerApiException(
        status is String && status.isNotEmpty
            ? 'Prayer times service returned: $status'
            : 'Prayer times service returned an error.',
      );
    }

    final data = body['data'];
    if (data is! Map) {
      throw const PrayerApiException('Prayer times response had no data.');
    }

    final timings = data['timings'];
    final date = data['date'];
    final meta = data['meta'];
    if (timings is! Map || date is! Map || meta is! Map) {
      throw const PrayerApiException(
        'Prayer times response is missing required fields.',
      );
    }

    final parsedTimes = <PrayerName, PrayerTime>{};
    for (final prayer in PrayerName.values) {
      final raw = timings[prayer.apiKey];
      if (raw is! String) {
        throw PrayerApiException(
          'Prayer times response is missing ${prayer.apiKey}.',
        );
      }
      parsedTimes[prayer] = _parsePrayerTime(raw);
    }

    final hijri = date['hijri'];
    if (hijri is! Map) {
      throw const PrayerApiException('Prayer times response has no Hijri date.');
    }

    final month = hijri['month'];
    if (month is! Map) {
      throw const PrayerApiException('Prayer times response has no Hijri month.');
    }

    final timezone = meta['timezone'];
    if (timezone is! String ||
        timezone.trim().isEmpty ||
        !PrayerSchedule.isKnownTimezone(timezone)) {
      throw const PrayerApiException(
        'Prayer times response is missing a valid timezone.',
      );
    }

    final resolvedMethod = meta['method'];
    final resolvedMethodName = resolvedMethod is Map
        ? resolvedMethod['name'] as String?
        : null;

    return PrayerDay(
      date: DateTime(request.date.year, request.date.month, request.date.day),
      timezone: timezone.trim(),
      times: parsedTimes,
      hijriDate: HijriDate(
        day: _parseInt(hijri['day']),
        month: month['en'] is String ? month['en'] as String : 'Unknown',
        year: _parseInt(hijri['year']),
      ),
      fetchedAt: DateTime.now().toUtc(),
      resolvedCalculationMethodName: resolvedMethodName,
    );
  }

  PrayerTime _parsePrayerTime(String value) {
    final normalized = value.trim();
    var clock = normalized;
    final separator = normalized.indexOf('T');
    if (separator >= 0 && normalized.length >= separator + 6) {
      clock = normalized.substring(separator + 1, separator + 6);
    } else if (normalized.length >= 5) {
      clock = normalized.substring(0, 5);
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clock);
    if (match == null) {
      throw PrayerApiException('Invalid prayer time: $value');
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw PrayerApiException('Invalid prayer time: $value');
    }

    return PrayerTime(hour: hour, minute: minute);
  }

  int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.parse(value);
    throw const PrayerApiException(
      'Prayer times response contains invalid data.',
    );
  }

  void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const PrayerApiException('Invalid location coordinates.');
    }
  }
}
