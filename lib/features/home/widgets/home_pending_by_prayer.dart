import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../l10n/prayer_type_l10n.dart';

import '../../qaza/qaza_navigation.dart';

class HomePendingByPrayer extends ConsumerWidget {
  const HomePendingByPrayer({super.key, required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final charts = AppChartColors.of(context);
    final enabledPrayers = ref.watch(enabledPrayerTypesProvider);
    final pendingPrayers = enabledPrayers
        .where(
          (prayer) => (summary.byPrayer[prayer]?.progress.pending ?? 0) > 0,
        )
        .toList(growable: false);
    final totalPending = pendingPrayers.fold<int>(
      0,
      (total, prayer) => total + summary.byPrayer[prayer]!.progress.pending,
    );

    return Card(
      key: const Key('home_pending_by_prayer'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.homePendingByPrayer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  constraints: const BoxConstraints(minWidth: 58),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormatters.formatCount(totalPending),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.homePending,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingPrayers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 22,
                      color: charts.completed,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.completeNoPendingTitle,
                        key: const Key('home_pending_by_prayer_empty'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              for (var index = 0; index < pendingPrayers.length; index++) ...[
                _PrayerPendingBar(
                  prayer: pendingPrayers[index],
                  progress: summary.byPrayer[pendingPrayers[index]]!.progress,
                  charts: charts,
                  onTap: () => openQazaForPrayer(ref, pendingPrayers[index]),
                ),
                if (index < pendingPrayers.length - 1)
                  const Divider(height: 1, indent: 52),
              ],
              const Divider(height: 1, indent: 52),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const Key('home_pending_by_prayer_view_all'),
                onPressed: () => openQazaAll(ref),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(l10n.homeViewAll),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
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

class _PrayerPendingBar extends StatelessWidget {
  const _PrayerPendingBar({
    required this.prayer,
    required this.progress,
    required this.charts,
    required this.onTap,
  });

  final PrayerType prayer;
  final QazaProgress progress;
  final AppChartColors charts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fraction = progress.total <= 0
        ? 0.0
        : (progress.pending / progress.total).clamp(0.0, 1.0).toDouble();
    final prayerLabel = prayer.localizedLabel(l10n);
    final pendingLabel = DateFormatters.formatCount(progress.pending);
    final prayerColor = charts.forPrayer(prayer);

    return Semantics(
      key: Key('home_pending_prayer_semantics_${prayer.name}'),
      button: true,
      label: '$prayerLabel, $pendingLabel ${l10n.homePending}',
      child: InkWell(
        key: Key('home_pending_prayer_${prayer.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: prayerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      homePrayerIcon(prayer),
                      size: 22,
                      color: prayerColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prayerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pendingLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.homePending,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 52, end: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: Key('home_pending_bar_${prayer.name}'),
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: charts.track,
                    color: prayerColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData homePrayerIcon(PrayerType prayer) {
  switch (prayer) {
    case PrayerType.fajr:
      return Icons.wb_twilight_outlined;
    case PrayerType.zuhr:
      return Icons.wb_sunny_outlined;
    case PrayerType.asr:
      return Icons.sunny_snowing;
    case PrayerType.maghrib:
      return Icons.wb_twilight;
    case PrayerType.isha:
      return Icons.nightlight_outlined;
    case PrayerType.witr:
      return Icons.nightlight_round;
  }
}
