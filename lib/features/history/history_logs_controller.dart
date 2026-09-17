import 'dart:async';

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
    if (userId == null) return const <QazaRecord>[];

    final page = await ref.read(qazaServiceProvider).getHistoryPage(
          userId: userId,
          limit: pageSize,
          prayerType: prayerFilter,
          status: statusFilter,
          from: from,
          to: to,
        );
    if (generation != _requestGeneration) return const <QazaRecord>[];
    _setCursor(page);
    return page.records;
  }

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      _resetCursor();
      state = const AsyncData(<QazaRecord>[]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _resetCursor();
      final page = await ref.read(qazaServiceProvider).getHistoryPage(
            userId: userId,
            limit: pageSize,
            prayerType: prayerFilter,
            status: statusFilter,
            from: from,
            to: to,
          );
      if (generation != _requestGeneration) return const <QazaRecord>[];
      _setCursor(page);
      return page.records;
    });
  }

  Future<void> setFilters({PrayerType? prayer, QazaStatus? status, DateTime? rangeStart, DateTime? rangeEnd}) async {
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

    _loadingMore = true;
    final current = state.valueOrNull ?? const <QazaRecord>[];
    try {
      final page = await ref.read(qazaServiceProvider).getHistoryPage(
            userId: userId,
            limit: pageSize,
            prayerType: prayerFilter,
            status: statusFilter,
            from: from,
            to: to,
            beforeOriginalDate: _beforeOriginalDate,
            beforeId: _beforeId,
          );
      final existingIds = current.map((record) => record.id).toSet();
      final appended = page.records.where((record) => existingIds.add(record.id));
      _setCursor(page);
      state = AsyncData([...current, ...appended]);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _loadingMore = false;
    }
  }

  void _resetCursor() {
    _beforeOriginalDate = null;
    _beforeId = null;
    _hasMore = false;
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
