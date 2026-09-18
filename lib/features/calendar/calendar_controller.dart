import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Earliest year the Qaza calendar will navigate to.
///
/// Single-sourced here because the month arrows, the day grid and the year
/// selector all have to agree on the boundary.
const int calendarFirstYear = 1950;

/// The first day the calendar allows.
DateTime get calendarFirstDate => DateTime(calendarFirstYear);

final calendarTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum DateSelectionMode { single, range, multiple }

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class CalendarSelectionState {
  const CalendarSelectionState({
    this.selectionMode = DateSelectionMode.single,
    this.selectedDates = const <DateTime>[],
  });

  final DateSelectionMode selectionMode;
  final List<DateTime> selectedDates;

  int get selectedCount => selectedDates.length;
  bool get hasSelection => selectedDates.isNotEmpty;
  bool get isRangeComplete =>
      selectionMode == DateSelectionMode.range && selectedDates.length == 2;

  DateTime? get startDate => selectedDates.isEmpty ? null : selectedDates.first;
  DateTime? get endDate => selectedDates.length > 1 ? selectedDates.last : null;

  List<DateTime> get datesForStorage {
    if (!isRangeComplete) return selectedDates;

    final start = selectedDates.first;
    final end = selectedDates.last;
    final dates = <DateTime>[];
    for (var date = start;
        !date.isAfter(end);
        date = DateTime(date.year, date.month, date.day + 1)) {
      dates.add(date);
    }
    return dates;
  }

  CalendarSelectionState copyWith({
    DateSelectionMode? selectionMode,
    List<DateTime>? selectedDates,
  }) {
    final dates = _canonicalize(selectedDates ?? this.selectedDates);
    return CalendarSelectionState(
      selectionMode: selectionMode ?? this.selectionMode,
      selectedDates: List.unmodifiable(dates),
    );
  }

  static List<DateTime> _canonicalize(List<DateTime> dates) {
    final unique = <DateTime>{for (final date in dates) _dateOnly(date)};
    final result = unique.toList()..sort();
    return result;
  }
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarSelectionState>(
        CalendarController.new);

class CalendarController extends Notifier<CalendarSelectionState> {
  @override
  CalendarSelectionState build() => const CalendarSelectionState();

  void setSelectionMode(DateSelectionMode mode) {
    if (mode == state.selectionMode) return;
    // Add Qaza merges the mode selector and the calendar onto one step, so
    // users may switch modes after selecting dates. Keep the dates that remain
    // valid under the new mode instead of discarding the selection.
    state = state.copyWith(
      selectionMode: mode,
      selectedDates: _preserveAcrossModeChange(mode, state.selectedDates),
    );
  }

  static List<DateTime> _preserveAcrossModeChange(
    DateSelectionMode mode,
    List<DateTime> dates,
  ) {
    if (dates.isEmpty) return const <DateTime>[];
    // dates are canonically sorted; `.last` is the most recent calendar date.
    return switch (mode) {
      DateSelectionMode.single => [dates.last],
      DateSelectionMode.range =>
        dates.length == 1 ? dates : [dates.first, dates.last],
      DateSelectionMode.multiple => dates,
    };
  }

  void select(DateTime value,
      {bool Function(DateTime date)? isDateSelectable}) {
    final date = _dateOnly(value);
    if (date.isAfter(ref.read(calendarTodayProvider))) return;
    final isSelectable = isDateSelectable ?? (_) => true;
    if (!isSelectable(date)) return;

    switch (state.selectionMode) {
      case DateSelectionMode.single:
        state = state.copyWith(selectedDates: [date]);
      case DateSelectionMode.multiple:
        final selected = {...state.selectedDates};
        if (!selected.add(date)) selected.remove(date);
        state = state.copyWith(selectedDates: selected.toList());
      case DateSelectionMode.range:
        final start = state.startDate;
        if (start == null || state.isRangeComplete || date.isBefore(start)) {
          state = state.copyWith(selectedDates: [date]);
        } else if (date == start) {
          // Re-tapping the pending anchor must not collapse into a same-day
          // range; the anchor stays pending until a different end is chosen.
          return;
        } else {
          final end = date;
          for (var cursor = start;
              !cursor.isAfter(end);
              cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)) {
            if (!isSelectable(cursor)) return;
          }
          state = state.copyWith(selectedDates: [start, end]);
        }
    }
  }

  void clear() => state = state.copyWith(selectedDates: const []);
}
