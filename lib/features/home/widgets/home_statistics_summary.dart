import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/theme/app_theme.dart';import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/prayer_type_l10n.dart';

import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';
import 'home_skeleton.dart';

class HomeStatisticsSummaryScreen extends ConsumerWidget {
  const HomeStatisticsSummaryScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return AppScaffold(
      title: l10n.homeDetailedStatistics,
      body: summaryAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            HomeSkeletonCard(height: 210),
            SizedBox(height: 12),
            HomeSkeletonCard(height: 420),
          ],
        ),
        error: (_, __) => Center(
          child: ErrorState(
            key: const Key('detailed_statistics_error'),
            message: l10n.homeProgressError,
            onRetry: () => ref.invalidate(progressSummaryProvider),
          ),
        ),
        data: (summary) => _DetailedStatisticsContent(summary: summary),
      ),
    );
  }
}

class _DetailedStatisticsContent extends StatelessWidget {
  const _DetailedStatisticsContent({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('detailed_statistics_screen'),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        AppSpacing.fabClearance,
      ),
      children: [
        _DetailedOverallStatistics(progress: summary.overall),
        const SizedBox(height: 12),
        _DetailedPrayerBreakdown(summary: summary),
      ],
    );
  }
}

class _DetailedOverallStatistics extends StatelessWidget {
  const _DetailedOverallStatistics({required this.progress});

  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final charts = AppChartColors.of(context);
    final percent = (progress.percentage * 100).round();

    return AppCard(
      key: const Key('detailed_overall_statistics'),
      padding: const EdgeInsets.all(16),
      child: Semantics(
        container: true,
        label: progress.completed.toString() +
            ' ' +
            l10n.homeCompleted +
            ', ' +
            progress.pending.toString() +
            ' ' +
            l10n.homePending +
            ', ' +
            progress.total.toString() +
            ' ' +
            l10n.homeStatTotal +
            ', ' +
            percent.toString() +
            '%',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.homeOverallQaza,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  percent.toString() + '%',
                  key: const Key('detailed_overall_percent'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                key: const Key('detailed_overall_progress'),
                value: progress.percentage.clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                backgroundColor: charts.track,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            HomeStatLine(
              key: const Key('detailed_overall_completed'),
              label: l10n.homeCompleted,
              value: DateFormatters.formatCount(progress.completed),
              color: charts.completed,
            ),
            HomeStatLine(
              key: const Key('detailed_overall_pending'),
              label: l10n.homePending,
              value: DateFormatters.formatCount(progress.pending),
              color: charts.pending,
            ),
            HomeStatLine(
              key: const Key('detailed_overall_total'),
              label: l10n.homeStatTotal,
              value: DateFormatters.formatCount(progress.total),
              color: charts.total,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedPrayerBreakdown extends StatelessWidget {
  const _DetailedPrayerBreakdown({required this.summary});

  final QazaProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      key: const Key('detailed_prayer_breakdown'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homePrayerBreakdown,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < PrayerType.values.length; index++) ...[
            _DetailedPrayerRow(
              prayer: PrayerType.values[index],
              progress: summary.byPrayer[PrayerType.values[index]]?.progress ??
                  const QazaProgress(pending: 0, completed: 0),
            ),
            if (index != PrayerType.values.length - 1)
              Divider(
                height: 20,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailedPrayerRow extends StatelessWidget {
  const _DetailedPrayerRow({
    required this.prayer,
    required this.progress,
  });

  final PrayerType prayer;
  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final charts = AppChartColors.of(context);
    final percent = (progress.percentage * 100).round();
    final accent = charts.forPrayer(prayer);

    return Semantics(
      container: true,
      label: prayer.localizedLabel(l10n) +
          ', ' +
          progress.completed.toString() +
          ' ' +
          l10n.homeCompleted +
          ', ' +
          progress.pending.toString() +
          ' ' +
          l10n.homePending +
          ', ' +
          progress.total.toString() +
          ' ' +
          l10n.homeStatTotal +
          ', ' +
          percent.toString() +
          '%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                homePrayerIcon(prayer),
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prayer.localizedLabel(l10n),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percent.toString() + '%',
                key: Key('detailed_prayer_percent_' + prayer.name),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: Key('detailed_prayer_progress_' + prayer.name),
              value: progress.percentage.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: charts.track,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DetailedMetric(
                  key: Key('detailed_prayer_completed_' + prayer.name),
                  label: l10n.homeCompleted,
                  value: DateFormatters.formatCount(progress.completed),
                ),
              ),
              Expanded(
                child: _DetailedMetric(
                  key: Key('detailed_prayer_pending_' + prayer.name),
                  label: l10n.homePending,
                  value: DateFormatters.formatCount(progress.pending),
                ),
              ),
              Expanded(
                child: _DetailedMetric(
                  key: Key('detailed_prayer_total_' + prayer.name),
                  label: l10n.homeStatTotal,
                  value: DateFormatters.formatCount(progress.total),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailedMetric extends StatelessWidget {
  const _DetailedMetric({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
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
