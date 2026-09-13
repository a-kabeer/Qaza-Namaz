import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';

enum QazaDateMode { single, range }
enum QazaCalendarMode { gregorian, hijri }

class QazaAddFlowV2Screen extends StatefulWidget {
  const QazaAddFlowV2Screen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<QazaAddFlowV2Screen> createState() => _QazaAddFlowV2ScreenState();
}

class _QazaAddFlowV2ScreenState extends State<QazaAddFlowV2Screen> {
  static final DateTime firstDate = DateTime(1950);

  QazaDateMode dateMode = QazaDateMode.single;
  QazaCalendarMode calendarMode = QazaCalendarMode.gregorian;
  DateTime? startDate;
  DateTime? endDate;
  final Set<PrayerType> prayers = {};
  List<QazaRecord> existing = const [];
  bool checking = false;
  bool saving = false;
  int step = 0;

  List<DateTime> get dates {
    if (startDate == null) return const [];
    if (dateMode == QazaDateMode.single || endDate == null) return [_dateOnly(startDate!)];
    final result = <DateTime>[];
    var cursor = _dateOnly(startDate!);
    final end = _dateOnly(endDate!);
    while (!cursor.isAfter(end)) {
      result.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  int get totalCombinations => dates.length * prayers.length;

  int get existingCombinations {
    final keys = existing.map((r) => '${r.prayerType.name}_${_key(r.originalDate)}').toSet();
    return dates
        .expand((d) => prayers.map((p) => '${p.name}_${_key(d)}'))
        .where(keys.contains)
        .length;
  }

  int get newCombinations => totalCombinations - existingCombinations;

  Future<void> _checkExisting() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      existing = await widget.service.getRecords(userId: widget.userId);
    } catch (_) {
      existing = const [];
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  void _continueFromMode() {
    if (calendarMode == QazaCalendarMode.hijri) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hijri calendar selection is reserved for the calendar engine task.')),
      );
      return;
    }
    setState(() => step = 1);
  }

  Future<void> _continueFromDates() async {
    if (dates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one date.')));
      return;
    }
    await _checkExisting();
    if (mounted) setState(() => step = 2);
  }

