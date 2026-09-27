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
    this.excludedDates = const <DateTime>{},
  });

  final DateSelectionMode selectionMode;
  final List<DateTime> selectedDates;
  final Set<DateTime> excludedDates;

  int get selectedCount =>
      isRangeComplete ? datesForStorage.length : selectedDates.length;
  bool get hasSelection => selectedDates.isNotEmpty;
  bool get isRangeComplete =>
      selectionMode == DateSelectionMode.range && selectedDates.length == 2;

  DateTime? get startDate => selectedDates.isEmpty ? null : selectedDates.first;
  DateTime? get endDate => selectedDates.length > 1 ? selectedDates.last : null;

  bool isRangeExcluded(DateTime date) =>
      excludedDates.contains(_dateOnly(date));

  List<DateTime> get datesForStorage {
    if (!isRangeComplete) return selectedDates;

    final start = selectedDates.first;
    final end = selectedDates.last;
    final dates = <DateTime>[];
    for (var date = start;
        !date.isAfter(end);
        date = DateTime(date.year, date.month, date.day + 1)) {
      if (!excludedDates.contains(date)) dates.add(date);
    }
    return List.unmodifiable(dates);
  }

  CalendarSelectionState copyWith({
    DateSelectionMode? selectionMode,
    List<DateTime>? selectedDates,
    Set<DateTime>? excludedDates,
  }) {
    final nextMode = selectionMode ?? this.selectionMode;
    final dates = _canonicalize(selectedDates ?? this.selectedDates);
    final exclusions = nextMode == DateSelectionMode.range
        ? _canonicalizeSet(excludedDates ?? this.excludedDates)
        : const <DateTime>{};
    return CalendarSelectionState(
      selectionMode: nextMode,
      selectedDates: List.unmodifiable(dates),
      excludedDates: Set.unmodifiable(exclusions),
    );
  }

  static List<DateTime> _canonicalize(List<DateTime> dates) {
    final unique = <DateTime>{for (final date in dates) _dateOnly(date)};
    final result = unique.toList()..sort();
    return result;
  }

  static Set<DateTime> _canonicalizeSet(Iterable<DateTime> dates) =>
      <DateTime>{for (final date in dates) _dateOnly(date)};
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarSelectionState>(
        CalendarController.new);

class CalendarController extends Notifier<CalendarSelectionState> {
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
        final end = currentDates.last;
        final selected = currentDates.toSet();
        final exclusions = <DateTime>{};
        for (var date = start;
            !date.isAfter(end);
            date = DateTime(date.year, date.month, date.day + 1)) {
          if (!selected.contains(date)) exclusions.add(date);
        }

        state = CalendarSelectionState(
          selectionMode: mode,
          selectedDates: [start, end],
          excludedDates: exclusions,
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
        state = state.copyWith(
          selectedDates: [date],
          excludedDates: const {},
        );
      case DateSelectionMode.multiple:
        final selected = {...state.selectedDates};
        if (!selected.add(date)) selected.remove(date);
        state = state.copyWith(
          selectedDates: selected.toList(),
          excludedDates: const {},
        );
      case DateSelectionMode.range:
        final start = state.startDate;
        if (start == null || state.isRangeComplete || date.isBefore(start)) {
          state = state.copyWith(
            selectedDates: [date],
            excludedDates: const {},
          );
        } else if (date == start) {
          return;
        } else {
          final end = date;
          for (var cursor = start;
              !cursor.isAfter(end);
              cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)) {
            if (!isSelectable(cursor)) return;
          }
          state = state.copyWith(
            selectedDates: [start, end],
            excludedDates: const {},
          );
        }
    }
  }

  void toggleRangeExclusion(DateTime value) {
    if (state.selectionMode != DateSelectionMode.range ||
        !state.isRangeComplete) {
      return;
    }

    final date = _dateOnly(value);
    final start = state.startDate!;
    final end = state.endDate!;
    if (date.isBefore(start) || date.isAfter(end)) return;

    final exclusions = Set<DateTime>.of(state.excludedDates);
    if (!exclusions.add(date)) exclusions.remove(date);
    state = state.copyWith(excludedDates: exclusions);
  }

  void clear() => state = state.copyWith(
        selectedDates: const [],
        excludedDates: const {},
      );
}
