import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/icon_action_button.dart';
import '../../../domain/entities/qaza_activity.dart';
import '../../../domain/services/qaza_activity_service.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';

class HomeQazaGoals extends ConsumerWidget {
  const HomeQazaGoals({
    super.key,
    required this.onDetails,
  });

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activity = ref.watch(homeQazaActivityCurrentWeekProvider);

    return Card(
      key: const Key('home_qaza_goals'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: activity.when(
          loading: () => const SizedBox(
            height: 104,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => Row(
            children: [
              const Icon(Icons.refresh_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.homeProgressError)),
              TextButton(
                key: const Key('home_qaza_goals_retry'),
                onPressed: () => ref.invalidate(
                  homeQazaActivityCurrentWeekProvider,
                ),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
          data: (period) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final start = period.from;
            final end = period.toExclusive.subtract(const Duration(days: 1));
            final dailyTarget =
                period.days.isEmpty ? 0 : period.days.first.target;
            final weeklyTarget =
                QazaActivityService.weeklyTargetFromDailyTarget(dailyTarget);
            final weeklyCompleted = period.totalCompleted;
            final progress = weeklyTarget <= 0
                ? 0.0
                : (weeklyCompleted / weeklyTarget)
                    .clamp(0.0, 1.0)
                    .toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeWeeklyTarget,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconActionButton(
                      key: const Key('home_qaza_goals_details'),
                      tooltip: l10n.homeViewDetails,
                      icon: Icons.chevron_right_rounded,
                      onPressed: onDetails,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatWeekRange(context, start, end),
                  key: const Key('home_qaza_goals_date_range'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l10n.homeWeeklyTargetProgress(
                        weeklyCompleted,
                        weeklyTarget,
                      ),
                      key: const Key('home_qaza_goals_progress_text'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          key: const Key('home_qaza_goals_progress'),
                          value: progress,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatWeekRange(
    BuildContext context,
    DateTime start,
    DateTime end,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final sameYear = start.year == end.year;
    final formatter = sameYear
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    return '${formatter.format(start)} – ${formatter.format(end)}';
  }
}
