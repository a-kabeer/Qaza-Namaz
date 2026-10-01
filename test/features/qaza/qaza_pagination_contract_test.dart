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

  test('Pending tracker controller uses the forward keyset cursor', () {
    final source =
        File('lib/features/qaza/qaza_tracker_controller.dart')
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');

    expect(
      source,
      contains(
        'afterOriginalDate: completed ? after?.originalDate : null,',
      ),
    );
    expect(
      source,
      contains(
        'afterId: completed ? after?.id : null,',
      ),
    );
    expect(
      source,
      contains(
        'beforeCompletedAt: completed ? after?.completedAt : null,',
      ),
    );
    expect(
      source,
      contains(
        'beforeId: completed ? after?.id : null,',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'beforeOriginalDate: completed ? null : after?.originalDate,',
        ),
      ),
    );
  });
}
