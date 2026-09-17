import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum DateSelectionMode { single, range, multiple }

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

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
    NotifierProvider<CalendarController, CalendarSelectionState>(CalendarController.new);

class CalendarController extends Notifier<CalendarSelectionState> {
  @override
  CalendarSelectionState build() => const CalendarSelectionState();

  void setSelectionMode(DateSelectionMode mode) {
    state = state.copyWith(selectionMode: mode, selectedDates: const []);
  }

  void select(DateTime value, {bool Function(DateTime date)? isDateSelectable}) {
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
