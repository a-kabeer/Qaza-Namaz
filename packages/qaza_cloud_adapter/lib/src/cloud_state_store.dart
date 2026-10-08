import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_models.dart';

abstract interface class CloudSyncStateStore {
  Future<String> deviceId();
  Future<CloudSyncCursor> readCursor();
  Future<void> writeCursor(CloudSyncCursor cursor);
}

class SharedPreferencesCloudSyncStateStore implements CloudSyncStateStore {
  SharedPreferencesCloudSyncStateStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _deviceIdKey = 'qaza_cloud_adapter.device_id';
  static const _cursorKey = 'qaza_cloud_adapter.sync_cursor_v1';

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
