import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending Qaza completion is swipe-only in both directions', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(source, contains('direction: DismissDirection.horizontal'));
    expect(source, contains('DismissDirection.startToEnd: 0.32'));
    expect(source, contains('DismissDirection.endToStart: 0.32'));
    expect(
      source,
      contains(
        'secondaryBackground: const _CompletionSwipeBackground',
      ),
    );
    expect(
      source,
      contains(
        'Swipe left or right to complete. Long press to select.',
      ),
    );
    expect(source, contains('showQazaUndoFeedback('));
    expect(source, contains('onTap: onTap'));
    expect(
      source,
      isNot(
        contains(
          'Tap to complete. Swipe to complete. Long press to select.',
        ),
      ),
    );
  });

  test('workspace Back cancels Qaza selection before returning Home', () {
    final source =
        File('lib/features/shell/workspace_shell.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../qaza/qaza_tracker_controller.dart';",
      ),
    );
    expect(
      source,
      contains(
        'if (destination == WorkspaceDestination.qaza)',
      ),
    );
    expect(source, contains('if (qazaState.selectionMode)'));
    expect(
      source,
      contains(
        'qazaTrackerControllerProvider(null).notifier',
      ),
    );
    expect(source, contains('exitSelectionMode();'));
    expect(
      source,
      contains('WorkspaceDestination.home;'),
    );
  });

  test('selection mode preserves the shared tracker header slot', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(
      source,
      contains('class _QazaTrackerHeader extends StatelessWidget {'),
    );
    expect(
      source,
      contains(
        'static const double _headerContentHeight = kTextTabBarHeight;',
      ),
    );
    expect(source, contains('const SizedBox(height: AppSpacing.sm),'));
    expect(source, contains('height: _headerContentHeight,'));
    expect(source, contains('child: selectionMode'));
    expect(source, contains('? const _SelectionContextHeader()'));
    expect(source, contains('l10n.addQazaSelectionLabel'));
    expect(source, contains('Icons.checklist_rounded'));
    expect(source, isNot(contains('if (!state.selectionMode) ...[')));
  });

  test(
    'selection mode keeps the Qaza row footprint stable and uses trailing checkbox',
    () {
      final source =
          File('lib/features/qaza/qaza_tracker_screen.dart')
              .readAsStringSync()
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n');

      expect(source, contains('static const double _rowHeight = 68;'));
      expect(
        source,
        contains(
          'child: SizedBox(\n        height: _rowHeight,\n        child: ListTile(',
        ),
      );
      expect(source, contains('trailing: SizedBox('));
      expect(source, contains('width: _selectionControlWidth,'));
      expect(source, contains('height: _selectionControlWidth,'));
      expect(
        source,
        contains(
          'selectionMode && record.status == QazaStatus.pending',
        ),
      );
      expect(source, isNot(contains('leading: selectionMode')));
      expect(
        source,
        contains(
          'selectable ? (_) => onTap!() : null',
        ),
      );
    },
  );

  test('single swipe completion never enters user-visible selection mode', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<QazaCompletionBatchReceipt?> completeRecordWithUndo(',
    );
    final end = source.indexOf(
      'Future<int> deleteSelected()',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = source.substring(start, end);
    expect(method, contains('_completeRecordIdsWithUndo([recordId])'));
    expect(method, isNot(contains('selectionMode: true')));
    expect(method, isNot(contains('selectionMode: true')));
    expect(method, isNot(contains('selected: <String>{recordId}')));
  });

  test('swipe feedback callback uses the stable tracker context', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(source, contains('itemBuilder: (_, index) {'));
    expect(
      source,
      contains(
        ': () => _completeSingle(context, ref, record),',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          ': () => _completeSingle(_, ref, record),',
        ),
      ),
    );
  });

  test('single swipe shows global Undo feedback only after completion returns', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();
    final completionIndex =
        source.indexOf('await controller.completeRecordWithUndo(record.id)');
    final feedbackIndex =
        source.indexOf('await showQazaUndoFeedback(', completionIndex);

    expect(completionIndex, greaterThanOrEqualTo(0));
    expect(feedbackIndex, greaterThan(completionIndex));
  });


  test('Qaza tracker has no dedicated History tab or operation subsystem', () {
    final screen =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();
    final controller =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();

    expect(screen, isNot(contains('QazaHistoryScreen')));
    expect(screen, isNot(contains('TabBar(')));
    expect(screen, isNot(contains('Pending/History')));
    expect(controller, isNot(contains('QazaOperation')));
    expect(controller, isNot(contains('QazaRecoveryRepository')));
    expect(controller, isNot(contains('deleteSelectedWithRecovery')));
  });

  test('Qaza Undo feedback uses the global Undo Snackbar service', () {
    final source =
        File('lib/features/qaza/qaza_undo_feedback.dart').readAsStringSync();

    expect(
      source,
      contains(
        'ref.read(appSnackbarServiceProvider).undo(',
      ),
    );
  });

  test('shared completion pipeline persists before refreshing the tracker', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();

    final persistIndex = source.indexOf(
      'completeRecordsWithReceipt(',
    );
    final refreshIndex = source.indexOf(
      'await refresh();',
      persistIndex,
    );

    expect(persistIndex, greaterThanOrEqualTo(0));
    expect(refreshIndex, greaterThan(persistIndex));
  });

  test('filter sheet reads live Riverpod filter state while it remains open', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(source, contains('class _FilterSheet extends ConsumerWidget {'));
    expect(source, contains('_FilterSheet(additionId: additionId)'));
    expect(
      source,
      contains(
        'builder: (context) => _FilterSheet(additionId: additionId),',
      ),
    );
    expect(
      source,
      contains(
        'final state = ref.watch(qazaTrackerControllerProvider(additionId));',
      ),
    );
    expect(
      source,
      contains(
        'qazaTrackerControllerProvider(additionId).notifier',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          '_FilterSheet(state: state, controller: controller)',
        ),
      ),
    );
    expect(
      source,
      contains(
        'selected: state.prayerFilter == prayer,',
      ),
    );
    expect(
      source,
      contains(
        'selected: state.prayerFilter == null,',
      ),
    );
  });

  test('refresh preserves the active prayer filter in tracker state', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();
    final start = source.indexOf('Future<void> refresh() async {');
    final end = source.indexOf(
      '  /// Reads a bounded page using the status-specific fixed ordering.',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final refreshMethod = source.substring(start, end);
    expect(refreshMethod, contains('selected: const <String>{},'));
    expect(refreshMethod, isNot(contains('clearPrayerFilter: true')));
  });

  test('prayer filter state updates synchronously before refresh', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();
    final start = source.indexOf('void setPrayerFilter(PrayerType? prayer) {');
    final end = source.indexOf(
      '  void setDateRange(DateTime? from, DateTime? to) {',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = source.substring(start, end);
    final stateUpdateIndex = method.indexOf('state =');
    final refreshIndex = method.indexOf('refresh();');

    expect(stateUpdateIndex, greaterThanOrEqualTo(0));
    expect(refreshIndex, greaterThan(stateUpdateIndex));
    expect(method, contains('copyWith(prayerFilter: prayer)'));
    expect(method, contains('clearPrayerFilter: true'));
  });

  test('disabled Witr is absent from tracker filters', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        'final enabledPrayers = ref.watch(enabledPrayerTypesProvider);',
      ),
    );
    expect(source, contains('for (final prayer in enabledPrayers)'));
    expect(source, isNot(contains('for (final prayer in PrayerType.values)')));
  });


  test('Qaza reuses the shared active restricted-time timeline row', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../prayer_time/presentation/prayer_timeline_row.dart';",
      ),
    );
    expect(source, contains('child: RestrictedTimeTimelineRow(),'));
    expect(source, isNot(contains('RestrictedTimesStatusCard')));
  });


  test('Qaza workspace exposes a Pending/Completed switch and no sorting control', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();
    final controller =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();

    expect(source, contains("key: const Key('qaza_status_switch')"));
    expect(source, contains('QazaStatusFilter.pending'));
    expect(source, contains('QazaStatusFilter.completed'));
    expect(source, isNot(contains('QazaSortOrder')));
    expect(source, isNot(contains('SegmentedButton<QazaSortOrder>')));
    expect(controller, isNot(contains('setSortOrder')));
    expect(controller, isNot(contains('QazaSortOrder')));
  });

  test('Completed workspace uses completion-time keyset paging and fixed newest-first order', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();
    final dao =
        File('lib/data/local/database/qaza_records_dao.dart').readAsStringSync();

    expect(source, contains('beforeCompletedAt: completed ? after?.completedAt : null'));
    expect(source, contains('status: state.statusFilter.status'));
    expect(dao, contains('OrderingTerm.desc(r.completedAt)'));
    expect(dao, contains('OrderingTerm.desc(r.id)'));
    expect(dao, contains('row.completedAt.isNotNull()'));
  });

  test('Completed rows remain compact and expose required dates and completion time', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    final start = source.indexOf('class _CompletedRecordRow');
    final end = source.indexOf('class _CompletedRecordDetails', start);
    final row = source.substring(start, end);

    expect(row, contains('DateFormatters.formatClockTime(completedAt)'));
    expect(row, contains('DateFormatters.formatGregorianDatePadded(record.originalDate)'));
    expect(row, contains('l10n.formatHijriDate(record.originalDate)'));
    expect(row, contains("Icons.check_circle_rounded"));
    expect(row, isNot(contains('Card(')));
  });

  test('Completed detail provides permanent Mark as Pending correction', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();
    final service =
        File('lib/domain/services/qaza_service.dart').readAsStringSync();
    final controller =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();

    expect(source, contains('Mark as Pending'));
    expect(source, contains('confirmDestructive'));
    expect(controller, contains('markCompletedAsPending'));
    expect(service, contains('Future<bool> markCompletedAsPending'));
    expect(service, contains('clearCompletedAt: true'));
    expect(service, contains('clearCompletionId: true'));
  });

  test('Home and tracker both depend on the shared completion controller', () {
    final home =
        File('lib/features/home/widgets/home_today_progress.dart').readAsStringSync();
    final tracker =
        File('lib/features/qaza/qaza_tracker_controller.dart').readAsStringSync();

    expect(home, contains('qazaCompletionControllerProvider.notifier'));
    expect(tracker, contains('qazaCompletionControllerProvider.notifier'));
    expect(tracker, contains('completeRecordsWithReceipt('));
    expect(home, contains('QazaCompletionReceipt'));
  });

  test('Undo feedback supports selected and all restoration', () {
    final source =
        File('lib/features/qaza/qaza_undo_feedback.dart').readAsStringSync();
    final service =
        File('lib/domain/services/qaza_undo_service.dart').readAsStringSync();

    expect(source, contains('Undo Selected'));
    expect(source, contains('Undo All'));
    expect(source, contains('undoSelected('));
    expect(service, contains('Future<QazaUndoResult> undoSelected('));
    expect(service, contains('Never clear the store here'));
  });
}
