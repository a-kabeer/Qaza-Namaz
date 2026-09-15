import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/legacy_components.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/sync_status.dart';
import '../../domain/entities/qaza_record.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/completion_screen.dart';
import '../qaza/namaz_wise_screen.dart';
import '../qaza/pending_dates_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    final ledger = ref.read(qazaRecordsProvider.notifier);
    final changed = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => page));
    if (changed != null && changed > 0) await ledger.refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(qazaRecordsProvider);
    final records = ref.watch(loadedRecordsProvider);
    final progress = ref.watch(overallProgressProvider);
    final pending = progress.pending;
    final completed = progress.completed;
    final total = pending + completed;
    final ratio = total == 0 ? 0.0 : completed / total;

    return AppScaffold(
      title: 'Qaza Namaz',
      actions: [
        IconButton(
          tooltip: 'Refresh ledger',
          onPressed: ledger.isLoading ? null : () => ref.read(qazaRecordsProvider.notifier).refresh(),
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.read(qazaRecordsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatus(),
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
                    StatusChip('$pending pending'),
                    const SizedBox(width: 8),
                    StatusChip('$completed fulfilled'),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Ledger overview',
                    trailing: Text('$pending pending'),
                  ),
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
              title: 'Prayer ledger',
              trailing: TextButton(onPressed: () => _open(context, ref, const NamazWiseScreen()), child: const Text('View all')),
            ),
            const SizedBox(height: 4),
            for (final prayer in PrayerType.values)
              PrayerCard(prayer: prayer, subtitle: _summary(records, prayer), trailing: Text('${_pendingFor(records, prayer)}', style: theme.textTheme.headlineSmall), onTap: () => _open(context, ref, PendingDatesScreen(prayer: prayer))),
            if (records.isEmpty)
              const AppCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb_outline_rounded),
                  SizedBox(width: 12),
                  Expanded(child: Text('Your dashboard is ready. Add your first missed-prayer record to begin your ledger.')),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  int _pendingFor(List<QazaRecord> records, PrayerType prayer) => records.where((r) => r.prayerType == prayer && r.status == QazaStatus.pending).length;

  String _summary(List<QazaRecord> records, PrayerType prayer) {
    final pending = _pendingFor(records, prayer);
    final completed = records.where((r) => r.prayerType == prayer && r.status == QazaStatus.completed).length;
    if (pending == 0 && completed == 0) return 'No records yet';
    return pending == 0 ? '$completed completed' : '$pending pending • $completed completed';
  }

  String _todayLabel() {
    final now = DateTime.now();
    return 'Today • ${DateFormatters.weekdayShortNames[now.weekday - 1]}, ${now.day} ${DateFormatters.gregorianMonthName(now.month)} ${now.year}';
  }
}
