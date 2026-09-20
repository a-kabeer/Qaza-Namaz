import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_times_models.dart';

class PrayerTimesCache(this._preferencesFuture);

  static const _locationKey = 'prayer_times_v1.location';
  static const _settingsKey = 'prayer_times_v1.settings';
  static const _daysKey = 'prayer_times_v1.days';
  static const _maxCachedDays = 30;

  final Future<SharedPreferences> _preferencesFuture;

  Future<PrayerLocation?> getLocation() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_locationKey);
    if (raw == null) return null;
    try {
      return PrayerLocation.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocation(PrayerLocation location) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(_locationKey, jsonEncode(location.toJson()));
  }

  Future<PrayerSettings> getSettings() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_settingsKey);
    if (raw == null) return const PrayerSettings();
    try {
      return PrayerSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PrayerSettings();
    }
  }

  Future<void> saveSettings(PrayerSettings settings) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<PrayerDay?> getDay(PrayerTimesRequest request) async {
    final preferences = await _preferencesFuture;
    final days = _readDays(preferences);
    final raw = days[request.cacheKey];
    if (raw is! String) return null;
    try {
      return PrayerDay.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDay(
    PrayerTimesRequest request,
    PrayerDay day,
  ) async {
    final preferences = await _preferencesFuture;
    final days = _readDays(preferences);
    days[request.cacheKey] = jsonEncode(day.toJson());

    final entries = days.entries.toList()
      ..sort((a, b) {
        final aDay = _decodeFetchedAt(a.value);
        final bDay = _decodeFetchedAt(b.value);
        return bDay.compareTo(aDay);
      });

    final retained = <String, String>{
      for (final entry in entries.take(_maxCachedDays))
        entry.key: entry.value,
    };

    await preferences.setString(_daysKey, jsonEncode(retained));
  }

  Map<String, String> _readDays(SharedPreferences preferences) {
    final raw = _preferences.getString(_daysKey);
    if (raw == null) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  DateTime _decodeFetchedAt(String raw) {
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return DateTime.parse(decoded['fetchedAt'] as String);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}
