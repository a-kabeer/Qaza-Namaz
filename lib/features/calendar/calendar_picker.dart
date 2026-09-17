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
            for (final label in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
              const Expanded(child: Center(child: Text(''))),
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
