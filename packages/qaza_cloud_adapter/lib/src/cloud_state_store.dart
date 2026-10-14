import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

import 'cloud_models.dart';

abstract interface class CloudSyncStateStore {
  Future<String> deviceId();
  Future<CloudSyncCursor> readCursor();
  Future<void> writeCursor(CloudSyncCursor cursor);
  Future<bool> isCloudSyncEnabled();
  Future<void> setCloudSyncEnabled(bool enabled);
  Future<bool> isAutomaticSyncEnabled();
  Future<bool> hasAutomaticSyncPreference();
  Future<void> setAutomaticSyncEnabled(bool enabled);
  Future<CloudBackupFrequency> backupFrequency();
  Future<void> setBackupFrequency(CloudBackupFrequency frequency);
  Future<bool> isReconnectRequired();
  Future<void> setReconnectRequired(bool required);
  Future<DateTime?> lastSuccessfulSyncAt();
  Future<void> setLastSuccessfulSyncAt(DateTime value);
  Future<CloudConflict?> readPendingConflict();
  Future<void> writePendingConflict(CloudConflict conflict);
  Future<void> clearPendingConflict();
}

/// Optional capability implemented by the production store. Keeping this
/// separate avoids forcing unrelated/test-only CloudSyncStateStore
/// implementations to carry account-selection responsibilities.
abstract interface class CloudAccountScopedSyncStateStore {
  Future<String?> activeAccountId();

  /// Selects a verified GoogleSignInAccount.id as the account-state namespace.
  /// Passing null is supported for explicit account reset/maintenance flows.
  Future<void> setActiveAccountId(String? accountId);
}

