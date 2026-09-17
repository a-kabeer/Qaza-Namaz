import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/sync_status.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_progress.dart' show QazaProgressSummary;
import '../calculator/calculator_screen.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/completion_screen.dart';
import '../qaza/namaz_wise_screen.dart';
import '../qaza/pending_dates_screen.dart';
import '../settings/account_screen.dart';
import '../settings/notifications_screen.dart';
import 'home_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(progressSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressSummaryProvider);
    return AppScaffold(
      title: 'Home',
      actions: [
        IconButton(tooltip: 'Notifications', onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.notifications_none_rounded)),
        IconButton(tooltip: 'Profile', onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AccountScreen())), icon: const Icon(Icons.person_outline_rounded)),
      ],
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _message('Unable to load your Qaza progress. Pull to retry.'),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressSummaryProvider),
          child: _buildContent(context, ref, summary),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, QazaProgressSummary summary) {
    final state = HomeStateResolver.ledgerState(pending: summary.overall.pending, completed: summary.overall.completed);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = switch (state) {
      HomeLedgerState.setupRequired => AppButton(expand: true, icon: Icons.calculate_outlined, label: 'Calculate Qaza', onPressed: () => _open(context, ref, const CalculatorScreen())),
      HomeLedgerState.hasPendingQaza => AppButton(expand: true, icon: Icons.check_circle_outline_rounded, label: 'Complete Qaza', onPressed: () => _open(context, ref, const CompleteQazaScreen())),
      HomeLedgerState.allQazaCompleted => AppButton(expand: true, icon: Icons.add_rounded, label: 'Add New Qaza', onPressed: () => _open(context, ref, const AddQazaScreen())),
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        const SyncStatus(),
        const SizedBox(height: 12),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(
            color: scheme.primaryContainer,
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(switch (state) { HomeLedgerState.setupRequired => 'Start Your Qaza Journey', HomeLedgerState.hasPendingQaza => 'Keep going', HomeLedgerState.allQazaCompleted => 'You are all caught up' }, style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(state == HomeLedgerState.setupRequired ? 'Calculate an estimate or add missed prayers manually to begin tracking them.' : '${summary.overall.pending} pending • ${summary.overall.completed} completed', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .86), height: 1.45)),
              const SizedBox(height: 20),
              primary,
              const SizedBox(height: 10),
              AppButton(expand: true, secondary: true, icon: Icons.add_rounded, label: state == HomeLedgerState.setupRequired ? 'Add Qaza Manually' : 'Add New Qaza', onPressed: () => _open(context, ref, const AddQazaScreen())),
            ]),
          ),
          if (state != HomeLedgerState.setupRequired) ...[
            const SizedBox(height: 16),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your progress', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: Text('${summary.overall.completed} completed • ${summary.overall.pending} pending')), ProgressRing(progress: summary.overall.percentage, size: 64, strokeWidth: 6)]),
              const SizedBox(height: 12),
              for (final prayer in PrayerType.values) if ((summary.byPrayer[prayer]?.progress.total ?? 0) > 0) _prayerRow(context, prayer, summary.byPrayer[prayer]!.progress),
            ])),
            const SizedBox(height: 16),
            AppButton(expand: true, secondary: true, icon: Icons.list_alt_rounded, label: 'View All Qaza', onPressed: () => _open(context, ref, const NamazWiseScreen())),
            const SizedBox(height: 10),
            for (final prayer in PrayerType.values) if ((summary.byPrayer[prayer]?.progress.pending ?? 0) > 0) Padding(padding: const EdgeInsets.only(bottom: 8), child: AppButton(expand: true, secondary: true, icon: Icons.arrow_forward_rounded, label: '${_label(prayer)} — ${summary.byPrayer[prayer]!.progress.pending} pending', onPressed: () => _open(context, ref, PendingDatesScreen(prayer: prayer)))),
          ],
        ]))),
      ],
    );
  }

  Widget _prayerRow(BuildContext context, PrayerType prayer, QazaProgress progress) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: Text(_label(prayer), style: const TextStyle(fontWeight: FontWeight.w600))), Text('${progress.completed}/${progress.total}')]));

  String _label(PrayerType prayer) => switch (prayer) { PrayerType.fajr => 'Fajr', PrayerType.zuhr => 'Zuhr', PrayerType.asr => 'Asr', PrayerType.maghrib => 'Maghrib', PrayerType.isha => 'Isha', PrayerType.witr => 'Witr' };

  Widget _message(String text) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(text, textAlign: TextAlign.center)))]);
}
