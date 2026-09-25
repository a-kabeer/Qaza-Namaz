import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../features/settings/profile_screen.dart';
import '../../l10n/app_localizations.dart';
import '../qaza/qaza_import_controller.dart';
import 'home_controller.dart';
import 'providers/home_providers.dart';
import 'widgets/home_all_completed_state.dart';
import 'widgets/home_empty_state.dart';
import 'widgets/home_overall_progress.dart';
import 'widgets/home_pending_by_prayer.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/home_statistics_summary.dart';
import 'widgets/home_today_progress.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// The local date the dashboard was last built for.
  ///
  /// Home is a screen people leave open. Everything on it that says "today" —
  /// the date, daily progress, the history window — is derived from this, so
  /// when the day turns underneath it the whole dashboard is stale until
  /// something says so.
  DateTime? _renderedDate;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _renderedDate = ref.read(homeLocalDateProvider);
      _scheduleMidnight();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Coming back from the background is the other way the day turns without
    // this screen noticing: the process may have been suspended for hours.
    _refreshIfDayTurned();
    _scheduleMidnight();
  }

  /// Arms a timer for the next local midnight in the prayer location's zone.
  ///
  /// The location's timezone rather than the device's, because that is the
  /// zone the prayer schedule and every "today" on this page are computed in;
  /// a traveller whose phone has moved on should still see their chosen
  /// location's day.
  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextMidnight = DateTime(today.year, today.month, today.day + 1);

    // A second past the boundary, so the clock has unambiguously rolled over
    // by the time the date is read again.
    var wait = nextMidnight.difference(now) + const Duration(seconds: 1);
    if (wait.isNegative) wait = const Duration(seconds: 1);

    _midnightTimer = Timer(wait, () {
      if (!mounted) return;
      _refreshIfDayTurned();
      _scheduleMidnight();
    });
  }

  /// Rebuilds the dashboard when, and only when, the local date has changed.
  void _refreshIfDayTurned() {
    if (!mounted) return;
    // The clock is read through a provider, so it has to be invalidated
    // before the new date can be observed.
    ref.invalidate(homeNowProvider);
    final current = ref.read(homeLocalDateProvider);
    if (_renderedDate != null && current == _renderedDate) return;

    _renderedDate = current;
    ref.read(homeControllerProvider).invalidateDashboard();
    ref.invalidate(sahibAlTartibProvider);
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    ref.read(homeControllerProvider).invalidateDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final importState = ref.watch(qazaImportProvider);
    final summaryAsync = ref.watch(progressSummaryProvider);

    ref.listen<AsyncValue<QazaProgressSummary>>(
      progressSummaryProvider,
      (previous, next) {
        if (!next.hasError || next.error == previous?.error) return;
        ref.read(diagnosticsProvider).recordFailure(
              DiagnosticArea.uncaught,
              'home_summary_failed',
              next.error!,
              stack: next.stackTrace,
            );
      },
    );

    ref.listen<QazaImportTaskState>(
      qazaImportProvider,
      (previous, next) {
        if (previous?.isActive != true) return;
        if (next.phase == QazaImportTaskPhase.completed) {
          final message = next.added == 0
              ? l10n.addQazaNothingNew
              : l10n.addQazaCreatedMessage(next.added);
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );

    return AppScaffold(
      title: l10n.homeTitle,
      actions: [
        IconButton(
          key: const Key('home_profile'),
          tooltip: l10n.homeProfileTooltip,
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => _open(
            context,
            ref,
            const ProfileScreen(),
          ),
        ),
      ],
      body: _buildBody(context, ref, summaryAsync, importState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<QazaProgressSummary> summaryAsync,
    QazaImportTaskState importState,
  ) {
    Widget base = summaryAsync.when(
      loading: () => const HomeSkeleton(),
      error: (_, __) => HomeError(
        onRetry: () => ref.read(homeControllerProvider).refresh(),
      ),
      data: (summary) => RefreshIndicator(
        onRefresh: () => ref.read(homeControllerProvider).refresh(),
        child: _buildContent(context, ref, summary),
      ),
    );

    if (importState.isActive) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const HomeSkeleton(),
          Center(child: _QazaImportProgressCard(state: importState)),
        ],
      );
    }

    if (importState.phase == QazaImportTaskPhase.failed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          base,
          Center(
            child: _QazaImportFailureCard(
              onRetry: () => ref.read(qazaImportProvider.notifier).retry(),
            ),
          ),
        ],
      );
    }

    return base;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    QazaProgressSummary summary,
  ) {
    if (summary.overall.total == 0) {
      return const HomeEmptyState();
    }

    final allCompleted = summary.overall.pending == 0;

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
                if (allCompleted) ...[
                  const SizedBox(height: 6),
                  HomeAllCompletedState(
                    completed: summary.overall.completed,
                    total: summary.overall.total,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  HomeTodayProgress(summary: summary),
                  const SizedBox(height: 12),
                ],
                HomeOverallProgress(
                  progress: summary.overall,
                  onDetails: () => _open(
                    context,
                    ref,
                    const HomeStatisticsSummaryScreen(),
                  ),
                ),
                const SizedBox(height: 16),
                if (!allCompleted) ...[
                  HomePendingByPrayer(summary: summary),
                  const SizedBox(height: 16),
                ],
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

class _QazaImportProgressCard extends StatelessWidget {
  const _QazaImportProgressCard({required this.state});

  final QazaImportTaskState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final importing = state.phase == QazaImportTaskPhase.importing;
    final value = state.progress;

    return Card(
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: scheme.primary, size: 28),
              const SizedBox(height: 10),
              Text(l10n.addQazaInProgress,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              if (importing && value != null) ...[
                Text('${(value * 100).round()}%',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 10),
                Text('${state.processed} / ${state.total}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge),
                if (state.added != 0 || state.skipped != 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${state.added} ${l10n.addQazaNewRecordsLabel} • '
                    '${state.skipped} ${l10n.addQazaExistingLabel}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ] else ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                Text(l10n.commonLoading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QazaImportFailureCard extends StatelessWidget {
  const _QazaImportFailureCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: scheme.error, size: 30),
              const SizedBox(height: 10),
              Text(l10n.stateErrorTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(l10n.homeProgressError,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      ),
    );
  }
}
