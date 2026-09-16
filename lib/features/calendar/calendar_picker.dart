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

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isQazaDate(DateTime date) =>
      widget.qazaDates.any((qaza) => _sameDay(qaza, date));

  String _hijriLabel(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} AH';
  }

  String _gregorianLabel(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  void _goMonth(int delta) {
    final next = DateTime(_monthAnchor.year, _monthAnchor.month + delta, 1);
    final minimum = DateTime(1950, 1, 1);
    final maximum = DateTime(_today.year, _today.month, 1);
    if (next.isBefore(minimum) || next.isAfter(maximum)) return;
    setState(() => _monthAnchor = next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final selected = state.selectedDates;
    final minimum = DateTime(1950, 1, 1);
    final canPrevious = _monthAnchor.isAfter(minimum);
    final canNext = _monthAnchor.isBefore(DateTime(_today.year, _today.month, 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calendar_prev_month'),
              tooltip: 'Previous month',
              onPressed: canPrevious ? () => _goMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    MaterialLocalizations.of(context).formatMonthYear(_monthAnchor),
                    key: const Key('calendar_month_header'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _hijriLabel(_monthAnchor),
                    key: const Key('calendar_hijri_month_label'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month'),
              tooltip: 'Next month',
              onPressed: canNext ? () => _goMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          switch (state.selectionMode) {
            DateSelectionMode.single => 'Select one date.',
            DateSelectionMode.range => selected.length < 2
                ? 'Select a start date, then an end date.'
                : 'Range selected: ${selected.length} days.',
            DateSelectionMode.multiple =>
                '${selected.length} date${selected.length == 1 ? '' : 's'} selected.',
          },
          key: const Key('calendar_selection_prompt'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _DayGrid(
          anchor: _monthAnchor,
          today: _today,
          selectedDates: selected,
          onDayTap: (date) =>
              ref.read(calendarControllerProvider.notifier).select(date),
          hijriLabel: _hijriLabel,
          gregorianLabel: (date) => _gregorianLabel(context, date),
          isQazaDate: _isQazaDate,
        ),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.anchor,
    required this.today,
    required this.selectedDates,
    required this.onDayTap,
    required this.hijriLabel,
    required this.gregorianLabel,
    required this.isQazaDate,
  });

  final DateTime anchor;
  final DateTime today;
  final List<DateTime> selectedDates;
  final ValueChanged<DateTime> onDayTap;
  final String Function(DateTime) hijriLabel;
  final String Function(DateTime) gregorianLabel;
  final bool Function(DateTime) isQazaDate;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _selected(DateTime day) =>
      selectedDates.any((date) => _sameDay(date, day));

  bool _inRange(DateTime day) =>
      selectedDates.length == 2 &&
      !day.isBefore(selectedDates.first) &&
      !day.isAfter(selectedDates.last);

  bool _rangeEndpoint(DateTime day) =>
      selectedDates.length == 2 &&
      (_sameDay(day, selectedDates.first) ||
          _sameDay(day, selectedDates.last));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final leading = anchor.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const size = 44.0;

    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Center(child: Text('Mo'))),
            Expanded(child: Center(child: Text('Tu'))),
            Expanded(child: Center(child: Text('We'))),
            Expanded(child: Center(child: Text('Th'))),
            Expanded(child: Center(child: Text('Fr'))),
            Expanded(child: Center(child: Text('Sa'))),
            Expanded(child: Center(child: Text('Su'))),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size * 7,
          height: (totalCells ~/ 7) * size,
          child: Column(
            children: [
              for (var row = 0; row < totalCells ~/ 7; row++)
                SizedBox(
                  height: size,
                  child: Row(
                    children: [
                      for (var column = 0; column < 7; column++)
                        SizedBox(
                          width: size,
                          child: _cell(
                            context,
                            row * 7 + column,
                            leading,
                            daysInMonth,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int index, int leading, int daysInMonth) {
    final number = index - leading + 1;
    if (number < 1 || number > daysInMonth) return const SizedBox.shrink();

    final date = DateTime(anchor.year, anchor.month, number);
    final enabled = !date.isAfter(today) && !date.isBefore(DateTime(1950));
    final selected = _selected(date);
    final inRange = _inRange(date);
    final endpoint = _rangeEndpoint(date);
    final todayDate = _sameDay(date, today);
    final qaza = isQazaDate(date);
    final scheme = Theme.of(context).colorScheme;
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Semantics(
      label: '${gregorianLabel(date)}, ${hijriLabel(date)}',
      button: enabled,
      selected: selected,
      child: InkWell(
        key: Key('calendar_day_$dateKey'),
        onTap: enabled ? () => onDayTap(date) : null,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? scheme.primary
                    : endpoint
                        ? scheme.primaryContainer
                        : inRange
                            ? scheme.primaryContainer
                            : todayDate
                                ? scheme.secondaryContainer
                                : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? scheme.onPrimary : null,
                      fontWeight: todayDate || selected || endpoint
                          ? FontWeight.w700
                          : null,
                    ),
              ),
            ),
            if (qaza)
              Positioned(
                bottom: 2,
                child: Container(
                  key: Key('calendar_qaza_indicator_$dateKey'),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
