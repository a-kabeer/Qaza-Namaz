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
  late DateTime _gregorianAnchor;
  late int _hijriYear;
  late int _hijriMonth;

  @override
  void initState() {
    super.initState();
    _setAnchorFromGregorian(ref.read(calendarTodayProvider));
  }

  void _setAnchorFromGregorian(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    _gregorianAnchor = DateTime(normalized.year, normalized.month, 1);
    final hijri = HijriCalendar.fromDate(normalized);
    _hijriYear = hijri.hYear;
    _hijriMonth = hijri.hMonth;
  }

  void _reanchorForMode(CalendarMode mode, List<DateTime> selected) {
    final reference = selected.isEmpty ? ref.read(calendarTodayProvider) : selected.first;
    if (mode == CalendarMode.gregorian) {
      _gregorianAnchor = DateTime(reference.year, reference.month, 1);
    } else {
      final h = HijriCalendar.fromDate(reference);
      _hijriYear = h.hYear;
      _hijriMonth = h.hMonth;
    }
  }

  DateTime get _today => ref.read(calendarTodayProvider);
  DateTime _firstGregorianOfHijri() => HijriCalendar().hijriToGregorian(_hijriYear, _hijriMonth, 1);
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isQazaDate(DateTime date) => widget.qazaDates.any((qaza) => _sameDay(qaza, date));

  String _hijriMonthHeader() {
    final h = HijriCalendar();
    h.hYear = _hijriYear;
    h.hMonth = _hijriMonth;
    h.hDay = 1;
    return '${h.getLongMonthName()} $_hijriYear AH';
  }

  String _hijriLabel(DateTime date) {
    final h = HijriCalendar.fromDate(date);
    return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} AH';
  }

  String _gregorianLabel(BuildContext context, DateTime date) => MaterialLocalizations.of(context).formatMediumDate(date);

  void _goMonth(int delta) {
    final state = ref.read(calendarControllerProvider);
    if (state.calendarMode == CalendarMode.gregorian) {
      final next = DateTime(_gregorianAnchor.year, _gregorianAnchor.month + delta, 1);
      if (next.isBefore(DateTime(1950, 1, 1)) || next.isAfter(DateTime(_today.year, _today.month, 1))) return;
      setState(() => _gregorianAnchor = next);
      return;
    }

    var year = _hijriYear;
    var month = _hijriMonth + delta;
    while (month < 1) {
      month += 12;
      year--;
    }
    while (month > 12) {
      month -= 12;
      year++;
    }
    final candidate = HijriCalendar().hijriToGregorian(year, month, 1);
    if (candidate.isBefore(DateTime(1950, 1, 1)) || candidate.isAfter(_today)) return;
    setState(() {
      _hijriYear = year;
      _hijriMonth = month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final selected = state.selectedDates;
    final header = state.calendarMode == CalendarMode.gregorian
        ? MaterialLocalizations.of(context).formatMonthYear(_gregorianAnchor)
        : _hijriMonthHeader();
    final canPrevious = state.calendarMode == CalendarMode.gregorian
        ? _gregorianAnchor.isAfter(DateTime(1950, 1, 1))
        : _firstGregorianOfHijri().isAfter(DateTime(1950, 1, 1));
    final canNext = state.calendarMode == CalendarMode.gregorian
        ? _gregorianAnchor.isBefore(DateTime(_today.year, _today.month, 1))
        : _firstGregorianOfHijri().isBefore(_today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CalendarMode>(
          key: const Key('calendar_mode_selector'),
          segments: const [
            ButtonSegment(value: CalendarMode.gregorian, icon: Icon(Icons.calendar_today_rounded), label: Text('Gregorian')),
            ButtonSegment(value: CalendarMode.hijri, icon: Icon(Icons.nightlight_round), label: Text('Hijri')),
          ],
          selected: {state.calendarMode},
          onSelectionChanged: (value) {
            final mode = value.first;
            _reanchorForMode(mode, selected);
            ref.read(calendarControllerProvider.notifier).setCalendarMode(mode);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(key: const Key('calendar_prev_month'), tooltip: 'Previous month', onPressed: canPrevious ? () => _goMonth(-1) : null, icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Text(header, key: const Key('calendar_month_header'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
            IconButton(key: const Key('calendar_next_month'), tooltip: 'Next month', onPressed: canNext ? () => _goMonth(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          state.selectionMode == DateSelectionMode.single
              ? 'Select one date.'
              : state.selectionMode == DateSelectionMode.range
                  ? selected.length < 2 ? 'Select a start date, then a later end date.' : 'Range selected: ${selected.length == 2 ? '2 dates' : '${selected.length} dates'}.'
                  : '${selected.length} date${selected.length == 1 ? '' : 's'} selected.',
          key: const Key('calendar_selection_prompt'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _DayGrid(
          anchor: state.calendarMode == CalendarMode.gregorian ? _gregorianAnchor : _firstGregorianOfHijri(),
          hijriMode: state.calendarMode == CalendarMode.hijri,
          today: _today,
          selectedDates: selected,
          onDayTap: (date) => ref.read(calendarControllerProvider.notifier).select(date),
          isHijriLabel: _hijriLabel,
          gregorianLabel: (date) => _gregorianLabel(context, date),
          isQazaDate: _isQazaDate,
        ),
        const SizedBox(height: 10),
        if (selected.isNotEmpty)
          _SelectionSummary(selectedDates: selected, hijriLabel: _hijriLabel, gregorianLabel: (date) => _gregorianLabel(context, date)),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.anchor, required this.hijriMode, required this.today, required this.selectedDates, required this.onDayTap, required this.isHijriLabel, required this.gregorianLabel, required this.isQazaDate});

  final DateTime anchor;
  final bool hijriMode;
  final DateTime today;
  final List<DateTime> selectedDates;
  final ValueChanged<DateTime> onDayTap;
  final String Function(DateTime) isHijriLabel;
  final String Function(DateTime) gregorianLabel;
  final bool Function(DateTime) isQazaDate;

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _selected(DateTime day) => selectedDates.any((d) => _sameDay(d, day));
  bool _inRange(DateTime day) => selectedDates.length == 2 && day.isAfter(selectedDates.first) && day.isBefore(selectedDates.last);

  @override
  Widget build(BuildContext context) {
    final monthStart = anchor;
    final hijri = hijriMode ? HijriCalendar.fromDate(monthStart) : null;
    final daysInMonth = hijriMode ? hijri!.getDaysInMonth(hijri.hYear, hijri.hMonth) : DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final leading = monthStart.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const size = 44.0;

    return Column(
      children: [
        const Row(children: [
          Expanded(child: Center(child: Text('Mo'))),
          Expanded(child: Center(child: Text('Tu'))),
          Expanded(child: Center(child: Text('We'))),
          Expanded(child: Center(child: Text('Th'))),
          Expanded(child: Center(child: Text('Fr'))),
          Expanded(child: Center(child: Text('Sa'))),
          Expanded(child: Center(child: Text('Su'))),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          width: size * 7,
          height: (totalCells ~/ 7) * size,
          child: Column(children: [
            for (var row = 0; row < totalCells ~/ 7; row++)
              SizedBox(height: size, child: Row(children: [
                for (var column = 0; column < 7; column++)
                  SizedBox(width: size, child: _cell(context, row * 7 + column, leading, daysInMonth, hijri)),
              ])),
          ]),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int index, int leading, int daysInMonth, HijriCalendar? monthHijri) {
    final number = index - leading + 1;
    if (number < 1 || number > daysInMonth) return const SizedBox.shrink();

    final day = hijriMode
        ? HijriCalendar().hijriToGregorian(monthHijri!.hYear, monthHijri.hMonth, number)
        : DateTime(anchor.year, anchor.month, number);
    final normalized = DateTime(day.year, day.month, day.day);
    final enabled = !normalized.isAfter(today) && !normalized.isBefore(DateTime(1950));
    final selected = _selected(normalized);
    final inRange = _inRange(normalized);
    final qaza = isQazaDate(normalized);
    final scheme = Theme.of(context).colorScheme;
    final keyDate = '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';

    return Semantics(
      label: hijriMode ? isHijriLabel(normalized) : gregorianLabel(normalized),
      button: enabled,
      child: InkWell(
        key: Key('calendar_day_$keyDate'),
        onTap: enabled ? () => onDayTap(normalized) : null,
        borderRadius: BorderRadius.circular(22),
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? scheme.primary : inRange ? scheme.primaryContainer : _sameDay(normalized, today) ? scheme.secondaryContainer : null),
            alignment: Alignment.center,
            child: Text('$number', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? scheme.onPrimary : null, fontWeight: _sameDay(normalized, today) || selected ? FontWeight.w700 : null)),
          ),
          if (qaza)
            Positioned(
              bottom: 2,
              child: Container(
                key: Key('calendar_qaza_indicator_$keyDate'),
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.tertiary),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.selectedDates, required this.hijriLabel, required this.gregorianLabel});
  final List<DateTime> selectedDates;
  final String Function(DateTime) hijriLabel;
  final String Function(DateTime) gregorianLabel;

  @override
  Widget build(BuildContext context) {
    final gregorian = selectedDates.length == 1
        ? gregorianLabel(selectedDates.single)
        : selectedDates.length == 2
            ? '${gregorianLabel(selectedDates.first)} → ${gregorianLabel(selectedDates.last)}'
            : '${selectedDates.length} selected dates';
    final hijri = selectedDates.length == 1
        ? hijriLabel(selectedDates.single)
        : selectedDates.length == 2
            ? '${hijriLabel(selectedDates.first)} → ${hijriLabel(selectedDates.last)}'
            : 'Hijri dates are derived from the hijri package.';
    return Card(
      key: const Key('calendar_selected_summary'),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text(gregorian), const SizedBox(height: 4), Text(hijri, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)])),
    );
  }
}
