import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/entities/qaza_record.dart';
import 'history_query.dart';

class HistoryState {
  const HistoryState({
    required this.records,
    required this.query,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.loadMoreError,
    this.refreshError,
  });

  final List<QazaRecord> records;
  final HistoryQuery query;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? loadMoreError;
  final Object? refreshError;

  HistoryState copyWith({
    List<QazaRecord>? records,
    HistoryQuery? query,
    Object? nextCursor = _keep,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? loadMoreError = _keep,
    Object? refreshError = _keep,
  }) {
    return HistoryState(
      records: records ?? this.records,
      query: query ?? this.query,
      nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadMoreError: identical(loadMoreError, _keep) ? this.loadMoreError : loadMoreError,
      refreshError: identical(refreshError, _keep) ? this.refreshError : refreshError,
    );
  }
}

const _keep = Object();

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(HistoryController.new);

class HistoryController extends AsyncNotifier<HistoryState> {
  static const _pageSize = 25;

  @override
  Future<HistoryState> build() => _loadPage(const HistoryQuery());

  Future<void> setQuery(HistoryQuery query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadPage(query));
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      state = await AsyncValue.guard(() => _loadPage(const HistoryQuery()));
      return;
    }

    state = AsyncData(current.copyWith(isRefreshing: true, refreshError: null));
    try {
      final refreshed = await _loadPage(current.query);
      state = AsyncData(refreshed.copyWith(isRefreshing: false));
    } catch (error) {
      state = AsyncData(current.copyWith(isRefreshing: false, refreshError: error));
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final cursor = current.nextCursor;
    if (cursor == null) return;

    state = AsyncData(current.copyWith(isLoadingMore: true, loadMoreError: null));
    try {
      final page = await _fetchPage(current.query, cursor: cursor);
      final existingIds = current.records.map((record) => record.id).toSet();
      final appended = [
        ...current.records,
        ...page.records.where((record) => existingIds.add(record.id)),
      ];
      state = AsyncData(
        current.copyWith(
          records: List.unmodifiable(appended),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: error,
        ),
      );
    }
  }

  void clearLoadMoreError() {
    final current = state.valueOrNull;
    if (current == null || current.loadMoreError == null) return;
    state = AsyncData(current.copyWith(loadMoreError: null));
  }

  Future<HistoryState> _loadPage(HistoryQuery query) async {
    final page = await _fetchPage(query);
    return HistoryState(
      records: page.records,
      query: query,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<QazaHistoryPage> _fetchPage(
    HistoryQuery query, {
    String? cursor,
  }) {
    return ref.read(qazaRepositoryProvider).getHistoryPage(
          userId: ref.read(currentUserIdProvider),
          prayerType: query.prayer,
          status: query.status,
          originalDateFrom: query.originalDateRange?.start,
          originalDateTo: query.originalDateRange?.end,
          cursor: cursor,
          limit: _pageSize,
          ascending: query.sortOrder == HistorySortOrder.oldestFirst,
        );
  }
}
