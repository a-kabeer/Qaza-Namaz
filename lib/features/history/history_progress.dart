// Logs & progress.
// Step 10: progress summary is queried from the local database instead of loading the ledger.

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
  final ScrollController _scrollController = ScrollController();
  bool _showPrayerProgress = false;

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ref.read(historyControllerProvider.notifier).refresh();
    ref.invalidate(qazaLedgerSummaryProvider);
    await ref.read(qazaLedgerSummaryProvider.future);
  }

  Future<void> _setQuery(HistoryQuery query) => ref.read(historyControllerProvider.notifier).setQuery(query);

  Future<void> _pickDateRange(HistoryQuery query) async {
    final selected = await showDateRangePicker(context: context, firstDate: DateTime(1950), lastDate: DateTime.now(), initialDateRange: query.originalDateRange, helpText: 'Filter by original Qaza date');
    if (selected == null || !mounted) return;
    await _setQuery(query.copyWith(originalDateRange: DateTimeRange(start: DateTime(selected.start.year, selected.start.month, selected.start.day), end: DateTime(selected.end.year, selected.end.month, selected.end.day))));
  }

  String _dateLabel(DateTimeRange? range) => range == null ? 'Date' : '${formatAppDate(range.start)} – ${formatAppDate(range.end)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyControllerProvider);
    final summary = ref.watch(qazaLedgerSummaryProvider);
    final data = history.valueOrNull;
    final summaryValue = summary.valueOrNull;
    final progress = QazaProgress(pending: summaryValue?.pending ?? 0, completed: summaryValue?.completed ?? 0);
    final total = progress.pending + progress.completed;

    return AppScaffold(
      title: 'Logs & Progress',
      actions: [IconButton(tooltip: 'Refresh logs', onPressed: data?.isRefreshing == true ? null : _refresh, icon: const Icon(Icons.sync_rounded))],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), sliver: SliverToBoxAdapter(child: SyncStatusBar())),
            if (data == null && history.isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: LoadingState(message: 'Loading your history...', padding: 60))
            else if (data == null && history.hasError)
              SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: 'We could not load your history.', onRetry: _refresh))
            else if (data != null) ...[
              if (data.refreshError != null)
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), sliver: SliverToBoxAdapter(child: _InlineError(message: 'Could not refresh the latest history.', onRetry: _refresh))),
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), sliver: SliverToBoxAdapter(child: summary.hasError ? const SizedBox.shrink() : ProgressOverviewCard(progress: progress, header: Text('Progress', style: theme.textTheme.titleMedium)))),
              if (summary.hasError)
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), sliver: SliverToBoxAdapter(child: _InlineError(message: 'Could not load progress summary.', onRetry: _refresh))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Card(child: Column(children: [
                    ListTile(
                      key: const Key('history_prayer_progress_toggle'),
                      leading: const Icon(Icons.bar_chart_rounded),
                      title: const Text('Prayer progress'),
                      subtitle: Text(total == 0 ? 'No Qaza records yet' : '$total total • ${progress.pending} pending • ${progress.completed} completed'),
                      trailing: Icon(_showPrayerProgress ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                      onTap: () => setState(() => _showPrayerProgress = !_showPrayerProgress),
                    ),
                    if (_showPrayerProgress && summaryValue != null)
                      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(children: [for (final p in PrayerType.values) _PrayerProgressTile(prayerType: p, progress: summaryValue.byPrayer[p])])),
                  ])),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _HistoryHeader(query: data.query, loadedCount: data.records.length, dateLabel: _dateLabel(data.query.originalDateRange), onPrayerChanged: (v) => _setQuery(data.query.copyWith(prayer: v)), onStatusChanged: (v) => _setQuery(data.query.copyWith(status: v)), onDatePressed: () => _pickDateRange(data.query), onClear: data.query.hasFilters ? () => _setQuery(data.query.clearFilters()) : null),
                ),
              ),
              if (data.records.isEmpty)
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 28), sliver: SliverToBoxAdapter(child: EmptyState(icon: data.query.hasFilters ? Icons.filter_alt_off_rounded : Icons.history_toggle_off_rounded, title: data.query.hasFilters ? 'No matching Qaza records.' : 'No Qaza records yet.', message: data.query.hasFilters ? 'Try changing or clearing the filters.' : 'Your Qaza records will appear here.')))
              else ...[
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _HistoryTile(key: ValueKey(data.records[index].id), record: data.records[index]), childCount: data.records.length))),
                if (data.isLoadingMore) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))),
                if (data.loadMoreError != null) SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), sliver: SliverToBoxAdapter(child: _InlineError(message: 'Could not load more logs.', onRetry: () => ref.read(historyControllerProvider.notifier).loadMore()))),
                if (!data.hasMore) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), child: Center(child: Text('You have reached the end of the logs.', style: theme.textTheme.bodySmall)))),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.query, required this.loadedCount, required this.dateLabel, required this.onPrayerChanged, required this.onStatusChanged, required this.onDatePressed, required this.onClear});
  final HistoryQuery query;
  final int loadedCount;
  final String dateLabel;
  final ValueChanged<PrayerType?> onPrayerChanged;
  final ValueChanged<QazaStatus?> onStatusChanged;
  final VoidCallback onDatePressed;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Qaza logs', style: Theme.of(context).textTheme.titleLarge)), Text('$loadedCount loaded', key: const Key('history_result_count'), style: Theme.of(context).textTheme.labelLarge)]),
        const SizedBox(height: 4),
        Text(query.sortOrder == HistorySortOrder.newestFirst ? 'Newest original Qaza dates first' : 'Oldest original Qaza dates first', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            Expanded(child: DropdownButtonFormField<PrayerType?>(key: const Key('history_prayer_filter'), value: query.prayer, isExpanded: true, decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_rounded)), items: [const DropdownMenuItem<PrayerType?>(value: null, child: Text('All prayers')), ...PrayerType.values.map((p) => DropdownMenuItem<PrayerType?>(value: p, child: Text(p.label)))], onChanged: onPrayerChanged)),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<QazaStatus?>(key: const Key('history_status_filter'), value: query.status, isExpanded: true, decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.filter_alt_rounded)), items: const [DropdownMenuItem<QazaStatus?>(value: null, child: Text('All')), DropdownMenuItem<QazaStatus?>(value: QazaStatus.pending, child: Text('Pending')), DropdownMenuItem<QazaStatus?>(value: QazaStatus.completed, child: Text('Completed'))], onChanged: onStatusChanged)),
          ]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(key: const Key('history_date_filter'), onPressed: onDatePressed, icon: const Icon(Icons.date_range_rounded), label: Text(dateLabel))), if (onClear != null) ...[const SizedBox(width: 8), IconButton(key: const Key('history_clear_filters'), tooltip: 'Clear filters', onPressed: onClear, icon: const Icon(Icons.clear_rounded))]]),
          if (query.hasFilters) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, children: [if (query.prayer != null) Chip(label: Text(query.prayer!.label)), if (query.status != null) Chip(label: Text(query.status == QazaStatus.pending ? 'Pending' : 'Completed')), if (query.originalDateRange != null) Chip(label: Text(dateLabel))]))],
        ]))),
      ]);
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(key: const Key('history_refresh_error'), leading: const Icon(Icons.cloud_off_rounded), title: Text(message), trailing: TextButton(onPressed: onRetry, child: const Text('Retry'))));
}

