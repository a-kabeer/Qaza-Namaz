import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/qaza_operation.dart';
import '../../domain/repositories/qaza_recovery_repository.dart';
import '../../domain/services/qaza_service.dart';
import '../prayer_times/prayer_times_providers.dart';

/// Status filter for the Qaza workspace. [all] leaves the status unconstrained
/// so the database returns both pending and completed records.
enum QazaStatusFilter { all, pending, completed }

extension QazaStatusFilterX on QazaStatusFilter {
  QazaStatus? get status => switch (this) {
        QazaStatusFilter.all => null,
        QazaStatusFilter.pending => QazaStatus.pending,
        QazaStatusFilter.completed => QazaStatus.completed,
      };

  String get label => switch (this) {
        QazaStatusFilter.all => 'All',
        QazaStatusFilter.pending => 'Pending',
        QazaStatusFilter.completed => 'Completed',
      };
}

/// Bounded, filterable page of the Qaza ledger plus the current selection.
///
/// The full ledger is never held here: [records] only ever contains the pages
/// that have actually been requested.
/// Which end of the ledger the tracker reads from.
///
/// Both directions are keyset queries over the same `(originalDate, id)` index,
/// so paging stays bounded and the tie-breaker keeps the order total: two
/// records on the same day can never swap places between pages.
enum QazaSortOrder {
  /// Ascending by date. The order a Qaza debt is owed in.
  oldestFirst,

  /// Descending by date. What was missed most recently.
  newestFirst;

  bool get isOldestFirst => this == QazaSortOrder.oldestFirst;
}

class QazaTrackerState {
  const QazaTrackerState({
    this.statusFilter = QazaStatusFilter.pending,
    this.selectionMode = false,
    this.sortOrder = QazaSortOrder.oldestFirst,
    this.selectingAll = false,
    this.prayerFilter,
    this.from,
    this.to,
    this.records = const <QazaRecord>[],
    this.hasMore = false,
    this.loading = true,
    this.refreshing = false,
    this.loadingMore = false,
    this.completing = false,
    this.recordMutating = false,
    this.error,
    this.selected = const <String>{},
  });

  final QazaStatusFilter statusFilter;
  final bool selectionMode;

  /// Which end of the ledger is read first. Oldest by default,
  /// because that is the order Qaza is owed in.
  final QazaSortOrder sortOrder;

  /// True while the whole filtered ledger is being gathered for selection.
  final bool selectingAll;
  final PrayerType? prayerFilter;
  final DateTime? from;
  final DateTime? to;
  final List<QazaRecord> records;
  final bool hasMore;

  /// True only while there is nothing to show yet.
  final bool loading;

  /// True while a page is being fetched over content already on screen.
  ///
  /// Switching a filter does not blank the list: the previous page stays
  /// visible under a thin progress bar until the new one arrives.
  final bool refreshing;

  final bool loadingMore;
  final bool completing;
  final bool recordMutating;
  final String? error;
  final Set<String> selected;

  /// True when the user has narrowed the ledger, which distinguishes an empty
  /// ledger from an empty filter result.
  bool get isFiltered =>
      statusFilter != QazaStatusFilter.pending ||
      prayerFilter != null ||
      from != null ||
      to != null;

  bool get hasDateFilter => from != null || to != null;

  /// Only pending records can be completed, so selection is offered for those.
  List<QazaRecord> get selectableRecords =>
      records.where((record) => record.status == QazaStatus.pending).toList();

  /// How many selected records it takes before completing them is confirmed.
  ///
  /// Bulk completion is undoable, but an undo banner is a poor answer to
  /// "I have just completed four thousand prayers by accident".
  static const int largeSelectionThreshold = 25;

  /// A selection big enough that acting on it should be confirmed first.
  bool get selectionNeedsConfirmation =>
      selected.length >= largeSelectionThreshold;

  bool get isEmpty => records.isEmpty && !loading && error == null;

