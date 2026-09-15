import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';

class HistoryProgressV2Screen extends StatefulWidget {
  const HistoryProgressV2Screen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<HistoryProgressV2Screen> createState() => _HistoryProgressV2ScreenState();
}

class _HistoryProgressV2ScreenState extends State<HistoryProgressV2Screen> {
  bool loading = true;
  Object? error;
  List<QazaRecord> history = const [];
  QazaProgress progress = const QazaProgress(pending: 0, completed: 0);
  final Map<PrayerType, PrayerProgress> prayerProgress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait<dynamic>([
        widget.service.history(widget.userId),
        widget.service.overallProgress(widget.userId),
        ...PrayerType.values.map((p) => widget.service.prayerProgress(widget.userId, p)),
      ]);
      if (!mounted) return;
      setState(() {
        history = List<QazaRecord>.from(results[0] as List<QazaRecord>);
        progress = results[1] as QazaProgress;
        prayerProgress
          ..clear()
          ..addEntries((results.skip(2).cast<PrayerProgress>()).map((item) => MapEntry(item.prayerType, item)));
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs & Progress'),
        actions: [
          IconButton(
            tooltip: 'Refresh logs',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              _ErrorState(onRetry: _load)
            else ...[
              _OverviewCard(progress: progress),
              const SizedBox(height: 18),
              Text('Prayer progress', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final prayer in PrayerType.values)
                _PrayerProgressTile(progress: prayerProgress[prayer]),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Completed history', style: Theme.of(context).textTheme.titleLarge)),
                  Text('${history.length}', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                const _EmptyHistory()
              else
                for (final record in history) _HistoryTile(record: record),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.progress});
  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your progress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Metric(label: 'Pending', value: '${progress.pending}')),
            Expanded(child: _Metric(label: 'Completed', value: '${progress.completed}')),
            Expanded(child: _Metric(label: 'Total', value: '$total')),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: ratio, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text('${(ratio * 100).round()}% completed', style: TextStyle(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _PrayerProgressTile extends StatelessWidget {
  const _PrayerProgressTile({required this.progress});
  final PrayerProgress? progress;

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();
    final item = progress!;
    final total = item.progress.pending + item.progress.completed;
    final ratio = total == 0 ? 0.0 : item.progress.completed / total;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon(item.prayerType))),
        title: Text(item.prayerType.label),
        subtitle: Text('${item.progress.pending} pending • ${item.progress.completed} completed'),
        trailing: SizedBox(width: 82, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(ratio * 100).round()}%'),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio),
        ])),
      ),
    );
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});
  final QazaRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
        title: Text('${record.prayerType.label} Qaza completed'),
        subtitle: Text('Original missed date: ${_format(record.originalDate)}\nCompleted: ${_formatDateTime(record.completedAt)}'),
        isThreeLine: true,
      ),
    );
  }

  String _format(DateTime? value) {
    if (value == null) return 'Unknown';
    return '${value.day.toString().padLeft(2, '0')} ${_months[value.month - 1]} ${value.year}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Unknown';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_format(value)} $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 42),
              SizedBox(height: 10),
              Text('No completed Qaza yet.'),
              SizedBox(height: 4),
              Text('Completed individual records will appear here in newest-first order.'),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
              const Text('We could not load your history.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
