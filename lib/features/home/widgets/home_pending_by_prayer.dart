import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../qaza/qaza_navigation.dart';

class HomePendingByPrayer extends ConsumerWidget {
  const HomePendingByPrayer({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final charts = AppChartColors.of(context);
    final pendingPrayers = PrayerType.values
        .where(
          (prayer) => (summary.byPrayer[prayer]?.progress.pending ?? 0) > 0,
        )
        .toList(growable: false);

    return AppCard(
      key: const Key('home_pending_by_prayer'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homePendingByPrayer,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                key: const Key('home_pending_by_prayer_view_all'),
                onPressed: () => openQazaAll(ref),
                child: Text(l10n.homeViewAll),
              ),
            ],
          ),
          if (pendingPrayers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: charts.completed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.completeNoPendingTitle,
                    key: const Key('home_pending_by_prayer_empty'),
                  ),
                ],
              ),
            )
          else
            for (final prayer in pendingPrayers)
              _PrayerPendingBar(
                prayer: prayer,
                progress: summary.byPrayer[prayer]!.progress,
                charts: charts,
                onTap: () => openQazaForPrayer(ref, prayer),
              ),
        ],
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

    return Semantics(
      key: Key('home_pending_prayer_semantics_' + prayer.name),
      button: true,
      label: prayerLabel + ', ' + pendingLabel + ' ' + l10n.homePending,
      child: InkWell(
        key: Key('home_pending_prayer_' + prayer.name),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(
                  _prayerIcon(prayer),
                  size: 20,
                  color: charts.forPrayer(prayer),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 74,
                child: Text(
                  prayerLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: Key('home_pending_bar_' + prayer.name),
                    value: fraction,
                    minHeight: 10,
                    backgroundColor: charts.track,
                    color: charts.forPrayer(prayer),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  pendingLabel,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
