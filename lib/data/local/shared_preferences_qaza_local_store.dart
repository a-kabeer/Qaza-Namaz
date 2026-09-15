import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/qaza_record.dart';
import 'qaza_local_store.dart';

/// Production [QazaLocalStore] backed by `shared_preferences`.
///
/// The whole cache (records + outbox + last-sync per Firebase UID) is stored
/// as one JSON document so writes are atomic from the app's point of view.
/// Records are kept individually with all fields — never aggregate counters.
class SharedPreferencesQazaLocalStore implements QazaLocalStore {
  SharedPreferencesQazaLocalStore({
    SharedPreferences? preferences,
    this.storageKey = defaultStorageKey,
  }) : _preferencesFuture =
            preferences == null ? null : Future.value(preferences);

  static const int currentSchemaVersion = 1;
  static const String defaultStorageKey = 'qaza_offline_cache_v1';

  /// The payload carries an explicit schema version. A missing version is
  /// treated as the original v1 shape for backward compatibility, while every
  /// subsequent write emits the explicit version marker.
  final String storageKey;

  Future<SharedPreferences>? _preferencesFuture;
  OfflineCacheSnapshot? _cache;
  bool _loaded = false;

  Future<SharedPreferences> _preferences() =>
      _preferencesFuture ??= SharedPreferences.getInstance();

  @override
  Future<OfflineCacheSnapshot> load() => _ensureLoaded();

  Future<OfflineCacheSnapshot> _ensureLoaded() async {
    if (_loaded) return _cache!;
    final preferences = await _preferences();
    _cache = _decode(preferences.getString(storageKey));
    _loaded = true;
    return _cache!;
  }

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) async {
    final cache = await _ensureLoaded();
    cache.recordsByUser[userId] = List<QazaRecord>.of(records);
    await _persist(cache);
  }

  @override
  Future<void> saveOutbox(String userId, List<PendingSyncOp> ops) async {
    final cache = await _ensureLoaded();
    cache.outboxByUser[userId] = List<PendingSyncOp>.of(ops);
    await _persist(cache);
  }

  @override
  Future<void> saveLastSync(String userId, DateTime? lastSync) async {
    final cache = await _ensureLoaded();
    if (lastSync == null) {
      cache.lastSyncByUser.remove(userId);
    } else {
      cache.lastSyncByUser[userId] = lastSync;
    }
    await _persist(cache);
  }

  Future<void> _persist(OfflineCacheSnapshot cache) async {
    final preferences = await _preferences();
    await preferences.setString(storageKey, jsonEncode(_encode(cache)));
  }

  Map<String, dynamic> _encode(OfflineCacheSnapshot cache) => {
        'schemaVersion': currentSchemaVersion,
        'recordsByUser': {
          for (final entry in cache.recordsByUser.entries)
            entry.key: entry.value.map((r) => r.toJson()).toList(),
        },
        'outboxByUser': {
          for (final entry in cache.outboxByUser.entries)
            entry.key: entry.value.map((op) => op.toJson()).toList(),
        },
        'lastSyncByUser': {
          for (final entry in cache.lastSyncByUser.entries)
            entry.key: entry.value.toIso8601String(),
        },
      };

  OfflineCacheSnapshot _decode(String? raw) {
    if (raw == null || raw.isEmpty) return _emptySnapshot();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ??
          currentSchemaVersion;
      if (schemaVersion != currentSchemaVersion) {
        throw StateError(
          'Unsupported Qaza offline cache schema version $schemaVersion. '
          'Expected $currentSchemaVersion.',
        );
      }
      return OfflineCacheSnapshot(
        recordsByUser: {
          for (final entry
              in (decoded['recordsByUser'] as Map<String, dynamic>? ?? {})
                  .entries)
            entry.key: (entry.value as List<dynamic>)
                .map(
                  (item) => QazaRecord.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(),
        },
        outboxByUser: {
          for (final entry
              in (decoded['outboxByUser'] as Map<String, dynamic>? ?? {})
                  .entries)
            entry.key: (entry.value as List<dynamic>)
                .map(
                  (item) => PendingSyncOp.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(),
        },
        lastSyncByUser: {
          for (final entry
              in (decoded['lastSyncByUser'] as Map<String, dynamic>? ?? {})
                  .entries)
            entry.key: DateTime.parse(entry.value as String),
        },
      );
    } on StateError {
      rethrow;
    } catch (error) {
      // A malformed cache cannot be migrated safely. Reset it rather than
      // interpreting partial data as valid records; Firestore remains the
      // canonical source after the account reconnects.
      debugPrint('Qaza offline cache was unreadable and has been reset: $error');
      return _emptySnapshot();
    }
  }

  OfflineCacheSnapshot _emptySnapshot() => OfflineCacheSnapshot(
        recordsByUser: <String, List<QazaRecord>>{},
        outboxByUser: <String, List<PendingSyncOp>>{},
        lastSyncByUser: <String, DateTime>{},
      );
}
