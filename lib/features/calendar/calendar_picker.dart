import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import 'calendar_controller.dart';

class CalendarPicker extends ConsumerStatefulWidget {
  const CalendarPicker({super.key, this.qazaDates = const <DateTime>{}});
  final Set<DateTime> qazaDates;
  @override
  ConsumerState<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends ConsumerState<CalendarPicker> {
  late DateTime _monthAnchor;

  @override
  void initState() {
    super.initState();
    final today = ref.read(calendarTodayProvider);
    _monthAnchor = DateTime(today.year, today.month, 1);
  }

  DateTime get _today => ref.read(calendarTodayProvider);
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isQazaDate(DateTime date) => widget.qazaDates.any((qaza) => _sameDay(qaza, date));
  String _hijriLabel(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} AH';
  }
  String _gregorianLabel(BuildContext context, DateTime date) => MaterialLocalizations.of(context).formatMediumDate(date);

  void _goMonth(int delta) {
    final next = DateTime(_monthAnchor.year, _monthAnchor.month + delta, 1);
    final minimum = DateTime(1950, 1, 1);
    final maximum = DateTime(_today.year, _today.month, 1);
    if (next.isBefore(minimum) || next.isAfter(maximum)) return;
    setState(() => _monthAnchor = next);
  }

  String _prompt(CalendarSelectionState state) {
    switch (state.selectionMode) {
      case DateSelectionMode.single:
        return state.hasSelection ? 'Date selected. Review the date below or choose another.' : 'Tap one date to select it.';
      case DateSelectionMode.range:
        if (!state.hasSelection) return 'Tap a start date, then tap an end date.';
        if (!state.isRangeComplete) return 'Now tap an end date on or after the start.';
        return '${state.selectedCount} days selected.';
      case DateSelectionMode.multiple:
        return state.hasSelection ? '${state.selectedCount} dates selected. Tap a selected date to remove it.' : 'Tap dates individually to select or deselect them.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final theme = Theme.of(context);
    final selected = state.selectedDates;
    final minimum = DateTime(1950, 1, 1);
    final canPrevious = _monthAnchor.isAfter(minimum);
    final canNext = _monthAnchor.isBefore(DateTime(_today.year, _today.month, 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(key: const Key('calendar_prev_month'), tooltip: 'Previous month', onPressed: canPrevious ? () => _goMonth(-1) : null, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: Column(children: [
            Text(MaterialLocalizations.of(context).formatMonthYear(_monthAnchor), key: const Key('calendar_month_header'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            Text(_hijriLabel(_monthAnchor), key: const Key('calendar_hijri_month_label'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ])),
          IconButton(key: const Key('calendar_next_month'), tooltip: 'Next month', onPressed: canNext ? () => _goMonth(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Text(_prompt(state), key: const Key('calendar_selection_prompt'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: 12),
        _DayGrid(anchor: _monthAnchor, today: _today, selectionMode: state.selectionMode, selectedDates: selected, onDayTap: (date) => ref.read(calendarControllerProvider.notifier).select(date), hijriLabel: _hijriLabel, gregorianLabel: (date) => _gregorianLabel(context, date), isQazaDate: _isQazaDate),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SelectionSummary(state: state, hijriLabel: _hijriLabel, gregorianLabel: (date) => _gregorianLabel(context, date), onClear: () => ref.read(calendarControllerProvider.notifier).clear()),
        ],
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.anchor, required this.today, required this.selectionMode, required this.selectedDates, required this.onDayTap, required this.hijriLabel, required this.gregorianLabel, required this.isQazaDate});
  final DateTime anchor, today;
  final DateSelectionMode selectionMode;
  final List<DateTime> selectedDates;
  final ValueChanged<DateTime> onDayTap;
  final String Function(DateTime) hijriLabel, gregorianLabel;
  final bool Function(DateTime) isQazaDate;
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _selected(DateTime day) => selectedDates.any((date) => _sameDay(date, day));
  bool _inRange(DateTime day) => selectionMode == DateSelectionMode.range && selectedDates.length == 2 && !day.isBefore(selectedDates.first) && !day.isAfter(selectedDates.last);
  bool _rangeEndpoint(DateTime day) => selectionMode == DateSelectionMode.range && selectedDates.length == 2 && (_sameDay(day, selectedDates.first) || _sameDay(day, selectedDates.last));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final leading = anchor.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const size = 44.0;
    return Column(children: [
      const Row(children: [Expanded(child: Center(child: Text('Mo'))), Expanded(child: Center(child: Text('Tu'))), Expanded(child: Center(child: Text('We'))), Expanded(child: Center(child: Text('Th'))), Expanded(child: Center(child: Text('Fr'))), Expanded(child: Center(child: Text('Sa'))), Expanded(child: Center(child: Text('Su')))]),
      const SizedBox(height: 4),
      SizedBox(width: size * 7, height: (totalCells ~/ 7) * size, child: Column(children: [
        for (var row = 0; row < totalCells ~/ 7; row++) SizedBox(height: size, child: Row(children: [for (var column = 0; column < 7; column++) SizedBox(width: size, child: _cell(context, row * 7 + column, leading, daysInMonth))])),
      ])),
    ]);
  }

  Widget _cell(BuildContext context, int index, int leading, int daysInMonth) {
    final number = index - leading + 1;
    if (number < 1 || number > daysInMonth) return const SizedBox.shrink();
    final date = DateTime(anchor.year, anchor.month, number);
    final enabled = !date.isAfter(today) && !date.isBefore(DateTime(1950));
    final selected = _selected(date), inRange = _inRange(date), endpoint = _rangeEndpoint(date), todayDate = _sameDay(date, today), qaza = isQazaDate(date);
    final scheme = Theme.of(context).colorScheme;
    final dateKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Semantics(label: '${gregorianLabel(date)}, ${hijriLabel(date)}', button: enabled, selected: selected, child: InkWell(key: Key('calendar_day_$dateKey'), onTap: enabled ? () => onDayTap(date) : null, borderRadius: BorderRadius.circular(22), child: Stack(alignment: Alignment.center, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? scheme.primary : endpoint || inRange ? scheme.primaryContainer : todayDate ? scheme.secondaryContainer : null), alignment: Alignment.center, child: Text('$number', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? scheme.onPrimary : null, fontWeight: todayDate || selected || endpoint ? FontWeight.w700 : null))),
      if (qaza) Positioned(bottom: 2, child: Container(key: Key('calendar_qaza_indicator_$dateKey'), width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.tertiary))),
    ])));
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.state, required this.hijriLabel, required this.gregorianLabel, required this.onClear});
  final CalendarSelectionState state;
  final String Function(DateTime) hijriLabel, gregorianLabel;
  final VoidCallback onClear;

  Widget _dateLine(BuildContext context, DateTime date, String label) {
    final theme = Theme.of(context);
    return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, foregroundColor: theme.colorScheme.onPrimaryContainer, child: Text('${date.day}', style: theme.textTheme.labelLarge)), title: Text(label), subtitle: Text(hijriLabel(date)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), dates = state.selectedDates;
    final title = switch (state.selectionMode) { DateSelectionMode.single => 'Selected date', DateSelectionMode.range => 'Selected range', DateSelectionMode.multiple => '${state.selectedCount} selected dates' };
    return Card(key: const Key('calendar_selected_summary'), child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(title, style: theme.textTheme.titleSmall)), TextButton(key: const Key('calendar_clear_selection'), onPressed: onClear, child: const Text('Clear'))]),
      const Divider(height: 12),
      if (state.selectionMode == DateSelectionMode.multiple) ...dates.map((date) => _dateLine(context, date, gregorianLabel(date)))
      else if (dates.length == 1) _dateLine(context, dates.single, gregorianLabel(dates.single))
      else if (dates.length == 2) ...[_dateLine(context, dates.first, 'Start · ${gregorianLabel(dates.first)}'), _dateLine(context, dates.last, 'End · ${gregorianLabel(dates.last)}')],
      if (state.selectionMode == DateSelectionMode.single && dates.length == 1 || state.selectionMode == DateSelectionMode.range && state.isRangeComplete) _continueHint(context),
      if (state.selectionMode == DateSelectionMode.multiple) Text('Review the selected dates before continuing.', style: theme.textTheme.bodySmall),
    ])));
  }

  Widget _continueHint(BuildContext context) => Text('Selection ready to continue.', key: const Key('calendar_continue_ready'), style: Theme.of(context).textTheme.bodySmall);
}
