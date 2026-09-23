import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../features/calculator/calculator_screen.dart';
import '../../features/qaza/add_qaza_screen.dart';
import '../../l10n/app_localizations.dart';
import 'home_controller.dart';
import 'widgets/home_empty_state.dart';
import 'widgets/home_overall_progress.dart';
import 'widgets/home_pending_by_prayer.dart';
import 'widgets/home_progress_history.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/home_statistics_summary.dart';
import 'widgets/home_today_progress.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    ref.read(homeControllerProvider).invalidateDashboard();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return AppScaffold(
      title: l10n.homeTitle,
      body: summaryAsync.when(
        loading: () => const HomeSkeleton(),
        error: (_, __) => HomeError(
          onRetry: () => ref.read(homeControllerProvider).refresh(),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider).refresh(),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    QazaProgressSummary summary,
  ) {
    if (summary.overall.total == 0) {
      return HomeEmptyState(
        onCalculate: () => _open(context, ref, const CalculatorScreen()),
        onAdd: () => _open(context, ref, const AddQazaScreen()),
      );
    }

    return ListView(
      key: const Key('home_dashboard'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        AppSpacing.fabClearance,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeTodayProgress(summary: summary),
                const SizedBox(height: 12),
                HomeOverallProgress(
                  progress: summary.overall,
                  onDetails: () => _open(
                    context,
                    ref,
                    const HomeStatisticsSummaryScreen(),
                  ),
                ),
                const SizedBox(height: 12),
                HomePendingByPrayer(summary: summary),
                const SizedBox(height: 12),
                const HomeProgressHistory(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HomeError extends StatelessWidget {
  const HomeError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      key: const Key('home_error'),
      message: AppLocalizations.of(context).homeProgressError,
      onRetry: onRetry,
    );
  }
}
