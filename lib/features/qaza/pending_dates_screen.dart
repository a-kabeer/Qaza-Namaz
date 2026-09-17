import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
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
  static const _pageSize = 50;
  final Set<String> selected = {};
  final List<QazaRecord> records = [];
  DateTime? _afterDate;
  String? _afterId;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _working = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(reset: true); }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore && !reset) return;
    if (reset) setState(() { _loading = true; _error = null; _afterDate = null; _afterId = null; records.clear(); selected.clear(); });
    else setState(() => _loadingMore = true);
    try {
      final userId = ref.read(requiredUserIdProvider);
      final page = await ref.read(qazaServiceProvider).getPage(userId: userId, limit: _pageSize, prayerType: widget.prayer, status: QazaStatus.pending, afterOriginalDate: _afterDate, afterId: _afterId);
      if (!mounted) return;
      setState(() {
        records.addAll(page.records);
        _hasMore = page.hasMore;
        _afterDate = page.nextOriginalDate;
        _afterId = page.nextId;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _loadingMore = false; _error = error.toString(); });
    }
  }

  Future<void> _completeSelected() async {
    if (selected.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      final count = await ref.read(qazaServiceProvider).completeSelected(userId: ref.read(requiredUserIdProvider), recordIds: selected.toList(growable: false), completedAt: DateTime.now());
      if (!mounted) return;
      await _load(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count ${widget.prayer.label} Qaza record${count == 1 ? '' : 's'} completed.')));
    } finally { if (mounted) setState(() => _working = false); }
  }

  void _toggleAll() {
    setState(() {
      if (selected.length == records.length) selected.clear();
      else { selected.clear(); selected.addAll(records.map((r) => r.id)); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = records.isNotEmpty && selected.length == records.length;
    final hasSelection = selected.isNotEmpty;
    return AppScaffold(
      title: '${widget.prayer.label} Qaza',
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, hasSelection ? 104 : 28),
                children: [
                  Text('Pending dates', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Select one or more pending dates. More dates load in small pages for large Qaza ledgers.'),
                  const SizedBox(height: 16),
                  if (_loading) const LoadingState(message: 'Loading pending Qaza records…', padding: 28)
                  else if (_error != null) ErrorState(message: 'We could not load pending Qaza records.', onRetry: () => _load(reset: true))
                  else if (records.isEmpty) const EmptyState(icon: Icons.inbox_outlined, title: 'No pending Qaza records.', message: 'This prayer is currently up to date.')
                  else ...[
                    Row(children: [Expanded(child: Text('${records.length}${_hasMore ? '+' : ''} pending loaded', style: Theme.of(context).textTheme.titleMedium)), TextButton.icon(onPressed: _working ? null : _toggleAll, icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded), label: Text(allSelected ? 'Clear all' : 'Select loaded'))]),
                    const SizedBox(height: 8),
                    for (final record in records)
                      Card(margin: const EdgeInsets.only(bottom: 8), child: CheckboxListTile(value: selected.contains(record.id), onChanged: _working ? null : (value) => setState(() { if (value == true) selected.add(record.id); else selected.remove(record.id); }), secondary: const Icon(Icons.event_note_outlined), title: Text(formatAppDate(record.originalDate)), subtitle: const Text('Pending Qaza record'), controlAffinity: ListTileControlAffinity.trailing)),
                    if (_hasMore) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(onPressed: _loadingMore || _working ? null : () => _load(reset: false), icon: _loadingMore ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more), label: Text(_loadingMore ? 'Loading…' : 'Load more'))),
                  ],
                ],
              ),
            ),
            if (hasSelection) Positioned(left: 16, right: 16, bottom: 16, child: SafeArea(top: false, child: AppButton(label: _working ? 'Completing...' : 'Complete ${selected.length} Qaza', icon: _working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded, onPressed: _working ? null : _completeSelected, expand: true))),
          ],
        ),
      ),
    );
  }
}
