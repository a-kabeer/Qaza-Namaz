import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/data/sync/qaza_sync_remote_data_source.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';

import 'support/in_memory_qaza_repository.dart';

/// The Home "Complete Qaza" path, exercised over the real Drift/SQLite store.
///
/// The persistence here is genuine: an in-memory SQLite database, the real
/// DAO, the real [DriftQazaLocalStore] and the real
/// [OfflineFirstQazaRepository]. Only the cloud is a double. Each failure
/// case breaks exactly one stage, by subclassing the real store, so every
/// other stage is still production code running against real SQLite.
void main() {
  const userId = 'u1';
  final now = DateTime(2026, 9, 24, 7, 30);

  late AppDatabase database;
  late DriftQazaLocalStore store;
  late InMemoryQazaRepository remote;
  late BufferedDiagnostics diagnostics;

  QazaRecord pending(String id, PrayerType prayer, int day) => QazaRecord(
        id: id,
        userId: userId,
        prayerType: prayer,
        originalDate: DateTime(2026, 1, day),
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftQazaLocalStore(database: database);
    remote = InMemoryQazaRepository();
    diagnostics = BufferedDiagnostics(capacity: 100);
    addTearDown(database.close);
  });

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Builds the real repository over [localStore] (the plain Drift store
  /// unless a test hands in one with a broken stage) and seeds the ledger.
  Future<OfflineFirstQazaRepository> open({
    QazaLocalStore? localStore,
    QazaSyncRemoteDataSource? syncRemote,
    Stream<bool>? connectivity,
    List<QazaRecord> seed = const [],
  }) async {
    if (seed.isNotEmpty) await store.appendRecords(userId, seed);
    final repository = OfflineFirstQazaRepository(
      remote: remote,
      syncRemote: syncRemote,
      localStore: localStore ?? store,
      connectivityChanges: connectivity,
      now: () => now,
      diagnostics: diagnostics,
    );
    addTearDown(repository.dispose);
    // Completions kick off a fire-and-forget sync. Teardowns run last-in
    // first-out, so this drains that work before the repository is disposed
    // and the database underneath it is closed.
    addTearDown(settle);
    await repository.setActiveUser(userId);
    return repository;
  }

  List<String> codes() => diagnostics.events.map((e) => e.code).toList();

  /// Reads straight out of SQLite, bypassing the repository's own cache.
  Future<QazaRecord?> stored(String id) async {
    final rows = await store.getRecordsByIds(userId: userId, ids: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  group('a completion that works', () {
    test('is written through Drift and reported as completed', () async {
      final repository = await open(seed: [pending('r1', PrayerType.fajr, 1)]);

      final result = await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      expect(result, QazaCompletionResult.completed);
      final saved = await stored('r1');
      expect(saved!.status, QazaStatus.completed);
      expect(saved.completedAt, now);
      expect(codes(), isNot(contains('local_completion_failed')));
    });

    test('drops the pending count and reveals the next Qaza', () async {
      final repository = await open(seed: [
        pending('r1', PrayerType.fajr, 1),
        pending('r2', PrayerType.fajr, 2),
      ]);

      final before = await repository.getProgressSummary(userId: userId);
      expect(before.overall.pending, 2);

      await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      final after = await repository.getProgressSummary(userId: userId);
      expect(after.overall.pending, 1, reason: 'Home counts down by one');
      expect(after.overall.completed, 1);

      final next = await repository.getOldestPending(
        userId: userId,
        prayerType: PrayerType.fajr,
      );
      expect(next!.id, 'r2', reason: 'the next pending Qaza takes its place');
    });

    test('queues the change for the cloud', () async {
      final repository = await open(seed: [pending('r1', PrayerType.fajr, 1)]);

      await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      final outbox = await store.loadOutbox(userId);
      final completions =
          outbox.where((op) => op.type == SyncOpType.complete).toList();
      expect(completions, hasLength(1));
      expect(completions.single.targetRecordId, 'r1');
    });
  });

  group('outcomes that are not persistence failures', () {
    test('a second tap on the same record reports alreadyCompleted', () async {
      final repository = await open(seed: [pending('r1', PrayerType.fajr, 1)]);
      await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      final again = await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      expect(again, QazaCompletionResult.alreadyCompleted,
          reason: 'a stale tap must not be dressed up as a failure');
      expect(codes(), isNot(contains('local_completion_failed')));
      expect((await stored('r1'))!.status, QazaStatus.completed);
    });

    test('an unknown record reports notFound rather than throwing', () async {
      final repository = await open(seed: [pending('r1', PrayerType.fajr, 1)]);

      expect(
        await repository.completeRecord(
          userId: userId,
          recordId: 'ghost',
          completedAt: now,
        ),
        QazaCompletionResult.notFound,
      );
    });
  });

  group('offline and sync', () {
    test('completes with no connectivity and holds the change', () async {
      final connectivity = StreamController<bool>.broadcast();
      addTearDown(connectivity.close);
      final repository = await open(
        connectivity: connectivity.stream,
        seed: [pending('r1', PrayerType.fajr, 1)],
      );
      connectivity.add(false);
      await settle();

      final result = await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );

      expect(result, QazaCompletionResult.completed,
          reason: 'offline completion is the whole point of the local store');
      expect((await stored('r1'))!.status, QazaStatus.completed);
      expect(await store.loadOutbox(userId), isNotEmpty,
          reason: 'the change is held for later, not dropped');
    });

    test('a failing cloud sync never undoes the local completion', () async {
      final connectivity = StreamController<bool>.broadcast();
      addTearDown(connectivity.close);
      final repository = await open(
        syncRemote: _FailingSyncRemote(remote),
        connectivity: connectivity.stream,
        seed: [pending('r1', PrayerType.fajr, 1)],
      );
      connectivity.add(true);
      await settle();

      final result = await repository.completeRecord(
        userId: userId,
        recordId: 'r1',
        completedAt: now,
      );
      // The sync is deliberately not awaited; let it fail in the background.
      await settle();
      await settle();

      expect(result, QazaCompletionResult.completed,
          reason: 'the local write is what the user asked for');
      expect((await stored('r1'))!.status, QazaStatus.completed,
          reason: 'a cloud failure must not roll the device back');
    });
  });

  group('each stage failure is named, and the real exception survives', () {
    test('a Drift completion failure is local_completion_failed', () async {
      final repository = await open(
        localStore: _BrokenStore(database: database, breakCompletion: true),
        seed: [pending('r1', PrayerType.fajr, 1)],
      );

      await expectLater(
        repository.completeRecord(
          userId: userId,
          recordId: 'r1',
          completedAt: now,
        ),
        throwsA(isA<StateError>()),
        reason: 'the real exception must reach the caller, not be swallowed',
      );

      expect(codes(), contains('local_completion_failed'));
      final event = diagnostics.events
          .firstWhere((e) => e.code == 'local_completion_failed');
      expect(event.area, DiagnosticArea.qazaCompletion);
      expect(event.errorType, 'StateError');
      expect(event.stackTrace, isNotNull,
          reason: 'the stack trace is the point of the diagnostic');
      expect((await stored('r1'))!.status, QazaStatus.pending);
    });

    test('an outbox write failure is outbox_write_failed', () async {
      final repository = await open(
        localStore: _BrokenStore(database: database, breakOutbox: true),
        seed: [pending('r1', PrayerType.fajr, 1)],
      );

      await expectLater(
        repository.completeRecord(
          userId: userId,
          recordId: 'r1',
          completedAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      expect(codes(), contains('outbox_write_failed'));
      expect(codes(), isNot(contains('local_completion_failed')));
      expect((await stored('r1'))!.status, QazaStatus.completed,
          reason: 'the record was already written before the outbox stage');
    });

    test('a changed-record lookup failure is changed_record_lookup_failed',
        () async {
      final repository = await open(
        localStore: _BrokenStore(database: database, breakLookup: true),
        seed: [pending('r1', PrayerType.fajr, 1)],
      );

      await expectLater(
        repository.completeRecord(
          userId: userId,
          recordId: 'r1',
          completedAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      expect(codes(), contains('changed_record_lookup_failed'));
    });

    test('a Sahib al-Tartib failure is tartib_check_failed', () async {
      final repository = await open(seed: [
        pending('r1', PrayerType.fajr, 1),
        pending('r2', PrayerType.zuhr, 1),
      ]);
      final service = QazaService(
        repository,
        tartib: _BrokenTartib(repository),
        diagnostics: diagnostics,
      );

      await expectLater(
        service.completeRecord(
          userId: userId,
          recordId: 'r1',
          completedAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      expect(codes(), contains('tartib_check_failed'));
      expect(codes(), isNot(contains('local_completion_failed')));
      expect((await stored('r1'))!.status, QazaStatus.pending,
          reason: 'an order check that could not run must complete nothing');
    });

    test('no ledger data reaches the diagnostics', () async {
      const sensitiveId = 'u1_fajr_2026-01-01';
      final repository = await open(
        localStore: _BrokenStore(database: database, breakCompletion: true),
        seed: [
          QazaRecord(
            id: sensitiveId,
            userId: userId,
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 1, 1),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await repository
          .completeRecord(
            userId: userId,
            recordId: sensitiveId,
            completedAt: now,
          )
          .then<void>((_) {}, onError: (_) {});

      expect(diagnostics.events, isNotEmpty);
      for (final event in diagnostics.events) {
        final text = '${event.message ?? ''} ${event.stackTrace ?? ''}';
        expect(text, isNot(contains(sensitiveId)));
        expect(text, isNot(contains('2026-01-01')));
      }
    });
  });
}

/// The real Drift store with exactly one stage broken.
class _BrokenStore extends DriftQazaLocalStore {
  _BrokenStore({
    required super.database,
    this.breakCompletion = false,
    this.breakOutbox = false,
    this.breakLookup = false,
  });

  final bool breakCompletion;
  final bool breakOutbox;
  final bool breakLookup;

  @override
  Future<List<String>> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) {
    if (breakCompletion) throw StateError('drift: database is locked');
    return super.completeRecords(
      userId: userId,
      recordIds: recordIds,
      completedAt: completedAt,
    );
  }

  @override
  Future<List<QazaRecord>> getRecordsByIds({
    required String userId,
    required List<String> ids,
  }) {
    if (breakLookup) throw StateError('drift: read failed');
    return super.getRecordsByIds(userId: userId, ids: ids);
  }

  @override
  Future<void> appendRecordsAndOutbox(
    String userId,
    List<QazaRecord> records,
    List<PendingSyncOp> ops,
  ) {
    if (breakOutbox) throw StateError('drift: outbox write failed');
    return super.appendRecordsAndOutbox(userId, records, ops);
  }
}

/// An order check that cannot be completed.
class _BrokenTartib extends SahibAlTartibService {
  const _BrokenTartib(super.repository);

  @override
  Future<SahibAlTartibState> evaluate({
    required String userId,
    DateTime? today,
  }) async =>
      throw StateError('tartib: evaluation failed');
}

/// A cloud that rejects everything the outbox sends it.
class _FailingSyncRemote implements QazaSyncRemoteDataSource {
  _FailingSyncRemote(this._inner);

  final QazaSyncRemoteDataSource _inner;

  @override
  Future<QazaRemoteChangeCursor> applyOperationsBatch({
    required String userId,
    required List<PendingSyncOp> operations,
  }) async =>
      throw StateError('cloud rejected the batch');

  @override
  Future<QazaRemoteChangeCursor> resetUserRecordsForSync({
    required String userId,
    required String operationId,
  }) async =>
      throw StateError('cloud rejected the reset');

  @override
  Future<void> deleteCloudData({required String userId}) =>
      _inner.deleteCloudData(userId: userId);

  @override
  Future<QazaRemoteChangePage> getChanges({
    required String userId,
    QazaRemoteChangeCursor? after,
    int limit = 100,
  }) =>
      _inner.getChanges(userId: userId, after: after, limit: limit);

  @override
  Future<QazaRemoteChangeCursor?> getLatestChange({required String userId}) =>
      _inner.getLatestChange(userId: userId);

  @override
  Future<QazaRemoteResetState> getResetState({required String userId}) =>
      _inner.getResetState(userId: userId);
}
