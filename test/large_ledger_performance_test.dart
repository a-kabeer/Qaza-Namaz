import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';

const _userId = 'u1';
final _start = DateTime(2000, 1, 1);
final _now = DateTime(2026, 9, 19);

/// A ledger of [count] records spread over dates and prayers.
List<QazaRecord> _ledger(int count) => [
      for (var i = 0; i < count; i++)
        QazaRecord(
          id: 'r_${i.toString().padLeft(6, '0')}',
          userId: _userId,
          prayerType: PrayerType.values[i % PrayerType.values.length],
          originalDate: _start.add(Duration(days: i ~/ 6)),
          createdAt: _now,
          updatedAt: _now,
        ),
    ];

/// Counts the whole-ledger operations the repository performs.
class _CountingLocalStore extends InMemoryQazaLocalStore {
  int fullRewrites = 0;
  int targetedCompletions = 0;
  int appends = 0;

  @override
  Future<void> saveRecords(String userId, List<QazaRecord> records) {
    fullRewrites++;
    return super.saveRecords(userId, records);
  }

  @override
  Future<List<String>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    targetedCompletions++;
    return super.completeRecords(
        userId: userId, recordIds: recordIds, completedAt: completedAt);
  }

  @override
  Future<void> appendRecords(String userId, List<QazaRecord> records) {
    appends++;
    return super.appendRecords(userId, records);
  }
}

/// Counts what the repository asks of the cloud.
class _CountingRemote extends InMemoryQazaRepository {
  int fullReads = 0;
  int completions = 0;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) {
    fullReads++;
    return super
        .getRecords(userId: userId, prayerType: prayerType, status: status);
  }

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    completions++;
    return super.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) =>
      completeRecords(
        userId: userId,
        recordIds: [recordId],
        completedAt: completedAt,
      );
}

