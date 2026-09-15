import 'package:flutter/material.dart';

import 'app_card.dart';
import 'metric_tile.dart';

import '../../domain/entities/qaza_progress.dart';

class ProgressOverviewCard extends StatelessWidget {
  const ProgressOverviewCard({super.key, required this.progress, this.header});

  final QazaProgress progress;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 16)],
          Row(
            children: [
              Expanded(child: MetricTile(label: 'Pending', value: '${progress.pending}')),
              Expanded(child: MetricTile(label: 'Completed', value: '${progress.completed}')),
              Expanded(child: MetricTile(label: 'Total', value: '$total')),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: ratio, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text(total == 0 ? 'No records yet' : '${(ratio * 100).round()}% completed'),
        ],
      ),
    );
  }
}