class SharedPreferencesCloudSyncStateStore
    implements CloudSyncStateStore, CloudAccountScopedSyncStateStore {
  SharedPreferencesCloudSyncStateStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _keyPrefix = 'qaza_cloud_adapter.';
  static const _deviceIdKey = '${_keyPrefix}device_id';
  static const _activeAccountIdKey =
      '${_keyPrefix}active_account_id_v1';
  static const _cursorKey = '${_keyPrefix}sync_cursor_v1';
  static const _cloudEnabledKey = '${_keyPrefix}cloud_enabled_v1';
  static const _automaticSyncEnabledKey =
      '${_keyPrefix}automatic_sync_enabled_v1';
  static const _backupFrequencyKey = '${_keyPrefix}backup_frequency_v1';
  static const _reconnectRequiredKey =
      '${_keyPrefix}reconnect_required_v1';
  static const _lastSuccessfulSyncAtKey =
      '${_keyPrefix}last_successful_sync_at_v1';
  static const _pendingConflictKey =
      '${_keyPrefix}pending_conflict_v1';
  static const _legacyQuarantineMarkerKey =
      '${_keyPrefix}legacy_state_quarantined_v1';
  static const _legacyQuarantineContainsStateKey =
      '${_keyPrefix}legacy_state_quarantine_nonempty_v1';
  static const _legacyQuarantinePrefix =
      '${_keyPrefix}legacy_quarantine_v1.';

  static const List<String> _legacyAccountStateKeys = <String>[
    _cursorKey,
    _cloudEnabledKey,
    _reconnectRequiredKey,
    _lastSuccessfulSyncAtKey,
    _pendingConflictKey,
  ];

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> activeAccountId() async {
    final value = (await _prefs).getString(_activeAccountIdKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> setActiveAccountId(String? accountId) async {
    final prefs = await _prefs;
    final normalized = accountId?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_activeAccountIdKey);
      return;
    }

    // Older releases had a single unscoped cursor and conflict. Cached email
    // from those releases is not enough to prove who owns that state, so keep
    // a recoverable quarantined copy rather than attaching it to this account.
    await _quarantineLegacyAccountState(prefs);
    await prefs.setString(_activeAccountIdKey, normalized);
  }

  /// True only for an upgrade that still has a legacy connected flag but no
  /// stable account identifier. The account UI should request reconnection.
  Future<bool> hasUnscopedLegacyConnection() async {
    final prefs = await _prefs;
    if (prefs.getString(_activeAccountIdKey)?.trim().isNotEmpty ?? false) {
      return false;
    }
    return prefs.getBool(_cloudEnabledKey) == true;
  }

  Future<void> _quarantineLegacyAccountState(
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_legacyQuarantineMarkerKey) == true) return;

    var containsState = false;
    for (final key in _legacyAccountStateKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      final quarantineKey =
          '$_legacyQuarantinePrefix${key.substring(_keyPrefix.length)}';
      if (!prefs.containsKey(quarantineKey)) {
        if (value is String) {
          await prefs.setString(quarantineKey, value);
        } else if (value is bool) {
          await prefs.setBool(quarantineKey, value);
        } else if (value is int) {
          await prefs.setInt(quarantineKey, value);
        } else if (value is double) {
          await prefs.setDouble(quarantineKey, value);
        } else if (value is List<String>) {
          await prefs.setStringList(quarantineKey, value);
        }
      }
      await prefs.remove(key);
      containsState = true;
    }

    await prefs.setBool(_legacyQuarantineContainsStateKey, containsState);
    await prefs.setBool(_legacyQuarantineMarkerKey, true);
  }

  String? _accountScopedKey(SharedPreferences prefs, String legacyKey) {
    final accountId = prefs.getString(_activeAccountIdKey)?.trim();
    if (accountId == null || accountId.isEmpty) return null;
    final encodedId = base64Url
        .encode(utf8.encode(accountId))
        .replaceAll('=', '');
    final suffix = legacyKey.substring(_keyPrefix.length);
    return '${_keyPrefix}account.$encodedId.$suffix';
  }

  String _requiredAccountKey(SharedPreferences prefs, String legacyKey) {
    final key = _accountScopedKey(prefs, legacyKey);
    if (key == null) {
      throw const CloudAdapterException(
        'A verified Google account is required before using cloud sync state.',
      );
    }
    return key;
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
    final key = _accountScopedKey(prefs, _cursorKey);
    if (key == null) return const CloudSyncCursor.empty();
    final raw = prefs.getString(key);
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
    final key = _requiredAccountKey(prefs, _cursorKey);
    await prefs.setString(key, jsonEncode(cursor.toJson()));
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _cloudEnabledKey);
    return key == null ? false : (prefs.getBool(key) ?? false);
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _cloudEnabledKey);
    if (key == null) {
      if (enabled) {
        throw const CloudAdapterException(
          'Verify a Google account before connecting cloud backup.',
        );
      }
      return;
    }
    await prefs.setBool(key, enabled);
    if (!enabled) {
      // Cloud-enabled is the hard worker guard. Retain the user's automatic
      // backup choice so reconnecting does not silently change that choice.
      await prefs.setBool(
        _requiredAccountKey(prefs, _reconnectRequiredKey),
        false,
      );
      await prefs.remove(_requiredAccountKey(prefs, _pendingConflictKey));
    }
  }

  @override
  Future<bool> isAutomaticSyncEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_automaticSyncEnabledKey) ?? false;
  }

  @override
  Future<bool> hasAutomaticSyncPreference() async {
    final prefs = await _prefs;
    return prefs.containsKey(_automaticSyncEnabledKey);
  }

  @override
  Future<CloudBackupFrequency> backupFrequency() async {
    final prefs = await _prefs;
    final value = prefs.getString(_backupFrequencyKey);
    return CloudBackupFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => CloudBackupFrequency.daily,
    );
  }

  @override
  Future<void> setBackupFrequency(CloudBackupFrequency frequency) async {
    final prefs = await _prefs;
    await prefs.setString(_backupFrequencyKey, frequency.name);
  }

  @override
  Future<void> setAutomaticSyncEnabled(bool enabled) async {
    final prefs = await _prefs;
    if (enabled && !(await isCloudSyncEnabled())) {
      throw const CloudAdapterException(
        'Connect a Google account before enabling automatic cloud backup.',
      );
    }
    await prefs.setBool(_automaticSyncEnabledKey, enabled);
  }

  @override
  Future<bool> isReconnectRequired() async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _reconnectRequiredKey);
    return key == null ? false : (prefs.getBool(key) ?? false);
  }

  @override
  Future<void> setReconnectRequired(bool required) async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _reconnectRequiredKey);
    if (key == null) return;
    if (required && !(prefs.getBool(
          _accountScopedKey(prefs, _cloudEnabledKey) ?? '',
        ) ??
        false)) {
      return;
    }
    await prefs.setBool(key, required);
  }

  @override
  Future<DateTime?> lastSuccessfulSyncAt() async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _lastSuccessfulSyncAtKey);
    if (key == null) return null;
    final value = prefs.getString(key);
    if (value == null) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  @override
  Future<void> setLastSuccessfulSyncAt(DateTime value) async {
    final prefs = await _prefs;
    final key = _requiredAccountKey(prefs, _lastSuccessfulSyncAtKey);
    await prefs.setString(key, value.toUtc().toIso8601String());
  }

  @override
  Future<CloudConflict?> readPendingConflict() async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _pendingConflictKey);
    if (key == null) return null;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CloudAdapterException(
        'Stored pending cloud conflict is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const CloudAdapterException(
        'Stored pending cloud conflict has an invalid root.',
      );
    }
    return CloudConflict.fromJson(decoded);
  }

  @override
  Future<void> writePendingConflict(CloudConflict conflict) async {
    final prefs = await _prefs;
    final key = _requiredAccountKey(prefs, _pendingConflictKey);
    await prefs.setString(key, jsonEncode(conflict.toJson()));
  }

  @override
  Future<void> clearPendingConflict() async {
    final prefs = await _prefs;
    final key = _accountScopedKey(prefs, _pendingConflictKey);
    if (key != null) await prefs.remove(key);
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