void main() {
  late _CountingLocalStore local;
  late _CountingRemote remote;
  late OfflineFirstQazaRepository repository;

  /// A repository whose local store already holds [count] records.
  Future<void> openWithLedger(int count, {Stream<bool>? connectivity}) async {
    local = _CountingLocalStore();
    remote = _CountingRemote();
    await local.saveRecords(_userId, _ledger(count));
    local.fullRewrites = 0;
    repository = OfflineFirstQazaRepository(
      remote: remote,
      localStore: local,
      connectivityChanges: connectivity,
      now: () => _now,
    );
    addTearDown(repository.dispose);
    await repository.setActiveUser(_userId);
    await repository.ensureHydrated();
    // Startup is allowed its reads; the counters measure what follows.
    local.fullRewrites = 0;
    remote.fullReads = 0;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('a 10,000 record ledger', () {
    test('filters read one bounded page, not the ledger', () async {
      await openWithLedger(10000);

      final all = await repository.getPage(userId: _userId, limit: 50);
      expect(all.records, hasLength(50));
      expect(all.hasMore, isTrue);

      for (final prayer in PrayerType.values) {
        final page = await repository.getPage(
            userId: _userId, limit: 50, prayerType: prayer);
        expect(page.records, hasLength(50));
        expect(page.records.every((r) => r.prayerType == prayer), isTrue,
            reason: prayer.name);
      }

      final pending = await repository.getPage(
          userId: _userId, limit: 50, status: QazaStatus.pending);
      expect(pending.records, hasLength(50));
      expect(local.fullRewrites, 0);
    });

    test('switching filters repeatedly never rewrites anything', () async {
      await openWithLedger(10000);

      for (var round = 0; round < 3; round++) {
        for (final prayer in PrayerType.values) {
          await repository.getPage(
              userId: _userId, limit: 50, prayerType: prayer);
          await repository.getPage(
              userId: _userId, limit: 50, status: QazaStatus.completed);
        }
      }

      expect(local.fullRewrites, 0);
    });

    test('pagination stays bounded through the keyset', () async {
      await openWithLedger(10000);

      var page = await repository.getPage(userId: _userId, limit: 50);
      final seen = <String>{...page.records.map((r) => r.id)};
      for (var i = 0; i < 4 && page.hasMore; i++) {
        page = await repository.getPage(
          userId: _userId,
          limit: 50,
          afterOriginalDate: page.nextOriginalDate,
          afterId: page.nextId,
        );
        expect(page.records.length, lessThanOrEqualTo(50));
        // No page ever repeats a record from an earlier one.
        for (final record in page.records) {
          expect(seen.add(record.id), isTrue, reason: record.id);
        }
      }
      expect(seen.length, 250);
      expect(local.fullRewrites, 0);
    });
  });

  group('completion touches only what it must', () {
    test('completing one record rewrites nothing', () async {
      await openWithLedger(10000);

      await repository.completeRecord(
          userId: _userId, recordId: 'r_000000', completedAt: _now);
      await settle();

      expect(local.targetedCompletions, 1);
      // The whole point: no load(), no replaceUserRecords().
      expect(local.fullRewrites, 0);
      final record = (await repository.getPage(
              userId: _userId, limit: 1, status: QazaStatus.completed))
          .records
          .single;
      expect(record.id, 'r_000000');
    });

    test('completing ten records is one targeted write', () async {
      await openWithLedger(10000);
      final ids = [
        for (var i = 0; i < 10; i++) 'r_${i.toString().padLeft(6, '0')}'
      ];

      await repository.completeRecords(
          userId: _userId, recordIds: ids, completedAt: _now);
      await settle();

      expect(local.targetedCompletions, 1);
      expect(local.fullRewrites, 0);
      final completed = await repository.getRecords(
          userId: _userId, status: QazaStatus.completed);
      expect(completed, hasLength(10));
    });

    test('completing a hundred records is still one targeted write', () async {
      await openWithLedger(10000);
      final ids = [
        for (var i = 0; i < 100; i++) 'r_${i.toString().padLeft(6, '0')}'
      ];

      await repository.completeRecords(
          userId: _userId, recordIds: ids, completedAt: _now);
      await settle();

      expect(local.targetedCompletions, 1);
      expect(local.fullRewrites, 0);
      expect(
          await repository.getRecords(
              userId: _userId, status: QazaStatus.completed),
          hasLength(100));
    });

    test('an already completed record is not queued twice', () async {
      await openWithLedger(100);

      await repository.completeRecord(
          userId: _userId, recordId: 'r_000000', completedAt: _now);
      await settle();
      final afterFirst = remote.completions;

      await repository.completeRecord(
          userId: _userId, recordId: 'r_000000', completedAt: _now);
      await settle();

      expect(remote.completions, afterFirst);
    });

    test('the oldest pending lookup stays bounded and moves on', () async {
      await openWithLedger(10000);

      final first = await repository.getOldestPending(
          userId: _userId, prayerType: PrayerType.fajr);
      expect(first, isNotNull);

      await repository.completeRecord(
          userId: _userId, recordId: first!.id, completedAt: _now);
      final next = await repository.getOldestPending(
          userId: _userId, prayerType: PrayerType.fajr);

      expect(next, isNotNull);
      expect(next!.id, isNot(first.id));
      expect(local.fullRewrites, 0);
    });
  });

  group('sync', () {
    test('a completion pushes without re-reading the cloud ledger', () async {
      await openWithLedger(1000);

      await repository.completeRecord(
          userId: _userId, recordId: 'r_000000', completedAt: _now);
      await settle();
      await settle();

      expect(remote.completions, 1);
      // Regression: every small change used to pull the whole ledger back.
      expect(remote.fullReads, 0);
    });

    test('an explicit sync uses incremental reconciliation', () async {
      await openWithLedger(1000);

      await repository.syncNow();

      expect(remote.fullReads, 0);
    });

    test('coming back online reconciles too', () async {
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      await openWithLedger(1000, connectivity: connectivity.stream);

      connectivity.add(false);
      await settle();
      await repository.completeRecord(
          userId: _userId, recordId: 'r_000001', completedAt: _now);
      await settle();
      expect(remote.fullReads, 0);

      connectivity.add(true);
      await repository.syncNow();

      expect(remote.completions, 1);
      expect(remote.fullReads, 0);
    });

    test('an offline completion is kept and flushed later', () async {
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      await openWithLedger(500, connectivity: connectivity.stream);

      connectivity.add(false);
      await settle();
      await repository.completeRecord(
          userId: _userId, recordId: 'r_000000', completedAt: _now);
      await settle();

      expect(remote.completions, 0);
      expect((await local.load()).outboxByUser[_userId], hasLength(1));
      // The local record is already done for the reader.
      expect(
          (await repository.getPage(
                  userId: _userId, limit: 1, status: QazaStatus.completed))
              .records
              .single
              .id,
          'r_000000');

      connectivity.add(true);
      await repository.syncNow();

      expect(remote.completions, 1);
      expect((await local.load()).outboxByUser[_userId], isEmpty);
    });
  });

  group('adding', () {
    test('new records are appended, not written over the ledger', () async {
      await openWithLedger(1000);

      await repository.addRecords([
        QazaRecord(
          id: 'new_1',
          userId: _userId,
          prayerType: PrayerType.fajr,
          originalDate: DateTime(2030, 1, 1),
          createdAt: _now,
          updatedAt: _now,
        ),
      ]);
      await settle();

      expect(local.appends, 1);
      expect(local.fullRewrites, 0);
      expect(await repository.getRecords(userId: _userId), hasLength(1001));
    });
  });
}
