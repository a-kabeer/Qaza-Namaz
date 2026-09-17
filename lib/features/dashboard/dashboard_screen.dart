import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/sync_status.dart';
import '../../domain/entities/qaza_progress.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/completion_screen.dart';
import '../qaza/namaz_wise_screen.dart';
import '../qaza/pending_dates_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(progressSummaryProvider);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(progressSummaryProvider);
    await ref.read(progressSummaryProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progressAsync = ref.watch(progressSummaryProvider);
    final summary = progressAsync.valueOrNull ?? QazaProgressSummary.empty();
    final progress = summary.overall;
    final pending = progress.pending;
    final completed = progress.completed;
    final total = progress.total;
    final ratio = progress.percentage;

    return AppScaffold(
      title: 'Qaza Namaz',
      actions: [
        IconButton(
          tooltip: 'Refresh progress',
          onPressed: progressAsync.isLoading ? null : () => _refresh(ref),
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatus(),
            if (progressAsync.hasError && progressAsync.valueOrNull == null)
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded),
                  title: const Text('Could not load progress'),
                  subtitle: const Text('Your local Qaza data is still available; retry the count query.'),
                  trailing: TextButton(onPressed: () => ref.invalidate(progressSummaryProvider), child: const Text('Retry')),
                ),
              )
            else ...[
              AppCard(
                color: scheme.primaryContainer,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_todayLabel(), style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Continue your prayer journey', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(total == 0 ? 'Start by recording the dates and prayers you need to make up.' : 'Every completed prayer brings your ledger closer to zero.', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .86), height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        ProgressRing(progress: ratio),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      StatusChip('$pending pending', tone: StatusChipTone.pending),
                      const SizedBox(width: 8),
                      StatusChip('$completed fulfilled', tone: StatusChipTone.fulfilled),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: 'Ledger overview', trailing: Text('$pending pending')),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: MetricTile(label: 'Pending', value: '$pending')),
                      Expanded(child: MetricTile(label: 'Completed', value: '$completed')),
                      Expanded(child: MetricTile(label: 'Total', value: '$total')),
                    ]),
                    const SizedBox(height: 16),
                    ClipRRect(borderRadius: BorderRadius.circular(AppRadius.pill), child: LinearProgressIndicator(value: ratio, minHeight: 10)),
                    const SizedBox(height: 8),
                    Text(total == 0 ? 'No records yet' : '${(ratio * 100).round()}% completed'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: AppButton(onPressed: () => _open(context, ref, const AddQazaScreen()), icon: Icons.add_rounded, label: 'Add Qaza')),
                const SizedBox(width: 10),
                Expanded(child: AppButton(onPressed: pending == 0 ? null : () => _open(context, ref, const CompleteQazaScreen()), icon: Icons.check_circle_outline_rounded, label: 'Complete', secondary: true)),
              ]),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Prayer overview',
                trailing: TextButton(onPressed: () => _open(context, ref, const NamazWiseScreen()), child: const Text('View all')),
              ),
              const SizedBox(height: 4),
              for (final prayer in PrayerType.values)
                PrayerCard(
                  prayer: prayer,
                  subtitle: _summary(summary.byPrayer[prayer]),
                  trailing: Text('${summary.byPrayer[prayer]?.progress.pending ?? 0}', style: theme.textTheme.headlineSmall),
                  onTap: () => _open(context, ref, PendingDatesScreen(prayer: prayer)),
                ),
              if (total == 0)
                const AppCard(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lightbulb_outline_rounded),
                    SizedBox(width: 12),
                    Expanded(child: Text('Your dashboard is ready. Add your first missed-prayer record to begin your ledger.')),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _summary(PrayerProgress? item) {
    if (item == null || item.progress.total == 0) return 'No records yet';
    final pending = item.progress.pending;
    final completed = item.progress.completed;
    return pending == 0 ? '$completed completed' : '$pending pending • $completed completed';
  }

  String _todayLabel() {
    final now = DateTime.now();
    return 'Today • ${DateFormatters.weekdayShortNames[now.weekday - 1]}, ${now.day} ${DateFormatters.gregorianMonthName(now.month)} ${now.year}';
  }
}
