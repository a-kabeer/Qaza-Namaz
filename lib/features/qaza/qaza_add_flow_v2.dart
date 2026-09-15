import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_picker.dart';
import '../ui/components.dart';

class QazaAddFlowV2Screen extends ConsumerStatefulWidget {
  const QazaAddFlowV2Screen({super.key});

  @override
  ConsumerState<QazaAddFlowV2Screen> createState() => _QazaAddFlowV2ScreenState();
}

class _QazaAddFlowV2ScreenState extends ConsumerState<QazaAddFlowV2Screen> {
  DateSelectionMode get dateMode => ref.watch(calendarControllerProvider).selectionMode;
  Set<PrayerType> prayers = <PrayerType>{};
  List<QazaRecord> existing = const [];
  bool checking = false;
  bool saving = false;
  int step = 0;

  List<DateTime> get dates => ref.read(calendarControllerProvider).selectedDates.toList();
  int get totalCombinations => dates.length * prayers.length;

  int get existingCombinations {
    final keys = existing.map((r) => '${r.prayerType.name}_${_dateKey(r.originalDate)}').toSet();
    return dates.expand((d) => prayers.map((p) => '${p.name}_${_dateKey(d)}')).where(keys.contains).length;
  }

  int get newCombinations => totalCombinations - existingCombinations;
  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  QazaService get service => ref.read(qazaServiceProvider);
  String get userId => ref.read(requiredUserIdProvider);

  Future<void> _checkExisting() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      existing = await service.getRecords(userId: userId);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _openDateStep() async {
    await _checkExisting();
    if (mounted) setState(() => step = 1);
  }

  Future<void> _continueFromDates() async {
    if (dates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one date.')));
      return;
    }
    await _checkExisting();
    if (mounted) setState(() => step = 2);
  }

  Future<void> _confirmAndSave() async {
    if (prayers.isEmpty || newCombinations <= 0 || saving) return;
    setState(() => saving = true);
    try {
      await service.recordQazaForDates(userId: userId, dates: dates, prayerTypes: prayers);
      if (!mounted) return;
      final created = newCombinations;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Qaza records created'),
          content: Text('$created independent Qaza record${created == 1 ? '' : 's'} were added to your ledger.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context, created);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Add Qaza'),
          leading: IconButton(
            tooltip: step == 0 ? 'Close' : 'Back',
            onPressed: () => step == 0 ? Navigator.pop(context) : setState(() => step--),
            icon: Icon(step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressHeader(step: step),
              Expanded(child: switch (step) {0 => _modeStep(), 1 => _dateStep(), _ => _prayerStep()}),
            ],
          ),
        ),
      );

