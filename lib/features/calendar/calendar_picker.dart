import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_controller.dart';

class CalendarPicker extends ConsumerStatefulWidget {
  const CalendarPicker({
    super.key,
    this.qazaDates = const <DateTime>{},
    this.availablePrayersByDate,
    this.availabilityLoading = false,
    this.onMonthChanged,
  });

  final Set<DateTime> qazaDates;
  final Map<DateTime, Set<PrayerType>>? availablePrayersByDate;
  final bool availabilityLoading;
  final ValueChanged<DateTime>? onMonthChanged;

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

  bool _isDateAvailable(DateTime date) {
    final availability = widget.availablePrayersByDate;
    if (availability == null || widget.availabilityLoading) return true;
    for (final entry in availability.entries) {
      if (_sameDay(entry.key, date)) return entry.value.isNotEmpty;
    }
    return false;
  }

  bool _hasExistingQaza(DateTime date) =>
      widget.qazaDates.any((item) => _sameDay(item, date));

  void _moveMonth(int delta) {
    final next = DateTime(month.year, month.month + delta, 1);
    final min = DateTime(1950);
    final max = DateTime(today.year, today.month, 1);
    if (next.isBefore(min) || next.isAfter(max)) return;
    setState(() => month = next);
    widget.onMonthChanged?.call(next);
  }

  String _hijriLabel(DateTime date) => DateFormatters.hijriLabel(date);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final min = DateTime(1950);
    final selected = state.selectedDates;
    final currentMonth = DateTime(month.year, month.month, 1);
    final canPrevious = currentMonth.isAfter(min);
    final canNext = currentMonth.isBefore(DateTime(today.year, today.month, 1));

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
              child: Column(
                children: [
                  Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    key: const Key('calendar_month_header'),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    _hijriLabel(month),
                    key: const Key('calendar_hijri_month_label'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month'),
              onPressed: canNext ? () => _moveMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
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
        _Grid(
          anchor: month,
          today: today,
          state: state,
          onTap: (date) => ref
              .read(calendarControllerProvider.notifier)
              .select(date, isDateSelectable: _isDateAvailable),
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
                    title: Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                    ),
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
    required this.state,
    required this.onTap,
    required this.available,
    required this.qaza,
    required this.hijri,
  });

  final DateTime anchor;
  final DateTime today;
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
        !date.isBefore(DateTime(1950)) &&
        available(date);
    final isSelected = _selected(date);
    final isRange = _inRange(date);
    final scheme = Theme.of(context).colorScheme;
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatMediumDate(date)}, ${hijri(date)}${isAvailable ? '' : ', unavailable'}',
      button: isAvailable,
      selected: isSelected,
      child: InkWell(
        key: Key('calendar_day_$key'),
        onTap: isAvailable ? () => onTap(date) : null,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? scheme.primary
                    : isRange
                        ? scheme.primaryContainer
                        : _sameDay(date, today) && isAvailable
                            ? scheme.secondaryContainer
                            : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$dayNumber',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? scheme.onPrimary
                          : isAvailable
                              ? null
                              : scheme.onSurfaceVariant.withValues(alpha: .45),
                      fontWeight: isSelected || _sameDay(date, today)
                          ? FontWeight.w700
                          : null,
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
