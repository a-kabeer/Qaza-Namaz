import 'package:flutter/material.dart';

import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/qaza_addition.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';

class QazaAdditionDateLine {
  const QazaAdditionDateLine({
    required this.gregorian,
    required this.hijri,
  });

  final String gregorian;
  final String hijri;
}

class QazaAdditionDateSummary {
  const QazaAdditionDateSummary(this.snapshot);

  final QazaAdditionInputSnapshot snapshot;

  int get dayCount {
    if (snapshot.mode == QazaAdditionMode.range) {
      return snapshot.expandedDates.length;
    }
    return snapshot.selectedDates.length;
  }

  List<DateTime> get selectedDates =>
      List.unmodifiable(snapshot.selectedDates);

  List<DateTime> get dateScope => snapshot.mode == QazaAdditionMode.range
      ? snapshot.expandedDates
      : List.unmodifiable(snapshot.selectedDates);

  List<List<DateTime>> get consecutiveGroups {
    if (selectedDates.isEmpty) return const <List<DateTime>>[];

    final sorted = List<DateTime>.of(selectedDates)..sort();
    final groups = <List<DateTime>>[];
    var group = <DateTime>[sorted.first];

    for (var index = 1; index < sorted.length; index++) {
      final previous = group.last;
      final current = sorted[index];
      final expected = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );
      if (current == expected) {
        group.add(current);
      } else {
        groups.add(group);
        group = <DateTime>[current];
      }
    }

    groups.add(group);
    return groups;
  }

  bool get isContiguous {
    if (selectedDates.length < 2) return true;

    for (var index = 1; index < selectedDates.length; index++) {
      final previous = selectedDates[index - 1];
      final expected = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );
      if (selectedDates[index] != expected) return false;
    }
    return true;
  }

  String modeLabel(AppLocalizations l10n) => switch (snapshot.mode) {
        QazaAdditionMode.single => l10n.addQazaModeSingle,
        QazaAdditionMode.range => l10n.addQazaModeRange,
        QazaAdditionMode.multiple => l10n.addQazaModeMultiple,
      };

  String selectedDatesLabel(AppLocalizations l10n) =>
      l10n.qazaHistorySelectedDates(snapshot.selectedDates.length);

  String selectionScopeLabel(AppLocalizations l10n) =>
      l10n.qazaHistorySelectionScope(
        snapshot.selectedPrayers.length,
        dayCount,
      );

  List<String> prayerLabels(AppLocalizations l10n) {
    final ordered = snapshot.selectedPrayers.toList(growable: false)
      ..sort(
        (a, b) => a.qazaSequenceIndex.compareTo(b.qazaSequenceIndex),
      );
    return ordered
        .map((prayer) => prayer.localizedLabel(l10n))
        .toList(growable: false);
  }

  String formatGregorian(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  String formatHijri(AppLocalizations l10n, DateTime date) =>
      HijriDateService.format(date, l10n);

  String formatConsecutiveRange(
    BuildContext context,
    AppLocalizations l10n,
    List<DateTime> group,
  ) {
    final materialL10n = MaterialLocalizations.of(context);
    final from = materialL10n.formatMediumDate(group.first);
    if (group.length == 1) return from;

    return l10n.qazaDateFilterRange(
      from,
      materialL10n.formatMediumDate(group.last),
    );
  }

  QazaAdditionDateLine line(
    BuildContext context,
    AppLocalizations l10n,
    DateTime date,
  ) =>
      QazaAdditionDateLine(
        gregorian: formatGregorian(context, date),
        hijri: formatHijri(l10n, date),
      );

  List<QazaAdditionDateLine> multiplePreview({
    required BuildContext context,
    required AppLocalizations l10n,
    int limit = 4,
  }) =>
      selectedDates
          .take(limit)
          .map((date) => line(context, l10n, date))
          .toList(growable: false);

  List<QazaAdditionDateLine> multipleExpanded(
    BuildContext context,
    AppLocalizations l10n,
  ) =>
      selectedDates
          .map((date) => line(context, l10n, date))
          .toList(growable: false);

  bool get hasExpandableMultipleDates =>
      snapshot.mode == QazaAdditionMode.multiple && selectedDates.length > 4;

  String rangeGregorian(BuildContext context, AppLocalizations l10n) {
    if (snapshot.selectedDates.length < 2) {
      return snapshot.selectedDates.isEmpty
          ? l10n.qazaHistoryNoDates
          : formatGregorian(context, snapshot.selectedDates.first);
    }

    return l10n.qazaDateFilterRange(
      formatGregorian(context, snapshot.selectedDates.first),
      formatGregorian(context, snapshot.selectedDates.last),
    );
  }

  String rangeHijri(BuildContext context, AppLocalizations l10n) {
    if (snapshot.selectedDates.length < 2) {
      return snapshot.selectedDates.isEmpty
          ? l10n.qazaHistoryNoDates
          : formatHijri(l10n, snapshot.selectedDates.first);
    }

    return l10n.qazaDateFilterRange(
      formatHijri(l10n, snapshot.selectedDates.first),
      formatHijri(l10n, snapshot.selectedDates.last),
    );
  }
}
