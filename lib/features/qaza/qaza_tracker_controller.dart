import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/entities/qaza_record.dart';

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
class QazaTrackerState {
  const QazaTrackerState({
    this.statusFilter = QazaStatusFilter.pending,
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

  bool get isEmpty => records.isEmpty && !loading && error == null;

  QazaTrackerState copyWith({
    QazaStatusFilter? statusFilter,
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
    bool clearPrayerFilter = false,
    bool clearDates = false,
    bool clearError = false,
  }) =>
      QazaTrackerState(
        statusFilter: statusFilter ?? this.statusFilter,
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
      final page = await ref.read(qazaServiceProvider).getPage(
            userId: userId,
            limit: pageSize,
            prayerType: state.prayerFilter,
            status: state.statusFilter.status,
            from: state.from,
            to: state.to,
          );
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

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final userId = ref.read(activeUserIdProvider);
    final last = state.records.isEmpty ? null : state.records.last;
    if (userId == null || last == null) return;

    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref.read(qazaServiceProvider).getPage(
            userId: userId,
            limit: pageSize,
            prayerType: state.prayerFilter,
            status: state.statusFilter.status,
            from: state.from,
            to: state.to,
            afterOriginalDate: last.originalDate,
            afterId: last.id,
          );
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

  void toggleSelection(String recordId) {
    final next = Set<String>.of(state.selected);
    if (!next.remove(recordId)) next.add(recordId);
    state = state.copyWith(selected: next);
  }

  /// Selection is bounded to the records actually loaded, never the ledger.
  void selectAllLoaded() => state = state.copyWith(
        selected: {for (final record in state.selectableRecords) record.id},
      );

  void clearSelection() => state = state.copyWith(selected: const <String>{});

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

  /// Completes the selected records in one repository call. Repeat taps are
  /// rejected while in flight and the service is idempotent.
  Future<int> completeSelected() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null || state.selected.isEmpty || state.completing) return 0;

    state = state.copyWith(completing: true, clearError: true);
    try {
      final completed = await ref.read(qazaServiceProvider).completeSelected(
            userId: userId,
            recordIds: state.selected.toList(),
          );
      state = state.copyWith(completing: false);
      ref.invalidate(progressSummaryProvider);
      await refresh();
      return completed;
    } catch (error) {
      state = state.copyWith(
        completing: false,
        error: error.toString(),
      );
      return 0;
    }
  }
}

final qazaTrackerControllerProvider =
    AutoDisposeNotifierProvider<QazaTrackerController, QazaTrackerState>(
  QazaTrackerController.new,
);
