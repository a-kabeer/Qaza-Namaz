import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/progress_widgets.dart';
import '../../core/widgets/sync_status.dart';
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
    final ledger = ref.read(qazaRecordsProvider.notifier);
    final changed = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => page));
    if (changed != null && changed > 0) await ledger.refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(overallProgressProvider);
    final pending = progress.pending;
    final completed = progress.completed;
    final homeState = HomeStateResolver.ledgerState(pending: pending, completed: completed);

    return AppScaffold(
      title: 'Home',
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.read(qazaRecordsProvider.notifier).refresh(),
        child: switch (homeState) {
          HomeLedgerState.setupRequired => _buildSetupHome(context, ref),
          HomeLedgerState.hasPendingQaza => _buildPendingHome(context, ref, pending),
          HomeLedgerState.allQazaCompleted => _buildCompletedHome(context, ref, completed),
        },
      ),
    );
  }

  Widget _responsiveList({required List<Widget> children}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupHome(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _responsiveList(children: [
      AppCard(
        color: scheme.primaryContainer,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 32),
          const SizedBox(height: 20),
          Text('Start Your Qaza Journey', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Your Qaza ledger is empty. Calculate an estimate from your prayer history or add missed prayers manually to begin tracking them.', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .86), height: 1.45)),
          const SizedBox(height: 24),
          AppButton(expand: true, icon: Icons.calculate_outlined, label: 'Calculate Qaza', onPressed: () => _open(context, ref, const CalculatorScreen())),
          const SizedBox(height: 10),
          AppButton(expand: true, secondary: true, icon: Icons.add_rounded, label: 'Add Qaza Manually', onPressed: () => _open(context, ref, const AddQazaScreen())),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text('After you add records, Home will focus on your pending Qaza and progress.', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
      ])),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildPendingHome(BuildContext context, WidgetRef ref, int pending) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final records = ref.watch(loadedRecordsProvider);
    return _responsiveList(children: [
      const SyncStatus(),
      const SizedBox(height: 8),
      AppCard(
        color: scheme.primaryContainer,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_todayLabel(), style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            final message = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Keep going', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('$pending Qaza ${pending == 1 ? 'prayer remains' : 'prayers remain'} in your ledger.', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .86), height: 1.45)),
            ]);
            final count = DecoratedBox(decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle), child: Padding(padding: const EdgeInsets.all(16), child: Text('$pending', style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800))));
            return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [message, const SizedBox(height: 14), Align(alignment: AlignmentDirectional.centerEnd, child: count)]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: message), const SizedBox(width: 16), count]);
          }),
          const SizedBox(height: 20),
          AppButton(expand: true, icon: Icons.check_circle_outline_rounded, label: 'Complete Qaza', onPressed: () => _open(context, ref, const CompleteQazaScreen())),
          const SizedBox(height: 10),
          AppButton(expand: true, secondary: true, icon: Icons.add_rounded, label: 'Add New Qaza', onPressed: () => _open(context, ref, const AddQazaScreen())),
        ]),
      ),
      const SizedBox(height: 16),
      _buildProgressSummary(context, ref),
      const SizedBox(height: 18),
      _buildPendingPrayerCard(context, ref, records),
      const SizedBox(height: 14),
      AppButton(expand: true, secondary: true, icon: Icons.list_alt_rounded, label: 'View All Qaza', onPressed: () => _open(context, ref, const NamazWiseScreen())),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildProgressSummary(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(overallProgressProvider);
    final prayerProgress = ref.watch(prayerProgressProvider);
    final activePrayers = PrayerType.values.where((prayer) => prayerProgress[prayer]!.progress.total > 0).toList();

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final summary = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your progress', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${progress.completed} completed • ${progress.pending} pending', style: theme.textTheme.bodyMedium),
          ]);
          final ring = ProgressRing(progress: progress.percentage, size: 64, strokeWidth: 6);
          return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [summary, const SizedBox(height: 12), Align(alignment: AlignmentDirectional.centerEnd, child: ring)]) : Row(children: [Expanded(child: summary), ring]);
        }),
        if (activePrayers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (var i = 0; i < activePrayers.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildPrayerSummaryRow(context, prayerProgress[activePrayers[i]]!),
          ],
        ],
      ]),
    );
  }

  Widget _buildPrayerSummaryRow(BuildContext context, PrayerProgress summary) {
    final theme = Theme.of(context);
    final progress = summary.progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(child: Text(_prayerLabel(summary.prayerType), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
        Text('${progress.completed}/${progress.total}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        SizedBox(width: 56, child: LinearProgressIndicator(value: progress.percentage, minHeight: 6)),
      ]),
    );
  }

  Widget _buildPendingPrayerCard(BuildContext context, WidgetRef ref, List<dynamic> records) {
    final theme = Theme.of(context);
    final pendingByPrayer = <PrayerType, int>{for (final prayer in PrayerType.values) prayer: records.where((r) => r.prayerType == prayer && r.status == QazaStatus.pending).length};
    final prayersWithPending = pendingByPrayer.entries.where((entry) => entry.value > 0).toList();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Continue by prayer', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Choose a prayer to view its pending dates.', style: theme.textTheme.bodyMedium),
      const SizedBox(height: 12),
      for (var index = 0; index < prayersWithPending.length; index++) ...[
        if (index > 0) const Divider(height: 1),
        PrayerCard(
          prayer: prayersWithPending[index].key,
          subtitle: '${prayersWithPending[index].value} pending',
          trailing: Text('${prayersWithPending[index].value}', style: theme.textTheme.titleLarge),
          onTap: () => _open(context, ref, PendingDatesScreen(prayer: prayersWithPending[index].key)),
        ),
      ],
    ]));
  }

  Widget _buildCompletedHome(BuildContext context, WidgetRef ref, int completed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _responsiveList(children: [
      const SyncStatus(),
      const SizedBox(height: 8),
      AppCard(color: scheme.secondaryContainer, padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_rounded, color: scheme.secondary, size: 42),
        const SizedBox(height: 16),
        Text('You are all caught up', style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('$completed ${completed == 1 ? 'Qaza prayer has' : 'Qaza prayers have'} been completed. Your pending ledger is currently clear.', style: TextStyle(color: scheme.onSecondaryContainer.withValues(alpha: .86), height: 1.45)),
        const SizedBox(height: 20),
        AppButton(expand: true, icon: Icons.add_rounded, label: 'Add New Qaza', onPressed: () => _open(context, ref, const AddQazaScreen())),
        const SizedBox(height: 10),
        AppButton(expand: true, secondary: true, icon: Icons.calculate_outlined, label: 'Recalculate Qaza', onPressed: () => _open(context, ref, const CalculatorScreen())),
      ])),
      const SizedBox(height: 16),
      _buildProgressSummary(context, ref),
      const SizedBox(height: 16),
      AppCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.history_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text('Your completed history remains available in Logs.', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
      ])),
      const SizedBox(height: 16),
    ]);
  }

  String _prayerLabel(PrayerType prayer) => switch (prayer) {
        PrayerType.fajr => 'Fajr',
        PrayerType.zuhr => 'Zuhr',
        PrayerType.asr => 'Asr',
        PrayerType.maghrib => 'Maghrib',
        PrayerType.isha => 'Isha',
        PrayerType.witr => 'Witr',
      };

  String _todayLabel() {
    final now = DateTime.now();
    return 'Today • ${DateFormatters.weekdayShortNames[now.weekday - 1]}, ${now.day} ${DateFormatters.gregorianMonthName(now.month)} ${now.year}';
  }
}
