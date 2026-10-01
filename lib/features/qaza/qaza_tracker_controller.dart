import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';
import 'completion/qaza_completion_controller.dart';
import '../prayer_time/application/prayer_time_providers.dart';

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

/// The tracker always uses fixed status-specific ordering.
/// Pending: originalDate ASC, id ASC.
/// Completed: completedAt DESC, id DESC.

class QazaTrackerState {
  const QazaTrackerState({
    this.statusFilter = QazaStatusFilter.pending,
    this.selectionMode = false,
    this.selectingAll = false,
    this.prayerFilter,
    this.from,
    this.to,
    this.additionId,
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

  /// True while the whole filtered ledger is being gathered for selection.
  final bool selectingAll;
  final PrayerType? prayerFilter;
  final DateTime? from;
  final DateTime? to;
  final String? additionId;
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
      prayerFilter != null ||
      from != null ||
      to != null ||
      additionId != null;

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
    bool? selectingAll,
    PrayerType? prayerFilter,
    DateTime? from,
    DateTime? to,
    String? additionId,
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
        selectingAll: selectingAll ?? this.selectingAll,
        prayerFilter:
            clearPrayerFilter ? null : prayerFilter ?? this.prayerFilter,
        from: clearDates ? null : from ?? this.from,
        to: clearDates ? null : to ?? this.to,
        additionId: additionId ?? this.additionId,
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

class QazaTrackerController extends AutoDisposeFamilyNotifier<QazaTrackerState, String?> {
  static const int pageSize = 50;

  late String? _additionId;

  @override
  QazaTrackerState build(String? additionId) {
    _additionId = additionId;
    ref.watch(activeUserIdProvider);
    // The Qaza tab stays mounted once visited, so a second hand-off arrives
    // while this controller is already built and build() never runs again for
    // it. Listening covers those; the read below covers the first one, which
    // is already waiting before this listener exists.
    if (additionId == null) ref.listen<QazaTrackerFilterRequest?>(
      qazaTrackerFilterRequestProvider,
      (_, next) {
        if (next != null) _applyRequest(next);
      },
    );

    final request = additionId == null
        ? ref.read(qazaTrackerFilterRequestProvider)
        : null;
    Future.microtask(refresh);
    if (request == null) return QazaTrackerState(additionId: additionId);
    _consumeRequest(request);
    return QazaTrackerState(
      statusFilter: request.status ?? QazaStatusFilter.pending,
      prayerFilter: request.prayer,
      additionId: additionId,
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

  /// Reads a bounded page using the status-specific fixed ordering.
  Future<QazaPage> _readPage({
    required String userId,
    QazaRecord? after,
  }) {
    final completed = state.statusFilter == QazaStatusFilter.completed;
    return ref.read(qazaServiceProvider).getPage(
          userId: userId,
          limit: pageSize,
          prayerType: state.prayerFilter,
          status: state.statusFilter.status,
          from: state.from,
          to: state.to,
          additionId: _additionId,
          beforeOriginalDate: completed ? null : after?.originalDate,
          beforeId: completed ? null : after?.id,
          beforeCompletedAt: completed ? after?.completedAt : null,
          afterCompletedAt: null,
          descending: false,
        );
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
    state = state.copyWith(
      statusFilter: filter,
      records: const <QazaRecord>[],
      hasMore: false,
      selectionMode: false,
      selected: const <String>{},
      clearError: true,
    );
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
      clearPrayerFilter: true,
      clearDates: true,
      clearError: true,
      selected: const <String>{},
      selectionMode: false,
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
      state = state.copyWith(
          selectionMode: true, selected: ids, selectingAll: false);
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

  /// Permanently deletes a single tracker record and reloads the bounded page.
  Future<void> deleteRecord(String recordId) async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.recordMutating) return;
    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      await ref.read(qazaServiceProvider).deleteRecord(
        userId: userId,
        recordId: recordId,
      );
      ref.invalidate(progressSummaryProvider);
      await refresh();
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  Future<QazaCompletionBatchReceipt?> completeRecordWithUndo(
    String recordId,
  ) async {
    return _completeRecordIdsWithUndo([recordId]);
  }

  Future<QazaCompletionBatchReceipt?> completeSelectedWithUndo() async {
    return _completeRecordIdsWithUndo(
      state.selected.toList(growable: false),
      exitSelectionModeOnSuccess: true,
    );
  }

  Future<QazaCompletionBatchReceipt?> _completeRecordIdsWithUndo(
    List<String> selectedIds, {
    bool exitSelectionModeOnSuccess = false,
  }) async {
    if (ref.read(qazaCompletionRestrictedProvider)) return null;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || selectedIds.isEmpty || state.completing) {
      return null;
    }

    state = state.copyWith(completing: true, clearError: true);
    try {
      final receipt = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecordsWithReceipt(
            userId: userId,
            recordIds: selectedIds,
            completedAt: DateTime.now(),
          );

      if (receipt.result == QazaCompletionResult.blockedByRestrictedTime ||
          receipt.entries.isEmpty) {
        state = state.copyWith(completing: false);
        return null;
      }

      state = state.copyWith(
        completing: false,
        selectionMode:
            exitSelectionModeOnSuccess ? false : state.selectionMode,
        selected:
            exitSelectionModeOnSuccess ? const <String>{} : state.selected,
      );
      ref.invalidate(sahibAlTartibProvider);
      ref.invalidate(progressSummaryProvider);
      for (final prayer in ref.read(enabledPrayerTypesProvider)) {
        ref.invalidate(oldestPendingProvider(prayer));
      }
      await refresh();
      return receipt;
    } on QazaTartibViolationException {
      state = state.copyWith(completing: false, clearError: true);
      ref.invalidate(sahibAlTartibProvider);
      return null;
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.qazaCompletion,
            'tracker_completion_failed',
            error,
            stack: stack,
          );
      state = state.copyWith(
        completing: false,
        error: error.toString(),
      );
      return null;
    }
  }

  Future<bool> markCompletedAsPending(String recordId) async {
    if (recordId.isEmpty || state.recordMutating) return false;
    final index = state.records.indexWhere((record) => record.id == recordId);
    if (index < 0 || state.records[index].status != QazaStatus.completed) {
      return false;
    }

    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      final changed = await ref.read(qazaServiceProvider).markCompletedAsPending(
            userId: ref.read(requiredUserIdProvider),
            recordId: recordId,
          );
      if (changed) {
        ref.invalidate(progressSummaryProvider);
        for (final prayer in ref.read(enabledPrayerTypesProvider)) {
          ref.invalidate(oldestPendingProvider(prayer));
        }
        ref.invalidate(sahibAlTartibProvider);
        await refresh();
      }
      return changed;
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.qazaCompletion,
            'mark_completed_pending_failed',
            error,
            stack: stack,
          );
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  Future<int> deleteSelected() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.selected.isEmpty || state.recordMutating) {
      return 0;
    }
    final ids = state.selected.toList(growable: false);
    state = state.copyWith(recordMutating: true, clearError: true);
    try {
      var count = 0;
      for (final id in ids) {
        await ref.read(qazaServiceProvider).deleteRecord(
          userId: userId,
          recordId: id,
        );
        count++;
      }
      exitSelectionMode();
      ref.invalidate(progressSummaryProvider);
      await refresh();
      return count;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return 0;
    } finally {
      state = state.copyWith(recordMutating: false);
    }
  }

  Future<QazaCompletionBatchReceipt?> completeRecordWithUndo(
    String recordId,
  ) async {
    return _completeRecordIdsWithUndo([recordId]);
  }

  Future<QazaCompletionBatchReceipt?> completeSelectedWithUndo() async {
    return _completeRecordIdsWithUndo(
      state.selected.toList(growable: false),
      exitSelectionModeOnSuccess: true,
    );
  }

  Future<QazaCompletionBatchReceipt?> _completeRecordIdsWithUndo(
    List<String> selectedIds, {
    bool exitSelectionModeOnSuccess = false,
  }) async {
    if (ref.read(qazaCompletionRestrictedProvider)) return null;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || selectedIds.isEmpty || state.completing) {
      return null;
    }

    state = state.copyWith(completing: true, clearError: true);
    try {
      final receipt = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecordsWithReceipt(
            userId: userId,
            recordIds: selectedIds,
            completedAt: DateTime.now(),
          );

      if (receipt.result == QazaCompletionResult.blockedByRestrictedTime ||
          receipt.entries.isEmpty) {
        state = state.copyWith(completing: false);
        return null;
      }

      state = state.copyWith(
        completing: false,
        selectionMode:
            exitSelectionModeOnSuccess ? false : state.selectionMode,
        selected:
            exitSelectionModeOnSuccess ? const <String>{} : state.selected,
      );
      ref.invalidate(sahibAlTartibProvider);
      ref.invalidate(progressSummaryProvider);
      for (final prayer in ref.read(enabledPrayerTypesProvider)) {
        ref.invalidate(oldestPendingProvider(prayer));
      }
      await refresh();
      return receipt;
    } on QazaTartibViolationException {
      state = state.copyWith(completing: false, clearError: true);
      ref.invalidate(sahibAlTartibProvider);
      return null;
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.qazaCompletion,
            'tracker_completion_failed',
            error,
            stack: stack,
          );
      state = state.copyWith(
        completing: false,
        error: error.toString(),
      );
      return null;
    }
  }

  /// Legacy count-returning wrapper kept for older callers/tests.
  Future<int> completeSelected() async {
    final batch = await completeSelectedWithUndo();
    return batch?.count ?? 0;
  }

final qazaTrackerControllerProvider =
    AutoDisposeNotifierProviderFamily<QazaTrackerController, QazaTrackerState, String?>(
  QazaTrackerController.new,
);
