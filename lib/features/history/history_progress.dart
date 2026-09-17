// Logs & progress.
//
// History rows are loaded from the local SQLite source of truth in bounded
// keyset pages. Progress cards remain separate derived views for now and will
// be optimized in the statistics phase.

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
import '../sync/sync_status_bar.dart';
import 'history_logs_controller.dart';

class HistoryProgressScreen extends ConsumerStatefulWidget {
  const HistoryProgressScreen({super.key});

  @override
  ConsumerState<HistoryProgressScreen> createState() => _HistoryProgressScreenState();
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
        SnackBar(content: Text('Could not load more history: $error')),
      );
    }
  }

  Future<void> _refresh() async {
    await ref.read(historyLogsProvider.notifier).refresh();
  }

  Future<void> _pickOriginalDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDateRange: _originalDateFilter,
      helpText: 'Filter by original Qaza date',
    );
    if (selected == null) return;

    final normalized = DateTimeRange(
      start: DateTime(selected.start.year, selected.start.month, selected.start.day),
      end: DateTime(selected.end.year, selected.end.month, selected.end.day),
    );
    setState(() => _originalDateFilter = normalized);
    unawaited(
      ref.read(historyLogsProvider.notifier).setFilters(
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
      ref.read(historyLogsProvider.notifier).setFilters(
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
      ref.read(historyLogsProvider.notifier).setFilters(
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
    unawaited(ref.read(historyLogsProvider.notifier).clearFilters());
  }

  String _dateFilterLabel() {
    final range = _originalDateFilter;
    if (range == null) return 'Original Qaza date';
    return '${formatAppDate(range.start)} – ${formatAppDate(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyLogsProvider);
    final records = history.valueOrNull ?? const <QazaRecord>[];
    final notifier = ref.read(historyLogsProvider.notifier);
    final progress = ref.watch(overallProgressProvider);
    final prayerProgress = ref.watch(prayerProgressProvider);
    final hasFilters = _prayerFilter != null || _statusFilter != null || _originalDateFilter != null;

    return AppScaffold(
      title: 'Logs & Progress',
      actions: [
        IconButton(
          tooltip: 'Refresh logs',
          onPressed: history.isLoading ? null : _refresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatusBar(),
            if (history.isLoading && !history.hasValue)
              const LoadingState(message: 'Loading your history...', padding: 60)
            else if (history.hasError && !history.hasValue)
              ErrorState(message: 'We could not load your history.', onRetry: _refresh)
            else ...[
              if (history.hasError && history.hasValue)
                _InlineError(message: 'We could not refresh the latest history.', onRetry: _refresh),
              ProgressOverviewCard(
                progress: progress,
                header: Text('Your progress', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 18),
              Text('Prayer progress', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final prayer in PrayerType.values)
                _PrayerProgressTile(progress: prayerProgress[prayer]),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Qaza logs', style: theme.textTheme.titleLarge)),
                  Text('${records.length}${notifier.hasMore ? '+' : ''}', key: const Key('history_result_count'), style: theme.textTheme.titleMedium),
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
                              decoration: const InputDecoration(
                                labelText: 'Prayer',
                                prefixIcon: Icon(Icons.mosque_rounded),
                              ),
                              items: [
                                const DropdownMenuItem<PrayerType?>(value: null, child: Text('All prayers')),
                                ...PrayerType.values.map(
                                  (prayer) => DropdownMenuItem<PrayerType?>(value: prayer, child: Text(prayer.label)),
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
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.filter_alt_rounded),
                              ),
                              items: const [
                                DropdownMenuItem<QazaStatus?>(value: null, child: Text('All')),
                                DropdownMenuItem<QazaStatus?>(value: QazaStatus.pending, child: Text('Pending')),
                                DropdownMenuItem<QazaStatus?>(value: QazaStatus.completed, child: Text('Completed')),
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
                              label: Text(_dateFilterLabel()),
                            ),
                          ),
                          if (hasFilters) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              key: const Key('history_clear_filters'),
                              tooltip: 'Clear filters',
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
                          'Newest original Qaza dates first • loads 50 at a time',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (records.isEmpty)
                EmptyState(
                  icon: hasFilters ? Icons.filter_alt_off_rounded : Icons.history_toggle_off_rounded,
                  title: hasFilters ? 'No matching Qaza records.' : 'No Qaza records yet.',
                  message: hasFilters
                      ? 'Try changing or clearing the filters.'
                      : 'Your Qaza records will appear here in chronological order.',
                )
              else ...[
                for (final record in records) _HistoryTile(key: ValueKey(record.id), record: record),
                if (notifier.hasMore || notifier.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: notifier.isLoadingMore
                          ? const CircularProgressIndicator()
                          : Text('Scroll for more history', style: theme.textTheme.bodySmall),
                    ),
                  ),
              ],
            ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
          leading: CircleAvatar(
            child: Icon(record.status == QazaStatus.completed ? Icons.check_rounded : Icons.schedule_rounded),
          ),
          title: Text('${record.prayerType.label} Qaza'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Original Qaza date: ${formatAppDate(record.originalDate)}'),
              Text(
                record.status == QazaStatus.completed
                    ? 'Completed: ${formatAppDateTime(record.completedAt)}'
                    : 'Status: Pending',
              ),
            ],
          ),
          isThreeLine: true,
        ),
      );
}
