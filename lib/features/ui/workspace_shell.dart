import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../domain/entities/qaza_record.dart';
import '../qaza/qaza_add_flow.dart';
import '../qaza/qaza_completion_flow.dart';
import '../sync/sync_status_bar.dart';
import '../../core/widgets/components.dart';
import 'final_ui.dart';
import 'history_progress.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});
  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  static const List<Widget> _pages = [_Dashboard(), CalculatorScreen(), HistoryProgressScreen(), SettingsScreen()];
  int index = 0;
  final Set<int> _mounted = {0};
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: index, children: [for (var i = 0; i < _pages.length; i++) if (_mounted.contains(i)) _pages[i] else const SizedBox.shrink()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() { index = value; _mounted.add(value); }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'Calculator'),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Logs'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();
  static Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
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
    return Scaffold(
      appBar: AppBar(title: const Row(children: [Icon(Icons.mosque_rounded), SizedBox(width: 10), Text('Qaza Namaz')]), actions: [IconButton(tooltip: 'Refresh ledger', onPressed: ledger.isLoading ? null : () => ref.read(qazaRecordsProvider.notifier).refresh(), icon: const Icon(Icons.sync_rounded))]),
      body: RefreshIndicator(
        onRefresh: () => ref.read(qazaRecordsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const SyncStatusBar(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_todayLabel(), style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Continue your prayer journey', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(total == 0 ? 'Start by recording the dates and prayers you need to make up.' : 'Every completed prayer brings your ledger closer to zero.', style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(.86), height: 1.4)),
                  ])),
                  const SizedBox(width: 14),
                  ProgressRing(progress: ratio),
                ]),
                const SizedBox(height: 16),
                Row(children: [StatusChip('$pending pending'), const SizedBox(width: 8), StatusChip('$completed fulfilled')]),
              ]),
            ),
            const SizedBox(height: 16),
            ProgressOverviewCard(progress: progress, header: Row(children: [Expanded(child: Text('Ledger overview', style: theme.textTheme.titleMedium)), Text('$pending pending')])),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => _open(context, ref, const QazaAddFlowScreen()), icon: const Icon(Icons.add_rounded), label: const Text('Add Qaza'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: pending == 0 ? null : () => _open(context, ref, const CompleteQazaScreen()), icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Complete'))),
            ]),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: Text('Prayer ledger', style: theme.textTheme.titleLarge)), TextButton(onPressed: () => _open(context, ref, const NamazWiseScreen()), child: const Text('View all'))]),
            const SizedBox(height: 4),
            for (final prayer in PrayerType.values)
              PrayerTile(prayer: prayer, subtitle: _summary(records, prayer), trailing: Text('${_pendingFor(records, prayer)}', style: theme.textTheme.headlineSmall), onTap: () => _open(context, ref, PendingDatesScreen(prayer: prayer))),
            if (records.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline_rounded), SizedBox(width: 12), Expanded(child: Text('Your dashboard is ready. Add your first missed-prayer record to begin your ledger.'))]))),
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
