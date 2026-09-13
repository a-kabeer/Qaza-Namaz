import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';
import 'final_ui.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    required this.userId,
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final String userId;
  final QazaRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  late final QazaService service = QazaService(widget.repository);
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardWorkspace(service: service, userId: widget.userId),
      const CalculatorScreen(),
      HistoryScreen(service: service, userId: widget.userId),
      SettingsScreen(onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardWorkspace extends StatefulWidget {
  const DashboardWorkspace({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<DashboardWorkspace> createState() => _DashboardWorkspaceState();
}

class _DashboardWorkspaceState extends State<DashboardWorkspace> {
  late Future<List<QazaRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recordsFuture = widget.service.getRecords(userId: widget.userId);
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _recordsFuture;
    } catch (_) {
      // The visible FutureBuilder owns the error presentation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.mosque_rounded),
            SizedBox(width: 10),
            Text('Qaza Namaz'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh ledger',
            onPressed: _refresh,
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<QazaRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DashboardLoading();
          }

          if (snapshot.hasError) {
            return _DashboardError(
              message: 'We could not load your Qaza ledger.',
              onRetry: _refresh,
            );
          }

          final records = snapshot.data ?? const <QazaRecord>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _todayLabel(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Continue your prayer journey',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        records.isEmpty
                            ? 'Start by recording the dates and prayers you need to make up.'
                            : 'Every completed prayer brings your ledger closer to zero.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimaryContainer.withOpacity(.86),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _OverviewCard(records: records),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(
                          context,
                          AddQazaScreen(service: widget.service, userId: widget.userId),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Qaza'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: records.any((r) => r.status == QazaStatus.pending)
                            ? () => _open(
                                  context,
                                  CompleteQazaScreen(
                                    service: widget.service,
                                    userId: widget.userId,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Complete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Prayer ledger', style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                ...PrayerType.values.map(
                  (prayer) => _PrayerLedgerCard(
                    prayer: prayer,
                    records: records,
                    onTap: () => _open(
                      context,
                      PendingDatesScreen(
                        service: widget.service,
                        userId: widget.userId,
                        prayer: prayer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _DashboardEmptyHint(records: records),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      setState(_load);
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Today • ${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.records});

  final List<QazaRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = records.where((r) => r.status == QazaStatus.pending).length;
    final completed = records.where((r) => r.status == QazaStatus.completed).length;
    final total = pending + completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ledger overview', style: theme.textTheme.titleMedium),
                ),
                Text('$pending pending', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Pending', value: '$pending')),
                Expanded(child: _Metric(label: 'Completed', value: '$completed')),
                Expanded(child: _Metric(label: 'Total', value: '$total')),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0 ? 'No records yet' : '${(progress * 100).round()}% completed',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PrayerLedgerCard extends StatelessWidget {
  const _PrayerLedgerCard({required this.prayer, required this.records, required this.onTap});

  final PrayerType prayer;
  final List<QazaRecord> records;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = records.where((r) => r.prayerType == prayer && r.status == QazaStatus.pending).length;
    final completed = records.where((r) => r.prayerType == prayer && r.status == QazaStatus.completed).length;
    final total = pending + completed;
    final ratio = total == 0 ? 0.0 : completed / total;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary.withOpacity(.10),
                    child: Icon(_iconFor(prayer), color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prayer.label, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          pending == 0 ? 'No pending Qaza' : '$pending pending',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text('$pending', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: ratio, minHeight: 5),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return Icons.wb_twilight_rounded;
      case PrayerType.zuhr:
        return Icons.wb_sunny_rounded;
      case PrayerType.asr:
        return Icons.wb_sunny_outlined;
      case PrayerType.maghrib:
        return Icons.nights_stay_outlined;
      case PrayerType.isha:
        return Icons.dark_mode_outlined;
      case PrayerType.witr:
        return Icons.brightness_3_outlined;
    }
  }
}

class _DashboardEmptyHint extends StatelessWidget {
  const _DashboardEmptyHint({required this.records});

  final List<QazaRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isNotEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your dashboard is ready. Add your first missed-prayer record to begin building a reliable ledger.',
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading your Qaza ledger...'),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
