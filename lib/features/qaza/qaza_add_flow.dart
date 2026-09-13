import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class QazaAddFlowScreen extends StatefulWidget {
  const QazaAddFlowScreen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<QazaAddFlowScreen> createState() => _QazaAddFlowScreenState();
}

enum _SelectionMode { single, range }
enum _CalendarMode { gregorian, hijri }

class _QazaAddFlowScreenState extends State<QazaAddFlowScreen> {
  static final DateTime _firstAllowedDate = DateTime(1950, 1, 1);

  _SelectionMode selectionMode = _SelectionMode.single;
  _CalendarMode calendarMode = _CalendarMode.gregorian;
  DateTime? startDate;
  DateTime? endDate;
  final Set<PrayerType> selectedPrayers = {};
  List<QazaRecord>? existingRecords;
  bool loadingRecords = false;
  bool saving = false;
  int step = 0;

  List<DateTime> get selectedDates {
    if (startDate == null) return const [];
    if (selectionMode == _SelectionMode.single || endDate == null) {
      return [DateTime(startDate!.year, startDate!.month, startDate!.day)];
    }

    final dates = <DateTime>[];
    var cursor = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final last = DateTime(endDate!.year, endDate!.month, endDate!.day);
    while (!cursor.isAfter(last)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  int get totalRecords => selectedDates.length * selectedPrayers.length;

  int get newRecords {
    final existing = existingRecords ?? const <QazaRecord>[];
    final keys = existing
        .map((record) => '${record.prayerType.name}_${_dateKey(record.originalDate)}')
        .toSet();
    return selectedDates
        .expand((date) => selectedPrayers.map((prayer) => '${prayer.name}_${_dateKey(date)}'))
        .where((key) => !keys.contains(key))
        .length;
  }

  Future<void> _loadExistingRecords() async {
    if (loadingRecords) return;
    setState(() => loadingRecords = true);
    try {
      existingRecords = await widget.service.getRecords(userId: widget.userId);
    } catch (_) {
      existingRecords = const [];
    } finally {
      if (mounted) setState(() => loadingRecords = false);
    }
  }

  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final initial = startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: _firstAllowedDate,
      lastDate: now,
      initialDate: initial.isAfter(now) ? now : initial,
      helpText: 'Select Qaza date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      startDate = DateTime(picked.year, picked.month, picked.day);
      endDate = null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = startDate ?? now.subtract(const Duration(days: 6));
    final safeStart = initialStart.isBefore(_firstAllowedDate)
        ? _firstAllowedDate
        : initialStart.isAfter(now)
            ? now
            : initialStart;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstAllowedDate,
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: safeStart,
        end: (endDate ?? safeStart).isAfter(now) ? now : (endDate ?? safeStart),
      ),
      helpText: 'Select Qaza date range',
    );
    if (picked == null || !mounted) return;
    setState(() {
      startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  void _nextFromMode() {
    if (calendarMode == _CalendarMode.hijri) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hijri calendar selection will be enabled with the calendar engine task.')),
      );
      return;
    }
    setState(() => step = 1);
  }

  void _nextFromDates() {
    if (selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one date.')));
      return;
    }
    setState(() => step = 2);
  }

