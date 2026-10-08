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

  int get selectedCount {
    if (!isRangeComplete) return selectedDates.length;
    return selectedDates.last.difference(selectedDates.first).inDays + 1;
  }

  bool get hasSelection => selectedCount > 0;
  bool get isRangeComplete =>
      selectionMode == DateSelectionMode.range && selectedDates.length == 2;

  DateTime? get startDate => selectedDates.isEmpty ? null : selectedDates.first;
  DateTime? get endDate => selectedDates.length > 1 ? selectedDates.last : null;

  List<DateTime> get datesForStorage {
    if (!isRangeComplete) return selectedDates;

    final start = selectedDates.first;
    final end = selectedDates.last;
    return List.unmodifiable([
      for (var date = start;
          !date.isAfter(end);
          date = DateTime(date.year, date.month, date.day + 1))
        date,
    ]);
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
  static bool _isContiguous(List<DateTime> dates) {
    if (dates.length < 2) return true;
    for (var index = 1; index < dates.length; index++) {
      final expected = DateTime(
        dates[index - 1].year,
        dates[index - 1].month,
        dates[index - 1].day + 1,
      );
      if (dates[index] != expected) return false;
    }
    return true;
  }

  @override
  CalendarSelectionState build() => const CalendarSelectionState();

  void setSelectionMode(DateSelectionMode mode) {
    if (mode == state.selectionMode) return;

    final currentDates = state.datesForStorage;
    switch (mode) {
      case DateSelectionMode.single:
        state = CalendarSelectionState(
          selectionMode: mode,
          selectedDates: currentDates.isEmpty ? const [] : [currentDates.last],
        );
      case DateSelectionMode.multiple:
        state = CalendarSelectionState(
          selectionMode: mode,
          selectedDates: currentDates,
        );
      case DateSelectionMode.range:
        if (currentDates.isEmpty) {
          state = CalendarSelectionState(selectionMode: mode);
          return;
        }
        if (currentDates.length == 1) {
          state = CalendarSelectionState(
            selectionMode: mode,
            selectedDates: currentDates,
          );
          return;
        }

        final start = currentDates.first;
        if (!_isContiguous(currentDates)) {
          state = CalendarSelectionState(
            selectionMode: mode,
            selectedDates: [start],
          );
          return;
        }

        state = CalendarSelectionState(
          selectionMode: mode,
          selectedDates: [start, currentDates.last],
        );
    }
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

  void restoreSelection({
    required DateSelectionMode mode,
    required List<DateTime> dates,
  }) {
    state = CalendarSelectionState(
      selectionMode: mode,
      selectedDates: dates.map(_dateOnly).toList(growable: false),
    );
  }

  void clear() => state = state.copyWith(selectedDates: const []);
}
