import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../core/widgets/components.dart';

class CompleteQazaScreen extends ConsumerStatefulWidget {
  const CompleteQazaScreen({super.key});
  @override
  ConsumerState<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends ConsumerState<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;
  List<QazaRecord> get pending => ref.watch(pendingForPrayerProvider(prayer));
  QazaRecord? get oldest => pending.isEmpty ? null : pending.first;
  Future<void> _refresh() => ref.read(qazaRecordsProvider.notifier).refresh();

  Future<void> _complete() async {
    final record = oldest;
    if (record == null || working) return;
    setState(() => working = true);
    try {
      await ref.read(qazaServiceProvider).completeRecord(userId: ref.read(requiredUserIdProvider), recordId: record.id, completedAt: DateTime.now());
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${prayer.label} Qaza completed successfully.')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(qazaRecordsProvider);
    final record = oldest;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Qaza'), leading: IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))),
      body: SafeArea(child: RefreshIndicator(onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        Text('Complete the oldest pending record', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Qaza is completed one individual record at a time. The original missed-prayer date is preserved.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<PrayerType>(
          value: prayer,
          decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_outlined)),
          items: [for (final item in PrayerType.values) DropdownMenuItem(value: item, child: Text(item.label))],
          onChanged: working || ledger.isLoading ? null : (value) { if (value != null) setState(() => prayer = value); },
        ),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: ledger.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          error: (_, __) => ErrorState(message: 'We could not load your Qaza ledger.', onRetry: _refresh),
          data: (_) {
            if (record == null) return const _EmptyCompletionState();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [CircleAvatar(child: Icon(prayer.icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${prayer.label} Qaza', style: Theme.of(context).textTheme.titleLarge), Text('Oldest pending record', style: Theme.of(context).textTheme.bodySmall)]))]),
              const SizedBox(height: 18), const Text('Original missed date'), const SizedBox(height: 4),
              Text(formatDate(record.originalDate), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
              const Text('Completion timestamp will be recorded separately.'),
            ]);
          },
        ))),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: oldest == null || ledger.isLoading || working ? null : _complete, icon: Icon(working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded), label: Text(working ? 'Completing...' : 'Complete oldest pending')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NamazWiseScreen())), icon: const Icon(Icons.format_list_bulleted_rounded), label: const Text('Open Namaz-wise completion')),
      ]))),
    );
  }
}

class NamazWiseScreen extends ConsumerWidget {
  const NamazWiseScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Namaz-wise')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
      Text('Choose a prayer', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
      const Text('Select one prayer to review its pending dates and complete multiple records together.'), const SizedBox(height: 18),
      for (final prayer in PrayerType.values) PrayerTile(prayer: prayer, subtitle: prayer.rakats, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingDatesScreen(prayer: prayer)))),
    ])),
  );
}

class PendingDatesScreen extends ConsumerStatefulWidget {
  const PendingDatesScreen({required this.prayer, super.key});
  final PrayerType prayer;
  @override ConsumerState<PendingDatesScreen> createState() => _PendingDatesScreenState();
}

class _PendingDatesScreenState extends ConsumerState<PendingDatesScreen> {
  final Set<String> selected = {};
  bool working = false;
  List<QazaRecord> get records => ref.watch(pendingForPrayerProvider(widget.prayer));
  Future<void> _refresh() => ref.read(qazaRecordsProvider.notifier).refresh();

  Future<void> _completeSelected() async {
    if (selected.isEmpty || working) return;
    setState(() => working = true);
    try {
      final count = await ref.read(qazaServiceProvider).completeSelected(userId: ref.read(requiredUserIdProvider), recordIds: selected.toList(growable: false), completedAt: DateTime.now());
      selected.clear();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count ${widget.prayer.label} Qaza record${count == 1 ? '' : 's'} completed.')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _toggleAll() {
    setState(() {
      if (selected.length == records.length) {
        selected.clear();
      } else {
        selected..clear()..addAll(records.map((r) => r.id));
      }
    });
  }

  @override Widget build(BuildContext context) {
    final ledger = ref.watch(qazaRecordsProvider);
    final visible = records;
    final allSelected = visible.isNotEmpty && selected.length == visible.length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.prayer.label} Qaza')),
      body: SafeArea(child: RefreshIndicator(onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Text('Pending dates', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
        const Text('Select one or more pending dates. Completion affects only the selected individual records.'), const SizedBox(height: 16),
        if (ledger.isLoading && !ledger.hasValue)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
        else if (ledger.hasError)
          ErrorState(message: 'We could not load pending Qaza records.', onRetry: _refresh)
        else if (visible.isEmpty)
          const _EmptyPendingDates()
        else ...[
          Row(children: [Expanded(child: Text('${visible.length} pending', style: Theme.of(context).textTheme.titleMedium)), TextButton.icon(onPressed: working ? null : _toggleAll, icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded), label: Text(allSelected ? 'Clear all' : 'Select all'))]), const SizedBox(height: 8),
          for (final record in visible)
            Card(margin: const EdgeInsets.only(bottom: 8), child: CheckboxListTile(value: selected.contains(record.id), onChanged: working ? null : (value) => setState(() { if (value == true) selected.add(record.id); else selected.remove(record.id); }), secondary: const Icon(Icons.event_note_outlined), title: Text(formatDate(record.originalDate)), subtitle: const Text('Pending Qaza record'), controlAffinity: ListTileControlAffinity.trailing)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: selected.isEmpty || working ? null : _completeSelected, icon: Icon(working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded), label: Text(working ? 'Completing...' : 'Complete ${selected.length} selected')),
        ],
      ]))),
    );
  }
}

class _EmptyCompletionState extends StatelessWidget {
  const _EmptyCompletionState();
  @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(8), child: Column(children: [Icon(Icons.check_circle_outline_rounded, size: 40), SizedBox(height: 10), Text('No pending Qaza for this prayer.'), SizedBox(height: 4), Text('Choose another prayer or add a Qaza record first.')]));
}

class _EmptyPendingDates extends StatelessWidget {
  const _EmptyPendingDates();
  @override Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(20), child: Column(children: [Icon(Icons.inbox_outlined, size: 40), SizedBox(height: 10), Text('No pending Qaza records.'), SizedBox(height: 4), Text('This prayer is currently up to date.')])));
}