  Future<void> _save() async {
    if (selectedDates.isEmpty || selectedPrayers.isEmpty || saving) return;

    setState(() => saving = true);
    try {
      await widget.service.recordQazaForDates(
        userId: widget.userId,
        dates: selectedDates,
        prayerTypes: selectedPrayers,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$newRecords new Qaza record${newRecords == 1 ? '' : 's'} added.')),
      );
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
          onPressed: () {
            if (step == 0) {
              Navigator.pop(context);
            } else {
              setState(() => step--);
            }
          },
          icon: Icon(step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepHeader(step: step),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (step) {
                  0 => _buildModeStep(),
                  1 => _buildDateStep(),
                  _ => _buildPrayerStep(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeStep() {
    return ListView(
      key: const ValueKey('mode'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Range Setup', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('How do you want to add your missed prayers?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Choose a calendar and whether this is a single missed date or a continuous date range.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: 'Calendar',
          icon: Icons.calendar_month_rounded,
          child: SegmentedButton<_CalendarMode>(
            segments: const [
              ButtonSegment(value: _CalendarMode.gregorian, icon: Icon(Icons.calendar_today_rounded), label: Text('Gregorian')),
              ButtonSegment(value: _CalendarMode.hijri, icon: Icon(Icons.nightlight_round), label: Text('Hijri')),
            ],
            selected: {calendarMode},
            onSelectionChanged: (value) => setState(() => calendarMode = value.first),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Selection type',
          icon: Icons.date_range_rounded,
          child: SegmentedButton<_SelectionMode>(
            segments: const [
              ButtonSegment(value: _SelectionMode.single, icon: Icon(Icons.today_rounded), label: Text('Single Date')),
              ButtonSegment(value: _SelectionMode.range, icon: Icon(Icons.date_range_rounded), label: Text('Date Range')),
            ],
            selected: {selectionMode},
            onSelectionChanged: (value) => setState(() {
              selectionMode = value.first;
              if (selectionMode == _SelectionMode.single) endDate = null;
            }),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Each selected prayer/date becomes an independent Qaza record. Witr stays separate from Isha.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _nextFromMode,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildDateStep() {
    final dateText = selectedDates.isEmpty
        ? 'No date selected'
        : selectionMode == _SelectionMode.single
            ? _formatDate(startDate!)
            : '${_formatDate(startDate!)} – ${_formatDate(endDate!)}';

    return ListView(
      key: const ValueKey('dates'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Date Selection', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          calendarMode == _CalendarMode.gregorian ? 'Choose Gregorian date(s)' : 'Choose Hijri date(s)',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Future dates are locked. Existing Qaza records are preserved and will not be duplicated.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.10),
              child: Icon(Icons.date_range_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(selectionMode == _SelectionMode.single ? 'Single Date' : 'Date Range'),
            subtitle: Text(dateText),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: loadingRecords
                ? null
                : selectionMode == _SelectionMode.single
                    ? _pickSingleDate
                    : _pickDateRange,
          ),
        ),
        const SizedBox(height: 12),
        if (selectedDates.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectionMode == _SelectionMode.single
                        ? '1 day selected'
                        : '${selectedDates.length} days selected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: selectionMode == _SelectionMode.single ? _pickSingleDate : _pickDateRange,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text('Only today and earlier dates can be recorded.', style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: selectedDates.isEmpty ? null : _nextFromDates,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next: Choose missed prayers'),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerStep() {
    final allSelected = selectedPrayers.length == PrayerType.values.length;
    return ListView(
      key: const ValueKey('prayers'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Ledger Entry', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Which prayers were missed?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${selectedDates.length} ${selectedDates.length == 1 ? 'day' : 'days'} • Select all that apply.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => selectedPrayers.addAll(PrayerType.values)),
                icon: Icon(allSelected ? Icons.done_all_rounded : Icons.select_all_rounded),
                label: const Text('Select All'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedPrayers.isEmpty ? null : () => setState(selectedPrayers.clear),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: selectedPrayers.contains(prayer),
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                        if (value == true) {
                          selectedPrayers.add(prayer);
                        } else {
                          selectedPrayers.remove(prayer);
                        }
                      }),
              secondary: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.10),
                child: Icon(_iconFor(prayer), color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(prayer.label),
              subtitle: Text(_subtitleFor(prayer)),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        const SizedBox(height: 8),
        _ReviewCard(
          days: selectedDates.length,
          selectedPrayers: selectedPrayers.length,
          existingRecords: totalRecords - newRecords,
          newRecords: newRecords,
          loading: loadingRecords,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: selectedPrayers.isEmpty || newRecords == 0 || loadingRecords || saving ? null : _showConfirmation,
            icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.verified_rounded),
            label: Text(saving ? 'Creating Records...' : 'Review & Create Records'),
          ),
        ),
        if (newRecords == 0 && selectedPrayers.isNotEmpty && !loadingRecords)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'All selected prayer/date combinations already exist in your ledger.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Future<void> _showConfirmation() async {
    if (existingRecords == null) await _loadExistingRecords();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review & Confirm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectionMode == _SelectionMode.single
                  ? 'Create Qaza for ${_formatDate(startDate!)}?'
                  : 'Create Qaza for ${selectedDates.length} selected days?',
            ),
            const SizedBox(height: 14),
            Text('Selected prayers: ${selectedPrayers.length}'),
            Text('New ledger records: $newRecords'),
            if (totalRecords - newRecords > 0) Text('Already recorded: ${totalRecords - newRecords}'),
            const SizedBox(height: 12),
            const Text('Witr is tracked as its own independent obligation and is never merged with Isha.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create Records')),
        ],
      ),
    );

    if (confirmed == true) await _save();
  }

  IconData _iconFor(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return Icons.wb_twilight_rounded;
      case PrayerType.zuhr:
        return Icons.wb_sunny_rounded;
      case PrayerType.asr:
        return Icons.sunny_snowing_rounded;
      case PrayerType.maghrib:
        return Icons.nights_stay_outlined;
      case PrayerType.isha:
        return Icons.dark_mode_outlined;
      case PrayerType.witr:
        return Icons.brightness_3_outlined;
    }
  }

  String _subtitleFor(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return 'Fajr • 2 Rakat Fard';
      case PrayerType.zuhr:
        return 'Zuhr • 4 Rakat Fard';
      case PrayerType.asr:
        return 'Asr • 4 Rakat Fard';
      case PrayerType.maghrib:
        return 'Maghrib • 3 Rakat Fard';
      case PrayerType.isha:
        return 'Isha • 4 Rakat Fard';
      case PrayerType.witr:
        return 'Witr • 3 Rakat Wajib • Independent';
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = ['Method', 'Dates', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
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
            Text(labels[i], style: Theme.of(context).textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
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
                Icon(icon, color: scheme.primary),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.days,
    required this.selectedPrayers,
    required this.existingRecords,
    required this.newRecords,
    required this.loading,
  });

  final int days;
  final int selectedPrayers;
  final int existingRecords;
  final int newRecords;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text('Ledger summary', style: Theme.of(context).textTheme.titleMedium)),
                if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const Divider(height: 24),
            _SummaryRow(label: 'Days', value: '$days'),
            _SummaryRow(label: 'Prayers per day', value: '$selectedPrayers'),
            _SummaryRow(label: 'Already recorded', value: '$existingRecords'),
            _SummaryRow(label: 'New records to create', value: '$newRecords', emphasize: true),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
