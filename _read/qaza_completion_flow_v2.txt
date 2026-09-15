import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';

class CompleteQazaV2Screen extends StatefulWidget {
  const CompleteQazaV2Screen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<CompleteQazaV2Screen> createState() => _CompleteQazaV2ScreenState();
}

class _CompleteQazaV2ScreenState extends State<CompleteQazaV2Screen> {
  PrayerType prayer = PrayerType.fajr;
  QazaRecord? oldest;
  bool loading = true;
  bool working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      oldest = await widget.service.oldestPending(
        userId: widget.userId,
        prayerType: prayer,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _complete() async {
    final record = oldest;
    if (record == null || working) return;
    setState(() => working = true);
    try {
      await widget.service.completeRecord(
        userId: widget.userId,
        recordId: record.id,
        completedAt: DateTime.now(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${prayer.label} Qaza completed successfully.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _changePrayer(PrayerType value) {
    if (value == prayer) return;
    setState(() => prayer = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Qaza'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text('Complete the oldest pending record', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Qaza is completed one individual record at a time. The original missed-prayer date is preserved.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<PrayerType>(
                value: prayer,
                decoration: const InputDecoration(
                  labelText: 'Prayer',
                  prefixIcon: Icon(Icons.mosque_outlined),
                ),
                items: [
                  for (final item in PrayerType.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: working || loading ? null : (value) {
                  if (value != null) _changePrayer(value);
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: loading
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                      : oldest == null
                          ? const _EmptyCompletionState()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(child: Icon(_icon(prayer))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${prayer.label} Qaza', style: Theme.of(context).textTheme.titleLarge),
                                          Text('Oldest pending record', style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text('Original missed date'),
                                const SizedBox(height: 4),
                                Text(_format(oldest!.originalDate), style: Theme.of(context).textTheme.headlineSmall),
                                const SizedBox(height: 8),
                                const Text('Completion timestamp will be recorded separately.'),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: oldest == null || loading || working ? null : _complete,
                icon: Icon(working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded),
                label: Text(working ? 'Completing...' : 'Complete oldest pending'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NamazWiseV2Screen(service: widget.service, userId: widget.userId),
                  ),
                ),
                icon: const Icon(Icons.format_list_bulleted_rounded),
                label: const Text('Open Namaz-wise completion'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';

  IconData _icon(PrayerType p) => switch (p) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };
}

class NamazWiseV2Screen extends StatelessWidget {
  const NamazWiseV2Screen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Namaz-wise')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text('Choose a prayer', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Select one prayer to review its pending dates and complete multiple records together.'),
            const SizedBox(height: 18),
            for (final prayer in PrayerType.values)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_icon(prayer))),
                  title: Text(prayer.label),
                  subtitle: Text(_subtitle(prayer)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PendingDatesV2Screen(
                        service: service,
                        userId: userId,
                        prayer: prayer,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(PrayerType p) => switch (p) {
        PrayerType.fajr => '2 Rakat Fard',
        PrayerType.zuhr => '4 Rakat Fard',
        PrayerType.asr => '4 Rakat Fard',
        PrayerType.maghrib => '3 Rakat Fard',
        PrayerType.isha => '4 Rakat Fard',
        PrayerType.witr => '3 Rakat Wajib • Independent',
      };

  IconData _icon(PrayerType p) => switch (p) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };
}

class PendingDatesV2Screen extends StatefulWidget {
  const PendingDatesV2Screen({required this.service, required this.userId, required this.prayer, super.key});

  final QazaService service;
  final String userId;
  final PrayerType prayer;

  @override
  State<PendingDatesV2Screen> createState() => _PendingDatesV2ScreenState();
}

class _PendingDatesV2ScreenState extends State<PendingDatesV2Screen> {
  List<QazaRecord> records = const [];
  final Set<String> selected = {};
  bool loading = true;
  bool working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final result = await widget.service.getPendingForPrayer(
        userId: widget.userId,
        prayerType: widget.prayer,
      );
      result.sort((a, b) => a.originalDate.compareTo(b.originalDate));
      records = result;
      selected.removeWhere((id) => !records.any((r) => r.id == id));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _completeSelected() async {
    if (selected.isEmpty || working) return;
    setState(() => working = true);
    try {
      final ids = selected.toList(growable: false);
      final count = await widget.service.completeSelected(
        userId: widget.userId,
        recordIds: ids,
        completedAt: DateTime.now(),
      );
      selected.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count ${widget.prayer.label} Qaza record${count == 1 ? '' : 's'} completed.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _toggleAll() {
    setState(() {
      if (selected.length == records.length) {
        selected.clear();
      } else {
        selected
          ..clear()
          ..addAll(records.map((r) => r.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = records.isNotEmpty && selected.length == records.length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.prayer.label} Qaza')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Pending dates', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Select one or more pending dates. Completion affects only the selected individual records.'),
              const SizedBox(height: 16),
              if (loading)
                const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
              else if (records.isEmpty)
                const _EmptyPendingDates()
              else ...[
                Row(
                  children: [
                    Expanded(child: Text('${records.length} pending', style: Theme.of(context).textTheme.titleMedium)),
                    TextButton.icon(
                      onPressed: working ? null : _toggleAll,
                      icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
                      label: Text(allSelected ? 'Clear all' : 'Select all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final record in records)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: selected.contains(record.id),
                      onChanged: working ? null : (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(record.id);
                          } else {
                            selected.remove(record.id);
                          }
                        });
                      },
                      secondary: const Icon(Icons.event_note_outlined),
                      title: Text(_format(record.originalDate)),
                      subtitle: const Text('Pending Qaza record'),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: selected.isEmpty || working ? null : _completeSelected,
                  icon: Icon(working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded),
                  label: Text(working ? 'Completing...' : 'Complete ${selected.length} selected'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
}

class _EmptyCompletionState extends StatelessWidget {
  const _EmptyCompletionState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 40),
            SizedBox(height: 10),
            Text('No pending Qaza for this prayer.'),
            SizedBox(height: 4),
            Text('Choose another prayer or add a Qaza record first.'),
          ],
        ),
      );
}

class _EmptyPendingDates extends StatelessWidget {
  const _EmptyPendingDates();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 40),
              SizedBox(height: 10),
              Text('No pending Qaza records.'),
              SizedBox(height: 4),
              Text('This prayer is currently up to date.'),
            ],
          ),
        ),
      );
}
