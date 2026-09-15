import 'package:flutter/material.dart';

import '../utils/date_formatters.dart';

class DateDisplay extends StatelessWidget {
  const DateDisplay({super.key, required this.date, this.showWeekday = false});

  final DateTime date;
  final bool showWeekday;

  @override
  Widget build(BuildContext context) {
    final value = showWeekday
        ? '${DateFormatters.weekdayShortNames[date.weekday - 1]}, ${DateFormatters.formatGregorianDatePadded(date)}'
        : DateFormatters.formatGregorianDatePadded(date);
    return Text(value);
  }
}

String formatAppDate(DateTime? date) {
  return date == null ? '—' : DateFormatters.formatGregorianDatePadded(date);
}

String formatAppDateTime(DateTime? value) {
  return value == null
      ? '—'
      : '${DateFormatters.formatGregorianDatePadded(value)} ${DateFormatters.formatClockTime(value)}';
}
