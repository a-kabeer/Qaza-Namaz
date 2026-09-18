import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';

class HistoryLogsNotifier extends AsyncNotifier<List<QazaRecord>> {
  static const int pageSize = 50;

  PrayerType? prayerFilter;
  QazaStatus? statusFilter;
  DateTime? from;
  DateTime? to;

  DateTime? _beforeOriginalDate;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _requestGeneration = 0;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  @override
  Future<List<QazaRecord>> build() async {
    final generation = ++_requestGeneration;
    _resetCursor();
    final userId = ref.watch(activeUserIdProvider);
    final prayer = prayerFilter;
    final status = statusFilter;
    final rangeStart = from;
    final rangeEnd = to;
    if (userId == null) return const <QazaRecord>[];

    final page = await ref.read(qazaServiceProvider).getHistoryPage(
          userId: userId,
          limit: pageSize,
          prayerType: prayer,
          status: status,
          from: rangeStart,
          to: rangeEnd,
        );
    if (generation != _requestGeneration) return const <QazaRecord>[];
    _setCursor(page);
    return page.records;
  }

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    final userId = ref.read(activeUserIdProvider);
    final prayer = prayerFilter;
    final status = statusFilter;
    final rangeStart = from;
    final rangeEnd = to;
    final previous = state.valueOrNull;
    _resetCursor();

    if (userId == null) {
      state = const AsyncData(<QazaRecord>[]);
      return;
    }

    if (previous == null) {
      state = const AsyncLoading();
    }

    try {
      final page = await ref.read(qazaServiceProvider).getHistoryPage(
            userId: userId,
            limit: pageSize,
            prayerType: prayer,
            status: status,
            from: rangeStart,
            to: rangeEnd,
          );
      if (generation != _requestGeneration) return;
      _setCursor(page);
      state = AsyncData(page.records);
    } catch (error, stackTrace) {
      if (generation != _requestGeneration) return;
      if (previous == null) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncValue<List<QazaRecord>>.error(error, stackTrace)
            .copyWithPrevious(AsyncData<List<QazaRecord>>(previous));
      }
    }
  }

  Future<void> setFilters({
    PrayerType? prayer,
    QazaStatus? status,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    prayerFilter = prayer;
    statusFilter = status;
    from = rangeStart;
    to = rangeEnd;
    await refresh();
  }

  Future<void> clearFilters() async {
    prayerFilter = null;
    statusFilter = null;
    from = null;
    to = null;
    await refresh();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;

    final generation = _requestGeneration;
    final beforeOriginalDate = _beforeOriginalDate;
    final beforeId = _beforeId;
    final prayer = prayerFilter;
    final status = statusFilter;
    final rangeStart = from;
    final rangeEnd = to;
    final current = state.valueOrNull ?? const <QazaRecord>[];
    _loadingMore = true;

    try {
      final page = await ref.read(qazaServiceProvider).getHistoryPage(
            userId: userId,
            limit: pageSize,
            prayerType: prayer,
            status: status,
            from: rangeStart,
            to: rangeEnd,
            beforeOriginalDate: beforeOriginalDate,
            beforeId: beforeId,
          );
      if (generation != _requestGeneration) return;

      final existingIds = current.map((record) => record.id).toSet();
      final appended =
          page.records.where((record) => existingIds.add(record.id));
      _setCursor(page);
      state = AsyncData([...current, ...appended]);
    } catch (error, stackTrace) {
      if (generation != _requestGeneration) return;
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (generation == _requestGeneration) {
        _loadingMore = false;
      }
    }
  }

  void _resetCursor() {
    _beforeOriginalDate = null;
    _beforeId = null;
    _hasMore = false;
    _loadingMore = false;
  }

  void _setCursor(QazaHistoryPage page) {
    _hasMore = page.hasMore;
    _beforeOriginalDate = page.nextOriginalDate;
    _beforeId = page.nextId;
  }
}

final historyLogsProvider =
    AsyncNotifierProvider<HistoryLogsNotifier, List<QazaRecord>>(
  HistoryLogsNotifier.new,
);