  QazaTrackerState copyWith({
    QazaStatusFilter? statusFilter,
    QazaSortOrder? sortOrder,
    bool? selectingAll,
    PrayerType? prayerFilter,
    DateTime? from,
    DateTime? to,
    List<QazaRecord>? records,
    bool? hasMore,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    bool? completing,
    bool? recordMutating,
    String? error,
    Set<String>? selected,
    bool? selectionMode,
    bool clearPrayerFilter = false,
    bool clearDates = false,
    bool clearError = false,
  }) =>
      QazaTrackerState(
        statusFilter: statusFilter ?? this.statusFilter,
        selectionMode: selectionMode ?? this.selectionMode,
        sortOrder: sortOrder ?? this.sortOrder,
        selectingAll: selectingAll ?? this.selectingAll,
        prayerFilter:
            clearPrayerFilter ? null : prayerFilter ?? this.prayerFilter,
        from: clearDates ? null : from ?? this.from,
        to: clearDates ? null : to ?? this.to,
        records: records ?? this.records,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        refreshing: refreshing ?? this.refreshing,
        loadingMore: loadingMore ?? this.loadingMore,
        completing: completing ?? this.completing,
        recordMutating: recordMutating ?? this.recordMutating,
        error: clearError ? null : error ?? this.error,
        selected: selected ?? this.selected,
      );
}

/// A filter another screen wants the tracker to open with.
///
/// The controller is auto-disposed, so filters set on it before the Qaza tab
/// is on screen would be thrown away with the instance. Requests are left
/// here instead and applied by [QazaTrackerController.build], which makes the
/// hand-off independent of when each screen builds.
class QazaTrackerFilterRequest {
  const QazaTrackerFilterRequest({this.prayer, this.status});

  final PrayerType? prayer;
  final QazaStatusFilter? status;
}

final qazaTrackerFilterRequestProvider =
    StateProvider<QazaTrackerFilterRequest?>((ref) => null);

/// Result of one bulk completion action, including the exact timestamp
/// needed to make its undo safe.
class QazaCompletionBatch {
  const QazaCompletionBatch({
    required this.recordIds,
    required this.completedAt,
    required this.count,
  });

  final List<String> recordIds;
  final DateTime completedAt;
  final int count;
}

/// Owns the Qaza workspace: filters, bounded paging, selection and bulk
/// completion. Every read goes through [QazaService] with a page limit.
class QazaTrackerController extends AutoDisposeNotifier<QazaTrackerState> {
  static const int pageSize = 50;

  @override
  QazaTrackerState build() {
    ref.watch(activeUserIdProvider);
    // The Qaza tab stays mounted once visited, so a second hand-off arrives
    // while this controller is already built and build() never runs again for
    // it. Listening covers those; the read below covers the first one, which
    // is already waiting before this listener exists.
    ref.listen<QazaTrackerFilterRequest?>(
      qazaTrackerFilterRequestProvider,
      (_, next) {
        if (next != null) _applyRequest(next);
      },
    );

    final request = ref.read(qazaTrackerFilterRequestProvider);
    Future.microtask(refresh);
    if (request == null) return const QazaTrackerState();
    _consumeRequest(request);
    return QazaTrackerState(
      statusFilter: request.status ?? QazaStatusFilter.pending,
      prayerFilter: request.prayer,
    );
  }

  /// Applies a hand-off to a tracker that is already on screen.
  void _applyRequest(QazaTrackerFilterRequest request) {
    _consumeRequest(request);
    final status = request.status ?? state.statusFilter;
    // A new prayer means a new list, so any selection made under the previous
    // filter is dropped rather than carried across.
    state = request.prayer == null
        ? state.copyWith(
            statusFilter: status,
            clearPrayerFilter: true,
            selected: const <String>{})
        : state.copyWith(
            statusFilter: status,
            prayerFilter: request.prayer,
            selected: const <String>{});
    refresh();
  }

  /// Clears a request once it has been applied.
  ///
  /// Only this exact request is cleared: a newer one that arrived in the
  /// meantime must survive to be applied in its turn.
  void _consumeRequest(QazaTrackerFilterRequest request) {
    Future.microtask(() {
      final notifier = ref.read(qazaTrackerFilterRequestProvider.notifier);
      if (identical(notifier.state, request)) notifier.state = null;
    });
  }

