import 'package:flutter/material.dart';

import 'app_card.dart';
import 'metric_tile.dart';

import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';

class ProgressOverviewCard extends StatelessWidget {
  const ProgressOverviewCard({super.key, required this.progress, this.header});

  final QazaProgress progress;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 16)],
          Row(
            children: [
              Expanded(
                  child: MetricTile(
                      label: l10n.statusPending, value: '${progress.pending}')),
              Expanded(
                  child: MetricTile(
                      label: l10n.statusCompleted,
                      value: '${progress.completed}')),
              Expanded(
                  child: MetricTile(label: l10n.commonTotal, value: '$total')),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: ratio, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text(total == 0
              ? l10n.progressNoRecords
              : l10n.progressPercentCompleted((ratio * 100).round())),
        ],
      ),
    );
  }
}
