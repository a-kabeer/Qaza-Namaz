import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';
import '../qaza/qaza_add_flow_v2.dart';
import '../qaza/qaza_completion_flow_v2.dart';
import 'final_ui.dart';
import 'history_progress_v2.dart';

class WorkspaceShellV2 extends StatefulWidget {
  const WorkspaceShellV2({required this.userId, required this.repository, required this.onSignOut, super.key});

  final String userId;
  final QazaRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<WorkspaceShellV2> createState() => _WorkspaceShellV2State();
}

class _WorkspaceShellV2State extends State<WorkspaceShellV2> {
  late final QazaService service = QazaService(widget.repository);
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _Dashboard(service: service, userId: widget.userId),
      const CalculatorScreen(),
      HistoryProgressV2Screen(service: service, userId: widget.userId),
      SettingsScreen(onSignOut: widget.onSignOut),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'Calculator'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.service, required this.userId});
  final QazaService service;
  final String userId;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late Future<List<QazaRecord>> future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => future = widget.service.getRecords(userId: widget.userId);

  Future<void> _refresh() async {
    setState(_reload);
    await future;
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.mosque_rounded), SizedBox(width: 10), Text('Qaza Namaz')]),
        actions: [IconButton(tooltip: 'Refresh ledger', onPressed: _refresh, icon: const Icon(Icons.sync_rounded))],
      ),
      body: FutureBuilder<List<QazaRecord>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 42), const SizedBox(height: 12), const Text('We could not load your Qaza ledger.'), const SizedBox(height: 12), FilledButton(onPressed: _refresh, child: const Text('Try again'))]));
          }
          final records = snapshot.data ?? const <QazaRecord>[];
          final pending = records.where((r) => r.status == QazaStatus.pending).length;
          final completed = records.where((r) => r.status == QazaStatus.completed).length;
          final total = records.length;
          final progress = total == 0 ? 0.0 : completed / total;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_todayLabel(), style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Continue your prayer journey', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(total == 0 ? 'Start by recording the dates and prayers you need to make up.' : 'Every completed prayer brings your ledger closer to zero.', style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(.86), height: 1.4)),
                      ])),
                      const SizedBox(width: 14),
                      _ProgressRing(progress: progress),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _Pill(label: '$pending pending'),
                      const SizedBox(width: 8),
                      _Pill(label: '$completed fulfilled'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('Ledger overview', style: Theme.of(context).textTheme.titleMedium)), Text('$pending pending')]),
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: _Metric('Pending', '$pending')), Expanded(child: _Metric('Completed', '$completed')), Expanded(child: _Metric('Total', '$total'))]),
                  const SizedBox(height: 16),
                  ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 8)),
                  const SizedBox(height: 8),
                  Text(total == 0 ? 'No records yet' : '${(progress * 100).round()}% completed'),
                ]))),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(QazaAddFlowV2Screen(service: widget.service, userId: widget.userId)),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Qaza'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pending == 0 ? null : () => _open(CompleteQazaV2Screen(service: widget.service, userId: widget.userId)),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Complete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(children: [Expanded(child: Text('Prayer ledger', style: Theme.of(context).textTheme.titleLarge)), TextButton(onPressed: () => _open(NamazWiseV2Screen(service: widget.service, userId: widget.userId)), child: const Text('View all'))]),
                const SizedBox(height: 4),
                for (final prayer in PrayerType.values)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _open(PendingDatesV2Screen(service: widget.service, userId: widget.userId, prayer: prayer)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          CircleAvatar(child: Icon(_icon(prayer))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prayer.label, style: Theme.of(context).textTheme.titleMedium), Text(_summary(records, prayer), style: Theme.of(context).textTheme.bodySmall)])),
                          Text('${_pending(records, prayer)}', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ]),
                      ),
                    ),
                  ),
                if (records.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline_rounded), SizedBox(width: 12), Expanded(child: Text('Your dashboard is ready. Add your first missed-prayer record to begin your ledger.'))]))),
              ],
            ),
          );
        },
      ),
    );
  }

  int _pending(List<QazaRecord> records, PrayerType prayer) => records.where((r) => r.prayerType == prayer && r.status == QazaStatus.pending).length;

  String _summary(List<QazaRecord> records, PrayerType prayer) {
    final pending = _pending(records, prayer);
    final completed = records.where((r) => r.prayerType == prayer && r.status == QazaStatus.completed).length;
    if (pending == 0 && completed == 0) return 'No records yet';
    return pending == 0 ? '$completed completed' : '$pending pending • $completed completed';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Today • ${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  IconData _icon(PrayerType p) => switch (p) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: progress, strokeWidth: 6, backgroundColor: scheme.onPrimaryContainer.withOpacity(.18), color: scheme.secondary),
        Text('${(progress * 100).round()}%', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
}
