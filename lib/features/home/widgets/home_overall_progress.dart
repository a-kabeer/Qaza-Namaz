import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/qaza_progress.dart';
import '../../../l10n/app_localizations.dart';

class HomeOverallProgress extends StatelessWidget {
  const HomeOverallProgress({
    super.key,
    required this.progress,
    required this.onDetails,
  });

  final QazaProgress progress;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      key: const Key('home_overall_qaza'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stats = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    l10n.homeOverallQaza,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final action = TextButton(
                    key: const Key('home_overall_view_details'),
                    onPressed: onDetails,
                    child: Text(l10n.homeViewDetails),
                  );
                  if (constraints.maxWidth < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      action,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              HomeStatLine(
                key: const Key('home_completed_value'),
                label: l10n.homeCompleted,
                value: DateFormatters.formatCount(progress.completed),
                color: AppChartColors.of(context).completed,
              ),
              HomeStatLine(
                key: const Key('home_pending_value'),
                label: l10n.homePending,
                value: DateFormatters.formatCount(progress.pending),
                color: AppChartColors.of(context).pending,
              ),
              HomeStatLine(
                key: const Key('home_total_value'),
                label: l10n.homeStatTotal,
                value: DateFormatters.formatCount(progress.total),
                color: AppChartColors.of(context).total,
              ),
            ],
          );

          final donut = _OverviewDonut(progress: progress.percentage);

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    donut,
                    const SizedBox(width: 16),
                    Expanded(child: stats),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: stats),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewDonut extends StatelessWidget {
  const _OverviewDonut({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final charts = AppChartColors.of(context);

    return SizedBox(
      key: const Key('home_overall_donut'),
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 52,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  color: charts.primary,
                  radius: 16,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - progress).clamp(0.0, 1.0).toDouble(),
                  color: charts.track,
                  radius: 16,
                  showTitle: false,
                ),
              ],
            ),
            duration: Duration.zero,
          ),
          Text(
            '${(progress * 100).round()}%',
            key: const Key('home_overall_percent'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class HomeStatLine extends StatelessWidget {
  const HomeStatLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
