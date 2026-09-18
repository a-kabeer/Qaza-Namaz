import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'support/in_memory_qaza_repository.dart';

/// Counts what the production UX paths actually ask the data layer for.
///
/// `getRecords` is the full-ledger API; any use of it from a production screen
/// is a scalability regression, so it is recorded rather than forbidden and the
/// assertions state exactly who is allowed to call it.
class _CountingRepository implements QazaRepository {
  _CountingRepository(this.delegate);

  final InMemoryQazaRepository delegate;

  int fullLedgerReads = 0;
  int pageReads = 0;
  int historyReads = 0;
  int summaryReads = 0;
  int oldestPendingReads = 0;
  final List<int> requestedLimits = <int>[];

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) {
    fullLedgerReads++;
    return delegate.getRecords(
      userId: userId,
      prayerType: prayerType,
      status: status,
    );
  }

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
    pageReads++;
    requestedLimits.add(limit);
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
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status = QazaStatus.completed,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) {
    historyReads++;
    requestedLimits.add(limit);
    return delegate.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) {
    summaryReads++;
    return delegate.getProgressSummary(userId: userId);
  }

  @override
  Future<QazaRecord?> getOldestPending({
    required String userId,
    required PrayerType prayerType,
  }) {
    oldestPendingReads++;
    return delegate.getOldestPending(userId: userId, prayerType: prayerType);
  }

  @override
  Future<void> addRecord(QazaRecord record) => delegate.addRecord(record);

  @override
  Future<void> addRecords(List<QazaRecord> records) =>
      delegate.addRecords(records);

  @override
  Future<void> completeRecord({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) =>
      delegate.completeRecord(
        userId: userId,
        recordId: recordId,
        completedAt: completedAt,
      );

  @override
  Future<void> completeRecords({
    required String userId,
    required List<String> recordIds,
    required DateTime completedAt,
  }) =>
      delegate.completeRecords(
        userId: userId,
        recordIds: recordIds,
        completedAt: completedAt,
      );

  @override
  Future<void> resetUserRecords({required String userId}) =>
      delegate.resetUserRecords(userId: userId);
}

const _userId = 'scale-user';
final _start = DateTime(2000, 1, 1);

/// Builds [count] records spread across dates and all six prayers.
List<QazaRecord> _ledger(int count) {
  final stamp = DateTime(2026, 1, 1);
  return [
    for (var index = 0; index < count; index++)
      () {
        final prayer = PrayerType.values[index % PrayerType.values.length];
        final date =
            _start.add(Duration(days: index ~/ PrayerType.values.length));
        return QazaRecord(
          id: '${_userId}_${prayer.name}_${date.toIso8601String()}',
          userId: _userId,
          prayerType: prayer,
          originalDate: date,
          createdAt: stamp,
          updatedAt: stamp,
        );
      }(),
  ];
}

Future<_CountingRepository> _seed(int count) async {
  final delegate = InMemoryQazaRepository();
  await delegate.addRecords(_ledger(count));
  return _CountingRepository(delegate);
}

ProviderContainer _container(_CountingRepository repository) {
  final container = ProviderContainer(
    overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue(_userId),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  for (final size in [1000, 5000, 10000]) {
    group('$size records', () {
      test('the Qaza workspace fetches bounded pages only', () async {
        final repository = await _seed(size);
        final container = _container(repository);
        container.listen(qazaTrackerControllerProvider, (_, __) {});
        final controller =
            container.read(qazaTrackerControllerProvider.notifier);

        await controller.refresh();
        await controller.loadMore();
        await controller.loadMore();

        final state = container.read(qazaTrackerControllerProvider);
        expect(state.records.length, QazaTrackerController.pageSize * 3);
        expect(state.hasMore, isTrue);
        expect(repository.fullLedgerReads, 0,
            reason: 'the tracker must never read the complete ledger');
        expect(
          repository.requestedLimits.every(
            (limit) => limit <= QazaTrackerController.pageSize,
          ),
          isTrue,
        );
      });

      test('filtering stays database-side and bounded', () async {
        final repository = await _seed(size);
        final container = _container(repository);
        container.listen(qazaTrackerControllerProvider, (_, __) {});
        final controller =
            container.read(qazaTrackerControllerProvider.notifier);

        controller.setPrayerFilter(PrayerType.witr);
        await controller.refresh();
        controller.setDateRange(_start, _start.add(const Duration(days: 30)));
        await controller.refresh();

        final state = container.read(qazaTrackerControllerProvider);
        expect(state.records.length,
            lessThanOrEqualTo(QazaTrackerController.pageSize));
        expect(
          state.records.every((record) => record.prayerType == PrayerType.witr),
          isTrue,
        );
        expect(
          state.records.every(
            (record) => !record.originalDate
                .isAfter(_start.add(const Duration(days: 30))),
          ),
          isTrue,
        );
        expect(repository.fullLedgerReads, 0);
      });

      test('progress comes from a database aggregate', () async {
        final repository = await _seed(size);
        final container = _container(repository);

        final summary = await container.read(progressSummaryProvider.future);

        expect(summary.overall.total, size);
        expect(repository.summaryReads, greaterThan(0));
        expect(repository.fullLedgerReads, 0,
            reason: 'Home must not materialize the ledger to show progress');
      });

      test('completion uses a bounded oldest-pending lookup', () async {
        final repository = await _seed(size);
        final container = _container(repository);

        final oldest =
            await container.read(oldestPendingProvider(PrayerType.fajr).future);

        expect(oldest, isNotNull);
        expect(oldest!.prayerType, PrayerType.fajr);
        expect(repository.oldestPendingReads, 1);
        expect(repository.fullLedgerReads, 0);
      });

      test('availability is scoped to the requested dates and prayers',
          () async {
        final repository = await _seed(size);
        final container = _container(repository);
        final service = container.read(qazaServiceProvider);

        final dates = [
          _start.add(const Duration(days: 1)),
          _start.add(const Duration(days: 2)),
        ];
        final analysis = await service.analyzeAvailability(
          userId: _userId,
          dates: dates,
          prayerTypes: [PrayerType.fajr, PrayerType.zuhr],
        );

        expect(analysis.requestedCount, dates.length * 2);
        expect(repository.fullLedgerReads, 0,
            reason: 'availability must stay scoped, never a full-ledger scan');
        expect(repository.historyReads, greaterThan(0));
      });

      test('the calculator preflight does not materialize the ledger',
          () async {
        final repository = await _seed(size);
        final container = _container(repository);
        final service = container.read(qazaServiceProvider);

        // A one-year estimate across all six prayers.
        final dates = [
          for (var day = 0; day < 365; day++) _start.add(Duration(days: day)),
        ];
        final analysis = await service.analyzeAvailability(
          userId: _userId,
          dates: dates,
          prayerTypes: PrayerType.values,
        );

        expect(analysis.requestedCount, 365 * PrayerType.values.length);
        expect(analysis.newCount + analysis.unavailableCount,
            analysis.requestedCount);
        expect(repository.fullLedgerReads, 0);
      });
    });
  }

  group('selection bounds', () {
    test('bulk selection never exceeds the loaded page', () async {
      final repository = await _seed(10000);
      final container = _container(repository);
      container.listen(qazaTrackerControllerProvider, (_, __) {});
      final controller = container.read(qazaTrackerControllerProvider.notifier);

      await controller.refresh();
      controller.selectAllLoaded();

      final state = container.read(qazaTrackerControllerProvider);
      expect(state.selected.length, QazaTrackerController.pageSize);
      expect(state.selected.length, lessThan(10000));
    });
  });
}