  Future<void> refresh() async {
    ref.invalidate(sahibAlTartibProvider);
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        records: const <QazaRecord>[],
        hasMore: false,
        loading: false,
        refreshing: false,
        selected: const <String>{},
        clearError: true,
      );
      return;
    }
    // A full loading state only when there is nothing to keep: otherwise the
    // current page stays put and the bar does the talking.
    final initial = state.records.isEmpty;
    state = state.copyWith(
      loading: initial,
      refreshing: !initial,
      clearError: true,
      selected: const <String>{},
    );
    try {
      final page = await _readPage(userId: userId);
      state = state.copyWith(
        records: page.records,
        hasMore: page.hasMore,
        loading: false,
        refreshing: false,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        records: const <QazaRecord>[],
        hasMore: false,
        error: error.toString(),
      );
    }
  }

  /// Reads one bounded page in the active sort order.
  ///
  /// Ascending and descending are two different keyset queries — `after` for
  /// one, `before` for the other — so the direction is resolved here rather
  /// than at each call site.
  Future<QazaPage> _readPage({
    required String userId,
    QazaRecord? after,
  }) async {
    final service = ref.read(qazaServiceProvider);
    if (state.sortOrder.isOldestFirst) {
      return service.getPage(
        userId: userId,
        limit: pageSize,
        prayerType: state.prayerFilter,
        status: state.statusFilter.status,
        from: state.from,
        to: state.to,
        afterOriginalDate: after?.originalDate,
        afterId: after?.id,
      );
    }
    final page = await service.getHistoryPage(
      userId: userId,
      limit: pageSize,
      prayerType: state.prayerFilter,
      status: state.statusFilter.status,
      from: state.from,
      to: state.to,
      beforeOriginalDate: after?.originalDate,
      beforeId: after?.id,
    );
    return QazaPage(records: page.records, hasMore: page.hasMore);
  }

  /// Switches the order and reloads from the top. Paging state cannot be
  /// carried across a direction change, so the selection is dropped with it.
  void setSortOrder(QazaSortOrder order) {
    if (order == state.sortOrder) return;
    state = state.copyWith(
      sortOrder: order,
      records: const <QazaRecord>[],
      hasMore: false,
      selected: const <String>{},
    );
    refresh();
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final userId = ref.read(activeUserIdProvider);
    final last = state.records.isEmpty ? null : state.records.last;
    if (userId == null || last == null) return;

    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _readPage(userId: userId, after: last);
      state = state.copyWith(
        records: [...state.records, ...page.records],
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        loadingMore: false,
        error: error.toString(),
      );
    }
  }

  void setStatusFilter(QazaStatusFilter filter) {
    if (filter == state.statusFilter) return;
    state = state.copyWith(statusFilter: filter);
    refresh();
  }

  void setPrayerFilter(PrayerType? prayer) {
    if (prayer == state.prayerFilter) return;
    state = prayer == null
        ? state.copyWith(clearPrayerFilter: true)
        : state.copyWith(prayerFilter: prayer);
    refresh();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = from == null && to == null
        ? state.copyWith(clearDates: true)
        : state.copyWith(
            from: from == null ? null : QazaDate.normalize(from),
            to: to == null ? null : QazaDate.normalize(to),
          );
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(
      statusFilter: QazaStatusFilter.pending,
      clearPrayerFilter: true,
      clearDates: true,
    );
    refresh();
  }

  void enterSelectionMode(String recordId) {
    if (state.statusFilter != QazaStatusFilter.pending) return;
    final index = state.records.indexWhere((r) => r.id == recordId);
    final record = index < 0 ? null : state.records[index];
    if (record == null || record.status != QazaStatus.pending) return;
    final next = Set<String>.of(state.selected)..add(recordId);
    state = state.copyWith(selectionMode: true, selected: next);
  }

  void toggleSelection(String recordId) {
    final next = Set<String>.of(state.selected);
    if (!next.remove(recordId)) next.add(recordId);
    state = state.copyWith(selectionMode: true, selected: next);
  }

  void exitSelectionMode() => state = state.copyWith(
        selectionMode: false,
        selected: const <String>{},
      );

  /// Selection is bounded to the records actually loaded, never the ledger.
  void selectAllLoaded() => state = state.copyWith(
        selectionMode: true,
        selected: {for (final record in state.selectableRecords) record.id},
      );

  /// The most records one "select all matching" may gather.
  ///
  /// A bound rather than a preference: without it this walks an unbounded
  /// ledger into memory, which is the thing the rest of this controller is
  /// carefully built to avoid.
  static const int selectAllMatchingCap = 2000;

  /// Selects every pending record matching the active filter, not just the
  /// ones already paged in.
  ///
  /// Walks the same bounded keyset query the list uses, a page at a time, and
  /// stops at [selectAllMatchingCap]. Stopping early is reported through
  /// [QazaTrackerState.hasMore] semantics on the selection: the user gets the
  /// cap's worth and the count tells them what they got.
  Future<void> selectAllMatching() async {
    if (state.selectingAll) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;

    state = state.copyWith(selectingAll: true, clearError: true);
    final ids = <String>{};
    try {
      QazaRecord? cursor;
      while (ids.length < selectAllMatchingCap) {
        final page = await _readPage(userId: userId, after: cursor);
        if (page.records.isEmpty) break;
        for (final record in page.records) {
          if (record.status != QazaStatus.pending) continue;
          ids.add(record.id);
          if (ids.length >= selectAllMatchingCap) break;
        }
        if (!page.hasMore) break;
        cursor = page.records.last;
      }
      state = state.copyWith(selectionMode: true, selected: ids, selectingAll: false);
    } catch (error) {
      state = state.copyWith(
        selectingAll: false,
        error: error.toString(),
      );
    }
  }

  void clearSelection() => exitSelectionMode();

  /// Updates a single tracker record and reloads the bounded page.
  Future<void> updateRecord(QazaRecord record) async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.recordMutating) return;
    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      await ref.read(qazaServiceProvider).updateRecord(
            userId: userId,
            record: record,
          );
      ref.invalidate(progressSummaryProvider);
      await refresh();
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  /// Deletes a single tracker record and reloads the bounded page.
  Future<void> deleteRecord(String recordId) async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.recordMutating) return;
    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      final operation = await ref.read(qazaOperationServiceProvider).begin(
            userId: userId,
            type: QazaOperationType.bulkDelete,
          );
      try {
        final deletedAt = operation.createdAt;
        final recovery = ref.read(qazaServiceProvider);
        if (recovery.repository is! QazaRecoveryRepository) {
          throw StateError('Qaza recovery is not available.');
        }
        final count = await recovery.deleteRecordsWithRecovery(
          userId: userId,
          recordIds: [recordId],
          deletedAt: deletedAt,
          operationId: operation.operationId,
        );
        await ref.read(qazaOperationServiceProvider).finish(
              operation,
              status: count == 1
                  ? QazaOperationStatus.completed
                  : QazaOperationStatus.partial,
              affectedRecordCount: count,
            );
      } catch (error) {
        await ref.read(qazaOperationServiceProvider).finish(
              operation,
              status: QazaOperationStatus.failed,
              affectedRecordCount: 0,
              note: error.toString(),
            );
        rethrow;
      }
      ref.invalidate(progressSummaryProvider);
      await refresh();
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  Future<QazaCompletionBatch?> completeRecordWithUndo(String recordId) async {
    if (state.completing || state.recordMutating) return null;
    final index = state.records.indexWhere((record) => record.id == recordId);
    if (index < 0 || state.records[index].status != QazaStatus.pending) {
      return null;
    }
    final wasSelecting = state.selectionMode;
    final previousSelection = Set<String>.of(state.selected);
    state = state.copyWith(
      selectionMode: true,
      selected: <String>{recordId},
    );
    final batch = await completeSelectedWithUndo();
    if (batch == null && !wasSelecting) {
      state = state.copyWith(
        selectionMode: false,
        selected: previousSelection,
      );
    }
    return batch;
  }

  Future<int> deleteSelectedWithRecovery() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.selected.isEmpty || state.recordMutating) {
      return 0;
    }
    final ids = state.selected.toList(growable: false);
    final operation = await ref.read(qazaOperationServiceProvider).begin(
          userId: userId,
          type: QazaOperationType.bulkDelete,
        );
    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      final count = await ref.read(qazaServiceProvider).deleteRecordsWithRecovery(
            userId: userId,
            recordIds: ids,
            deletedAt: operation.createdAt,
            operationId: operation.operationId,
          );
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: count == ids.length
                ? QazaOperationStatus.completed
                : QazaOperationStatus.partial,
            affectedRecordCount: count,
          );
      exitSelectionMode();
      ref.invalidate(progressSummaryProvider);
      await refresh();
      return count;
    } catch (error) {
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: QazaOperationStatus.failed,
            affectedRecordCount: 0,
            note: error.toString(),
          );
      state = state.copyWith(recordMutating: false, error: error.toString());
      return 0;
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  /// Completes the selected records and returns the batch metadata needed
  /// for a safe, timestamp-bound undo action.
  Future<QazaCompletionBatch?> completeSelectedWithUndo() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.selected.isEmpty || state.completing) {
      return null;
    }

    final selectedIds = state.selected.toList(growable: false);
    final service = ref.read(qazaServiceProvider);
    final selectedRecords = await service.resolvePendingRecordsByIds(
      userId: userId,
      recordIds: selectedIds,
    );
    if (selectedRecords.length != selectedIds.length) {
      state = state.copyWith(
        selected: {for (final r in selectedRecords) r.id},
        error: 'Some selected Qaza records are no longer pending.',
      );
      return null;
    }

    final restrictionEvaluations = await ref
        .read(qazaRestrictionServiceProvider)
        .evaluateForPrayers(selectedRecords.map((record) => record.prayerType));
    if (restrictionEvaluations.values.any((evaluation) => evaluation.isRestricted)) {
      state = state.copyWith(clearError: true);
      return null;
    }

    if (!await service.tartib.canCompleteRecordIds(
      userId: userId,
      recordIds: selectedIds,
    )) {
      state = state.copyWith(clearError: true);
      ref.invalidate(sahibAlTartibProvider);
      return null;
    }

    final operation = await ref.read(qazaOperationServiceProvider).begin(
          userId: userId,
          type: QazaOperationType.bulkComplete,
        );
    state = state.copyWith(completing: true, clearError: true);
    try {
      final completedAt = operation.createdAt;
      final completed = await service.completeSelected(
        userId: userId,
        recordIds: selectedIds,
        completedAt: completedAt,
      );
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: completed == selectedIds.length
                ? QazaOperationStatus.completed
                : QazaOperationStatus.partial,
            affectedRecordCount: completed,
          );
      state = state.copyWith(
        completing: false,
        selectionMode: false,
        selected: const <String>{},
      );
      ref.invalidate(sahibAlTartibProvider);
      ref.invalidate(progressSummaryProvider);
      await refresh();
      if (completed == 0) return null;
      return QazaCompletionBatch(
        recordIds: selectedIds,
        completedAt: completedAt,
        count: completed,
      );
    } on QazaTartibViolationException {
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: QazaOperationStatus.failed,
            affectedRecordCount: 0,
            note: 'blocked_by_order',
          );
      state = state.copyWith(completing: false, clearError: true);
      ref.invalidate(sahibAlTartibProvider);
      return null;
    } catch (error) {
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: QazaOperationStatus.failed,
            affectedRecordCount: 0,
            note: error.toString(),
          );
      state = state.copyWith(
        completing: false,
        error: error.toString(),
      );
      return null;
    }
  }

  /// Legacy count-returning wrapper kept for existing controller callers/tests.
  Future<int> completeSelected() async {
    final batch = await completeSelectedWithUndo();
    return batch?.count ?? 0;
  }
}

final qazaTrackerControllerProvider =
    AutoDisposeNotifierProvider<QazaTrackerController, QazaTrackerState>(
  QazaTrackerController.new,
);
