import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/features/qaza/widgets/qaza_addition_date_summary.dart';

void main() {
  test('Date summary uses the canonical day-count source for each mode', () {
    final single = QazaAdditionDateSummary(
      _snapshot(
        mode: QazaAdditionMode.single,
        dates: [DateTime(2025, 3, 20)],
      ),
    );
    final range = QazaAdditionDateSummary(
      _snapshot(
        mode: QazaAdditionMode.range,
        dates: [DateTime(2025, 3, 12), DateTime(2025, 3, 18)],
      ),
    );
    final multiple = QazaAdditionDateSummary(
      _snapshot(
        mode: QazaAdditionMode.multiple,
        dates: [
          DateTime(2025, 3, 1),
          DateTime(2025, 3, 3),
          DateTime(2025, 3, 5),
        ],
      ),
    );

    expect(single.dayCount, 1);
    expect(range.dayCount, 7);
    expect(multiple.dayCount, 3);
    expect(range.dateScope, hasLength(7));
    expect(multiple.selectedDates, hasLength(3));
  });

  test('Multiple date grouping stays shared and preview expansion is bounded', () {
    final dates = [
      for (var day = 1; day <= 10; day++) DateTime(2025, 3, day),
    ];
    final summary = QazaAdditionDateSummary(
      _snapshot(
        mode: QazaAdditionMode.multiple,
        dates: dates,
      ),
    );

    expect(summary.consecutiveGroups, hasLength(1));
    expect(summary.consecutiveGroups.single, hasLength(10));
    expect(summary.hasExpandableMultipleDates, isTrue);
    expect(summary.selectedDates, hasLength(10));
  });

  test('History summary is current-record based and supports inline expansion', () {
    final source =
        File('lib/features/qaza/qaza_addition_history_screen.dart').readAsStringSync();

    expect(source, contains('QazaAdditionDateSummary(snapshot)'));
    expect(
      source,
      contains('final total = item.pendingCount + item.completedCount;'),
    );
    expect(source, contains('LinearProgressIndicator('));
    expect(source, contains('final progress = total == 0 ? 0.0 : item.completedCount / total;'));
    expect(source, contains('final percent = total == 0 ? 0 : item.completedCount * 100 ~/ total;'));
    expect(source, contains('qazaHistoryTrackedRecords(total)'));
    expect(source, contains('ValueKey(item.addition.id)'));
    expect(source, contains('TextButton.icon('));
    expect(source, contains('qazaHistoryShowAllDates'));
    expect(source, contains('qazaHistoryHideDates'));
    expect(
      source,
      contains('openQazaAdditionDetail(context, widget.item.addition.id)'),
    );
    expect(source, isNot(contains('item.activeCount')));
    expect(source, isNot(contains('Revision ')));
    expect(source, isNot(contains('requested slots')));
    expect(source, contains('_datesExpanded'));
    expect(source, contains('AnimatedSize('));
  });

  test('Add Qaza selection summary reuses the shared date helper', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();

    expect(source, contains('QazaAdditionDateSummary(_snapshot)'));
    expect(source, contains('summary.consecutiveGroups'));
    expect(source, contains('summary.formatConsecutiveRange('));
    expect(source, contains('summary.formatHijri(l10n, date)'));
    expect(source, isNot(contains('List<List<DateTime>> _groupConsecutiveDates')));
    expect(source, isNot(contains('String _rangeLabel(')));
  });
}

QazaAdditionInputSnapshot _snapshot({
  required QazaAdditionMode mode,
  required List<DateTime> dates,
}) =>
    QazaAdditionInputSnapshot(
      schemaVersion: 1,
      mode: mode,
      selectedDates: dates,
      selectedPrayers: const <PrayerType>[],
    );
