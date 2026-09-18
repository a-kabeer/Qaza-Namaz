import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Compact year grid for jumping the calendar straight to a year.
///
/// Reaching 1950 with the month arrows takes hundreds of taps, which is the
/// whole reason this exists. It returns the chosen year, or null if dismissed;
/// deciding what to do with it — clamping the month, reloading availability —
/// belongs to the calendar, not here.
Future<int?> showCalendarYearSelector(
  BuildContext context, {
  required int selectedYear,
  required int firstYear,
  required int lastYear,
}) =>
    showDialog<int>(
      context: context,
      builder: (context) => _YearSelectorDialog(
        selectedYear: selectedYear,
        firstYear: firstYear,
        lastYear: lastYear,
      ),
    );

class _YearSelectorDialog extends StatelessWidget {
  const _YearSelectorDialog({
    required this.selectedYear,
    required this.firstYear,
    required this.lastYear,
  });

  final int selectedYear;
  final int firstYear;
  final int lastYear;

  static const int _columns = 3;
  static const double _rowExtent = 52;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = lastYear - firstYear + 1;
    final selectedIndex = (selectedYear - firstYear).clamp(0, count - 1);

    // Open on the current year rather than at 1950, so the common case needs
    // no scrolling at all.
    final controller = ScrollController(
      initialScrollOffset: (selectedIndex ~/ _columns) * _rowExtent,
    );

    return AlertDialog(
      key: const Key('calendar_year_selector'),
      title: Text(l10n.calendarSelectYear),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      content: SizedBox(
        width: 300,
        height: 280,
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisExtent: _rowExtent,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final year = firstYear + index;
            final isSelected = year == selectedYear;
            return _YearCell(
              year: year,
              isSelected: isSelected,
              onTap: () => Navigator.of(context).pop(year),
              theme: theme,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _YearCell extends StatelessWidget {
  const _YearCell({
    required this.year,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final int year;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        key: Key('calendar_year_$year'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? scheme.primary : null,
            border:
                isSelected ? null : Border.all(color: scheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              '$year',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isSelected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
