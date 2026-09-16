import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_availability_service.dart';
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

  static const _availability = QazaAvailabilityService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExisting());
  }

  QazaAvailabilityAnalysis _analysisFor(Iterable<PrayerType> prayerTypes) {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      return QazaAvailabilityAnalysis(
        total: dates.length * prayerTypes.length,
        alreadyRecorded: 0,
        alreadyPrayed: 0,
        newCount: dates.length * prayerTypes.length,
        candidates: const [],
        newCandidates: const [],
      );
    }
    return _availability.analyze(
      userId: userId,
      dates: dates,
      prayerTypes: prayerTypes,
      existingRecords: existing,
    );
  }

  QazaAvailabilityAnalysis get selectedAnalysis => _analysisFor(prayers);

  Future<void> _checkExisting() async {
    if (checking || !mounted) return;
    setState(() => checking = true);
    try {
      existing = await ref.read(qazaRecordsProvider.future);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _continueFromDates() async {
    if (dates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one date.')),
      );
      return;
    }

    await _checkExisting();
    if (!mounted) return;

    final userId = ref.read(activeUserIdProvider);
    if (userId != null && !_availability.isDateAvailable(
      userId: userId,
      date: dates.first,
      existingRecords: existing,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible prayers remain for the selected date(s).')),
      );
      return;
    }

    setState(() => step = 1);
  }

  void _changeDateMode(DateSelectionMode mode) {
    ref.read(calendarControllerProvider.notifier).setSelectionMode(mode);
    setState(() => prayers.clear());
  }

  void _clearDates() {
    ref.read(calendarControllerProvider.notifier).clear();
    setState(() => prayers.clear());
  }

  void _continueFromPrayers() {
    final analysis = selectedAnalysis;
    if (prayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one missed prayer.')),
      );
      return;
    }
    if (analysis.newCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All selected prayer combinations are already tracked.')),
      );
      return;
    }
    setState(() => step = 2);
  }

  Future<void> _confirmAndSave() async {
    if (prayers.isEmpty || selectedAnalysis.newCount <= 0 || saving) return;
    setState(() => saving = true);
    try {
      final userId = ref.read(requiredUserIdProvider);
      final before = _availability.analyze(
        userId: userId,
        dates: dates,
        prayerTypes: prayers,
        existingRecords: existing,
      );

      await ref.read(qazaServiceProvider).recordQazaForDates(
            userId: userId,
            dates: dates,
            prayerTypes: prayers,
          );

      final after = await ref.read(qazaServiceProvider).getRecords(userId: userId);
      final afterAnalysis = _availability.analyze(
        userId: userId,
        dates: dates,
        prayerTypes: prayers,
        existingRecords: after,
      );
      final created = (before.newCount - afterAnalysis.newCount).clamp(0, before.newCount);

      if (!mounted) return;
      if (created == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing new was added. The selected combinations are already tracked.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Qaza records created'),
          content: Text(
            '$created independent Qaza record${created == 1 ? '' : 's'} were added to your ledger. Existing records were preserved.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
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
            onPressed: () => step == 0
                ? Navigator.pop(context)
                : setState(() => step--),
            icon: Icon(
              step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressHeader(step: step),
              Expanded(
                child: switch (step) {
                  0 => _dateStep(),
                  1 => _prayerStep(),
                  _ => _reviewStep(),
                },
              ),
            ],
          ),
        ),
      );

  Widget _dateStep() {
    final state = ref.watch(calendarControllerProvider);
    final qazaDates = existing
        .map((r) => DateTime(r.originalDate.year, r.originalDate.month, r.originalDate.day))
        .toSet();
    final userId = ref.read(activeUserIdProvider);
    final isDateUnavailable = userId == null
        ? null
        : (DateTime date) => !_availability.isDateAvailable(
              userId: userId,
              date: date,
              existingRecords: existing,
            );

    return ListView(
      key: const ValueKey('qaza_step_list_0'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Step 1 of 3 • Select Dates', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Select Dates', key: const Key('qaza_flow_heading'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Choose a single date, a range, or multiple dates. Only today and earlier dates can be recorded.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
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
            onSelectionChanged: checking ? null : (value) => _changeDateMode(value.first),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBox(
          text: 'Gregorian and Hijri dates are shown by the calendar. A date remains selectable when at least one prayer is still eligible.',
        ),
        const SizedBox(height: 16),
        CalendarPicker(
          key: const Key('qaza_calendar_picker'),
          qazaDates: qazaDates,
          isDateUnavailable: isDateUnavailable,
        ),
        const SizedBox(height: 12),
        _DateSelectionSummary(dates: dates, mode: state.selectionMode, onClear: dates.isEmpty ? null : _clearDates),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('qaza_continue_button'),
          onPressed: checking || dates.isEmpty ? null : _continueFromDates,
          icon: Icon(checking ? Icons.sync_rounded : Icons.arrow_forward_rounded),
          label: Text(checking ? 'Checking ledger...' : 'Next: Missed Prayers'),
        ),
      ],
    );
  }

  Widget _prayerStep() {
    final allAvailable = PrayerType.values.every(
      (prayer) => _analysisFor([prayer]).newCount > 0,
    );
    final analysis = selectedAnalysis;

    return ListView(
      key: const ValueKey('qaza_step_list_1'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Step 2 of 3 • Select Missed Prayers', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Select Missed Prayers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${dates.length} ${dates.length == 1 ? 'date' : 'dates'} selected • Choose the prayers that were missed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: checking || saving
                    ? null
                    : () => setState(() {
                          prayers.addAll(
                            PrayerType.values.where(
                              (prayer) => _analysisFor([prayer]).newCount > 0,
                            ),
                          );
                        }),
                icon: Icon(allAvailable ? Icons.done_all_rounded : Icons.select_all_rounded),
                label: const Text('Select Available'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: prayers.isEmpty || saving ? null : () => setState(prayers.clear),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values) _prayerOption(prayer),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(label: 'Dates', value: '${dates.length}'),
                _SummaryRow(label: 'Selected prayers', value: '${prayers.length}'),
                _SummaryRow(label: 'Already tracked', value: '${analysis.alreadyRecorded}'),
                if (analysis.alreadyPrayed > 0)
                  _SummaryRow(label: 'Already prayed', value: '${analysis.alreadyPrayed}'),
                _SummaryRow(label: 'New records', value: '${analysis.newCount}', emphasis: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('qaza_prayers_continue_button'),
          onPressed: prayers.isEmpty || analysis.newCount <= 0 || saving ? null : _continueFromPrayers,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review & Add'),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final analysis = selectedAnalysis;
    return ListView(
      key: const ValueKey('qaza_step_list_2'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Step 3 of 3 • Review & Add', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Review & Add', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Review the exact date + prayer combinations before they are added to your Qaza ledger.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected dates', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _DateSelectionSummary(dates: dates, mode: dateMode),
                const SizedBox(height: 16),
                Text('Selected prayers', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(prayers.map((prayer) => prayer.label).join(' • ')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(label: 'Total combinations', value: '${analysis.total}'),
                _SummaryRow(label: 'Already tracked', value: '${analysis.alreadyRecorded}'),
                if (analysis.alreadyPrayed > 0)
                  _SummaryRow(label: 'Already prayed', value: '${analysis.alreadyPrayed}'),
                _SummaryRow(label: 'New records', value: '${analysis.newCount}', emphasis: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoBox(
          text: 'Only new date + prayer combinations will be created. Existing records are preserved, and Witr remains an independent prayer record.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('qaza_final_add_button'),
          onPressed: analysis.newCount <= 0 || saving ? null : _confirmAndSave,
          icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.add_task_rounded),
          label: Text(saving ? 'Adding Qaza...' : 'Add ${analysis.newCount} New Qaza'),
        ),
      ],
    );
  }

  Widget _prayerOption(PrayerType prayer) {
    final analysis = _analysisFor([prayer]);
    final available = analysis.newCount > 0;
    final selected = prayers.contains(prayer);
    final scheme = Theme.of(context).colorScheme;
    final status = analysis.alreadyPrayed > 0 && analysis.newCount == 0
        ? 'Already prayed for selected date${dates.length == 1 ? '' : 's'}'
        : analysis.newCount == 0
            ? 'Already tracked for all selected dates'
            : analysis.newCount == dates.length
                ? 'Available for all ${dates.length} date${dates.length == 1 ? '' : 's'}'
                : 'Available for ${analysis.newCount} of ${dates.length} selected dates';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: selected && available,
        onChanged: saving || !available
            ? null
            : (value) => setState(() {
                  if (value == true) {
                    prayers.add(prayer);
                  } else {
                    prayers.remove(prayer);
                  }
                }),
        secondary: CircleAvatar(
          backgroundColor: available ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Icon(
            prayer.icon,
            color: available ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(prayer.label),
        subtitle: Text('$status • ${prayer.rakats}'),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
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
    const labels = ['Dates', 'Prayers', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= step ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            CircleAvatar(
              radius: 14,
              backgroundColor: i <= step ? scheme.primary : scheme.surfaceContainerHighest,
              child: Text(
                '${i + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i <= step ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              labels[i],
              style: theme.textTheme.labelMedium?.copyWith(
                color: i <= step ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: i == step ? FontWeight.w700 : null,
              ),
            ),
          ],
        ],
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _DateSelectionSummary extends StatelessWidget {
  const _DateSelectionSummary({required this.dates, required this.mode, this.onClear});
  final List<DateTime> dates;
  final DateSelectionMode mode;
  final VoidCallback? onClear;

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = dates.isEmpty
        ? 'No dates selected'
        : dates.length == 1
            ? 'Selected date: ${_formatDate(dates.first)}'
            : mode == DateSelectionMode.range
                ? 'Selected range: ${_formatDate(dates.first)} – ${_formatDate(dates.last)} (${dates.length} days)'
                : 'Selected dates: ${dates.length}';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.event_available_rounded),
        title: Text(text, style: theme.textTheme.bodyMedium),
        trailing: onClear == null
            ? null
            : IconButton(
                key: const Key('qaza_clear_dates_button'),
                tooltip: 'Clear selected dates',
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
              ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: emphasis ? Theme.of(context).textTheme.titleMedium : null),
          ],
        ),
      );
}
