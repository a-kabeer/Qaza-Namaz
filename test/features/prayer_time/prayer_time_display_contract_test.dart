import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prayer Time renders one row countdown and reuses the shared restriction card', () {
    final source =
        File('lib/features/prayer_time/presentation/prayer_time_page.dart')
            .readAsStringSync();

    expect(
      source,
      contains(
        'const RestrictedTimesStatusCard(showUpcomingWhenInactive: true)',
      ),
    );
    expect(
      source,
      contains('DateFormatters.formatDurationHhMmSs(nextRemaining)'),
    );
    expect(
      source,
      contains('if (prayer != PrayerSlot.values.last)'),
    );
    expect(source, isNot(contains('activeLabel')));
    expect(source, isNot(contains('class _CurrentPrayerCard')));
    expect(source, isNot(contains('class _RestrictedTimesCard')));
  });

  test('shared restricted status uses the central clock and state-derived remaining time', () {
    final source =
        File('lib/features/prayer_time/presentation/restricted_times_status.dart')
            .readAsStringSync();

    expect(source, contains('ref.watch(prayerTimeClockProvider)'));
    expect(source, contains('state.remainingAt(localNow)'));
    expect(source, contains('showUpcomingWhenInactive'));
    expect(source, contains('l10n.prayerTimeRemaining(_formatDuration(remaining!))'));
    expect(source, isNot(contains('prayerTimeStartsIn(')));
  });

  test('Home hides the inactive restricted-time card', () {
    final source =
        File('lib/features/home/widgets/home_today_progress.dart')
            .readAsStringSync();

    expect(source, contains('if (restricted) ...['));
    expect(
      source,
      contains('const RestrictedTimesStatusCard(compact: true),'),
    );
  });

  test('Qaza hides the inactive restricted-time card', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart')
            .readAsStringSync();

    expect(source, contains('if (restricted)'));
    expect(source, contains('const Padding('));
    expect(
      source,
      contains('child: RestrictedTimesStatusCard(compact: true),'),
    );
  });
}
