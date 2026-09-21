import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/prayer_progress_row.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import '../calculator/calculator_screen.dart';
import 'home_next_qaza_card.dart';
import 'home_plan.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/qaza_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeNextQazaProvider);
    ref.invalidate(homeDailyProgressProvider);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(homeNextQazaProvider);
    ref.invalidate(homeDailyProgressProvider);
    await ref.read(progressSummaryProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);
    return AppScaffold(
      // Minimal header: Account and Notifications live in Settings.
      title: l10n.homeTitle,
      body: summaryAsync.when(
        loading: () => const _HomeSkeleton(),
        error: (_, __) => _message(l10n.homeProgressError),
        data: (summary) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, QazaProgressSummary summary) {
    final l10n = AppLocalizations.of(context);
    final overall = summary.overall;

    // Nothing recorded at all: the page offers the two ways in instead.
    if (overall.total == 0) {
      return _EmptyLedger(
        onCalculate: () => _open(context, ref, const CalculatorScreen()),
        onAdd: () => _open(context, ref, const AddQazaScreen()),
      );
    }

    final plan = ref.watch(homeQazaPlanProvider);
    final dailyState = ref.watch(homeDailyProgressProvider);
    final now = ref.watch(homeNowProvider);

    return ListView(
      key: const Key('home_dashboard'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary daily action: deliberately first so the user never
                // has to scroll past statistics to find the next Qaza.
                const HomeNextQazaCard(),
                const SizedBox(height: 12),
                _ProgressOverview(progress: overall),
                const SizedBox(height: 12),
                _TodayProgress(state: dailyState),
                const SizedBox(height: 12),
                _QazaPlanCard(
                  pending: overall.pending,
                  completedToday: dailyState.valueOrNull?.completed ?? 0,
                  dailyState: dailyState,
                  plan: plan,
                  now: now,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const Key('home_view_all_qaza'),
                    onPressed: () => openQazaAll(ref),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(l10n.homeViewAllQaza),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeProgressTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final prayer in PrayerType.values)
                  PrayerProgressRow(
                    prayer: prayer,
                    progress: summary.byPrayer[prayer]?.progress ??
                        const QazaProgress(pending: 0, completed: 0),
                    onTap: () => openQazaForPrayer(ref, prayer),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _message(String text) =>
      ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(text, textAlign: TextAlign.center)))
      ]);
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        const _HomeSkeletonCard(height: 118),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: SkeletonText(width: 180, height: 22)),
            SizedBox(width: 12),
            SkeletonText(width: 60, height: 14),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 6; i++) ...[
          const _HomePrayerSkeleton(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HomeSkeletonCard extends StatelessWidget {
  const _HomeSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonText(width: 150, height: 18)),
                  SizedBox(width: 12),
                  SkeletonText(width: 84, height: 16),
                ],
              ),
              Spacer(),
              SkeletonBox(width: double.infinity, height: 8,
                  borderRadius: BorderRadius.all(Radius.circular(999))),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePrayerSkeleton extends StatelessWidget {
  const _HomePrayerSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SkeletonCircle(size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 92, height: 16),
                  SizedBox(height: 8),
                  SkeletonText(width: 150, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonText(width: 52, height: 14),
          ],
        ),
      ),
    );
  }
}

/// What Home shows before any Qaza has been recorded.
///
/// Stays scrollable so pull-to-refresh still reaches the ledger, and offers
/// the same two entry points the dashboard does.
class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.onCalculate, required this.onAdd});

  final VoidCallback onCalculate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const Key('home_empty_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: l10n.homeHeadingSetup,
              message: l10n.homeSetupMessage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    key: const Key('home_empty_calculate'),
                    expand: true,
                    icon: Icons.calculate_outlined,
                    label: l10n.homeCalculateQaza,
                    onPressed: onCalculate,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    key: const Key('home_empty_add'),
                    expand: true,
                    secondary: true,
                    icon: Icons.add_rounded,
                    label: l10n.homeAddManually,
                    onPressed: onAdd,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The overall completed share, presented as one compact summary row and bar.
class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});

  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final percent = (progress.percentage * 100).round();

    return AppCard(
      key: const Key('home_progress_overview'),
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.homeProgressTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${progress.completed} of ${progress.total} ${l10n.statusCompleted.toLowerCase()} · $percent%',
                  key: const Key('home_progress_summary'),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: const Key('home_progress_bar'),
              value: progress.percentage,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}


class _TodayProgress extends ConsumerWidget {
  const _TodayProgress({required this.state});

  final AsyncValue<HomeDailyProgress> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      key: const Key('home_today_progress'),
      child: state.when(
        loading: () => const _TodayProgressSkeleton(),
        error: (_, __) => Row(
          children: [
            const Icon(Icons.refresh_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.homeDailyProgressError)),
            TextButton(
              key: const Key('home_daily_progress_retry'),
              onPressed: () => ref.invalidate(homeDailyProgressProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
        data: (progress) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.homeTodayProgress,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homeDailyProgress(progress.completed, progress.target),
              key: const Key('home_daily_progress_summary'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                key: const Key('home_daily_progress_bar'),
                value: progress.percentage,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.homeDailyRemaining(progress.remainingToTarget),
              key: const Key('home_daily_remaining'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayProgressSkeleton extends StatelessWidget {
  const _TodayProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonText(width: 150, height: 18),
        SizedBox(height: 10),
        SkeletonText(width: 120, height: 24),
        SizedBox(height: 10),
        SkeletonBox(
          width: double.infinity,
          height: 6,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        SizedBox(height: 8),
        SkeletonText(width: 100, height: 12),
      ],
    );
  }
}

class _QazaPlanCard extends ConsumerWidget {
  const _QazaPlanCard({
    required this.pending,
    required this.completedToday,
    required this.dailyState,
    required this.plan,
    required this.now,
  });

  static const _targetOptions = [1, 2, 3, 5, 10, 15, 20, 30, 50];

  final int pending;
  final int completedToday;
  final AsyncValue<HomeDailyProgress> dailyState;
  final HomeQazaPlanState plan;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = plan.dailyTarget;
    final estimate = dailyState.valueOrNull == null || pending == 0
        ? null
        : homeEstimatedCompletionDate(
            now: now,
            pending: pending,
            dailyTarget: target,
            completedToday: completedToday,
          );

    return AppCard(
      key: const Key('home_qaza_plan'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeQazaPlan,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final selector = DropdownButton<int>(
                key: const Key('home_daily_target'),
                value: _targetOptions.contains(target)
                    ? target
                    : HomeQazaPlanState.defaultDailyTarget,
                items: [
                  for (final value in _targetOptions)
                    DropdownMenuItem<int>(
                      value: value,
                      child: Text(l10n.homePerDay(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(homeQazaPlanProvider.notifier)
                        .setDailyTarget(value);
                  }
                },
              );

              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.homeDailyTarget),
                    const SizedBox(height: 4),
                    selector,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: Text(l10n.homeDailyTarget)),
                  selector,
                ],
              );
            },
          ),
          if (estimate != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.homeEstimatedCompletion(
                DateFormatters.formatGregorianDatePadded(estimate),
              ),
              key: const Key('home_estimated_completion'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
