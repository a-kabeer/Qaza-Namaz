import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_controller.dart';

void main() {
  test('CalendarPicker uses shared calendar package and synchronizes month navigation', () {
    final source =
        File('lib/features/calendar/calendar_picker.dart').readAsStringSync();

    expect(
      source,
      contains("package:calendar_date_picker2/calendar_date_picker2.dart"),
    );
    expect(source, contains('CalendarDatePicker2('));
    expect(source, contains('CalendarDatePicker2Type.single'));
    expect(source, contains('CalendarDatePicker2Type.range'));
    expect(source, contains('CalendarDatePicker2Type.multi'));
    expect(source, contains('selectableDayPredicate'));
    expect(source, contains('_hijriMonthLabel(month, l10n)'));
    expect(source, contains('displayedMonthDate: month'));
    expect(source, contains('onDisplayedMonthChanged: _handleDisplayedMonthChanged'));
    expect(source, contains('widget.onMonthChanged?.call(next)'));
    expect(source, contains('previousMonthTooltip'));
    expect(source, contains('nextMonthTooltip'));
    expect(source, contains('Directionality.of(context)'));
    expect(source, contains('dateSelectablePredicate'));
    expect(source, isNot(contains('resolveAvailability')));
    expect(source, isNot(contains('_exclusionMode')));
    expect(source, isNot(contains('toggleRangeExclusion')));
    expect(source, isNot(contains('excludedDates')));
    expect(
      source,
      isNot(contains('calendar_selected_summary')),
    );
  });

  test('Add Qaza uses compact prayer chips, selection summary and sticky review action', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();

    expect(source, contains('SegmentedButton<DateSelectionMode>'));
    expect(source, contains('DateSelectionMode.single'));
    expect(source, contains('DateSelectionMode.range'));
    expect(source, contains('DateSelectionMode.multiple'));
    expect(source, contains('CalendarPicker('));
    expect(source, contains('class _SelectionSummary'));
    expect(source, contains('class _PrayerSelection'));
    expect(source, contains('PrayerSelectionGrid('));
    final prayerGrid =
        File('lib/core/widgets/prayer_selection_grid.dart').readAsStringSync();
    expect(prayerGrid, contains('FilterChip('));
    expect(prayerGrid, contains('crossAxisCount: 3'));
    expect(source, isNot(contains('CheckboxListTile')));
    expect(source, contains('HijriDateService.format(dates.first, l10n)'));
    expect(source, contains('bottomNavigationBar: _AddQazaBottomAction('));
    expect(source, contains('l10n.addQazaReviewHeading'));
    expect(source, contains('class _AnalysisSummary'));
    expect(source, contains('analysis.countForPrayer(prayer)'));
    expect(source, contains('addablePrayers'));
    expect(source, contains('prayerAvailabilityLoading'));
    expect(source, contains('disabledPrayers'));
    expect(source, contains('disabledPrayers: availabilityLoading'));
    expect(source, contains('PrayerType.values.toSet()'));
    expect(source, contains('.colorScheme'));
    expect(source, isNot(contains('_ReviewDateGroup')));
  });

  test('Add Qaza centralizes analysis counts and keeps status counts exhaustive', () {
    final items = [
      AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: DateTime(2026, 1, 1),
          prayerType: PrayerType.fajr,
        ),
        status: AddQazaCandidateStatus.newRecord,
      ),
      AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: DateTime(2026, 1, 1),
          prayerType: PrayerType.zuhr,
        ),
        status: AddQazaCandidateStatus.alreadyAdded,
      ),
      AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: DateTime(2026, 1, 2),
          prayerType: PrayerType.fajr,
        ),
        status: AddQazaCandidateStatus.unavailable,
      ),
    ];

    final analysis = AddQazaAnalysis(items: items);

    expect(analysis.countForPrayer(PrayerType.fajr), 1);
    expect(analysis.countForPrayer(PrayerType.zuhr), 0);
    expect(analysis.newPrayers, contains(PrayerType.fajr));
    expect(analysis.newPrayers, isNot(contains(PrayerType.zuhr)));
    expect(analysis.statusCountTotal, analysis.total);
    expect(
      analysis.newCount + analysis.existingCount + analysis.unavailableCount,
      analysis.total,
    );
  });

  test('Add Qaza review counts only records that will be added', () {
    final date = DateTime(2026, 9, 27);
    final items = [
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
    ].map(
      (prayer) => AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: date,
          prayerType: prayer,
        ),
        status: AddQazaCandidateStatus.alreadyAdded,
      ),
    ).toList()
      ..addAll([
        for (final prayer in [PrayerType.isha, PrayerType.witr])
          AddQazaCandidate(
            key: QazaPrayerKey(
              userId: 'user',
              date: date,
              prayerType: prayer,
            ),
            status: AddQazaCandidateStatus.newRecord,
          ),
      ]);

    final analysis = AddQazaAnalysis(items: items);

    expect(analysis.countForPrayer(PrayerType.fajr), 0);
    expect(analysis.countForPrayer(PrayerType.zuhr), 0);
    expect(analysis.countForPrayer(PrayerType.asr), 0);
    expect(analysis.countForPrayer(PrayerType.maghrib), 0);
    expect(analysis.countForPrayer(PrayerType.isha), 1);
    expect(analysis.countForPrayer(PrayerType.witr), 1);
    expect(analysis.newCount, 2);
    expect(analysis.existingCount, 4);
  });

  test('Add Qaza keeps a prayer addable when a later selected date is new', () {
    final items = [
      AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: DateTime(2026, 9, 27),
          prayerType: PrayerType.fajr,
        ),
        status: AddQazaCandidateStatus.alreadyAdded,
      ),
      AddQazaCandidate(
        key: QazaPrayerKey(
          userId: 'user',
          date: DateTime(2026, 9, 28),
          prayerType: PrayerType.fajr,
        ),
        status: AddQazaCandidateStatus.newRecord,
      ),
    ];

    final analysis = AddQazaAnalysis(items: items);

    expect(analysis.countForPrayer(PrayerType.fajr), 1);
    expect(analysis.newPrayers, contains(PrayerType.fajr));
  });

  test('Add Qaza preserves centralized availability and final preflight', () {
    final source =
        File('lib/features/qaza/add_qaza_controller.dart').readAsStringSync();

    expect(source, contains('getAvailablePrayersByDate('));
    expect(source, contains('analyzeAvailability('));
    expect(source, contains('_refreshPrayerAvailability()'));
    expect(source, contains('selectedDateAvailability'));
    expect(source, contains('_hasCompleteAvailabilitySnapshot'));
    expect(source, contains('AddQazaSelectionRules.normalizeForMode'));
    expect(source, contains('_prayerAvailabilityRequest'));
    expect(source, contains('++_analysisRequest'));
    expect(source, contains('retainAll(addable)'));
    expect(source, contains('ProfileRules.startPrayingDate(profile)'));
    expect(source, contains('calendarTodayProvider'));
    expect(source, contains('ProfileRules.effectiveWitr(profile)'));
    expect(source, contains('statusCountTotal'));
  });

  test('Add Qaza starts the addition pipeline without operation logging', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();
    final controller =
        File('lib/features/qaza/qaza_import_controller.dart').readAsStringSync();

    expect(source, contains('qazaImportProvider.notifier).start('));
    expect(source, isNot(contains('QazaOperationType')));
    expect(source, isNot(contains('inputSnapshot')));
    expect(controller, isNot(contains('QazaOperationType')));
    expect(controller, isNot(contains('qazaOperationServiceProvider')));
    expect(controller, contains('createOrEdit('));
    expect(controller, contains('additionId'));
    expect(controller, contains('expectedRevision'));
  });

  test('Add Qaza uses shared determinate import progress without a cancel action', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();
    final progress = File(
      'lib/features/qaza/qaza_import_progress_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('QazaImportProgressDialog('));
    expect(source, isNot(contains('qazaImportProvider.notifier).cancel()')));
    expect(
      progress,
      contains('LinearProgressIndicator(value: state.progress)'),
    );
    expect(progress, contains('qazaImportAdded'));
    expect(progress, contains('qazaImportSkipped'));
    expect(progress, isNot(contains('commonCancel')));

    final controller =
        File('lib/features/qaza/qaza_import_controller.dart').readAsStringSync();
    expect(controller, contains('bool cancel()'));
    expect(controller, contains('QazaImportTaskPhase.cancelled'));
    expect(controller, contains('_cancelRequested = false;'));

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

  test('Add Qaza exposes the shared Restricted Time row and Prayer Time navigation', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();
    final navigation =
        File('lib/features/qaza/qaza_navigation.dart').readAsStringSync();
    final timeline =
        File('lib/features/prayer_time/presentation/prayer_timeline_row.dart')
            .readAsStringSync();

    expect(source, contains('qazaCompletionRestrictedProvider'));
    expect(source, contains('_RestrictedTimeAddQazaRow'));
    expect(source, contains('RestrictedTimeTimelineRow('));
    expect(source, contains('onTap: () => openPrayerTimeFromRoute(context, ref)'));
    expect(navigation, contains('WorkspaceDestination.prayerTime'));
    expect(navigation, contains('openPrayerTimeFromRoute'));
    expect(navigation, contains('if (navigator.canPop()) navigator.pop();'));
    expect(timeline, contains('onTap: onTap'));
  });

  test('Restricted Time navigation does not mutate Qaza data', () {
    final source =
        File('lib/features/qaza/add_qaza_screen.dart').readAsStringSync();
    final start = source.indexOf('class _RestrictedTimeAddQazaRow');
    final end = source.indexOf('class _ModeSelector', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final row = source.substring(start, end);
    expect(row, contains('openPrayerTimeFromRoute(context, ref)'));
    expect(row, isNot(contains('addQazaControllerProvider.notifier')));
    expect(row, isNot(contains('qazaImportProvider')));
    expect(row, isNot(contains('qazaServiceProvider')));
  });

  test('AppScaffold supports reusable bottom actions', () {
    final source =
        File('lib/core/widgets/app_scaffold.dart').readAsStringSync();

    expect(source, contains('this.bottomNavigationBar'));
    expect(source, contains('bottomNavigationBar: bottomNavigationBar'));
  });

  test('Add Qaza separates Range date validity from target-mode availability', () {
    final source =
        File('lib/features/qaza/add_qaza_controller.dart').readAsStringSync();

    expect(source, contains('case DateSelectionMode.range:'));
    expect(
      source,
      contains('// Range intentionally ignores prayer availability.'),
    );
    expect(source, contains('case DateSelectionMode.single:'));
    expect(source, contains('case DateSelectionMode.multiple:'));
    expect(
      source,
      contains(
        '_restoreCalendarSelection(mode: mode, dates: normalized)',
      ),
    );
  });

  test('disabled Witr is removed from shared selection grid', () {
    final source =
        File('lib/core/widgets/prayer_selection_grid.dart').readAsStringSync();

    expect(
      source,
      contains(
        ".where((prayer) => prayer != PrayerType.witr || witrAllowed)",
      ),
    );
    expect(source, contains('itemCount: prayers.length'));
    expect(source, contains('final prayer = prayers[index];'));
  });

}
