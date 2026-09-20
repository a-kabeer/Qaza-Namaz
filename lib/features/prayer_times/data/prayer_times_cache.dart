import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_times_models.dart';

class PrayerTimesCache {
  PrayerTimesCache(this._preferences);

  static const _locationKey = 'prayer_times_v1.location';
  static const _settingsKey = 'prayer_times_v1.settings';
  static const _daysKey = 'prayer_times_v1.days';
  static const _maxCachedDays = 30;

  final SharedPreferences _preferences;

  PrayerLocation? getLocation() {
    final raw = _preferences.getString(_locationKey);
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
    await _preferences.setString(_locationKey, jsonEncode(location.toJson()));
  }

  PrayerSettings getSettings() {
    final raw = _preferences.getString(_settingsKey);
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
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  PrayerDay? getDay(PrayerTimesRequest request) {
    final days = _readDays();
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
    final days = _readDays();
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

    await _preferences.setString(_daysKey, jsonEncode(retained));
  }

  Map<String, String> _readDays() {
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
