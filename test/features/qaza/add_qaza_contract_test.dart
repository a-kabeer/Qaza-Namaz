import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CalendarPicker uses the same responsive geometry for weekdays and dates', () {
    final source =
        File('lib/features/calendar/calendar_picker.dart').readAsStringSync();

    expect(
      source,
      contains('for (final weekday in const [1, 2, 3, 4, 5, 6, 0])'),
    );
    expect(
      source,
      contains('for (var column = 0; column < 7; column++)'),
    );
    expect(
      source,
      contains('Expanded(\n                          child: _cell('),
    );
    expect(
      source,
      isNot(contains('width: 44,\n                          child: _cell(')),
    );
    expect(source, contains('_hijriMonthLabel(month, l10n)'));
  });

  test('Add Qaza is a single-page flow with three date modes', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();

    expect(source, contains('SegmentedButton<DateSelectionMode>'));
    expect(source, contains('DateSelectionMode.single'));
    expect(source, contains('DateSelectionMode.range'));
    expect(source, contains('DateSelectionMode.multiple'));
    expect(source, contains('CalendarPicker('));
    expect(source, contains('_PrayerSelection('));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('_groupItemsByDate('));
    expect(source, contains('_ReviewDateGroup('));
    expect(source, contains('crossAxisCount: 3'));
    expect(source, contains('HijriDateService.format(date, l10n)'));
    expect(source, contains('ColorScheme'));
  });

  test('Add Qaza uses centralized calendar availability and final preflight', () {
    final source =
        File('lib/features/qaza/add_qaza_controller.dart').readAsStringSync();

    expect(source, contains('getAvailablePrayersByDate('));
    expect(source, contains('analyzeAvailability('));
    expect(source, contains('ProfileRules.startPrayingDate(profile)'));
    expect(source, contains('calendarTodayProvider'));
    expect(source, contains('ProfileRules.effectiveWitr(profile)'));
  });

  test('Add Qaza maps operation types to the existing model', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();

    expect(source, contains('QazaOperationType.singleDateAdd'));
    expect(source, contains('QazaOperationType.rangeAdd'));
    expect(source, contains('QazaOperationType.multipleDateAdd'));
    expect(source, contains('qazaImportProvider.notifier).start('));
  });

  test('Add Qaza progress has real cancellation and determinate progress', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();

    expect(source, contains('qazaImportProvider.notifier).cancel()'));
    expect(source, contains('LinearProgressIndicator(value: progress)'));

    final controller =
        File('lib/features/qaza/qaza_import_controller.dart').readAsStringSync();
    expect(controller, contains('bool cancel()'));
    expect(controller, contains('QazaImportTaskPhase.cancelled'));

    final service =
        File('lib/domain/services/qaza_service.dart').readAsStringSync();
    expect(service, contains('isCancellationRequested'));
    expect(service, contains('cancelled: true'));
  });

  test('shared Add Qaza action is exposed from Home and tracker', () {
    final navigation =
        File('lib/features/qaza/qaza_navigation.dart').readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final empty =
        File('lib/features/home/widgets/home_empty_state.dart').readAsStringSync();
    final tracker =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(navigation, contains('class AddQazaFab'));
    expect(navigation, contains('Future<void> openAddQaza'));
    expect(home, contains('const AddQazaFab()'));
    expect(empty, contains('home_empty_add_qaza'));
    expect(tracker, contains('state.selectionMode ? null : const AddQazaFab()'));
  });
}
