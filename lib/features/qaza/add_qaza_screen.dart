import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/prayer_card.dart';
import '../../domain/services/qaza_bounded_availability.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_picker.dart';

class AddQazaScreen extends ConsumerStatefulWidget {
  const AddQazaScreen({super.key});
  @override
  ConsumerState<AddQazaScreen> createState() => _AddQazaScreenState();
}

class _AddQazaScreenState extends ConsumerState<AddQazaScreen> {
  DateSelectionMode get dateMode => ref.watch(calendarControllerProvider).selectionMode;
  List<DateTime> get dates => ref.read(calendarControllerProvider).datesForStorage.toList();
  Set<PrayerType> prayers = <PrayerType>{};
  int existingCombinations = 0;
  int newCombinations = 0;
  bool checking = false;
  bool saving = false;
  int step = 0;

  int get totalCombinations => dates.length * prayers.length;

  Future<void> _refreshAvailability() async {
    if (checking || dates.isEmpty || prayers.isEmpty) return;
    setState(() => checking = true);
    try {
      final analysis = await ref.read(qazaServiceProvider).analyzeAvailabilityBounded(
        userId: ref.read(requiredUserIdProvider),
        dates: dates,
        prayerTypes: prayers,
      );
      if (!mounted) return;
      setState(() {
        existingCombinations = analysis.alreadyRecorded + analysis.alreadyPrayed;
        newCombinations = analysis.newCount;
      });
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _openDateStep() async {
    if (mounted) setState(() => step = 1);
  }

  Future<void> _continueFromDates() async {
    if (dates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one date.')));
      return;
    }
    if (mounted) setState(() => step = 2);
  }

  Future<void> _togglePrayer(PrayerType prayer, bool selected) async {
    setState(() => selected ? prayers.add(prayer) : prayers.remove(prayer));
    if (prayers.isEmpty) {
      setState(() {
        existingCombinations = 0;
        newCombinations = 0;
      });
      return;
    }
    await _refreshAvailability();
  }

  Future<void> _selectAll() async {
    setState(() => prayers.addAll(PrayerType.values));
    await _refreshAvailability();
  }

  Future<void> _clearAll() async {
    setState(() {
      prayers.clear();
      existingCombinations = 0;
      newCombinations = 0;
    });
  }

  Future<void> _confirmAndSave() async {
    if (prayers.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final before = newCombinations;
      await ref.read(qazaServiceProvider).recordQazaForDatesBounded(
        userId: ref.read(requiredUserIdProvider),
        dates: dates,
        prayerTypes: prayers,
      );
      if (!mounted) return;
      final created = before;
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
      child: Column(children: [
        _ProgressHeader(step: step),
        Expanded(child: switch (step) {0 => _modeStep(), 1 => _dateStep(), _ => _prayerStep()}),
      ]),
    ),
  );

  Widget _modeStep() => ListView(
    key: const ValueKey('qaza_step_list_0'),
    padding: const EdgeInsets.all(20),
    children: [
      Text('Step 1 of 3 • Range Setup', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Text('Add Qaza', key: const Key('qaza_flow_heading'), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('Choose the date selection method.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 22),
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
      const _InfoBox(text: 'Gregorian is the source of truth for selection and storage. Hijri dates are shown as secondary information. Each date + prayer combination becomes one independent Qaza record.'),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const Key('qaza_continue_button'),
        onPressed: _openDateStep,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Continue'),
      ),
    ],
  );

  Widget _dateStep() {
    final state = ref.watch(calendarControllerProvider);
    return ListView(
      key: const ValueKey('qaza_step_list_1'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Step 2 of 3 • Date Selection', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          state.selectionMode == DateSelectionMode.single ? 'Choose a date' : state.selectionMode == DateSelectionMode.range ? 'Choose a date range' : 'Choose multiple dates',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text('Only today and earlier dates can be recorded.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        CalendarPicker(key: const Key('qaza_calendar_picker'), qazaDates: const <DateTime>{}),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: dates.isEmpty ? null : _continueFromDates,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Next: Choose missed prayers'),
        ),
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
        Text('Missed Prayers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${dates.length} ${dates.length == 1 ? 'day' : 'days'} • Select every prayer that was missed.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: checking || all ? null : _selectAll, icon: Icon(all ? Icons.done_all_rounded : Icons.select_all_rounded), label: const Text('Select All'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: checking || prayers.isEmpty ? null : _clearAll, icon: const Icon(Icons.clear_all_rounded), label: const Text('Clear'))),
        ]),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: prayers.contains(prayer),
              onChanged: saving || checking ? null : (value) => _togglePrayer(prayer, value == true),
              secondary: CircleAvatar(child: Icon(prayer.icon)),
              title: Text(prayer.label),
              subtitle: Text(prayer.rakats),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _SummaryRow(label: 'Dates', value: '${dates.length}'),
          _SummaryRow(label: 'Prayers per date', value: '${prayers.length}'),
          _SummaryRow(label: 'Existing combinations', value: '$existingCombinations'),
          _SummaryRow(label: 'New records', value: '$newCombinations', emphasis: true),
        ]))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: prayers.isEmpty || newCombinations <= 0 || saving || checking ? null : _confirmAndSave,
          icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.verified_rounded),
          label: Text(saving ? 'Creating Records...' : 'Review & Create Records'),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) Expanded(child: Container(height: 2, color: i <= step ? scheme.primary : scheme.outlineVariant)),
          CircleAvatar(radius: 14, backgroundColor: i <= step ? scheme.primary : scheme.surfaceContainerHighest, child: Text('${i + 1}', style: theme.textTheme.labelSmall?.copyWith(color: i <= step ? scheme.onPrimary : scheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          Text(const ['Method', 'Dates', 'Review'][i], style: theme.textTheme.labelMedium?.copyWith(color: i <= step ? scheme.onSurface : scheme.onSurfaceVariant, fontWeight: i == step ? FontWeight.w700 : null)),
        ],
      ]),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: scheme.onSurfaceVariant), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleMedium)]),
      const SizedBox(height: 14),
      child,
    ])));
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.info_outline_rounded, color: scheme.onPrimaryContainer), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)))]));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label)), Text(value, style: emphasis ? Theme.of(context).textTheme.titleMedium : null)]));
}
