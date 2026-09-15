import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum CalendarMode { gregorian, hijri }

enum DateSelectionMode { single, range, multiple }

class CalendarSelectionState {
  const CalendarSelectionState({
    this.calendarMode = CalendarMode.gregorian,
    this.selectionMode = DateSelectionMode.single,
    this.selectedDates = const <DateTime>[],
  });

  final CalendarMode calendarMode;
  final DateSelectionMode selectionMode;
  final List<DateTime> selectedDates;

  DateTime? get startDate => selectedDates.isEmpty ? null : selectedDates.first;
  DateTime? get endDate => selectedDates.length > 1 ? selectedDates.last : null;

  /// Expands a selected range into the individual canonical Gregorian dates
  /// that the Qaza service persists as independent records.
  List<DateTime> get datesForStorage {
    if (selectionMode != DateSelectionMode.range || selectedDates.length != 2) {
      return selectedDates;
    }

    final start = selectedDates.first;
    final end = selectedDates.last;
    final dates = <DateTime>[];
    for (var date = start; !date.isAfter(end); date = DateTime(date.year, date.month, date.day + 1)) {
      dates.add(date);
    }
    return dates;
  }

  CalendarSelectionState copyWith({
    CalendarMode? calendarMode,
    DateSelectionMode? selectionMode,
    List<DateTime>? selectedDates,
  }) {
    return CalendarSelectionState(
      calendarMode: calendarMode ?? this.calendarMode,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedDates: List.unmodifiable(selectedDates ?? this.selectedDates),
    );
  }
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarSelectionState>(CalendarController.new);

class CalendarController extends Notifier<CalendarSelectionState> {
  @override
  CalendarSelectionState build() => const CalendarSelectionState();

  void setCalendarMode(CalendarMode mode) {
    state = state.copyWith(calendarMode: mode, selectedDates: const []);
  }

  void setSelectionMode(DateSelectionMode mode) {
    state = state.copyWith(selectionMode: mode, selectedDates: const []);
  }

  void select(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    if (date.isAfter(ref.read(calendarTodayProvider))) return;

    switch (state.selectionMode) {
      case DateSelectionMode.single:
        state = state.copyWith(selectedDates: [date]);
      case DateSelectionMode.multiple:
        final selected = {...state.selectedDates};
        if (!selected.add(date)) selected.remove(date);
        final dates = selected.toList()..sort();
        state = state.copyWith(selectedDates: dates);
      case DateSelectionMode.range:
        final start = state.startDate;
        if (start == null || state.endDate != null || date.isBefore(start)) {
          state = state.copyWith(selectedDates: [date]);
        } else {
          state = state.copyWith(selectedDates: [start, date]);
        }
    }
  }

  void clear() => state = state.copyWith(selectedDates: const []);
}
