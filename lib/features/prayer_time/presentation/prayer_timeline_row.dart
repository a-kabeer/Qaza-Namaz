import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/date_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/restricted_time.dart';

enum PrayerTimelineRowVariant {
  card,
  cohesive,
}

class PrayerTimelineRow extends StatelessWidget {
  const PrayerTimelineRow({
    super.key,
    required this.name,
    required this.time,
    this.countdown,
    this.active = false,
    this.icon,
    this.variant = PrayerTimelineRowVariant.card,
    this.restricted = false,
  });

  final String name;
  final String time;
  final String? countdown;
  final bool active;
  final IconData? icon;
  final PrayerTimelineRowVariant variant;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    return variant == PrayerTimelineRowVariant.cohesive
        ? _buildCohesive(context)
        : _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final timeColor = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final countdownColor =
        active ? scheme.onPrimaryContainer : scheme.primary;

    return Card(
      margin: EdgeInsets.zero,
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
            if (countdown != null)
              Text(
                countdown!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: countdownColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            const SizedBox(width: 16),
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: timeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCohesive(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final background = active
        ? scheme.primaryContainer
        : Colors.transparent;
    final iconBackground = active
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHighest;
    final iconColor = active ? scheme.primary : scheme.onSurfaceVariant;
    final nameColor = active ? scheme.onPrimaryContainer : scheme.onSurface;
    final timeColor =
        active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: active
            ? Border.all(
                color: scheme.primary.withValues(alpha: .18),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: nameColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.end,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: timeColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
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
    final restricted = ref.watch(qazaCompletionRestrictedProvider);
    if (!restricted) return const SizedBox.shrink();

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
