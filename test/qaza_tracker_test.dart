import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_screen.dart';
import 'support/in_memory_qaza_repository.dart';

/// Fails the test if any consumer asks for the whole ledger.
class _BoundedOnlyRepository implements QazaRepository {
  _BoundedOnlyRepository(this.delegate);

  final InMemoryQazaRepository delegate;
  int pageCalls = 0;
  int? largestLimit;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async =>
      throw StateError('The Qaza tracker must not load the complete ledger.');

  @override
  Future<QazaPage> getPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? afterOriginalDate,
    String? afterId,
  }) {
    pageCalls++;
    largestLimit =
        largestLimit == null || limit > largestLimit! ? limit : largestLimit;
    return delegate.getPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      afterOriginalDate: afterOriginalDate,
      afterId: afterId,
    );
  }

  @override
  noSuchMethod(Invocation invocation) =>
      Function.apply(_forward(invocation), null);

  Function _forward(Invocation invocation) => () => throw UnimplementedError(
        '${invocation.memberName} is not used by the tracker tests.',
      );
}

QazaRecord _record({
  required PrayerType prayer,
  required DateTime date,
  QazaStatus status = QazaStatus.pending,
}) {
  final stamp = DateTime(2026, 1, 1);
  return QazaRecord(
    id: 'test-user_${prayer.name}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    userId: 'test-user',
    prayerType: prayer,
    originalDate: date,
    status: status,
    completedAt: status == QazaStatus.completed ? stamp : null,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

Future<ProviderContainer> _container(InMemoryQazaRepository repository) async {
  final container = ProviderContainer(
    overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('test-user'),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle(ProviderContainer container) async {
  await container.read(qazaTrackerControllerProvider.notifier).refresh();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('controller', () {
    test('loads a bounded first page and defaults to pending', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        for (var day = 1; day <= 120; day++)
          _record(
              prayer: PrayerType.fajr,
              date: DateTime(2025, 1, 1).add(Duration(days: day))),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);

      final state = container.read(qazaTrackerControllerProvider);
      expect(state.statusFilter, QazaStatusFilter.pending);
      expect(state.records.length, QazaTrackerController.pageSize);
      expect(state.hasMore, isTrue);
      expect(state.loading, isFalse);
    });

    test('load more appends the next bounded page without duplicates',
        () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        for (var day = 1; day <= 120; day++)
          _record(
              prayer: PrayerType.fajr,
              date: DateTime(2025, 1, 1).add(Duration(days: day))),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);

      final controller = container.read(qazaTrackerControllerProvider.notifier);
      await controller.loadMore();

      final state = container.read(qazaTrackerControllerProvider);
      expect(state.records.length, QazaTrackerController.pageSize * 2);
      expect(
        state.records.map((record) => record.id).toSet().length,
        state.records.length,
      );
    });

    test('prayer, status and date filters narrow the query', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
        _record(prayer: PrayerType.zuhr, date: DateTime(2025, 1, 2)),
        _record(prayer: PrayerType.witr, date: DateTime(2025, 6, 1)),
        _record(
          prayer: PrayerType.asr,
          date: DateTime(2025, 1, 3),
          status: QazaStatus.completed,
        ),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final controller = container.read(qazaTrackerControllerProvider.notifier);

      controller.setPrayerFilter(PrayerType.witr);
      await _settle(container);
      expect(
          container
              .read(qazaTrackerControllerProvider)
              .records
              .single
              .prayerType,
          PrayerType.witr);

      controller.setPrayerFilter(null);
      controller.setStatusFilter(QazaStatusFilter.completed);
      await _settle(container);
      expect(
          container
              .read(qazaTrackerControllerProvider)
              .records
              .single
              .prayerType,
          PrayerType.asr);

      controller.setStatusFilter(QazaStatusFilter.all);
      controller.setDateRange(DateTime(2025, 1, 1), DateTime(2025, 1, 2));
      await _settle(container);
      final dated = container.read(qazaTrackerControllerProvider).records;
      expect(dated.length, 2);
      expect(dated.every((r) => !r.originalDate.isAfter(DateTime(2025, 1, 2))),
          isTrue);
    });

    test('reset returns to the default pending view', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final controller = container.read(qazaTrackerControllerProvider.notifier);

      controller.setPrayerFilter(PrayerType.witr);
      await _settle(container);
      expect(container.read(qazaTrackerControllerProvider).isFiltered, isTrue);
      expect(container.read(qazaTrackerControllerProvider).records, isEmpty);

      controller.clearFilters();
      await _settle(container);
      final state = container.read(qazaTrackerControllerProvider);
      expect(state.isFiltered, isFalse);
      expect(state.records.length, 1);
    });

    test('bulk completion is bounded, repeat-safe and refreshes the page',
        () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        for (var day = 1; day <= 6; day++)
          _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, day)),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final controller = container.read(qazaTrackerControllerProvider.notifier);

      controller.selectAllLoaded();
      expect(container.read(qazaTrackerControllerProvider).selected.length, 6);

      final completed = await controller.completeSelected();
      expect(completed, 6);

      final state = container.read(qazaTrackerControllerProvider);
      expect(state.selected, isEmpty);
      expect(state.records, isEmpty, reason: 'nothing is pending any more');

      // A second completion of an already-empty selection is a no-op.
      expect(await controller.completeSelected(), 0);
    });

    test('selection only ever covers pending records', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
        _record(
          prayer: PrayerType.zuhr,
          date: DateTime(2025, 1, 2),
          status: QazaStatus.completed,
        ),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      final controller = container.read(qazaTrackerControllerProvider.notifier);
      controller.setStatusFilter(QazaStatusFilter.all);
      await _settle(container);

      controller.selectAllLoaded();
      final state = container.read(qazaTrackerControllerProvider);
      expect(state.records.length, 2);
      expect(state.selected.length, 1);
    });

    test('edits a record and keeps its identity', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final record =
          container.read(qazaTrackerControllerProvider).records.single;

      await container.read(qazaTrackerControllerProvider.notifier).updateRecord(
            record.copyWith(
              prayerType: PrayerType.zuhr,
              originalDate: DateTime(2025, 2, 3),
            ),
          );

      final updated = (await repository.getPage(
        userId: 'test-user',
        limit: 50,
      ))
          .records
          .single;
      expect(updated.id, record.id);
      expect(updated.prayerType, PrayerType.zuhr);
      expect(updated.originalDate, DateTime(2025, 2, 3));
      expect(updated.status, QazaStatus.pending);
    });

    test('rejects an edit that would create a duplicate prayer/date pair',
        () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
        _record(prayer: PrayerType.zuhr, date: DateTime(2025, 2, 1)),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final records =
          container.read(qazaTrackerControllerProvider).records.toList();

      await expectLater(
        container.read(qazaTrackerControllerProvider.notifier).updateRecord(
              records.first.copyWith(
                prayerType: PrayerType.zuhr,
                originalDate: DateTime(2025, 2, 1),
              ),
            ),
        throwsA(isA<QazaDuplicateRecordException>()),
      );
      final state = container.read(qazaTrackerControllerProvider);
      expect(state.recordMutating, isFalse);
      expect(state.records, isNotEmpty);
    });

    test('deletes a record from the bounded tracker', () async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      final container = await _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await _settle(container);
      final id =
          container.read(qazaTrackerControllerProvider).records.single.id;

      await container.read(qazaTrackerControllerProvider.notifier).deleteRecord(id);

      expect(
        (await repository.getPage(userId: 'test-user', limit: 50)).records,
        isEmpty,
      );
    });

    test('never asks the repository for the full ledger', () async {
      final delegate = InMemoryQazaRepository();
      await delegate.addRecords([
        for (var day = 1; day <= 200; day++)
          _record(
              prayer: PrayerType.fajr,
              date: DateTime(2025, 1, 1).add(Duration(days: day))),
      ]);
      final bounded = _BoundedOnlyRepository(delegate);
      final container = ProviderContainer(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(bounded),
          activeUserIdProvider.overrideWithValue('test-user'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      await container.read(qazaTrackerControllerProvider.notifier).refresh();
      await container.read(qazaTrackerControllerProvider.notifier).loadMore();

      expect(bounded.pageCalls, greaterThan(0));
      expect(bounded.largestLimit, QazaTrackerController.pageSize);
      expect(container.read(qazaTrackerControllerProvider).records.length,
          QazaTrackerController.pageSize * 2);
    });
  });

  group('screen', () {
    Future<void> pump(
        WidgetTester tester, InMemoryQazaRepository repository) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            qazaRepositoryProvider.overrideWithValue(repository),
            activeUserIdProvider.overrideWithValue('test-user'),
          ],
          child: const TestApp(home: QazaTrackerScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('an empty ledger shows the empty state', (tester) async {
      await pump(tester, InMemoryQazaRepository());
      expect(find.byKey(const Key('qaza_tracker_empty')), findsOneWidget);
      expect(
          find.byKey(const Key('qaza_tracker_filtered_empty')), findsNothing);
    });

    testWidgets('a filtered empty result is distinct from an empty ledger',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      await pump(tester, repository);
      expect(find.byKey(const Key('qaza_tracker_list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('qaza_tracker_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Witr'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
          find.byKey(const Key('qaza_tracker_filtered_empty')), findsOneWidget);
      expect(find.byKey(const Key('qaza_tracker_empty')), findsNothing);
    });

    testWidgets('record actions expose edit and delete without changing selection',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      await pump(tester, repository);

      expect(
        find.byKey(const Key(
          'qaza_record_actions_test-user_fajr_2025-01-01',
        )),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key(
          'qaza_record_actions_test-user_fajr_2025-01-01',
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('qaza_record_edit_save')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('qaza_record_edit_save')));
      await tester.pumpAndSettle();

      expect(find.text('Qaza record updated.'), findsOneWidget);
      expect(
        find.byKey(const Key(
          'qaza_record_actions_test-user_fajr_2025-01-01',
        )),
        findsOneWidget,
      );
    });

    testWidgets('delete action requires confirmation', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      await pump(tester, repository);

      await tester.tap(
        find.byKey(const Key(
          'qaza_record_actions_test-user_fajr_2025-01-01',
        )),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Delete Qaza record?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('qaza_tracker_empty')), findsOneWidget);
    });

    testWidgets('tap completion circle completes the oldest record', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
      ]);
      await pump(tester, repository);

      await tester.tap(find.byKey(const Key('qaza_record_complete_test-user_fajr_2025-01-01')));
      await tester.pumpAndSettle();

      final completed = await repository.getRecords(userId: 'test-user', status: QazaStatus.completed);
      expect(completed, hasLength(1));
      expect(find.byKey(const Key('qaza_tracker_empty')), findsOneWidget);
    });

    testWidgets('long press enters selection and back exits it', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
        _record(prayer: PrayerType.zuhr, date: DateTime(2025, 1, 2)),
      ]);
      await pump(tester, repository);

      await tester.longPress(find.byKey(const Key('qaza_record_test-user_fajr_2025-01-01')));
      await tester.pump();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byKey(const Key('qaza_tracker_complete_selected')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Qaza'), findsOneWidget);
      expect(find.byKey(const Key('qaza_tracker_complete_selected')), findsNothing);
    });

    testWidgets('selection mode supports bulk delete and records can be restored',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(prayer: PrayerType.fajr, date: DateTime(2025, 1, 1)),
        _record(prayer: PrayerType.zuhr, date: DateTime(2025, 1, 2)),
      ]);
      await pump(tester, repository);

      await tester.longPress(find.byKey(const Key('qaza_record_test-user_fajr_2025-01-01')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('qaza_record_test-user_zuhr_2025-01-02')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('qaza_tracker_delete_selected')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Qaza record?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final active = await repository.getRecords(userId: 'test-user');
      final deleted = await repository.getHistoryPage(userId: 'test-user', status: QazaStatus.deleted);
      expect(active, isEmpty);
      expect(deleted.records, hasLength(2));
    });
  });
}
