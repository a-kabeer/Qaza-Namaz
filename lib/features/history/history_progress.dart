// Logs & progress.
//
// History rows come from the local SQLite source of truth in bounded keyset
// pages. The progress cards use database aggregates so the History screen does
// not materialize the complete ledger.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/progress_overview_card.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../sync/sync_status_bar.dart';
import 'history_logs_controller.dart';

class HistoryProgressScreen extends ConsumerStatefulWidget {
  const HistoryProgressScreen({super.key});

  @override
  ConsumerState<HistoryProgressScreen> createState() =>
      _HistoryProgressScreenState();
}

class _HistoryProgressScreenState extends ConsumerState<HistoryProgressScreen> {
  PrayerType? _prayerFilter;
  QazaStatus? _statusFilter;
  DateTimeRange? _originalDateFilter;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(historyLogsProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).logsLoadMoreError('$error'))),
      );
    }
  }

  Future<void> _refresh() async {
    await ref.read(historyLogsProvider.notifier).refresh();
    ref.invalidate(historyProgressProvider);
  }

  Future<void> _applyFilters({
    required PrayerType? prayer,
    required QazaStatus? status,
    required DateTime? rangeStart,
    required DateTime? rangeEnd,
  }) async {
    await ref.read(historyLogsProvider.notifier).setFilters(
          prayer: prayer,
          status: status,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  Future<void> _pickOriginalDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDateRange: _originalDateFilter,
      helpText: AppLocalizations.of(context).logsFilterDate,
    );
    if (selected == null) return;

    final normalized = DateTimeRange(
      start: DateTime(
          selected.start.year, selected.start.month, selected.start.day),
      end: DateTime(selected.end.year, selected.end.month, selected.end.day),
    );
    setState(() => _originalDateFilter = normalized);
    unawaited(
      _applyFilters(
        prayer: _prayerFilter,
        status: _statusFilter,
        rangeStart: normalized.start,
        rangeEnd: normalized.end,
      ),
    );
  }

  void _setPrayerFilter(PrayerType? value) {
    setState(() => _prayerFilter = value);
    unawaited(
      _applyFilters(
        prayer: value,
        status: _statusFilter,
        rangeStart: _originalDateFilter?.start,
        rangeEnd: _originalDateFilter?.end,
      ),
    );
  }

  void _setStatusFilter(QazaStatus? value) {
    setState(() => _statusFilter = value);
    unawaited(
      _applyFilters(
        prayer: _prayerFilter,
        status: value,
        rangeStart: _originalDateFilter?.start,
        rangeEnd: _originalDateFilter?.end,
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _prayerFilter = null;
      _statusFilter = null;
      _originalDateFilter = null;
    });
    unawaited(_applyFilters(
        prayer: null, status: null, rangeStart: null, rangeEnd: null));
  }

  String _dateFilterLabel(AppLocalizations l10n) {
    final range = _originalDateFilter;
    if (range == null) return l10n.logsOriginalDateLabel;
    return '${formatAppDate(range.start)} – ${formatAppDate(range.end)}';
  }

  Widget _progressSection(
      ThemeData theme, AsyncValue<QazaProgressSummary> progressAsync) {
    final summary = progressAsync.valueOrNull;
    if (progressAsync.hasError && summary == null) {
      return _InlineError(
        message: AppLocalizations.of(context).logsProgressError,
        onRetry: () => ref.invalidate(historyProgressProvider),
      );
    }
    if (summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressOverviewCard(
          progress: summary.overall,
          header: Text(AppLocalizations.of(context).logsProgressTitle,
              style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 18),
        Text(AppLocalizations.of(context).logsPrayerProgressTitle,
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final prayer in PrayerType.values)
          _PrayerProgressTile(progress: summary.byPrayer[prayer]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(historyLogsProvider);
    final progressAsync = ref.watch(historyProgressProvider);
    final records = history.valueOrNull ?? const <QazaRecord>[];
    final notifier = ref.read(historyLogsProvider.notifier);
    final hasFilters = _prayerFilter != null ||
        _statusFilter != null ||
        _originalDateFilter != null;
    final showRecordSliver = history.hasValue && records.isNotEmpty;
    final showPaginationFooter = notifier.hasMore || notifier.isLoadingMore;

    return AppScaffold(
      title: l10n.logsTitle,
      actions: [
        IconButton(
          tooltip: l10n.logsRefresh,
          onPressed: history.isLoading ? null : _refresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SyncStatusBar(),
                  if (history.isLoading && !history.hasValue)
                    LoadingState(message: l10n.logsLoading, padding: 60)
                  else if (history.hasError && !history.hasValue)
                    ErrorState(message: l10n.logsLoadError, onRetry: _refresh)
                  else ...[
                    if (history.hasError && history.hasValue)
                      _InlineError(
                        message: l10n.logsRefreshError,
                        onRetry: _refresh,
                      ),
                    _progressSection(theme, progressAsync),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child: Text(l10n.logsSectionTitle,
                                style: theme.textTheme.titleLarge)),
                        Text(
                          '${records.length}${notifier.hasMore ? '+' : ''}',
                          key: const Key('history_result_count'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<PrayerType?>(
                                    key: const Key('history_prayer_filter'),
                                    value: _prayerFilter,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.logsFilterPrayer,
                                      prefixIcon:
                                          const Icon(Icons.mosque_rounded),
                                    ),
                                    items: [
                                      DropdownMenuItem<PrayerType?>(
                                          value: null,
                                          child:
                                              Text(l10n.logsFilterAllPrayers)),
                                      ...PrayerType.values.map(
                                        (prayer) =>
                                            DropdownMenuItem<PrayerType?>(
                                          value: prayer,
                                          child: Text(prayer.label),
                                        ),
                                      ),
                                    ],
                                    onChanged: _setPrayerFilter,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<QazaStatus?>(
                                    key: const Key('history_status_filter'),
                                    value: _statusFilter,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.logsFilterStatus,
                                      prefixIcon:
                                          const Icon(Icons.filter_alt_rounded),
                                    ),
                                    items: [
                                      DropdownMenuItem<QazaStatus?>(
                                          value: null,
                                          child: Text(l10n.filterAll)),
                                      DropdownMenuItem<QazaStatus?>(
                                          value: QazaStatus.pending,
                                          child: Text(l10n.statusPending)),
                                      DropdownMenuItem<QazaStatus?>(
                                          value: QazaStatus.completed,
                                          child: Text(l10n.statusCompleted)),
                                    ],
                                    onChanged: _setStatusFilter,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const Key('history_date_filter'),
                                    onPressed: _pickOriginalDateRange,
                                    icon: const Icon(Icons.date_range_rounded),
                                    label: Text(_dateFilterLabel(l10n)),
                                  ),
                                ),
                                if (hasFilters) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    key: const Key('history_clear_filters'),
                                    tooltip: l10n.logsClearFilters,
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.logsOrderNote,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (history.hasValue && records.isEmpty)
                      EmptyState(
                        icon: hasFilters
                            ? Icons.filter_alt_off_rounded
                            : Icons.history_toggle_off_rounded,
                        title: hasFilters
                            ? l10n.logsFilteredEmptyTitle
                            : l10n.logsEmptyTitle,
                        message: hasFilters
                            ? l10n.logsFilteredEmptyMessage
                            : l10n.logsEmptyMessage,
                      ),
                  ],
                ]),
              ),
            ),
            if (showRecordSliver)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < records.length) {
                        final record = records[index];
                        return _HistoryTile(
                            key: ValueKey(record.id), record: record);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: notifier.isLoadingMore
                              ? const CircularProgressIndicator()
                              : Text(l10n.logsScrollForMore,
                                  style: theme.textTheme.bodySmall),
                        ),
                      );
                    },
                    childCount: records.length + (showPaginationFooter ? 1 : 0),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          key: const Key('history_refresh_error'),
          leading: const Icon(Icons.cloud_off_rounded),
          title: Text(message),
          trailing: TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).commonRetry)),
        ),
      );
}

class _PrayerProgressTile extends StatelessWidget {
  const _PrayerProgressTile({required this.progress});
  final PrayerProgress? progress;

  @override
  Widget build(BuildContext context) {
    final item = progress;
    if (item == null) return const SizedBox.shrink();
    final total = item.progress.pending + item.progress.completed;
    final ratio = total == 0 ? 0.0 : item.progress.completed / total;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.mosque_rounded)),
        title: Text(item.prayerType.label),
        subtitle: Text(
            '${item.progress.pending} pending • ${item.progress.completed} completed'),
        trailing: SizedBox(
          width: 82,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(ratio * 100).round()}%'),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: ratio),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.record});
  final QazaRecord record;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(record.status == QazaStatus.completed
                ? Icons.check_rounded
                : Icons.schedule_rounded),
          ),
          title: Text('${record.prayerType.label} Qaza'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)
                  .logsOriginalDateValue(formatAppDate(record.originalDate))),
              Text(
                record.status == QazaStatus.completed
                    ? AppLocalizations.of(context).logsCompletedValue(
                        formatAppDateTime(record.completedAt))
                    : AppLocalizations.of(context).logsStatusPending,
              ),
            ],
          ),
          isThreeLine: true,
        ),
      );
}
