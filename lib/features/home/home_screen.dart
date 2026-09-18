import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_visuals.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/sync_status.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../calculator/calculator_screen.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/qaza_tracker_controller.dart';
import '../shell/workspace_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(progressSummaryProvider);
  }

  /// Home -> Qaza, with the tapped prayer selected and Pending applied.
  ///
  /// This drives the existing tracker filters and the existing workspace
  /// navigation rather than pushing a second tracker on top of Home, so the
  /// user lands on the Qaza tab they already know.
  void _openPrayerInTracker(WidgetRef ref, PrayerType prayer) {
    ref.read(qazaTrackerFilterRequestProvider.notifier).state =
        QazaTrackerFilterRequest(
      prayer: prayer,
      status: QazaStatusFilter.pending,
    );
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.qaza;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);
    return AppScaffold(
      // Minimal header: Account and Notifications live in Settings.
      title: l10n.homeTitle,
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _message(l10n.homeProgressError),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressSummaryProvider),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, QazaProgressSummary summary) {
    final l10n = AppLocalizations.of(context);
    final overall = summary.overall;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        const SyncStatus(),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressOverview(progress: overall),
                const SizedBox(height: 16),
                _QuickActions(
                  onCalculate: () =>
                      _open(context, ref, const CalculatorScreen()),
                  onAdd: () => _open(context, ref, const AddQazaScreen()),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.homeProgressTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final prayer in PrayerType.values)
                  _PrayerProgressRow(
                    prayer: prayer,
                    progress: summary.byPrayer[prayer]?.progress ??
                        const QazaProgress(pending: 0, completed: 0),
                    onTap: () => _openPrayerInTracker(ref, prayer),
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

/// Total, Pending and Completed beside the overall ring.
///
/// Sits on `primaryContainer`, which is what [ProgressRing] draws its own
/// colours against, and makes the overview the page's visual anchor.
class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});

  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return AppCard(
      key: const Key('home_progress_overview'),
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pending is what the user acts on, so it leads at display
                // size while Total and Completed stay supporting detail.
                Text(
                  '${progress.pending}',
                  key: const Key('home_pending_value'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.statusPending,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Stat(label: l10n.homeStatTotal, value: progress.total),
                    _Stat(
                        label: l10n.statusCompleted, value: progress.completed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ProgressRing(
            key: const Key('home_progress_ring'),
            progress: progress.percentage,
            size: 92,
            strokeWidth: 8,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: colour, fontWeight: FontWeight.w700)),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colour.withValues(alpha: .80))),
      ],
    );
  }
}

/// Calculate and Add, side by side at equal width.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCalculate, required this.onAdd});

  final VoidCallback onCalculate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: AppButton(
            key: const Key('home_calculate_qaza'),
            expand: true,
            secondary: true,
            icon: Icons.calculate_outlined,
            label: l10n.homeCalculateQaza,
            onPressed: onCalculate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            key: const Key('home_add_qaza'),
            expand: true,
            secondary: true,
            icon: Icons.add_rounded,
            label: l10n.homeAddQaza,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

/// One prayer's standing, tappable across its whole width.
class _PrayerProgressRow extends StatelessWidget {
  const _PrayerProgressRow({
    required this.prayer,
    required this.progress,
    required this.onTap,
  });

  final PrayerType prayer;
  final QazaProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final percent = (progress.percentage * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('home_prayer_row_${prayer.name}'),
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
                              key: Key('home_prayer_bar_${prayer.name}'),
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
                          key: Key('home_prayer_percent_${prayer.name}'),
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
                key: Key('home_prayer_pending_${prayer.name}'),
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
