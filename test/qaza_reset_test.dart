import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/features/settings/qaza_reset_controller.dart';
import 'package:qaza_namaz/features/settings/settings_screen.dart';

import 'support/in_memory_qaza_local_store.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

final _stamp = DateTime(2026, 9, 15);

QazaRecord _record({
  String userId = 'u1',
  PrayerType prayer = PrayerType.fajr,
  DateTime? date,
  QazaStatus status = QazaStatus.pending,
}) {
  final originalDate = date ?? _stamp;
  return QazaRecord(
    id: '${userId}_${prayer.name}_${originalDate.toIso8601String()}',
    userId: userId,
    prayerType: prayer,
    originalDate: originalDate,
    status: status,
    completedAt: status == QazaStatus.completed ? _stamp : null,
    createdAt: _stamp,
    updatedAt: _stamp,
  );
}

List<QazaRecord> _ledger(int count, {String userId = 'u1'}) => [
      for (var day = 0; day < count; day++)
        _record(
          userId: userId,
          date: _stamp.subtract(Duration(days: day)),
          status: day.isEven ? QazaStatus.pending : QazaStatus.completed,
        ),
    ];

/// A remote that fails every reset, for the controller's error path.
class _FailingResetRepository extends InMemoryQazaRepository {
  @override
  Future<void> resetUserRecords({required String userId}) =>
      Future.error(StateError('remote refused the reset'));
}