  Future<void> _pickSingle() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDate: startDate ?? now,
      helpText: 'Select Qaza date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      startDate = _dateOnly(picked);
      endDate = null;
      existing = const [];
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = _dateOnly(startDate ?? now.subtract(const Duration(days: 6)));
    final initialEnd = _dateOnly(endDate ?? initialStart);
    final safeStart = initialStart.isBefore(firstDate) ? firstDate : (initialStart.isAfter(now) ? now : initialStart);
    final safeEnd = initialEnd.isBefore(safeStart) ? safeStart : (initialEnd.isAfter(now) ? now : initialEnd);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      helpText: 'Select Qaza date range',
    );
    if (picked == null || !mounted) return;
    setState(() {
      startDate = _dateOnly(picked.start);
      endDate = _dateOnly(picked.end);
      existing = const [];
    });
  }

  Future<void> _confirmAndSave() async {
    if (prayers.isEmpty || newCombinations <= 0 || saving) return;
    setState(() => saving = true);
    try {
      await widget.service.recordQazaForDates(
        userId: widget.userId,
        dates: dates,
        prayerTypes: prayers,
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
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
            Expanded(
              child: switch (step) {
                0 => _modeStep(),
                1 => _dateStep(),
                _ => _prayerStep(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeStep() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Step 1 of 3 • Range Setup', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('Add Qaza', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Choose how you want to identify the missed-prayer dates.'),
          const SizedBox(height: 22),
          _ChoiceCard(
            title: 'Calendar',
            icon: Icons.calendar_month_rounded,
            child: SegmentedButton<QazaCalendarMode>(
              segments: const [
                ButtonSegment(value: QazaCalendarMode.gregorian, icon: Icon(Icons.calendar_today_rounded), label: Text('Gregorian')),
                ButtonSegment(value: QazaCalendarMode.hijri, icon: Icon(Icons.nightlight_round), label: Text('Hijri')),
              ],
              selected: {calendarMode},
              onSelectionChanged: (v) => setState(() => calendarMode = v.first),
            ),
          ),
          const SizedBox(height: 14),
          _ChoiceCard(
            title: 'Date selection',
            icon: Icons.date_range_rounded,
            child: SegmentedButton<QazaDateMode>(
              segments: const [
                ButtonSegment(value: QazaDateMode.single, icon: Icon(Icons.today_rounded), label: Text('Single Date')),
                ButtonSegment(value: QazaDateMode.range, icon: Icon(Icons.date_range_rounded), label: Text('Date Range')),
              ],
              selected: {dateMode},
              onSelectionChanged: (v) => setState(() {
                dateMode = v.first;
                if (dateMode == QazaDateMode.single) endDate = null;
                existing = const [];
              }),
            ),
          ),
          const SizedBox(height: 18),
          const _InfoBox(text: 'Each date + prayer combination becomes one independent Qaza record. Witr remains separate from Isha.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _continueFromMode,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
          ),
        ],
      );

  Widget _dateStep() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Step 2 of 3 • Date Selection', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('Choose ${dateMode == QazaDateMode.single ? 'a date' : 'a date range'}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Only today and earlier dates can be recorded. Future dates are locked by the picker.'),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_rounded),
              title: Text(dateMode == QazaDateMode.single ? 'Single Date' : 'Date Range'),
              subtitle: Text(_dateSummary()),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: dateMode == QazaDateMode.single ? _pickSingle : _pickRange,
            ),
          ),
          const SizedBox(height: 12),
          if (dates.isNotEmpty)
            _InfoBox(text: dateMode == QazaDateMode.single ? '1 day selected' : '${dates.length} days selected'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: checking || dates.isEmpty ? null : _continueFromDates,
            icon: Icon(checking ? Icons.sync_rounded : Icons.arrow_forward_rounded),
            label: Text(checking ? 'Checking ledger...' : 'Next: Choose missed prayers'),
          ),
        ],
      );

  Widget _prayerStep() {
    final all = prayers.length == PrayerType.values.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Step 3 of 3 • Ledger Entry', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Missed Prayers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${dates.length} ${dates.length == 1 ? 'day' : 'days'} • Select every prayer that was missed.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => prayers.addAll(PrayerType.values)), icon: Icon(all ? Icons.done_all_rounded : Icons.select_all_rounded), label: const Text('Select All'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: prayers.isEmpty ? null : () => setState(prayers.clear), icon: const Icon(Icons.clear_all_rounded), label: const Text('Clear'))),
          ],
        ),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: prayers.contains(prayer),
              onChanged: saving ? null : (v) => setState(() => v == true ? prayers.add(prayer) : prayers.remove(prayer)),
              secondary: CircleAvatar(child: Icon(_icon(prayer))),
              title: Text(prayer.label),
              subtitle: Text(_subtitle(prayer)),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(label: 'Days', value: '${dates.length}'),
                _SummaryRow(label: 'Prayers per day', value: '${prayers.length}'),
                _SummaryRow(label: 'Existing combinations', value: '$existingCombinations'),
                _SummaryRow(label: 'New records', value: '$newCombinations', emphasis: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: prayers.isEmpty || newCombinations <= 0 || saving ? null : _confirmAndSave,
          icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.verified_rounded),
          label: Text(saving ? 'Creating Records...' : 'Review & Create Records'),
        ),
        if (prayers.isNotEmpty && newCombinations <= 0)
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('All selected prayer/date combinations are already in your ledger.')),
      ],
    );
  }

  String _dateSummary() {
    if (startDate == null) return 'Tap to choose';
    if (dateMode == QazaDateMode.single) return _format(startDate!);
    return '${_format(startDate!)} – ${_format(endDate!)}';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _format(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
  IconData _icon(PrayerType p) => switch (p) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };
  String _subtitle(PrayerType p) => switch (p) {
        PrayerType.fajr => 'Fajr • 2 Rakat Fard',
        PrayerType.zuhr => 'Zuhr • 4 Rakat Fard',
        PrayerType.asr => 'Asr • 4 Rakat Fard',
        PrayerType.maghrib => 'Maghrib • 3 Rakat Fard',
        PrayerType.isha => 'Isha • 4 Rakat Fard',
        PrayerType.witr => 'Witr • 3 Rakat Wajib • Independent',
      };
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Method', 'Dates', 'Review'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: i <= step ? scheme.primary : Theme.of(context).dividerColor)),
            CircleAvatar(
              radius: 14,
              backgroundColor: i <= step ? scheme.primary : scheme.surfaceVariant,
              child: Text('${i + 1}', style: TextStyle(color: i <= step ? scheme.onPrimary : scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Text(labels[i], style: Theme.of(context).textTheme.labelMedium),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleMedium)]),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [const Icon(Icons.info_outline_rounded), const SizedBox(width: 10), Expanded(child: Text(text))]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(label)), Text(value, style: emphasis ? Theme.of(context).textTheme.titleMedium : null)]),
    );
  }
}
