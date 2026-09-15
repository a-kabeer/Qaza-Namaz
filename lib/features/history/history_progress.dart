// Logs & progress.
//
// Completed history plus overall and per-prayer progress, all derived from the
// shared ledger provider — this screen issues no queries of its own.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/progress_overview_card.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../sync/sync_status_bar.dart';

class HistoryProgressScreen extends ConsumerWidget {
  const HistoryProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledger = ref.watch(qazaRecordsProvider);
    final history = ref.watch(qazaHistoryProvider);
    final progress = ref.watch(overallProgressProvider);
    final prayerProgress = ref.watch(prayerProgressProvider);
    Future<void> refresh() => ref.read(qazaRecordsProvider.notifier).refresh();

    return AppScaffold(
      title: 'Logs & Progress',
      actions: [
        IconButton(
          tooltip: 'Refresh logs',
          onPressed: ledger.isLoading ? null : refresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatusBar(),
            if (ledger.isLoading && !ledger.hasValue)
              const LoadingState(message: 'Loading your ledger...', padding: 60)
            else if (ledger.hasError && !ledger.hasValue)
              ErrorState(message: 'We could not load your history.', onRetry: refresh)
            else ...[
              ProgressOverviewCard(progress: progress, header: Text('Your progress', style: theme.textTheme.titleLarge)),
              const SizedBox(height: 18),
              Text('Prayer progress', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final prayer in PrayerType.values)
                _PrayerProgressTile(progress: prayerProgress[prayer]),
              const SizedBox(height: 18),
              Row(children: [Expanded(child: Text('Completed history', style: theme.textTheme.titleLarge)), Text('${history.length}', style: theme.textTheme.titleMedium)]),
              const SizedBox(height: 10),
              if (history.isEmpty)
                const EmptyState(icon: Icons.history_toggle_off_rounded, title: 'No completed Qaza yet.', message: 'Completed individual records will appear here in newest-first order.')
              else
                for (final record in history) _HistoryTile(record: record),
            ],
          ],
        ),
      ),
    );
  }
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
        trailing: SizedBox(width: 82, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${(ratio * 100).round()}%'), const SizedBox(height: 4), LinearProgressIndicator(value: ratio)])),
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
          leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
          title: Text('${record.prayerType.label} Qaza completed'),
          subtitle: Text('Original missed date: ${formatAppDate(record.originalDate)}\nCompleted: ${formatAppDateTime(record.completedAt)}'),
          isThreeLine: true,
        ),
      );
}
