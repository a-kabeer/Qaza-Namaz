import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/shared_preferences_qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

QazaRecord _record({
  String userId = 'user-a',
  String id = 'user-a_fajr_2026-01-01',
  PrayerType prayerType = PrayerType.fajr,
  QazaStatus status = QazaStatus.pending,
  DateTime? completedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 2, 10);
  return QazaRecord(
    id: id,
    userId: userId,
    prayerType: prayerType,
    originalDate: DateTime.utc(2026, 1, 1),
    status: status,
    completedAt: completedAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  test('Qaza record preserves the complete database field set', () {
    final completedAt = DateTime.utc(2026, 1, 3, 10);
    final record = _record(
      status: QazaStatus.completed,
      completedAt: completedAt,
    );
    final json = record.toJson();

    expect(
      json.keys,
      containsAll([
        'id',
        'userId',
        'prayerType',
        'originalDate',
        'status',
        'completedAt',
        'createdAt',
        'updatedAt',
      ]),
    );

    final restored = QazaRecord.fromJson(json);
    expect(restored.id, record.id);
    expect(restored.userId, record.userId);
    expect(restored.prayerType, record.prayerType);
    expect(restored.originalDate, record.originalDate);
    expect(restored.status, record.status);
    expect(restored.completedAt, completedAt);
    expect(restored.createdAt, record.createdAt);
    expect(restored.updatedAt, record.updatedAt);
  });

  test('local cache writes an explicit schema version', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesQazaLocalStore(
      preferences: preferences,
      storageKey: 'test_cache',
    );

    await store.saveRecords('user-a', [_record()]);

    final raw = preferences.getString('test_cache');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], SharedPreferencesQazaLocalStore.currentSchemaVersion);
    expect((decoded['recordsByUser'] as Map<String, dynamic>).containsKey('user-a'), isTrue);
  });

  test('legacy v1 cache without schemaVersion remains readable', () async {
    final record = _record();
    SharedPreferences.setMockInitialValues({
      'test_cache': jsonEncode({
        'recordsByUser': {
          'user-a': [record.toJson()],
        },
        'outboxByUser': {},
        'lastSyncByUser': {},
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesQazaLocalStore(
      preferences: preferences,
      storageKey: 'test_cache',
    );

    final snapshot = await store.load();
    expect(snapshot.recordsByUser['user-a'], hasLength(1));
    expect(snapshot.recordsByUser['user-a']!.single.id, record.id);
  });

  test('unsupported local cache version is rejected instead of silently reset', () async {
    SharedPreferences.setMockInitialValues({
      'test_cache': jsonEncode({
        'schemaVersion': SharedPreferencesQazaLocalStore.currentSchemaVersion + 1,
        'recordsByUser': {},
        'outboxByUser': {},
        'lastSyncByUser': {},
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesQazaLocalStore(
      preferences: preferences,
      storageKey: 'test_cache',
    );

    expect(store.load(), throwsA(isA<StateError>()));
  });

  test('local cache remains namespaced by Firebase UID', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesQazaLocalStore(
      preferences: preferences,
      storageKey: 'test_cache',
    );

    await store.saveRecords('user-a', [_record(userId: 'user-a')]);
    await store.saveRecords('user-b', [
      _record(
        userId: 'user-b',
        id: 'user-b_witr_2026-01-01',
        prayerType: PrayerType.witr,
      ),
    ]);

    final snapshot = await store.load();
    expect(snapshot.recordsByUser['user-a']!.single.userId, 'user-a');
    expect(snapshot.recordsByUser['user-b']!.single.userId, 'user-b');
    expect(snapshot.recordsByUser['user-a']!.single.prayerType, PrayerType.fajr);
    expect(snapshot.recordsByUser['user-b']!.single.prayerType, PrayerType.witr);
  });
}
