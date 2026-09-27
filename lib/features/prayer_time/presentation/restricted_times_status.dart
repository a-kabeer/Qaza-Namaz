import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/date_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/restricted_time.dart';

class RestrictedTimesStatusCard extends ConsumerWidget {
  const RestrictedTimesStatusCard({
    super.key,
    this.compact = false,
    this.showUpcomingWhenInactive = false,
  });

  final bool compact;
  final bool showUpcomingWhenInactive;

  String _label(AppLocalizations l10n, RestrictedTimeType type) =>
      switch (type) {
        RestrictedTimeType.sunrise => l10n.prayerTimeSunrise,
        RestrictedTimeType.zawal => l10n.prayerTimeZawal,
        RestrictedTimeType.sunset => l10n.prayerTimeSunset,
      };

  String _formatDuration(Duration duration) =>
      DateFormatters.formatDurationHhMmSs(duration);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
    final state = ref.watch(restrictedTimeStateProvider);
    final now = ref.watch(prayerTimeClockProvider).valueOrNull;
    if (snapshot == null || state == null || now == null) {
      return const SizedBox.shrink();
    }

    final active = state.active;
    final next = state.next;
    if (active == null && !showUpcomingWhenInactive) {
      return const SizedBox.shrink();
    }

    final window = active ?? next;
    if (window == null) return const SizedBox.shrink();

    final location = tz.getLocation(snapshot.location.timezoneId);
    final localNow = tz.TZDateTime.from(now, location);
    final isActive = active != null;
    final remaining = isActive ? state.remainingAt(localNow) : null;
    final scheme = Theme.of(context).colorScheme;

    final content = Row(
      children: [
        Icon(
          Icons.lock_clock_rounded,
          size: compact ? 20 : 22,
          color: isActive ? scheme.onSecondaryContainer : scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(l10n, window.type),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive ? scheme.onSecondaryContainer : null,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                isActive
                    ? l10n.prayerTimeRemaining(_formatDuration(remaining!))
                    : l10n.prayerTimeNextRestricted(_label(l10n, window.type)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (isActive)
          Chip(
            label: Text(l10n.prayerTimeActive),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
          ),
      ],
    );

    return Card(
      color: isActive ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: content,
      ),
    );
  }

}
