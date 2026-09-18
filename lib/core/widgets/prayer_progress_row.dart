import 'package:flutter/material.dart';

import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../constants/prayer_types.dart';
import 'app_card.dart';
import 'prayer_visuals.dart';

/// One prayer's standing, tappable across its whole width.
class PrayerProgressRow extends StatelessWidget {
  const PrayerProgressRow({
    super.key,
    required this.prayer,
    required this.progress,
    required this.onTap,
    this.keyPrefix = 'home',
  });

  final PrayerType prayer;
  final QazaProgress progress;
  final VoidCallback onTap;

  /// Namespaces the row's widget keys, so two screens showing the list at
  /// the same time stay distinguishable in tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final percent = (progress.percentage * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('${keyPrefix}_prayer_row_${prayer.name}'),
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.secondaryContainer,
                // The shared prayer icon vocabulary, not a local one.
                child: Icon(prayer.icon, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.localizedLabel(l10n),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l10n.homeCompletedCount(progress.completed),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              key:
                                  Key('${keyPrefix}_prayer_bar_${prayer.name}'),
                              value: progress.percentage,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bare percentage, matching ProgressRing's own label;
                        // the row is too narrow on a small screen for the
                        // longer "N% completed" sentence.
                        Text(
                          '$percent%',
                          key:
                              Key('${keyPrefix}_prayer_percent_${prayer.name}'),
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Pending only, immediately before the arrow.
              Text(
                '${progress.pending}',
                key: Key('${keyPrefix}_prayer_pending_${prayer.name}'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              // Material chevrons do not mirror themselves, so the arrow is
              // chosen for the reading direction and points onward in Urdu too.
              Icon(Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
