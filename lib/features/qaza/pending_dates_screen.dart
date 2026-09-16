import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_record.dart';

class PendingDatesScreen extends ConsumerStatefulWidget {
  const PendingDatesScreen({required this.prayer, super.key});
  final PrayerType prayer;

  @override
  ConsumerState<PendingDatesScreen> createState() => _PendingDatesScreenState();
}

class _PendingDatesScreenState extends ConsumerState<PendingDatesScreen> {
  final Set<String> selected = <String>{};
  bool working = false;

  List<QazaRecord> get records => ref.watch(pendingForPrayerProvider(widget.prayer));

  Future<void> _refresh() => ref.read(qazaRecordsProvider.notifier).refresh();

  List<String> _visibleSelectedIds(List<QazaRecord> visible) {
    final visibleIds = visible.map((record) => record.id).toSet();
    return selected.where(visibleIds.contains).toList(growable: false);
  }

  Future<void> _completeSelected(List<String> selectedIds) async {
    if (selectedIds.isEmpty || working) return;
    setState(() => working = true);
    try {
      final count = await ref.read(qazaServiceProvider).completeSelected(
            userId: ref.read(requiredUserIdProvider),
            recordIds: selectedIds,
            completedAt: DateTime.now(),
          );
      if (count > 0) {
        selected.clear();
        await _refresh();
      }
      if (!mounted) return;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count ${widget.prayer.label} Qaza record${count == 1 ? '' : 's'} completed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _toggleAll(List<QazaRecord> visible) {
    setState(() {
      if (selected.length == visible.length) {
        selected.clear();
      } else {
        selected
          ..clear()
          ..addAll(visible.map((record) => record.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledger = ref.watch(qazaRecordsProvider);
    final visible = records;
    final selectedIds = _visibleSelectedIds(visible);
    final selectedCount = selectedIds.length;
    final allSelected = visible.isNotEmpty && selectedCount == visible.length;

    return AppScaffold(
      title: '${widget.prayer.label} Qaza',
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, selectedCount > 0 ? 104 : 28),
                children: [
                  Text('Pending dates', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Select one or more pending dates. Completion affects only the selected individual records.',
                  ),
                  const SizedBox(height: 16),
                  if (ledger.isLoading && !ledger.hasValue)
                    const LoadingState(message: 'Loading pending Qaza records…', padding: 28)
                  else if (ledger.hasError)
                    ErrorState(
                      message: 'We could not load pending Qaza records.',
                      onRetry: _refresh,
                    )
                  else if (visible.isEmpty)
                    const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No pending Qaza records.',
                      message: 'This prayer is currently up to date.',
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${visible.length} pending',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: working ? null : () => _toggleAll(visible),
                          icon: Icon(
                            allSelected
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                          ),
                          label: Text(allSelected ? 'Clear all' : 'Select all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final record in visible)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: selected.contains(record.id),
                          onChanged: working
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      selected.add(record.id);
                                    } else {
                                      selected.remove(record.id);
                                    }
                                  }),
                          secondary: const Icon(Icons.event_note_outlined),
                          title: Text(formatAppDate(record.originalDate)),
                          subtitle: const Text('Pending Qaza record'),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (selectedCount > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 8,
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    key: const Key('complete_selected_qaza_button'),
                    onPressed: working ? null : () => _completeSelected(selectedIds),
                    icon: working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      working
                          ? 'Completing $selectedCount Qaza…'
                          : 'Complete $selectedCount Qaza',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
