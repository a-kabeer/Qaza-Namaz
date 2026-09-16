import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/prayer_card.dart';
import '../../domain/entities/qaza_record.dart';
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
  List<QazaRecord> existing = const [];
  bool checking = false;
  bool saving = false;
  int step = 0;

  int get totalCombinations => dates.length * prayers.length;
  int get existingCombinations {
    final keys = existing.map((r) => '${r.prayerType.name}_${_dateKey(r.originalDate)}').toSet();
    return dates.expand((d) => prayers.map((p) => '${p.name}_${_dateKey(d)}')).where(keys.contains).length;
  }
  int get newCombinations => totalCombinations - existingCombinations;

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: step,
        children: [
          _methodStep(),
          _dateStep(),
          _prayerStep(),
        ],
      ),
    );
  }

  Widget _methodStep() => ListView(
        key: const ValueKey('qaza_step_list_0'),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Step 1 of 3 • Method'),
          const SizedBox(height: 6),
          Text('Add Qaza', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Choose how you want to select your missed dates.'),
          const SizedBox(height: 16),
          SegmentedButton<DateSelectionMode>(
            segments: const [
              ButtonSegment(value: DateSelectionMode.single, label: Text('Single')),
              ButtonSegment(value: DateSelectionMode.range, label: Text('Range')),
              ButtonSegment(value: DateSelectionMode.multiple, label: Text('Multiple')),
            ],
            selected: {dateMode},
            onSelectionChanged: (value) => ref.read(calendarControllerProvider.notifier).setSelectionMode(value.first),
          ),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Gregorian calendar is used for all selections and storage. Hijri is shown as secondary date information.', style: Theme.of(context).textTheme.bodyMedium))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => setState(() => step = 1), child: const Text('Continue to dates')),
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

  Future<void> _continueFromDates() async {
    setState(() => step = 2);
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(label)), Text(value, style: emphasis ? Theme.of(context).textTheme.titleMedium : null)]);
}
