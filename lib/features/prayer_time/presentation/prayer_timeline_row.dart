import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/date_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/restricted_time.dart';

class PrayerTimelineRow extends StatelessWidget {
  const PrayerTimelineRow({
    super.key,
    required this.name,
    required this.time,
    this.countdown,
    this.active = false,
  });

  static const double _countdownWidth = 96;
  static const double _timeWidth = 82;

  final String name;
  final String time;
  final String? countdown;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final timeColor = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final countdownColor =
        active ? scheme.onPrimaryContainer : scheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      color: active ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: labelColor,
                    ),
              ),
            ),
            SizedBox(
              width: _countdownWidth,
              child: Text(
                countdown ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: countdownColor,
                    ),
              ),
            ),
            SizedBox(
              width: _timeWidth,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: timeColor,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestrictedTimeTimelineRow extends ConsumerWidget {
  const RestrictedTimeTimelineRow({super.key});

  String _label(AppLocalizations l10n, RestrictedTimeType type) =>
      switch (type) {
        RestrictedTimeType.sunrise => l10n.prayerTimeSunrise,
        RestrictedTimeType.zawal => l10n.prayerTimeZawal,
        RestrictedTimeType.sunset => l10n.prayerTimeSunset,
      };

  String _formatTime(
    BuildContext context,
    DateTime utc,
    String timezoneId,
  ) {
    final location = tz.getLocation(timezoneId);
    final local = tz.TZDateTime.from(utc, location);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return intl.DateFormat.jm(locale).format(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
    final state = ref.watch(restrictedTimeStateProvider);
    final now = ref.watch(prayerTimeClockProvider).valueOrNull;
    final active = state?.active;
    if (snapshot == null || state == null || now == null || active == null) {
      return const SizedBox.shrink();
    }

    final location = tz.getLocation(snapshot.location.timezoneId);
    final localNow = tz.TZDateTime.from(now, location);
    final remaining = state.remainingAt(localNow);
    if (remaining == null) return const SizedBox.shrink();

    return PrayerTimelineRow(
      key: const Key('restricted_time_timeline_row'),
      name: _label(AppLocalizations.of(context), active.type),
      time: _formatTime(
        context,
        active.displayAt.toUtc(),
        snapshot.location.timezoneId,
      ),
      countdown: DateFormatters.formatDurationHhMmSs(remaining),
      active: true,
    );
  }
}
