import 'package:flutter/material.dart';

/// Where a day sits in the current selection.
///
/// One list, so the calendar has a single description of what a cell is.
enum CalendarDayStatus { normal, unavailable, today, inRange, selected }

/// The paired background and foreground for one calendar day.
///
/// Every colour comes from the active [ColorScheme], and every foreground is
/// the `on` colour of the surface it sits on. That pairing is the whole point:
/// it is what keeps a selected day and a day inside a range legible in both
/// the light and the dark theme, without a hard-coded colour anywhere.
class CalendarDayColors {
  const CalendarDayColors({
    required this.background,
    required this.foreground,
    required this.bold,
  });

  /// The circle behind the day number, or null for no circle at all.
  final Color? background;

  /// The day number's colour.
  final Color foreground;

  final bool bold;

  factory CalendarDayColors.resolve(
    ColorScheme scheme,
    CalendarDayStatus status,
  ) =>
      switch (status) {
        CalendarDayStatus.selected => CalendarDayColors(
            background: scheme.primary,
            foreground: scheme.onPrimary,
            bold: true,
          ),
        CalendarDayStatus.inRange => CalendarDayColors(
            background: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
            bold: false,
          ),
        CalendarDayStatus.today => CalendarDayColors(
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            bold: true,
          ),
        CalendarDayStatus.unavailable => CalendarDayColors(
            background: null,
            foreground: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            bold: false,
          ),
        CalendarDayStatus.normal => CalendarDayColors(
            background: null,
            foreground: scheme.onSurface,
            bold: false,
          ),
      };

  /// The one rule for which status a day has, in priority order.
  static CalendarDayStatus statusFor({
    required bool selected,
    required bool inRange,
    required bool isToday,
    required bool available,
  }) {
    if (selected) return CalendarDayStatus.selected;
    if (inRange) return CalendarDayStatus.inRange;
    if (!available) return CalendarDayStatus.unavailable;
    if (isToday) return CalendarDayStatus.today;
    return CalendarDayStatus.normal;
  }
}
