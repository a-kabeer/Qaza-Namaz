import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prayer Time uses the cohesive dashboard composition', () {
    final source =
        File('lib/features/prayer_time/presentation/prayer_time_page.dart')
            .readAsStringSync();

    expect(source, contains("import 'prayer_timeline_row.dart';"));
    expect(source, contains("import '../../../core/widgets/prayer_visuals.dart';"));
    expect(source, contains('LocationSelectorStyle.header'));
    expect(source, contains('_PrayerTimeHeader('));
    expect(source, contains('_PrayerTimeFocusCard('));
    expect(source, contains('_PrayerSchedule('));
    expect(source, contains('PrayerTimelineRowVariant.cohesive'));
    expect(source, contains('prayer.qazaPrayerType?.icon'));
    expect(source, contains('key: const Key(\'prayer_time_focus_card\')'));
    expect(source, contains('key: const Key(\'prayer_time_schedule\')'));
    expect(source, contains('const Key(\'prayer_time_use_current_location\')'));
    expect(source, contains('final byTime = a.at.compareTo(b.at);'));
    expect(source, contains('return a.isRestricted ? -1 : 1;'));
    expect(source, contains('RestrictedTimeType.zawal'));
    expect(source, contains('RestrictedTimeType.sunset'));
    expect(
      source,
      contains(
        'DateFormatters.formatDurationHhMmSs(restrictedRemaining)',
      ),
    );
    expect(
      source,
      contains(
        'DateFormatters.formatDurationHhMmSs(nextRemaining)',
      ),
    );
    expect(source, isNot(contains('RestrictedTimesStatusCard')));
    expect(source, isNot(contains('activeLabel')));
    expect(source, isNot(contains('class _PrayerTimeRow')));
    expect(source, isNot(contains('class _RestrictedTimesCard')));
  });

  test('Shared restricted row derives its active countdown from central state',
      () {
    final source =
        File('lib/features/prayer_time/presentation/prayer_timeline_row.dart')
            .readAsStringSync();

    expect(source, contains('ref.watch(prayerTimeClockProvider)'));
    expect(source, contains('ref.watch(qazaCompletionRestrictedProvider)'));
    expect(source, contains('if (!restricted) return const SizedBox.shrink();'));
    expect(source, contains('ref.watch(restrictedTimeStateProvider)'));
    expect(source, contains('state.remainingAt(localNow)'));
    expect(
      source,
      contains('DateFormatters.formatDurationHhMmSs(remaining)'),
    );
    expect(source, contains("key: const Key('restricted_time_timeline_row')"));
    expect(source, isNot(contains('prayerTimeRemaining(')));
    expect(source, isNot(contains('prayerTimeActive')));
    expect(source, isNot(contains('Remaining time')));
  });

  test('Shared row keeps its existing card contract and adds a cohesive variant',
      () {
    final source =
        File('lib/features/prayer_time/presentation/prayer_timeline_row.dart')
            .readAsStringSync();

    expect(source, contains('enum PrayerTimelineRowVariant'));
    expect(source, contains('PrayerTimelineRowVariant.cohesive'));
    expect(source, contains('static const double _countdownWidth = 96;'));
    expect(source, contains('static const double _timeWidth = 82;'));
    expect(source, contains('width: _countdownWidth'));
    expect(source, contains('width: _timeWidth'));
    expect(source, contains('margin: EdgeInsets.zero'));
    expect(source, contains('this.icon'));
    expect(source, contains('this.restricted'));
    expect(source, contains('scheme.primaryContainer'));
    expect(source, contains('scheme.tertiary'));
  });

  test('Home reuses the shared active restricted-time row', () {
    final source =
        File('lib/features/home/widgets/home_today_progress.dart')
            .readAsStringSync();

    expect(
      source,
      contains(
        "import '../../prayer_time/presentation/prayer_timeline_row.dart';",
      ),
    );
    expect(source, contains('const RestrictedTimeTimelineRow(),'));
    expect(source, isNot(contains('RestrictedTimesStatusCard')));
  });

  test('Qaza reuses the shared active restricted-time row', () {
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
}
