// Calendar picker for the Qaza Namaz Add-Qaza flow.
//
// This widget renders a month grid in either the Gregorian or the Hijri
// (Umm al-Qura) view and supports single-date and date-range selection. All
// date conversion goes through `CalendarEngine`; the widget stores and reports
// only canonical, normalized Gregorian dates. Future dates are locked, the
// active mode and the selected date are always visible, and the corresponding
// alternate calendar date is shown alongside the selection.

import 'package:flutter/material.dart';

import '../../domain/calendar/calendar_engine.dart';
import '../../domain/calendar/calendar_labels.dart';
import '../../domain/calendar/hijri_date.dart';

/// Which calendar view the picker displays.
enum CalendarMode { gregorian, hijri }

/// Single-date vs date-range selection behaviour.
enum DateSelectionMode { single, range }

/// The canonical selection reported by the picker.
///
/// The fields are normalized date-only Gregorian [DateTime]s. `endDate` is
/// null in single mode (and while a range is only half-picked).
class CalendarSelection {
  const CalendarSelection({required this.startDate, this.endDate});

  final DateTime startDate;
  final DateTime? endDate;
}

/// Month-grid calendar picker with single/range selection.
class CalendarPicker extends StatefulWidget {
  const CalendarPicker({
    super.key,
    required this.engine,
    required this.mode,
    required this.selectionMode,
    required this.onSelectionChanged,
    this.startDate,
    this.endDate,
    this.anchorDate,
  });

  final CalendarEngine engine;
  final CalendarMode mode;
  final DateSelectionMode selectionMode;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Optional Gregorian month anchor used to open the grid at a specific
  /// month instead of the month containing [startDate] or today. Primarily
  /// useful for deterministic widget tests.
  final DateTime? anchorDate;

  final ValueChanged<CalendarSelection> onSelectionChanged;

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  late DateTime _gAnchor = _initialGregorianAnchor();
  late HijriDate _hAnchor = _initialHijriAnchor();

  CalendarEngine get engine => widget.engine;

  DateTime _reference() =>
      widget.startDate ?? widget.anchorDate ?? engine.today();

  /// First day of the Gregorian month that contains the reference date.
  DateTime _initialGregorianAnchor() {
    final reference = engine.normalize(_reference());
    return DateTime(reference.year, reference.month, 1);
  }

  /// First day of the Hijri month that contains the reference date.
  HijriDate _initialHijriAnchor() {
    final hijri = engine.gregorianToHijri(engine.normalize(_reference()));
    return HijriDate(year: hijri.year, month: hijri.month, day: 1);
  }