class _PrayerProgressTile extends StatelessWidget {
  const _PrayerProgressTile({required this.prayerType, required this.progress});
  final PrayerType prayerType;
  final QazaProgress? progress;
  @override
  Widget build(BuildContext context) {
    final item = progress ?? const QazaProgress(pending: 0, completed: 0);
    final total = item.pending + item.completed;
    final ratio = total == 0 ? 0.0 : item.completed / total;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.mosque_rounded)), title: Text(prayerType.label), subtitle: Text('${item.pending} pending • ${item.completed} completed'), trailing: SizedBox(width: 82, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${(ratio * 100).round()}%'), const SizedBox(height: 4), LinearProgressIndicator(value: ratio)]))));
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.record});
  final QazaRecord record;
  @override
  Widget build(BuildContext context) {
    final completed = record.status == QazaStatus.completed;
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: CircleAvatar(radius: 18, child: Icon(completed ? Icons.check_rounded : Icons.schedule_rounded, size: 19)), title: Text(record.prayerType.label, style: Theme.of(context).textTheme.titleSmall), subtitle: Text(formatAppDate(record.originalDate)), trailing: _StatusBadge(completed: completed), onTap: () => _showHistoryDetail(context, record)));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});
  final bool completed;
  @override
  Widget build(BuildContext context) {
    final color = completed ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(completed ? 'Completed' : 'Pending', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)));
  }
}

void _showHistoryDetail(BuildContext context, QazaRecord record) {
  final completed = record.status == QazaStatus.completed;
  showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(child: Icon(completed ? Icons.check_rounded : Icons.schedule_rounded)), const SizedBox(width: 12), Expanded(child: Text('${record.prayerType.label} Qaza', style: Theme.of(context).textTheme.titleLarge)), _StatusBadge(completed: completed)]), const SizedBox(height: 20), _DetailRow(label: 'Original Qaza date', value: formatAppDate(record.originalDate), icon: Icons.event_rounded), const SizedBox(height: 12), _DetailRow(label: 'Status', value: completed ? 'Completed' : 'Pending', icon: completed ? Icons.check_circle_rounded : Icons.schedule_rounded), if (completed && record.completedAt != null) ...[const SizedBox(height: 12), _DetailRow(label: 'Completed', value: formatAppDateTime(record.completedAt), icon: Icons.task_alt_rounded)]]))));
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 2), SelectableText(value, style: Theme.of(context).textTheme.bodyLarge)]))]);
}
