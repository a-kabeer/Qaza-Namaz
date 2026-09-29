import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/home_providers.dart';

class HomeQazaGoals extends ConsumerWidget {
  const HomeQazaGoals({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activity = ref.watch(homeQazaActivitySevenDaysProvider);

    return Card(
      key: const Key('home_qaza_goals'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: activity.when(
          loading: () => const SizedBox(
            height: 94,
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
                  homeQazaActivitySevenDaysProvider,
                ),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
          data: (period) {
            final locale = Localizations.localeOf(context).languageCode;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeGoalsLastSevenDays,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.homeActual}: ${DateFormatters.formatCount(period.totalCompleted)}  •  '
                  '${l10n.homeDailyTarget}: ${DateFormatters.formatCount(period.days.isEmpty ? 0 : period.days.first.target)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < period.days.length; index++)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == period.days.length - 1 ? 0 : 10,
                          ),
                          child: _HomeGoalDay(
                            label: DateFormat.E(locale).format(
                              period.days[index].date,
                            ),
                            completed: period.days[index].completed,
                            target: period.days[index].target,
                            progress: period.days[index].progress,
                            goalReached: period.days[index].goalReached,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeGoalDay extends StatelessWidget {
  const _HomeGoalDay({
    required this.label,
    required this.completed,
    required this.target,
    required this.progress,
    required this.goalReached,
  });

  final String label;
  final int completed;
  final int target;
  final double progress;
  final bool goalReached;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 46,
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              Text(
                completed.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            target > 0 ? '$completed/$target' : '$completed',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: goalReached ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: goalReached ? FontWeight.w700 : null,
                ),
          ),
        ],
      ),
    );
  }
}