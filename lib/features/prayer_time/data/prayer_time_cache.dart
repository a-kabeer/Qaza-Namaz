import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/prayer_time.dart';
import '../../../data/local/database/app_database.dart';

class PrayerTimeCache {
  const PrayerTimeCache(this.database);

  static const _key = 'prayer_time_snapshot';

  final AppDatabase database;

  Future<PrayerTimeSnapshot?> load() async {
    final rows = await database
        .customSelect(
          'SELECT value FROM meta_store WHERE key = ? LIMIT 1',
          variables: [Variable.withString(_key)],
        )
        .get();

    if (rows.isEmpty) return null;
    final raw = rows.first.read<String>('value');
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PrayerTimeSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PrayerTimeSnapshot snapshot) async {
    await database.customUpdate(
      '''INSERT INTO meta_store (key, value)
         VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      variables: [
        Variable.withString(_key),
        Variable.withString(jsonEncode(snapshot.toJson())),
      ],
    );
  }

  Future<void> clear() async {
    await database.customDelete(
      'DELETE FROM meta_store WHERE key = ?',
      variables: [Variable.withString(_key)],
    );
  }
}
