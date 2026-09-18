import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_progress_row.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import '../calculator/calculator_screen.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/qaza_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(progressSummaryProvider);
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
      // The workspace FAB floats over this list, so the last prayer needs
      // room to scroll clear of it.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
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
