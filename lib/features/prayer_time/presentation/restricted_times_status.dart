import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/restricted_time.dart';

class RestrictedTimesStatusCard extends ConsumerWidget {
  const RestrictedTimesStatusCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  String _label(AppLocalizations l10n, RestrictedTimeType type) =>
      switch (type) {
        RestrictedTimeType.sunrise => l10n.prayerTimeSunrise,
        RestrictedTimeType.zawal => l10n.prayerTimeZawal,
        RestrictedTimeType.sunset => l10n.prayerTimeSunset,
      };

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0s';
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes}m ${seconds % 60}s';
    }
    return '${duration.inHours}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
    final state = ref.watch(restrictedTimeStateProvider);
    if (snapshot == null || state == null) return const SizedBox.shrink();

    final location = tz.getLocation(snapshot.location.timezoneId);
    final now = tz.TZDateTime.now(location);
    final active = state.active;
    final next = state.next;
    final window = active ?? next;
    if (window == null) return const SizedBox.shrink();

    final isActive = active != null;
    final remaining = isActive
        ? window.endsAt.difference(now)
        : window.startsAt.difference(now);
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
                    ? l10n.prayerTimeEndsIn(_formatDuration(remaining))
                    : '${l10n.prayerTimeNextRestricted(_label(l10n, window.type))} · '
                        '${l10n.prayerTimeStartsIn(_formatDuration(remaining))}',
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
