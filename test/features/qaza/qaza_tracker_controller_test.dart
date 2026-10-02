import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';

void main() {
  test('Reset clears filters while preserving the current status workspace', () {
    final state = QazaTrackerState(
      statusFilter: QazaStatusFilter.completed,
      prayerFilter: PrayerType.fajr,
      from: DateTime(2026, 9, 10),
      to: DateTime(2026, 9, 12),
      additionId: 'addition-1',
      selectionMode: true,
      selectionScope: QazaSelectionScope.completed,
      selected: {'record-1'},
    );

    final reset = state.copyWith(
      clearPrayerFilter: true,
      clearDates: true,
      clearAdditionId: true,
      selectionMode: false,
      selected: const <String>{},
      clearSelectionScope: true,
    );

    expect(reset.isFiltered, isFalse);
    expect(reset.statusFilter, QazaStatusFilter.completed);
    expect(reset.prayerFilter, isNull);
    expect(reset.from, isNull);
    expect(reset.to, isNull);
    expect(reset.additionId, isNull);
    expect(reset.selectionMode, isFalse);
    expect(reset.selectionScope, isNull);
    expect(reset.selected, isEmpty);
  });
  test('Sort direction is part of shared tracker state', () {
    const initial = QazaTrackerState();
    expect(initial.sortOrder, QazaSortOrder.oldestFirst);

    final newest = initial.copyWith(
      sortOrder: QazaSortOrder.newestFirst,
    );
    expect(newest.sortOrder, QazaSortOrder.newestFirst);
  });

}
