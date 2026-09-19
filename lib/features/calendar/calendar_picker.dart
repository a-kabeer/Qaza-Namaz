import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_controller.dart';
import 'calendar_day_colors.dart';
import 'year_selector.dart';

class CalendarPicker extends ConsumerStatefulWidget {
  const CalendarPicker({
    super.key,
    this.qazaDates = const <DateTime>{},
    this.availablePrayersByDate,
    this.availabilityLoading = false,
    this.onMonthChanged,
    this.resolveAvailability,
  });

  final Set<DateTime> qazaDates;

  /// Availability for the month on screen.
  final Map<DateTime, Set<PrayerType>>? availablePrayersByDate;
  final bool availabilityLoading;
  final ValueChanged<DateTime>? onMonthChanged;

  /// Availability for an arbitrary span, for a range that reaches past the
  /// month on screen.
  ///
  /// A range is checked date by date before it is accepted, and the month's
  /// own map knows nothing about the months either side of it. Without this
  /// the check fails for every date it has not heard of, which is what made
  /// ranges look like they could not leave the visible month.
  final Future<Map<DateTime, Set<PrayerType>>> Function(
      DateTime start, DateTime end)? resolveAvailability;

  @override
  ConsumerState<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends ConsumerState<CalendarPicker> {
  late DateTime month;

  /// True while a multi-month range is being checked.
  bool checkingRange = false;

  DateTime get today => ref.read(calendarTodayProvider);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    month = DateTime(today.year, today.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMonthChanged?.call(month);
    });
  }

  bool _isDateAvailable(DateTime date) =>
      _availableIn(widget.availablePrayersByDate, date);

  /// Days can only be tapped once their availability is known.
  ///
  /// While a month is loading the picker has nothing to judge a date by, and
  /// acting on availability it cannot vouch for is worse than a short wait —
  /// the progress bar above the grid says why.
  bool get _canSelect => !widget.availabilityLoading && !checkingRange;

  /// Whether [date] still has a prayer left to record, according to
  /// [availability]. An absent map means nothing is known to be unavailable.
  static bool _availableIn(
    Map<DateTime, Set<PrayerType>>? availability,
    DateTime date,
  ) {
    if (availability == null) return true;
    for (final entry in availability.entries) {
      if (entry.key.year == date.year &&
          entry.key.month == date.month &&
          entry.key.day == date.day) {
        return entry.value.isNotEmpty;
      }
    }
    return false;
  }

  /// Handles a tap on a day.
  ///
  /// Completing a range is the one case that needs to know about dates the
  /// visible month has never loaded, so it asks for the whole span first and
  /// judges every date in it against that answer. Eligibility still applies to
  /// every date in the range — it is simply now applied with the facts.
  Future<void> _selectDate(DateTime date) async {
    final controller = ref.read(calendarControllerProvider.notifier);
    final selection = ref.read(calendarControllerProvider);
    final start = selection.startDate;
    final resolve = widget.resolveAvailability;
    final completesRange = selection.selectionMode == DateSelectionMode.range &&
        start != null &&
        !selection.isRangeComplete &&
        date.isAfter(start);

    if (!completesRange || resolve == null) {
      controller.select(date, isDateSelectable: _isDateAvailable);
      return;
    }

    setState(() => checkingRange = true);
    try {
      final span = await resolve(start, date);
      if (!mounted) return;
      controller.select(
        date,
        isDateSelectable: (day) => _availableIn(span, day),
      );
    } finally {
      if (mounted) setState(() => checkingRange = false);
    }
  }

  bool _hasExistingQaza(DateTime date) =>
      widget.qazaDates.any((item) => _sameDay(item, date));

  /// The latest month the calendar may show: the current one.
  DateTime get _lastMonth => DateTime(today.year, today.month, 1);

  void _moveMonth(int delta) {
    _goToMonth(DateTime(month.year, month.month + delta, 1));
  }

  /// Moves to [next] and reloads availability, if it is inside the bounds.
  ///
  /// Every navigation — arrows and the year selector alike — lands here, so
  /// there is one place that enforces the range and one place that notifies
  /// [CalendarPicker.onMonthChanged].
  void _goToMonth(DateTime next) {
    if (next.isBefore(calendarFirstDate) || next.isAfter(_lastMonth)) return;
    if (next.year == month.year && next.month == month.month) return;
    setState(() => month = next);
    widget.onMonthChanged?.call(next);
  }

  Future<void> _pickYear() async {
    final year = await showCalendarYearSelector(
      context,
      selectedYear: month.year,
      firstYear: calendarFirstYear,
      lastYear: today.year,
    );
    if (year == null || !mounted) return;
    // Months after the current one do not exist yet, so jumping into the
    // current year from a later month lands on the current month instead of
    // being silently refused.
    final clampedMonth =
        year == today.year ? month.month.clamp(1, today.month) : month.month;
    _goToMonth(DateTime(year, clampedMonth, 1));
  }

  String _hijriLabel(DateTime date) => DateFormatters.hijriLabel(date);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = state.selectedDates;
    final currentMonth = DateTime(month.year, month.month, 1);
    final canPrevious = currentMonth.isAfter(calendarFirstDate);
    final canNext = currentMonth.isBefore(_lastMonth);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calendar_prev_month'),
              onPressed: canPrevious ? () => _moveMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              // The header is the shortcut to a year: reaching 1950 by arrow
              // would be several hundred taps.
              child: Semantics(
                button: true,
                label: l10n.calendarSelectYear,
                child: InkWell(
                  key: const Key('calendar_month_header_button'),
                  onTap: _pickYear,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                MaterialLocalizations.of(context)
                                    .formatMonthYear(month),
                                key: const Key('calendar_month_header'),
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded, size: 20),
                          ],
                        ),
                        // Gregorian leads; the Hijri month stays secondary.
                        Text(
                          _hijriLabel(month),
                          key: const Key('calendar_hijri_month_label'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month'),
              onPressed: canNext ? () => _moveMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        if (widget.availabilityLoading || checkingRange)
          const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        Text(
          state.hasSelection
              ? l10n.calendarSelectedCount(state.selectedCount)
              : l10n.calendarSelectHint,
          key: const Key('calendar_selection_prompt'),
        ),
        const SizedBox(height: 12),
        _Grid(
          anchor: month,
          today: today,
          enabled: _canSelect,
          state: state,
          onTap: _selectDate,
          available: _isDateAvailable,
          qaza: _hasExistingQaza,
          hijri: _hijriLabel,
        ),
        if (selected.isNotEmpty)
          Card(
            key: const Key('calendar_selected_summary'),
            child: Column(
              children: [
                ...selected.map(
                  (date) => ListTile(
                    dense: true,
                    // Day, month and year: a date acted on is never partial.
                    title: Text(DateFormatters.formatGregorianFull(date)),
                    subtitle: Text(_hijriLabel(date)),
                  ),
                ),
                TextButton(
                  key: const Key('calendar_clear_selection'),
                  onPressed: () =>
                      ref.read(calendarControllerProvider.notifier).clear(),
                  child: Text(l10n.commonClear),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.anchor,
    required this.today,
    required this.enabled,
    required this.state,
    required this.onTap,
    required this.available,
    required this.qaza,
    required this.hijri,
  });

  final DateTime anchor;
  final DateTime today;

  /// False while availability is being fetched.
  final bool enabled;
  final CalendarSelectionState state;
  final ValueChanged<DateTime> onTap;
  final bool Function(DateTime) available;
  final bool Function(DateTime) qaza;
  final String Function(DateTime) hijri;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _selected(DateTime date) =>
      state.selectedDates.any((item) => _sameDay(item, date));

  bool _inRange(DateTime date) =>
      state.selectionMode == DateSelectionMode.range &&
      state.selectedDates.length == 2 &&
      !date.isBefore(state.selectedDates.first) &&
      !date.isAfter(state.selectedDates.last);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final leadingDays = anchor.weekday - 1;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: [
            // Weekday names come from Material's own localizations. The grid
            // stays Monday-first, so the Sunday-indexed list is re-ordered
            // rather than hard-coded in English.
            for (final weekday in const [1, 2, 3, 4, 5, 6, 0])
              Expanded(
                child: Center(
                  child: Text(
                    MaterialLocalizations.of(context).narrowWeekdays[weekday],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: (totalCells ~/ 7) * 44,
          child: Column(
            children: [
              for (var row = 0; row < totalCells ~/ 7; row++)
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      for (var column = 0; column < 7; column++)
                        SizedBox(
                          width: 44,
                          child: _cell(
                            context,
                            row * 7 + column,
                            leadingDays,
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

  Widget _cell(
    BuildContext context,
    int index,
    int leadingDays,
    int daysInMonth,
  ) {
    final dayNumber = index - leadingDays + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox.shrink();
    }

    final date = DateTime(anchor.year, anchor.month, dayNumber);
    final isAvailable = !date.isAfter(today) &&
        !date.isBefore(calendarFirstDate) &&
        available(date);
    final isSelected = _selected(date);
    final scheme = Theme.of(context).colorScheme;
    final colors = CalendarDayColors.resolve(
      scheme,
      CalendarDayColors.statusFor(
        selected: isSelected,
        inRange: _inRange(date),
        isToday: _sameDay(date, today),
        available: isAvailable,
      ),
    );
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatMediumDate(date)}, ${hijri(date)}${isAvailable ? '' : ', unavailable'}',
      button: isAvailable && enabled,
      selected: isSelected,
      child: InkWell(
        key: Key('calendar_day_$key'),
        onTap: isAvailable && enabled ? () => onTap(date) : null,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.background,
              ),
              alignment: Alignment.center,
              child: Text(
                '$dayNumber',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.foreground,
                      fontWeight: colors.bold ? FontWeight.w700 : null,
                    ),
              ),
            ),
            if (qaza(date))
              Positioned(
                bottom: 2,
                child: Container(
                  key: Key('calendar_qaza_indicator_$key'),
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