void main() {
  group('offline-first repository', () {
    OfflineFirstQazaRepository create({
      required QazaRepository remote,
      required InMemoryQazaLocalStore local,
      Stream<bool>? connectivity,
    }) =>
        OfflineFirstQazaRepository(
          remote: remote,
          localStore: local,
          connectivityChanges: connectivity,
          now: () => _stamp,
        );

    test('a reset clears locally and reaches the remote ledger', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final repository = create(remote: remote, local: local);
      addTearDown(repository.dispose);
      await repository.setActiveUser('u1');
      await repository.addRecords(_ledger(4));
      await repository.syncNow();
      expect(await remote.getRecords(userId: 'u1'), hasLength(4));

      await repository.resetUserRecords(userId: 'u1');
      await repository.syncNow();

      expect(await repository.getRecords(userId: 'u1'), isEmpty);
      expect(await remote.getRecords(userId: 'u1'), isEmpty);
      expect((await local.load()).outboxByUser['u1'], isEmpty);
    });

    test('an offline reset queues one operation that supersedes the queue',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      final repository = create(
          remote: remote, local: local, connectivity: connectivity.stream);
      addTearDown(repository.dispose);
      await repository.setActiveUser('u1');
      connectivity.add(false);
      await Future<void>.delayed(Duration.zero);
      await repository.addRecords(_ledger(3));
      expect((await local.load()).outboxByUser['u1'], hasLength(3));

      await repository.resetUserRecords(userId: 'u1');

      final queued = (await local.load()).outboxByUser['u1']!;
      expect(queued, hasLength(1));
      expect(queued.single.type, SyncOpType.reset);
      expect(await repository.getRecords(userId: 'u1'), isEmpty);
      expect(await remote.getRecords(userId: 'u1'), isEmpty);

      connectivity.add(true);
      await repository.syncNow();
      expect(await remote.getRecords(userId: 'u1'), isEmpty);
      expect((await local.load()).outboxByUser['u1'], isEmpty);
    });

    test('a reset never reaches another signed-in account', () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      await remote.addRecords(_ledger(5, userId: 'u2'));
      final repository = create(remote: remote, local: local);
      addTearDown(repository.dispose);
      await repository.setActiveUser('u1');
      await repository.addRecords(_ledger(2));
      await repository.syncNow();

      await repository.resetUserRecords(userId: 'u1');
      await repository.syncNow();

      expect(await remote.getRecords(userId: 'u2'), hasLength(5));
    });

    test('resetting a non-active user is rejected', () async {
      final repository = create(
          remote: InMemoryQazaRepository(), local: InMemoryQazaLocalStore());
      addTearDown(repository.dispose);
      await repository.setActiveUser('u1');

      expect(() => repository.resetUserRecords(userId: 'u2'),
          throwsA(isA<StateError>()));
    });

    test('bootstrap does not re-hydrate a ledger with a queued reset',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      await remote.addRecords(_ledger(4));
      // The state a restart sees after an offline reset: no local records, and
      // a reset still waiting in the outbox.
      await local.saveRecordsAndOutbox('u1', const [], [
        PendingSyncOp(
            id: 'reset_u1',
            type: SyncOpType.reset,
            userId: 'u1',
            queuedAt: _stamp),
      ]);
      final repository = create(remote: remote, local: local);
      addTearDown(repository.dispose);

      await repository.setActiveUser('u1');
      await repository.ensureHydrated();

      expect(await repository.getRecords(userId: 'u1'), isEmpty);
    });

    test('bootstrap still hydrates an empty ledger with no queued reset',
        () async {
      final local = InMemoryQazaLocalStore();
      final remote = InMemoryQazaRepository();
      await remote.addRecords(_ledger(4));
      final repository = create(remote: remote, local: local);
      addTearDown(repository.dispose);

      await repository.setActiveUser('u1');
      await repository.ensureHydrated();

      expect(await repository.getRecords(userId: 'u1'), hasLength(4));
    });
  });

  group('reset controller', () {
    ProviderContainer container(QazaRepository repository, {String? userId}) {
      final result = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue(userId),
      ]);
      addTearDown(result.dispose);
      result.listen(qazaResetControllerProvider, (_, __) {});
      return result;
    }

    test('clears the ledger and reports what was deleted', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(7));
      final scope = container(repository, userId: 'u1');
      expect(
          (await scope.read(progressSummaryProvider.future)).overall.total, 7);

      final done =
          await scope.read(qazaResetControllerProvider.notifier).reset();

      expect(done, isTrue);
      expect(scope.read(qazaResetControllerProvider).recordCount, 7);
      expect(scope.read(qazaResetControllerProvider).error, isNull);
      expect(await repository.getRecords(userId: 'u1'), isEmpty);
      expect(
          (await scope.read(progressSummaryProvider.future)).overall.total, 0);
    });

    test('does nothing while signed out', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      final scope = container(repository);

      final done =
          await scope.read(qazaResetControllerProvider.notifier).reset();

      expect(done, isFalse);
      expect(scope.read(qazaResetControllerProvider).error, isNull);
      expect(await repository.getRecords(userId: 'u1'), hasLength(3));
    });

    test('surfaces a failure instead of claiming success', () async {
      final repository = _FailingResetRepository();
      await repository.addRecords(_ledger(2));
      final scope = container(repository, userId: 'u1');

      final done =
          await scope.read(qazaResetControllerProvider.notifier).reset();

      expect(done, isFalse);
      expect(scope.read(qazaResetControllerProvider).error, isNotNull);
      expect(scope.read(qazaResetControllerProvider).running, isFalse);
      expect(await repository.getRecords(userId: 'u1'), hasLength(2));
    });
  });

  group('settings flow', () {
    Future<void> pumpSettings(
        WidgetTester tester, InMemoryQazaRepository repository) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith((ref) =>
              Stream.value(const AppUser(id: 'u1', email: 'user@example.com'))),
        ],
        child: const TestApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openDialog(WidgetTester tester) async {
      final row = find.byKey(const Key('settings_reset_qaza_counter'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('Settings offers the reset action', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      await pumpSettings(tester, repository);

      expect(
          find.byKey(const Key('settings_reset_qaza_counter')), findsOneWidget);
      expect(find.text('Reset Qaza Counter'), findsOneWidget);
    });

    testWidgets('the action is inert when there is nothing to reset',
        (tester) async {
      await pumpSettings(tester, InMemoryQazaRepository());

      expect(find.text('There are no Qaza records to reset.'), findsOneWidget);
      await openDialog(tester);
      expect(find.byKey(const Key('destructive_confirm')), findsNothing);
    });

    testWidgets('the dialog warns before anything is deleted', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      await pumpSettings(tester, repository);

      await openDialog(tester);

      expect(find.text('Reset Qaza Counter?'), findsOneWidget);
      expect(find.textContaining('permanently deletes every Qaza record'),
          findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(
          find.text(
              'I understand that 3 Qaza records will be permanently deleted'),
          findsOneWidget);
      expect(await repository.getRecords(userId: 'u1'), hasLength(3));
    });

    testWidgets('confirming stays disabled until the warning is acknowledged',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      await pumpSettings(tester, repository);
      await openDialog(tester);

      final confirm = find.byKey(const Key('destructive_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Reset Qaza Counter?'), findsOneWidget);
      expect(await repository.getRecords(userId: 'u1'), hasLength(3));

      await tester.tap(find.byKey(const Key('destructive_acknowledge')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('cancelling leaves the ledger untouched', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      await pumpSettings(tester, repository);
      await openDialog(tester);

      await tester.tap(find.byKey(const Key('destructive_acknowledge')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await repository.getRecords(userId: 'u1'), hasLength(3));
    });

    testWidgets('acknowledging and confirming clears the counter',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords(_ledger(3));
      await pumpSettings(tester, repository);
      await openDialog(tester);

      await tester.tap(find.byKey(const Key('destructive_acknowledge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('destructive_confirm')));
      await tester.pumpAndSettle();

      expect(await repository.getRecords(userId: 'u1'), isEmpty);
      expect(find.text('Qaza counter reset.'), findsOneWidget);
      expect(find.text('There are no Qaza records to reset.'), findsOneWidget);
    });
  });
}
