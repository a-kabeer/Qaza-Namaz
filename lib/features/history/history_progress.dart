// Logs & progress.
//
// Step 6 connects the history UI to the dedicated paginated controller.
// Progress summaries still use the existing ledger providers until the
// statistics optimization step; the log browser itself only loads pages.

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
import '../sync/sync_status_bar.dart';
import 'history_controller.dart';
import 'history_query.dart';

class HistoryProgressScreen extends ConsumerStatefulWidget {
  const HistoryProgressScreen({super.key});

  @override
  ConsumerState<HistoryProgressScreen> createState() => _HistoryProgressScreenState();
}

class _HistoryProgressScreenState extends ConsumerState<HistoryProgressScreen> {
  bool _showPrayerProgress = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(historyControllerProvider.notifier).refresh(),
      ref.read(qazaRecordsProvider.notifier).refresh(),
    ]);
  }

  Future<void> _pickOriginalDateRange(HistoryQuery query) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDateRange: query.originalDateRange,
      helpText: 'Filter by original Qaza date',
    );
    if (selected == null || !mounted) return;
    final normalized = DateTimeRange(
      start: DateTime(selected.start.year, selected.start.month, selected.start.day),
      end: DateTime(selected.end.year, selected.end.month, selected.end.day),
    );
    await ref.read(historyControllerProvider.notifier).setQuery(
          query.copyWith(originalDateRange: normalized),
        );
  }

  Future<void> _setPrayerFilter(HistoryQuery query, PrayerType? prayer) =>
      ref.read(historyControllerProvider.notifier).setQuery(query.copyWith(prayer: prayer));

  Future<void> _setStatusFilter(HistoryQuery query, QazaStatus? status) =>
      ref.read(historyControllerProvider.notifier).setQuery(query.copyWith(status: status));

  Future<void> _clearFilters(HistoryQuery query) =>
      ref.read(historyControllerProvider.notifier).setQuery(query.clearFilters());

  Future<void> _retryLoadMore() async {
    ref.read(historyControllerProvider.notifier).clearLoadMoreError();
    await ref.read(historyControllerProvider.notifier).loadMore();
  }

  String _dateFilterLabel(DateTimeRange? range) {
    if (range == null) return 'Date';
    return '${formatAppDate(range.start)} – ${formatAppDate(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyControllerProvider);
    final ledger = ref.watch(qazaRecordsProvider);
    final progress = ref.watch(overallProgressProvider);
    final prayerProgress = ref.watch(prayerProgressProvider);
    final historyState = history.valueOrNull;
    final total = progress.pending + progress.completed;

    return AppScaffold(
      title: 'Logs & Progress',
      actions: [
        IconButton(
          tooltip: 'Refresh logs',
          onPressed: historyState?.isRefreshing == true ? null : _refresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: SyncStatusBar()),
            ),
            if (historyState == null && history.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(message: 'Loading your history...', padding: 60),
              )
            else if (historyState == null && history.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(message: 'We could not load your history.', onRetry: _refresh),
              )
            else if (historyState != null) ...[
              if (history.hasError)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _InlineError(message: 'We could not refresh the latest history.', onRetry: _refresh),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ProgressOverviewCard(
                    progress: progress,
                    header: Text('Progress', style: theme.textTheme.titleMedium),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          key: const Key('history_prayer_progress_toggle'),
                          leading: const Icon(Icons.bar_chart_rounded),
                          title: const Text('Prayer progress'),
                          subtitle: Text(total == 0 ? 'No Qaza records yet' : '$total total • ${progress.pending} pending • ${progress.completed} completed'),
                          trailing: Icon(_showPrayerProgress ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                          onTap: () => setState(() => _showPrayerProgress = !_showPrayerProgress),
                        ),
                        if (_showPrayerProgress)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(children: [for (final prayer in PrayerType.values) _PrayerProgressTile(progress: prayerProgress[prayer])]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _HistoryHeader(
                    query: historyState.query,
                    loadedCount: historyState.records.length,
                    onPrayerChanged: (value) => _setPrayerFilter(historyState.query, value),
                    onStatusChanged: (value) => _setStatusFilter(historyState.query, value),
                    onDatePressed: () => _pickOriginalDateRange(historyState.query),
                    onClear: historyState.query.hasFilters ? () => _clearFilters(historyState.query) : null,
                    dateLabel: _dateFilterLabel(historyState.query.originalDateRange),
                  ),
                ),
              ),
              if (historyState.records.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: EmptyState(
                      icon: historyState.query.hasFilters ? Icons.filter_alt_off_rounded : Icons.history_toggle_off_rounded,
                      title: historyState.query.hasFilters ? 'No matching Qaza records.' : 'No Qaza records yet.',
                      message: historyState.query.hasFilters ? 'Try changing or clearing the filters.' : 'Your Qaza records will appear here in chronological order.',
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _HistoryTile(
                        key: ValueKey(historyState.records[index].id),
                        record: historyState.records[index],
                      ),
                      childCount: historyState.records.length,
                    ),
                  ),
                ),
                if (historyState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (historyState.loadMoreError != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _InlineError(message: 'Could not load more logs.', onRetry: _retryLoadMore),
                    ),
                  ),
                if (!historyState.hasMore && historyState.records.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      child: Center(child: Text('You have reached the end of the logs.', style: theme.textTheme.bodySmall)),
                    ),
                  ),
                if (historyState.hasMore && !historyState.isLoadingMore && historyState.loadMoreError == null)
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.query,
    required this.loadedCount,
    required this.onPrayerChanged,
    required this.onStatusChanged,
    required this.onDatePressed,
    required this.onClear,
    required this.dateLabel,
  });

  final HistoryQuery query;
  final int loadedCount;
  final ValueChanged<PrayerType?> onPrayerChanged;
  final ValueChanged<QazaStatus?> onStatusChanged;
  final VoidCallback onDatePressed;
  final VoidCallback? onClear;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text('Qaza logs', style: theme.textTheme.titleLarge)),
            Text('$loadedCount loaded', key: const Key('history_result_count'), style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text(query.sortOrder == HistorySortOrder.newestFirst ? 'Newest original Qaza dates first' : 'Oldest original Qaza dates first', style: theme.textTheme.bodySmall),
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
                        value: query.prayer,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_rounded)),
                        items: [
                          const DropdownMenuItem<PrayerType?>(value: null, child: Text('All prayers')),
                          ...PrayerType.values.map((prayer) => DropdownMenuItem<PrayerType?>(value: prayer, child: Text(prayer.label))),
                        ],
                        onChanged: onPrayerChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<QazaStatus?>(
                        key: const Key('history_status_filter'),
                        value: query.status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.filter_alt_rounded)),
                        items: const [
                          DropdownMenuItem<QazaStatus?>(value: null, child: Text('All')),
                          DropdownMenuItem<QazaStatus?>(value: QazaStatus.pending, child: Text('Pending')),
                          DropdownMenuItem<QazaStatus?>(value: QazaStatus.completed, child: Text('Completed')),
                        ],
                        onChanged: onStatusChanged,
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
                        onPressed: onDatePressed,
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(dateLabel),
                      ),
                    ),
                    if (onClear != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('history_clear_filters'),
                        tooltip: 'Clear filters',
                        onPressed: onClear,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    ],
                  ],
                ),
                if (query.hasFilters) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (query.prayer != null) Chip(label: Text(query.prayer!.label)),
                        if (query.status != null) Chip(label: Text(query.status == QazaStatus.pending ? 'Pending' : 'Completed')),
                        if (query.originalDateRange != null) Chip(label: Text(dateLabel)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
          trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.mosque_rounded)),
        title: Text(item.prayerType.label),
        subtitle: Text('${item.progress.pending} pending • ${item.progress.completed} completed'),
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
          leading: CircleAvatar(child: Icon(record.status == QazaStatus.completed ? Icons.check_rounded : Icons.schedule_rounded)),
          title: Text('${record.prayerType.label} Qaza'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Original Qaza date: ${formatAppDate(record.originalDate)}'),
              Text(record.status == QazaStatus.completed ? 'Completed: ${formatAppDateTime(record.completedAt)}' : 'Status: Pending'),
            ],
          ),
          isThreeLine: true,
        ),
      );
}
