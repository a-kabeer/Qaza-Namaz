import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/components.dart';
import '../../domain/entities/qaza_record.dart';

class PendingDatesScreen extends ConsumerStatefulWidget {
  const PendingDatesScreen({required this.prayer, super.key});
  final PrayerType prayer;

  @override
  ConsumerState<PendingDatesScreen> createState() => _PendingDatesScreenState();
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

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(qazaRecordsProvider);
    final visible = records;
    final allSelected = visible.isNotEmpty && selected.length == visible.length;
    return PageScaffold(
      title: '${widget.prayer.label} Qaza',
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Pending dates', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Select one or more pending dates. Completion affects only the selected individual records.'),
              const SizedBox(height: 16),
              if (ledger.isLoading && !ledger.hasValue)
                const LoadingState(message: 'Loading pending Qaza records…', padding: 28)
              else if (ledger.hasError)
                ErrorState(message: 'We could not load pending Qaza records.', onRetry: _refresh)
              else if (visible.isEmpty)
                const EmptyState(icon: Icons.inbox_outlined, title: 'No pending Qaza records.', message: 'This prayer is currently up to date.')
              else ...[
                Row(children: [Expanded(child: Text('${visible.length} pending', style: Theme.of(context).textTheme.titleMedium)), TextButton.icon(onPressed: working ? null : _toggleAll, icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded), label: Text(allSelected ? 'Clear all' : 'Select all'))]),
                const SizedBox(height: 8),
                for (final record in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: selected.contains(record.id),
                      onChanged: working ? null : (value) => setState(() { if (value == true) selected.add(record.id); else selected.remove(record.id); }),
                      secondary: const Icon(Icons.event_note_outlined),
                      title: Text(formatDate(record.originalDate)),
                      subtitle: const Text('Pending Qaza record'),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),
                const SizedBox(height: 12),
                PrimaryButton(label: working ? 'Completing...' : 'Complete ${selected.length} selected', icon: working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded, onPressed: selected.isEmpty || working ? null : _completeSelected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
