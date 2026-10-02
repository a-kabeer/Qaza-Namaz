import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Qaza tracker triggers pagination near the end of both workspaces', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart')
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');

    final pendingStart = source.indexOf(
      'class _PendingTrackerBody extends ConsumerWidget {',
    );
    final completedStart = source.indexOf(
      'class _CompletedTrackerBody extends StatelessWidget {',
    );

    expect(pendingStart, greaterThanOrEqualTo(0));
    expect(completedStart, greaterThan(pendingStart));

    final pending = source.substring(pendingStart, completedStart);
    final completed = source.substring(completedStart);

    for (final body in [pending, completed]) {
      expect(body, contains('NotificationListener<ScrollNotification>'));
      expect(body, contains('if (notification.metrics.extentAfter < 320)'));
      expect(body, contains('controller.loadMore();'));
    }
  });

  test('Tracker controller keeps sort state and separates Pending/Completed cursors', () {
    final controller =
        File('lib/features/qaza/qaza_tracker_controller.dart')
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');

    expect(controller, contains('enum QazaSortOrder'));
    expect(controller, contains('this.sortOrder = QazaSortOrder.oldestFirst'));
    expect(controller, contains('void setSortOrder(QazaSortOrder order)'));

    final readStart = controller.indexOf('Future<QazaPage> _readPage');
    final loadMoreStart = controller.indexOf('Future<void> loadMore', readStart);
    expect(readStart, greaterThanOrEqualTo(0));
    expect(loadMoreStart, greaterThan(readStart));

    final readPage = controller.substring(readStart, loadMoreStart);
    expect(
      readPage,
      contains('afterOriginalDate:'),
    );
    expect(
      readPage,
      contains('beforeOriginalDate:'),
    );
    expect(
      readPage,
      contains('afterPrayerType:'),
    );
    expect(
      readPage,
      contains('beforePrayerType:'),
    );
    expect(
      readPage,
      contains('afterCompletedAt:'),
    );
    expect(
      readPage,
      contains('beforeCompletedAt:'),
    );
    expect(readPage, contains('descending: !oldestFirst'));

    expect(
      readPage,
      contains(
        '!completed && oldestFirst ? after?.originalDate : null',
      ),
    );
    expect(
      readPage,
      contains(
        '!completed && !oldestFirst ? after?.originalDate : null',
      ),
    );
    expect(
      readPage,
      contains(
        '!completed && oldestFirst ? after?.prayerType : null',
      ),
    );
    expect(
      readPage,
      contains(
        '!completed && !oldestFirst ? after?.prayerType : null',
      ),
    );
    expect(
      readPage,
      contains(
        'completed && oldestFirst ? after?.completedAt : null',
      ),
    );
    expect(
      readPage,
      contains(
        'completed && !oldestFirst ? after?.completedAt : null',
      ),
    );
    expect(
      readPage,
      contains(
        'from: completed && state.from != null',
      ),
    );
    expect(
      readPage,
      contains(
        'toExclusive: completed && state.to != null',
      ),
    );
  });

  test('Tracker screen restores the shared localized Material 3 sort control', () {
    final screen =
        File('lib/features/qaza/qaza_tracker_screen.dart')
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');

    expect(screen, contains('class _FilterSortBar extends StatelessWidget'));
    expect(screen, contains('SegmentedButton<QazaSortOrder>'));
    expect(screen, isNot(contains('l10n.qazaSortLabel')));
    expect(screen, contains('l10n.qazaSortOldestFirst'));
    expect(screen, contains('l10n.qazaSortNewestFirst'));
    expect(screen, contains("key: const Key('qaza_tracker_sort')"));
    expect(screen, contains('EdgeInsetsDirectional.only'));
    expect(screen, contains('_FilterSortBar('));
    expect(screen, contains('state: state'));
    expect(screen, contains('controller: controller'));
    expect(screen, contains('onFilterTap: () => _openFilters(context)'));
  });
}
