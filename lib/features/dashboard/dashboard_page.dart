import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.userId, required this.repository, super.key});

  final String userId;
  final QazaRepository repository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final QazaService _service;
  QazaProgress? _progress;
  List<QazaRecord> _recent = const [];
  Map<PrayerType, PrayerProgress> _prayers = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = QazaService(widget.repository);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final progress = await _service.overallProgress(widget.userId);
      final history = await _service.history(widget.userId);
      final prayerEntries = <PrayerType, PrayerProgress>{};
      for (final prayer in allPrayerTypes) {
        prayerEntries[prayer] = await _service.prayerProgress(widget.userId, prayer);
      }
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _recent = history.take(5).toList();
        _prayers = prayerEntries;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _complete(PrayerType prayer) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final completed = await _service.completeOldestPending(
        userId: widget.userId,
        prayerType: prayer,
      );
      if (mounted && !completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pending ${prayer.label} Qaza found.')),
        );
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFive(PrayerType prayer) async {
    final today = DateTime.now();
    setState(() => _busy = true);
    try {
      final dates = List.generate(
        5,
        (index) => DateTime(today.year, today.month, today.day - index - 1),
      );
      await _service.recordQazaForDates(
        userId: widget.userId,
        dates: dates,
        prayerTypes: [prayer],
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final progress = _progress ?? const QazaProgress(pending: 0, completed: 0);
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _GreetingHeader(userId: widget.userId),
          const SizedBox(height: 16),
          _ProgressCard(progress: progress, ratio: ratio),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Quick Actions', icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionButton(icon: Icons.today, label: 'Complete Full Day', onTap: _busy ? null : () => _completeDay())),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(icon: Icons.add_circle_outline, label: 'Batch Add', onTap: _busy ? null : () => _batchAdd())),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Prayer Ledger', icon: Icons.auto_stories_rounded),
          const SizedBox(height: 10),
          for (final prayer in allPrayerTypes) ...[
            _PrayerCard(
              prayer: prayer,
              progress: _prayers[prayer]?.progress ?? const QazaProgress(pending: 0, completed: 0),
              onDone: _busy ? null : () => _complete(prayer),
              onAddFive: _busy ? null : () => _addFive(prayer),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          _ActivitySnapshot(progress: progress),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Recent Ledger Logs', icon: Icons.history_rounded),
          const SizedBox(height: 10),
          if (_recent.isEmpty)
            const _EmptyCard()
          else
            for (final record in _recent) _LedgerRow(record: record),
          const SizedBox(height: 16),
          Text(
            'All figures above are calculated from your signed-in Qaza ledger.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDay() async {
    for (final prayer in allPrayerTypes) {
      await _service.completeOldestPending(userId: widget.userId, prayerType: prayer);
    }
    await _refresh();
  }

  Future<void> _batchAdd() async {
    final selected = <PrayerType>{...allPrayerTypes};
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (date == null) return;
    await _service.recordQazaForDates(
      userId: widget.userId,
      dates: [date],
      prayerTypes: selected,
    );
    await _refresh();
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mosque_rounded, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineSmall),
              Text('Your prayer ledger', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Icon(Icons.cloud_done_rounded, color: Theme.of(context).colorScheme.tertiary),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.ratio});
  final QazaProgress progress;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: ratio, strokeWidth: 9, backgroundColor: cs.outlineVariant)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${(ratio * 100).round()}%', style: Theme.of(context).textTheme.headlineSmall),
                    Text('complete', style: Theme.of(context).textTheme.labelSmall),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Remaining Backlog', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text('${progress.pending}', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text('${progress.completed} fulfilled', style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge)]);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), padding: const EdgeInsets.symmetric(horizontal: 10)));
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.prayer, required this.progress, required this.onDone, required this.onAddFive});
  final PrayerType prayer; final QazaProgress progress; final VoidCallback? onDone; final VoidCallback? onAddFive;
  @override
  Widget build(BuildContext context) {
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    final isWitr = prayer == PrayerType.witr;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 20, backgroundColor: isWitr ? cs.secondaryContainer : cs.primaryContainer, child: Icon(isWitr ? Icons.nights_stay_rounded : Icons.access_time_rounded, size: 20, color: isWitr ? cs.onSecondaryContainer : cs.onPrimaryContainer)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prayer.label, style: Theme.of(context).textTheme.titleLarge), if (isWitr) Text('Wajib • separate ledger', style: Theme.of(context).textTheme.labelSmall)])),
            Text('${progress.pending} pending', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
          ]),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: ratio, minHeight: 6, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('${progress.completed} completed', style: Theme.of(context).textTheme.bodySmall)),
            IconButton(tooltip: 'Complete oldest', onPressed: onDone, icon: const Icon(Icons.check_circle_outline)),
            TextButton(onPressed: onAddFive, child: const Text('+5')),
          ]),
        ]),
      ),
    );
  }
}

class _ActivitySnapshot extends StatelessWidget {
  const _ActivitySnapshot({required this.progress});
  final QazaProgress progress;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: _Metric('Today', '—')), Expanded(child: _Metric('Completed', '${progress.completed}')), Expanded(child: _Metric('Pending', '${progress.pending}'))])));
}

class _Metric extends StatelessWidget { const _Metric(this.label, this.value); final String label, value; @override Widget build(BuildContext context) => Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.labelSmall)]); }
class _LedgerRow extends StatelessWidget { const _LedgerRow({required this.record}); final QazaRecord record; @override Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.check_circle_rounded), title: Text(record.prayerType.label), subtitle: Text('Original: ${record.originalDate.year}-${record.originalDate.month.toString().padLeft(2, '0')}-${record.originalDate.day.toString().padLeft(2, '0')}'), trailing: Text(record.completedAt == null ? '' : '${record.completedAt!.hour.toString().padLeft(2, '0')}:${record.completedAt!.minute.toString().padLeft(2, '0')}'))); }
class _EmptyCard extends StatelessWidget { const _EmptyCard(); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No completed Qaza records yet.')))); }
