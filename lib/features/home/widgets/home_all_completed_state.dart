import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class HomeAllCompletedState extends StatelessWidget {
  const HomeAllCompletedState({
    super.key,
    required this.completed,
    required this.total,
    required this.onCalculate,
    required this.onAdd,
  });

  final int completed;
  final int total;
  final VoidCallback onCalculate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      key: const Key('home_all_completed_state'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.check_rounded, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeOverallQaza,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeCompleted,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: l10n.homeCompleted,
                  value: completed.toString(),
                ),
                _StatRow(
                  label: l10n.homeStatTotal,
                  value: total.toString(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('home_all_completed_calculate'),
                      onPressed: onCalculate,
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(l10n.homeCalculateQaza),
                    ),
                    OutlinedButton.icon(
                      key: const Key('home_all_completed_add'),
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.homeAddManually),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