  Widget _modeStep() => ListView(
        key: const ValueKey('qaza_step_list_0'),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Step 1 of 3 • Range Setup', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('Add Qaza', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Choose the calendar and date selection method.'),
          const SizedBox(height: 22),
          _ChoiceCard(
            title: 'Calendar',
            icon: Icons.calendar_month_rounded,
            child: SegmentedButton<CalendarMode>(
              segments: const [
                ButtonSegment(value: CalendarMode.gregorian, icon: Icon(Icons.calendar_today_rounded), label: Text('Gregorian')),
                ButtonSegment(value: CalendarMode.hijri, icon: Icon(Icons.nightlight_round), label: Text('Hijri')),
              ],
              selected: {ref.watch(calendarControllerProvider).calendarMode},
              onSelectionChanged: (value) => ref.read(calendarControllerProvider.notifier).setCalendarMode(value.first),
            ),
          ),
          const SizedBox(height: 14),
          _ChoiceCard(
            title: 'Date selection',
            icon: Icons.date_range_rounded,
            child: SegmentedButton<DateSelectionMode>(
              segments: const [
                ButtonSegment(value: DateSelectionMode.single, icon: Icon(Icons.today_rounded), label: Text('Single')),
                ButtonSegment(value: DateSelectionMode.range, icon: Icon(Icons.date_range_rounded), label: Text('Range')),
                ButtonSegment(value: DateSelectionMode.multiple, icon: Icon(Icons.library_add_check_rounded), label: Text('Multiple')),
              ],
              selected: {dateMode},
              onSelectionChanged: (value) => ref.read(calendarControllerProvider.notifier).setSelectionMode(value.first),
            ),
          ),
          const SizedBox(height: 18),
          const _InfoBox(text: 'Each date + prayer combination becomes one independent Qaza record. Witr remains separate from Isha. Records always store Gregorian originalDate.'),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: checking ? null : _openDateStep, icon: Icon(checking ? Icons.sync_rounded : Icons.arrow_forward_rounded), label: Text(checking ? 'Loading ledger...' : 'Continue')),
        ],
      );

  Widget _dateStep() {
    final state = ref.watch(calendarControllerProvider);
    final qazaDates = existing.map((r) => DateTime(r.originalDate.year, r.originalDate.month, r.originalDate.day)).toSet();
    return ListView(
      key: const ValueKey('qaza_step_list_1'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Step 2 of 3 • Date Selection', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(state.selectionMode == DateSelectionMode.single ? 'Choose a date' : state.selectionMode == DateSelectionMode.range ? 'Choose a date range' : 'Choose multiple dates', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Only today and earlier dates can be recorded.'),
        const SizedBox(height: 16),
        CalendarPicker(key: const Key('qaza_calendar_picker'), qazaDates: qazaDates),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: checking || dates.isEmpty ? null : _continueFromDates, icon: Icon(checking ? Icons.sync_rounded : Icons.arrow_forward_rounded), label: Text(checking ? 'Checking ledger...' : 'Next: Choose missed prayers')),
      ],
    );
  }

  Widget _prayerStep() {
    final all = prayers.length == PrayerType.values.length;
    return ListView(
      key: const ValueKey('qaza_step_list_2'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Step 3 of 3 • Ledger Entry', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        const Text('Missed Prayers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${dates.length} ${dates.length == 1 ? 'day' : 'days'} • Select every prayer that was missed.'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => prayers.addAll(PrayerType.values)), icon: Icon(all ? Icons.done_all_rounded : Icons.select_all_rounded), label: const Text('Select All'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: prayers.isEmpty ? null : () => setState(prayers.clear), icon: const Icon(Icons.clear_all_rounded), label: const Text('Clear'))),
        ]),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values)
          Card(margin: const EdgeInsets.only(bottom: 8), child: CheckboxListTile(value: prayers.contains(prayer), onChanged: saving ? null : (value) => setState(() => value == true ? prayers.add(prayer) : prayers.remove(prayer)), secondary: CircleAvatar(child: Icon(prayer.icon)), title: Text(prayer.label), subtitle: Text(prayer.rakats), controlAffinity: ListTileControlAffinity.trailing)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _SummaryRow(label: 'Dates', value: '${dates.length}'),
          _SummaryRow(label: 'Prayers per date', value: '${prayers.length}'),
          _SummaryRow(label: 'Existing combinations', value: '$existingCombinations'),
          _SummaryRow(label: 'New records', value: '$newCombinations', emphasis: true),
        ]))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: prayers.isEmpty || newCombinations <= 0 || saving ? null : _confirmAndSave, icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.verified_rounded), label: Text(saving ? 'Creating Records...' : 'Review & Create Records')),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= step ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                  ),
                ),
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= step ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i <= step ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(const ['Method', 'Dates', 'Review'][i], style: Theme.of(context).textTheme.labelMedium),
            ],
          ],
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleMedium)]), const SizedBox(height: 14), child])));
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.45), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.info_outline_rounded), const SizedBox(width: 10), Expanded(child: Text(text))]));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label)), Text(value, style: emphasis ? Theme.of(context).textTheme.titleMedium : null)]));
}
