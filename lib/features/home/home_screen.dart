import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_progress_row.dart';
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

    // Nothing recorded at all: the page offers the two ways in instead.
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
      // No FAB is present in the empty state, so no FAB clearance is needed.
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
                // Keep the reusable completion section on Home.
                const CompleteQazaSection(keyPrefix: 'home_complete'),
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