  @override
  void didUpdateWidget(CalendarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      // Re-anchor the newly activated view around the current selection (or
      // today) so switching modes always lands on a useful month.
      _gAnchor = _initialGregorianAnchor();
      _hAnchor = _initialHijriAnchor();
    }
  }

  DateTime _shiftGregorianMonth(DateTime firstOfMonth, int delta) {
    final total = (firstOfMonth.year * 12) + (firstOfMonth.month - 1) + delta;
    final shifted = total % 12; // Dart `%` is Euclidean (non-negative).
    final year = (total - shifted) ~/ 12;
    return DateTime(year, shifted + 1, 1);
  }

  bool get _canGoPrevious {
    if (widget.mode == CalendarMode.gregorian) {
      return _gAnchor.year > CalendarEngine.minAllowedDate.year ||
          _gAnchor.month > CalendarEngine.minAllowedDate.month;
    }
    final minimumHijri =
        engine.gregorianToHijri(CalendarEngine.minAllowedDate);
    return _hAnchor.monthIndex > minimumHijri.monthIndex;
  }

  bool get _canGoNext {
    final today = engine.today();
    if (widget.mode == CalendarMode.gregorian) {
      final currentIndex = (today.year * 12) + today.month - 1;
      final anchorIndex = (_gAnchor.year * 12) + _gAnchor.month - 1;
      return anchorIndex < currentIndex;
    }
    return _hAnchor.monthIndex < engine.todayHijri().monthIndex;
  }

  void _selectDay(DateTime day) {
    final start = widget.startDate;
    if (widget.selectionMode == DateSelectionMode.single) {
      widget.onSelectionChanged(CalendarSelection(startDate: day));
      return;
    }
    if (start == null || widget.endDate != null) {
      // Start a brand-new range.
      widget.onSelectionChanged(CalendarSelection(startDate: day));
      return;
    }
    if (engine.compareDates(day, start) < 0) {
      // Tap before the current start restarts the range there.
      widget.onSelectionChanged(CalendarSelection(startDate: day));
      return;
    }
    widget.onSelectionChanged(
      CalendarSelection(startDate: start, endDate: day),
    );
  }

  bool _isSelected(DateTime day) {
    final start = widget.startDate;
    if (start == null || widget.selectionMode == DateSelectionMode.range) {
      return false; // Range edges/middle are handled by dedicated predicates.
    }
    return engine.isSameDay(start, day);
  }

  bool _isRangeMiddle(DateTime day) {
    final start = widget.startDate;
    final end = widget.endDate;
    if (start == null || end == null) return false;
    final normalized = engine.normalize(day);
    return normalized.isAfter(engine.normalize(start)) &&
        normalized.isBefore(engine.normalize(end));
  }

  bool _isRangeEdge(DateTime day) {
    final start = widget.startDate;
    final end = widget.endDate;
    if (end == null) return false;
    return (start != null && engine.isSameDay(start, day)) ||
        engine.isSameDay(end, day);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeBanner(mode: widget.mode),
        const SizedBox(height: 10),
        _MonthNavigator(
          headerText: widget.mode == CalendarMode.gregorian
              ? CalendarLabels.gregorianMonthHeader(_gAnchor)
              : CalendarLabels.hijriMonthHeader(_hAnchor),
          canGoPrevious: _canGoPrevious,
          canGoNext: _canGoNext,
          onPrevious: () => setState(() {
            if (widget.mode == CalendarMode.gregorian) {
              _gAnchor = _shiftGregorianMonth(_gAnchor, -1);
            } else {
              _hAnchor = _hAnchor.addMonths(-1);
            }
          }),
          onNext: () => setState(() {
            if (widget.mode == CalendarMode.gregorian) {
              _gAnchor = _shiftGregorianMonth(_gAnchor, 1);
            } else {
              _hAnchor = _hAnchor.addMonths(1);
            }
          }),
        ),
        const SizedBox(height: 6),
        const _WeekdayHeader(),
        const SizedBox(height: 2),
        _DayGrid(
          engine: engine,
          mode: widget.mode,
          gAnchor: _gAnchor,
          hAnchor: _hAnchor,
          today: engine.today(),
          onDayTap: _selectDay,
          isDaySelected: _isSelected,
          isRangeEdge: _isRangeEdge,
          isInRangeDay: _isRangeMiddle,
          key: const Key('calendar_day_grid'),
        ),
        const SizedBox(height: 10),
        _SelectionSummary(
          engine: engine,
          mode: widget.mode,
          startDate: widget.startDate,
          endDate: widget.endDate,
          selectionMode: widget.selectionMode,
        ),
      ],
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.mode});

  final CalendarMode mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = mode == CalendarMode.gregorian
        ? 'Gregorian calendar'
        : 'Hijri calendar (Umm al-Qura)';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withOpacity(.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == CalendarMode.gregorian
                  ? Icons.calendar_today_rounded
                  : Icons.nights_stay_rounded,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              key: const Key('calendar_mode_label'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.headerText,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String headerText;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('calendar_prev_month'),
          tooltip: 'Previous month',
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            headerText,
            key: const Key('calendar_month_header'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('calendar_next_month'),
          tooltip: 'Next month',
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final label in CalendarLabels.weekdayInitials)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    super.key,
    required this.engine,
    required this.mode,
    required this.gAnchor,
    required this.hAnchor,
    required this.today,
    required this.onDayTap,
    required this.isDaySelected,
    required this.isRangeEdge,
    required this.isInRangeDay,
  });

  final CalendarEngine engine;
  final CalendarMode mode;
  final DateTime gAnchor;
  final HijriDate hAnchor;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final bool Function(DateTime day) isDaySelected;
  final bool Function(DateTime day) isRangeEdge;
  final bool Function(DateTime day) isInRangeDay;

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    const cellSize = 44.0;
    return Center(
      child: SizedBox(
        width: cellSize * 7,
        height: (cells.length ~/ 7) * cellSize,
        child: Column(
          children: [
            for (var rowIndex = 0; rowIndex < cells.length ~/ 7; rowIndex++)
              SizedBox(
                height: cellSize,
                child: Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      SizedBox(
                        width: cellSize,
                        child: _buildCell(
                          context,
                          cells[rowIndex * 7 + column],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_DayCellData> _buildCells() {
    if (mode == CalendarMode.gregorian) {
      return _buildGregorianCells();
    }
    return _buildHijriCells();
  }
List<_DayCellData> _buildGregorianCells() {
    final daysInMonth = DateTime(gAnchor.year, gAnchor.month + 1, 0).day;
    final leading = DateTime(gAnchor.year, gAnchor.month, 1).weekday - 1;
    final totalCells = _roundUpToWeeks(leading, daysInMonth) * 7;
    return [
      for (var index = 0; index < totalCells; index++)
        _makeCell(_gregorianDayForCell(index, leading, daysInMonth)),
    ];
  }

  DateTime? _gregorianDayForCell(int index, int leading, int daysInMonth) {
    final dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) return null;
    return DateTime(gAnchor.year, gAnchor.month, dayNumber);
  }

  List<_DayCellData> _buildHijriCells() {
    final daysInMonth = engine.islamic
        .hijriMonthLength(hAnchor.year, hAnchor.month);
    final firstGregorian = engine.hijriToGregorian(hAnchor.firstOfMonth);
    final leading = firstGregorian.weekday - 1;
    final totalCells = _roundUpToWeeks(leading, daysInMonth) * 7;
    return [
      for (var index = 0; index < totalCells; index++)
        _makeCell(_hijriDayForCell(index, leading, daysInMonth)),
    ];
  }

  DateTime? _hijriDayForCell(int index, int leading, int daysInMonth) {
    final dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) return null;
    return engine.hijriToGregorian(
      HijriDate(
        year: hAnchor.year,
        month: hAnchor.month,
        day: dayNumber,
      ),
    );
  }

  int _roundUpToWeeks(int leading, int daysInMonth) =>
      ((leading + daysInMonth) / 7).ceil();

  _DayCellData _makeCell(DateTime? day) {
    if (day == null) return const _DayCellData.empty();
    final enabled = !engine.isFuture(day) && !engine.isBeforeMinimum(day);
    return _DayCellData(
      day: day,
      label: day.day.toString(),
      enabled: enabled,
      isToday: engine.isSameDay(day, today),
      selected: isDaySelected(day),
      rangeEdge: isRangeEdge(day),
      isInRange: isInRangeDay(day),
    );
  }
Widget _buildCell(BuildContext context, _DayCellData cell) {
    final scheme = Theme.of(context).colorScheme;
    if (cell.day == null || !cell.enabled) {
      return Center(
        child: Container(
          key: cell.day == null
              ? null
              : Key('calendar_day_${engine.dateKey(cell.day!)}'),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHighest.withOpacity(.3),
          ),
          child: Text(
            cell.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(.3),
                ),
          ),
        ),
      );
    }

    final Color? background;
    final Color foreground;
    if (cell.selected) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else if (cell.rangeEdge) {
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
    } else if (cell.isInRange) {
      background = scheme.primaryContainer.withOpacity(.45);
      foreground = scheme.onPrimaryContainer;
    } else {
      background = Colors.transparent;
      foreground = scheme.onSurface;
    }

    return Center(
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          key: Key('calendar_day_${engine.dateKey(cell.day!)}'),
          customBorder: const CircleBorder(),
          onTap: () => onDayTap(cell.day!),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: cell.isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Text(
              cell.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: cell.isToday || cell.selected
                        ? FontWeight.w700
                        : null,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCellData {
  const _DayCellData({
    this.day,
    required this.label,
    required this.enabled,
    required this.isToday,
    required this.selected,
    required this.rangeEdge,
    this.isInRange = false,
  });

  const _DayCellData.empty()
      : day = null,
        label = '',
        enabled = false,
        isToday = false,
        selected = false,
        rangeEdge = false,
        isInRange = false;

  final DateTime? day;
  final String label;
  final bool enabled;
  final bool isToday;
  final bool selected;
  final bool rangeEdge;
  final bool isInRange;
}
class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.engine,
    required this.mode,
    required this.startDate,
    required this.endDate,
    required this.selectionMode,
  });

  final CalendarEngine engine;
  final CalendarMode mode;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateSelectionMode selectionMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (startDate == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap a date above to select it. Only today and earlier '
                'dates can be recorded.',
                key: const Key('calendar_selection_prompt'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final gregorian = engine.normalize(startDate!);
    final hijri = engine.gregorianToHijri(gregorian);
    final rows = <(String, String)>[
      (
        'Mode',
        mode == CalendarMode.gregorian
            ? 'Gregorian'
            : 'Hijri (Umm al-Qura)',
      ),
      ('Gregorian date', CalendarLabels.formatGregorianDate(gregorian)),
      ('Hijri date', CalendarLabels.formatHijriDate(hijri)),
    ];

    if (selectionMode == DateSelectionMode.range) {
      final end = endDate;
      if (end != null) {
        final endGregorian = engine.normalize(end);
        final endHijri = engine.gregorianToHijri(endGregorian);
        rows
          ..add((
            'Gregorian end',
            CalendarLabels.formatGregorianDate(endGregorian),
          ))
          ..add(('Hijri end', CalendarLabels.formatHijriDate(endHijri)));
        rows.add((
          'Days',
          '${engine.daysBetween(gregorian, endGregorian)}',
        ));
      } else {
        rows.add(('Range end', 'Tap a later date to finish the range'));
      }
    }

    return Container(
      key: const Key('calendar_selected_summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(.32),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected date', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}