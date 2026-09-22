import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_times_models.dart';

class PrayerTimesPreferences {
  const PrayerTimesPreferences(this._preferencesFuture);

  static const _locationKey = 'prayer_times_v1.location';
  static const _settingsKey = 'prayer_times_v1.settings';
  static const _notificationSettingsKey = 'prayer_times_v1.notifications';

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

  Future<PrayerNotificationSettings> getNotificationSettings() async {
    final preferences = await _preferencesFuture;
    final raw = preferences.getString(_notificationSettingsKey);
    if (raw == null) return const PrayerNotificationSettings();

    try {
      return PrayerNotificationSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PrayerNotificationSettings();
    }
  }

  Future<void> saveNotificationSettings(
    PrayerNotificationSettings settings,
  ) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(
      _notificationSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
