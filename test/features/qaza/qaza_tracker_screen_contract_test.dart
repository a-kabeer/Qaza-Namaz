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
        'ref.read(qazaTrackerControllerProvider.notifier).exitSelectionMode();',
      ),
    );
    expect(
      source,
      contains('WorkspaceDestination.home;'),
    );
  });

  test(
    'selection mode keeps the Qaza row footprint stable and uses trailing checkbox',
    () {
      final source =
          File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

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
      'Future<QazaCompletionBatch?> completeRecordWithUndo(String recordId)',
    );
    final end = source.indexOf(
      'Future<int> deleteSelectedWithRecovery()',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = source.substring(start, end);
    expect(method, contains('_completeRecordIdsWithUndo('));
    expect(method, contains('exitSelectionModeOnSuccess: false'));
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
      'final completed = await service.completeSelected(',
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
    expect(source, contains('const _FilterSheet();'));
    expect(
      source,
      contains(
        'builder: (context) => const _FilterSheet(),',
      ),
    );
    expect(
      source,
      contains(
        'final state = ref.watch(qazaTrackerControllerProvider);',
      ),
    );
    expect(
      source,
      contains(
        'final controller = ref.read(qazaTrackerControllerProvider.notifier);',
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
      '  /// Reads one bounded page in the active sort order.',
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
}
