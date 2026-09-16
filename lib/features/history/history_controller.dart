import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/qaza_record.dart';
import 'history_query.dart';

class HistoryState {
  const HistoryState({
    required this.records,
    required this.query,
    this.isRefreshing = false,
  });

  final List<QazaRecord> records;
  final HistoryQuery query;
  final bool isRefreshing;

  HistoryState copyWith({
    List<QazaRecord>? records,
    HistoryQuery? query,
    bool? isRefreshing,
  }) {
    return HistoryState(
      records: records ?? this.records,
      query: query ?? this.query,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(HistoryController.new);

class HistoryController extends AsyncNotifier<HistoryState> {
  @override
  Future<HistoryState> build() async {
    final records = await ref.read(qazaServiceProvider).getRecords(
          userId: ref.read(currentUserIdProvider),
        );
    return _stateFor(records, const HistoryQuery());
  }

  Future<void> setQuery(HistoryQuery query) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(_stateFor(current.records, query));
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final records = await ref.read(qazaServiceProvider).getRecords(
            userId: ref.read(currentUserIdProvider),
          );
      return _stateFor(records, query);
    });
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }

    state = await AsyncValue.guard(() async {
      final records = await ref.read(qazaServiceProvider).getRecords(
            userId: ref.read(currentUserIdProvider),
          );
      final query = current?.query ?? const HistoryQuery();
      return _stateFor(records, query);
    });
  }

  HistoryState _stateFor(List<QazaRecord> source, HistoryQuery query) {
    final records = source.where((record) {
      if (query.prayer != null && record.prayerType != query.prayer) return false;
      if (query.status != null && record.status != query.status) return false;
      final range = query.originalDateRange;
      if (range != null) {
        final date = DateTime(
          record.originalDate.year,
          record.originalDate.month,
          record.originalDate.day,
        );
        if (date.isBefore(range.start) || date.isAfter(range.end)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byOriginal = query.sortOrder == HistorySortOrder.newestFirst
            ? b.originalDate.compareTo(a.originalDate)
            : a.originalDate.compareTo(b.originalDate);
        if (byOriginal != 0) return byOriginal;
        final aCompleted = a.completedAt;
        final bCompleted = b.completedAt;
        if (aCompleted == null && bCompleted == null) return a.id.compareTo(b.id);
        if (aCompleted == null) return 1;
        if (bCompleted == null) return -1;
        final byCompleted = query.sortOrder == HistorySortOrder.newestFirst
            ? bCompleted.compareTo(aCompleted)
            : aCompleted.compareTo(bCompleted);
        return byCompleted != 0 ? byCompleted : a.id.compareTo(b.id);
      });

    return HistoryState(records: List.unmodifiable(records), query: query);
  }
}
