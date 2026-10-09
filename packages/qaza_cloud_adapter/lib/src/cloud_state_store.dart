import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_models.dart';

abstract interface class CloudSyncStateStore {
  Future<String> deviceId();
  Future<CloudSyncCursor> readCursor();
  Future<void> writeCursor(CloudSyncCursor cursor);
  Future<bool> isCloudSyncEnabled();
  Future<void> setCloudSyncEnabled(bool enabled);
  Future<bool> isAutomaticSyncEnabled();
  Future<void> setAutomaticSyncEnabled(bool enabled);
  Future<DateTime?> lastSuccessfulSyncAt();
  Future<void> setLastSuccessfulSyncAt(DateTime value);
}

class SharedPreferencesCloudSyncStateStore implements CloudSyncStateStore {
  SharedPreferencesCloudSyncStateStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _deviceIdKey = 'qaza_cloud_adapter.device_id';
  static const _cursorKey = 'qaza_cloud_adapter.sync_cursor_v1';
  static const _cloudEnabledKey = 'qaza_cloud_adapter.cloud_enabled_v1';
  static const _automaticSyncEnabledKey =
      'qaza_cloud_adapter.automatic_sync_enabled_v1';
  static const _lastSuccessfulSyncAtKey =
      'qaza_cloud_adapter.last_successful_sync_at_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String> deviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _newDeviceId();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  @override
  Future<CloudSyncCursor> readCursor() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cursorKey);
    if (raw == null || raw.isEmpty) return const CloudSyncCursor.empty();

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CloudAdapterException(
        'Stored cloud sync cursor is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const CloudAdapterException(
        'Stored cloud sync cursor has an invalid root.',
      );
    }
    return CloudSyncCursor.fromJson(decoded);
  }

  @override
  Future<void> writeCursor(CloudSyncCursor cursor) async {
    final prefs = await _prefs;
    await prefs.setString(_cursorKey, jsonEncode(cursor.toJson()));
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_cloudEnabledKey) ?? false;
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_cloudEnabledKey, enabled);
    if (!enabled) {
      // The worker checks both durable flags before opening local storage or
      // initializing Google authorization.
      await prefs.setBool(_automaticSyncEnabledKey, false);
    }
  }

  @override
  Future<bool> isAutomaticSyncEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_automaticSyncEnabledKey) ?? false;
  }

  @override
  Future<void> setAutomaticSyncEnabled(bool enabled) async {
    final prefs = await _prefs;
    if (enabled && !(prefs.getBool(_cloudEnabledKey) ?? false)) {
      throw const CloudAdapterException(
        'Connect a Google account before enabling automatic cloud backup.',
      );
    }
    await prefs.setBool(_automaticSyncEnabledKey, enabled);
  }

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async {
    final prefs = await _prefs;
    final value = prefs.getString(_lastSuccessfulSyncAtKey);
    if (value == null) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) async {
    final prefs = await _prefs;
    await prefs.setString(
      _lastSuccessfulSyncAtKey,
      value.toUtc().toIso8601String(),
    );
  }

  String _newDeviceId() {
    final random = Random.secure();
    final suffix = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'device-' +
        DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        '-' +
        suffix;
  }
}
