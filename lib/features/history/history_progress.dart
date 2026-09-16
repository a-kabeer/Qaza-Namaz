// Logs & progress.
//
// The history screen remains a derived view over the shared Qaza ledger. UI
// filters and sorting are intentionally local to this screen so business
// logic, persistence, and synchronization remain unchanged.

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

class HistoryProgressScreen extends ConsumerStatefulWidget {
  const HistoryProgressScreen({super.key});

  @override
  ConsumerState<HistoryProgressScreen> createState() => _HistoryProgressScreenState();
}

class _HistoryProgressScreenState extends ConsumerState<HistoryProgressScreen> {
  PrayerType? _prayerFilter;
  QazaStatus? _statusFilter;
  DateTimeRange? _originalDateFilter;

  Future<void> _refresh() async {
    await ref.read(qazaRecordsProvider.notifier).refresh();
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
    setState(() => _originalDateFilter = DateTimeRange(
          start: DateTime(selected.start.year, selected.start.month, selected.start.day),
          end: DateTime(selected.end.year, selected.end.month, selected.end.day),
        ));
  }

  void _clearFilters() {
    setState(() {
      _prayerFilter = null;
      _statusFilter = null;
      _originalDateFilter = null;
    });
  }

  List<QazaRecord> _filteredAndSorted(List<QazaRecord> records) {
    final filtered = records.where((record) {
      final matchesPrayer = _prayerFilter == null || record.prayerType == _prayerFilter;
      final matchesStatus = _statusFilter == null || record.status == _statusFilter;
      final range = _originalDateFilter;
      final date = DateTime(record.originalDate.year, record.originalDate.month, record.originalDate.day);
      final matchesDate = range == null ||
          (!date.isBefore(range.start) && !date.isAfter(range.end));
      return matchesPrayer && matchesStatus && matchesDate;
    }).toList();

    filtered.sort((a, b) {
      final byOriginal = b.originalDate.compareTo(a.originalDate);
      if (byOriginal != 0) return byOriginal;
      final aCompleted = a.completedAt;
      final bCompleted = b.completedAt;
      if (aCompleted == null && bCompleted == null) return a.id.compareTo(b.id);
      if (aCompleted == null) return 1;
      if (bCompleted == null) return -1;
      final byCompleted = bCompleted.compareTo(aCompleted);
      return byCompleted != 0 ? byCompleted : a.id.compareTo(b.id);
    });
    return filtered;
  }

  String _dateFilterLabel() {
    final range = _originalDateFilter;
    if (range == null) return 'Original Qaza date';
    return '${formatAppDate(range.start)} – ${formatAppDate(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledger = ref.watch(qazaRecordsProvider);
    final allRecords = ref.watch(loadedRecordsProvider);
    final progress = ref.watch(overallProgressProvider);
    final prayerProgress = ref.watch(prayerProgressProvider);
    final records = _filteredAndSorted(allRecords);
    final hasFilters = _prayerFilter != null || _statusFilter != null || _originalDateFilter != null;

    return AppScaffold(
      title: 'Logs & Progress',
      actions: [
        IconButton(
          tooltip: 'Refresh logs',
          onPressed: ledger.isLoading ? null : _refresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatusBar(),
            if (ledger.isLoading && !ledger.hasValue)
              const LoadingState(message: 'Loading your ledger...', padding: 60)
            else if (ledger.hasError && !ledger.hasValue)
              ErrorState(message: 'We could not load your history.', onRetry: _refresh)
            else ...[
              if (ledger.hasError && ledger.hasValue)
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
                  Expanded(child: Text('Qaza ledger', style: theme.textTheme.titleLarge)),
                  Text('${records.length}', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<PrayerType?>(
                        key: const Key('history_prayer_filter'),
                        value: _prayerFilter,
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
                        onChanged: (value) => setState(() => _prayerFilter = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<QazaStatus?>(
                        key: const Key('history_status_filter'),
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.filter_alt_rounded),
                        ),
                        items: const [
                          DropdownMenuItem<QazaStatus?>(value: null, child: Text('All statuses')),
                          DropdownMenuItem<QazaStatus?>(value: QazaStatus.pending, child: Text('Pending')),
                          DropdownMenuItem<QazaStatus?>(value: QazaStatus.completed, child: Text('Completed')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value),
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
                          'Newest original Qaza dates first',
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
              else
                for (final record in records) _HistoryTile(record: record),
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
        leading: CircleAvatar(child: Icon(item.prayerType.icon)),
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
  const _HistoryTile({required this.record});
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
