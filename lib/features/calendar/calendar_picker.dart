import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/hijri_date_service.dart';
import '../../core/constants/prayer_types.dart';
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
    this.dateSelectablePredicate,
  });

  final Set<DateTime> qazaDates;

  /// Availability for the month on screen.
  final Map<DateTime, Set<PrayerType>>? availablePrayersByDate;
  final bool availabilityLoading;
  final ValueChanged<DateTime>? onMonthChanged;

  /// Date validity for the current feature.
  ///
  /// Range selection uses this predicate rather than prayer availability:
  /// a valid date remains selectable even when every Qaza prayer on it has
  /// already been completed. Review/import decides which prayers are eligible.
  final bool Function(DateTime date)? dateSelectablePredicate;

  @override
  ConsumerState<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends ConsumerState<CalendarPicker> {
  late DateTime month;



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

  bool _isDateAllowed(DateTime date) =>
      widget.dateSelectablePredicate?.call(DateUtils.dateOnly(date)) ?? true;

  /// Range selection does not depend on availability loading. Single and
  /// Multiple modes still wait for their prayer-availability map.
  bool get _canSelect {
    if (_mode == DateSelectionMode.range) return true;
    return !widget.availabilityLoading;
  }

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

  /// The latest month the calendar may show: the current one.
  DateTime get _lastMonth => DateTime(today.year, today.month, 1);

  void _moveMonth(int delta) {
    _goToMonth(DateTime(month.year, month.month + delta, 1));
  }

  void _handleDisplayedMonthChanged(DateTime displayedMonth) {
    _goToMonth(
      DateTime(displayedMonth.year, displayedMonth.month, 1),
    );
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

  String _hijriLabel(DateTime date, AppLocalizations l10n) =>
      l10n.formatHijriDate(date);

  String _hijriMonthLabel(DateTime month, AppLocalizations l10n) =>
      HijriDateService.monthYearLabel(month, l10n);

  DateSelectionMode get _mode =>
      ref.read(calendarControllerProvider).selectionMode;

  List<DateTime?> get _pickerValue =>
      ref.read(calendarControllerProvider).selectedDates;

  CalendarDatePicker2Type _pickerType(DateSelectionMode mode) => switch (mode) {
        DateSelectionMode.single => CalendarDatePicker2Type.single,
        DateSelectionMode.range => CalendarDatePicker2Type.range,
        DateSelectionMode.multiple => CalendarDatePicker2Type.multi,
      };

  void _handlePickerValue(List<DateTime?> values) {
    if (!_canSelect) return;
    final controller = ref.read(calendarControllerProvider.notifier);
    final state = ref.read(calendarControllerProvider);
    final dates = values.whereType<DateTime>().map(DateUtils.dateOnly).toList();

    switch (state.selectionMode) {
      case DateSelectionMode.single:
        if (dates.isEmpty) {
          controller.clear();
        } else {
          controller.select(dates.last, isDateSelectable: _isDateAvailable);
        }
      case DateSelectionMode.multiple:
        final target = dates.toSet();
        final current = state.selectedDates.toSet();
        for (final date in current.difference(target)) {
          controller.select(date, isDateSelectable: (_) => true);
        }
        for (final date in target.difference(current)) {
          controller.select(date, isDateSelectable: _isDateAvailable);
        }
      case DateSelectionMode.range:
        if (dates.isEmpty) {
          controller.clear();
          return;
        }

        final startDate = dates.first;
        controller.select(
          startDate,
          isDateSelectable: _isDateAllowed,
        );
        if (dates.length < 2) return;

        controller.select(
          dates.last,
          isDateSelectable: _isDateAllowed,
        );
    }
  }
  bool _dayIsSelected(DateTime date) {
    final state = ref.read(calendarControllerProvider);
    return state.selectedDates.any((item) => _sameDay(item, date));
  }

  bool _dayIsInRange(DateTime date) {
    final state = ref.read(calendarControllerProvider);
    return state.selectionMode == DateSelectionMode.range &&
        state.selectedDates.length == 2 &&
        !date.isBefore(state.selectedDates.first) &&
        !date.isAfter(state.selectedDates.last);
  }

  Widget? _dayBuilder({
    required DateTime date,
    BoxDecoration? decoration,
    bool? isDisabled,
    bool? isSelected,
    bool? isToday,
    TextStyle? textStyle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final calendarState = ref.read(calendarControllerProvider);
    final rangeMode = calendarState.selectionMode == DateSelectionMode.range;
    final predicateAllowed = rangeMode
        ? _isDateAllowed(date)
        : _isDateAvailable(date);
    final selectable = predicateAllowed && isDisabled != true;
    final selected = _dayIsSelected(date) || isSelected == true;
    final colors = CalendarDayColors.resolve(
      scheme,
      CalendarDayColors.statusFor(
        selected: selected,
        inRange: _dayIsInRange(date),
        isToday: isToday == true || _sameDay(date, today),
        available: selectable,
      ),
    );
    final dayKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final cell = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: colors.background == null
              ? null
              : BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                ),
          alignment: Alignment.center,
          child: Text(
            date.day.toString(),
            style: textStyle?.copyWith(
              color: colors.foreground,
              fontWeight: colors.bold ? FontWeight.w700 : null,
            ),
          ),
        ),
        if (widget.qazaDates.any((item) => _sameDay(item, date)))
          Positioned(
            bottom: 2,
            child: Container(
              key: Key('calendar_qaza_indicator_${dayKey}'),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatMediumDate(date)}, '
          '${_hijriLabel(date, AppLocalizations.of(context))}'
          '${selectable ? '' : ', unavailable'}',
      selected: selected,
      child: cell,
    );
  }

  CalendarDatePicker2Config _config(BuildContext context) =>
      CalendarDatePicker2Config(
        calendarType: _pickerType(_mode),
        firstDate: calendarFirstDate,
        lastDate: today,
        currentDate: today,
        firstDayOfWeek: 1,
        dynamicCalendarRows: true,
        animateToDisplayedMonthDate: true,
        hideLastMonthIcon: true,
        hideNextMonthIcon: true,
        disableModePicker: true,
        controlsHeight: 0,
        dayMaxWidth: 44,
        dayBuilder: _dayBuilder,
        selectableDayPredicate: (date) =>
            _canSelect &&
            (_mode == DateSelectionMode.range
                ? _isDateAllowed(date)
                : _isDateAvailable(date)),
        selectedDayHighlightColor: Colors.transparent,
        selectedRangeHighlightColor: Colors.transparent,
        selectedDayTextStyle: Theme.of(context).textTheme.bodySmall,
        controlsTextStyle: Theme.of(context).textTheme.labelLarge,
        weekdayLabelTextStyle: Theme.of(context).textTheme.labelSmall,
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentMonth = DateTime(month.year, month.month, 1);
    final canPrevious = currentMonth.isAfter(calendarFirstDate);
    final canNext = currentMonth.isBefore(_lastMonth);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final materialL10n = MaterialLocalizations.of(context);

    return Column(
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: materialL10n.previousMonthTooltip,
              child: IconButton(
                key: const Key('calendar_prev_month'),
                tooltip: materialL10n.previousMonthTooltip,
                onPressed: canPrevious
                    ? () => _moveMonth(-1)
                    : null,
                icon: Icon(
                  isRtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
              ),
            ),
            Expanded(
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
                        Text(
                          _hijriMonthLabel(month, l10n),
                          key: const Key('calendar_hijri_month_label'),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: materialL10n.nextMonthTooltip,
              child: IconButton(
                key: const Key('calendar_next_month'),
                tooltip: materialL10n.nextMonthTooltip,
                onPressed: canNext
                    ? () => _moveMonth(1)
                    : null,
                icon: Icon(
                  isRtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ),
            ),
          ],
        ),
        if (widget.availabilityLoading)
          const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        Text(
          state.hasSelection
              ? l10n.calendarSelectedCount(state.selectedCount)
              : l10n.calendarSelectHint,
          key: const Key('calendar_selection_prompt'),
        ),
        const SizedBox(height: 12),
        CalendarDatePicker2(
          key: const Key('qaza_calendar_date_picker'),
          config: _config(context),
          value: List<DateTime?>.from(_pickerValue),
          displayedMonthDate: month,
          onDisplayedMonthChanged: _handleDisplayedMonthChanged,
          onValueChanged: _handlePickerValue,
        ),
      ],
    );
  }
}
