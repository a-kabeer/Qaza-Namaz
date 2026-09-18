import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_progress_row.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import '../calculator/calculator_screen.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/complete_qaza_section.dart';
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
          onRefresh: () => CompleteQazaSection.refresh(ref),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, QazaProgressSummary summary) {
    final l10n = AppLocalizations.of(context);
    final overall = summary.overall;

    // Nothing recorded at all: the dashboard would be six zeroes and a
    // progress ring at 0%, so the page offers the two ways in instead.
    if (overall.total == 0) {
      return _EmptyLedger(
        onCalculate: () => _open(context, ref, const CalculatorScreen()),
        onAdd: () => _open(context, ref, const AddQazaScreen()),
      );
    }

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
                const SizedBox(height: 20),
                // The Complete Qaza page's own section, not a copy of it.
                const CompleteQazaSection(keyPrefix: 'home_complete'),
                const SizedBox(height: 20),
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

/// The overall completed share, with the counts behind it underneath.
///
/// Sits on `primaryContainer`, which is what [ProgressRing] draws its own
/// colours against, and makes the overview the page's visual anchor.
class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});

  final QazaProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AppCard(
      key: const Key('home_progress_overview'),
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // The completed share leads the card at its full size.
          ProgressRing(
            key: const Key('home_progress_ring'),
            progress: progress.percentage,
            size: 132,
            strokeWidth: 10,
          ),
          const SizedBox(height: 20),
          // Three counts under it. Pending is what the reader acts on, so it
          // carries the weight; Total and Completed are the context for it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(label: l10n.homeStatTotal, value: progress.total),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.statusPending,
                  value: progress.pending,
                  valueKey: const Key('home_pending_value'),
                  emphasis: true,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.statusCompleted,
                  value: progress.completed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasis = false,
  });

  final String label;
  final int value;
  final Key? valueKey;

  /// Draws the count at display size instead of title size.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.onPrimaryContainer;
    final valueStyle =
        emphasis ? theme.textTheme.displaySmall : theme.textTheme.titleLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            key: valueKey,
            style: valueStyle?.copyWith(
                color: colour, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colour.withValues(alpha: emphasis ? 1 : .80),
            fontWeight: emphasis ? FontWeight.w600 : null,
          ),
        ),
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
