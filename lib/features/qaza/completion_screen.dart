import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/prayer_progress_row.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'qaza_navigation.dart';

class CompleteQazaScreen extends ConsumerStatefulWidget {
  const CompleteQazaScreen({super.key});
  @override
  ConsumerState<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends ConsumerState<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;

  AsyncValue<QazaRecord?> get selectedState =>
      ref.watch(latestPendingProvider(prayer));
  QazaRecord? get selected => selectedState.valueOrNull;

  /// Leaves this page for the Qaza tab, filtered to [item].
  ///
  /// Complete Qaza is a pushed route, so it has to pop itself or the tab
  /// change would happen out of sight behind it.
  void _openPrayer(PrayerType item) {
    openQazaForPrayer(ref, item);
    Navigator.of(context).pop();
  }

  Future<void> _refresh() async {
    ref.invalidate(latestPendingProvider(prayer));
    ref.invalidate(progressSummaryProvider);
    await ref.read(latestPendingProvider(prayer).future);
  }

  Future<void> _complete() async {
    final record = selected;
    if (working || record == null) return;
    final completedPrayer = prayer;
    final l10n = AppLocalizations.of(context);
    setState(() => working = true);
    try {
      final userId = ref.read(requiredUserIdProvider);
      await ref.read(qazaServiceProvider).completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: DateTime.now(),
          );
      ref.invalidate(latestPendingProvider(completedPrayer));
      ref.invalidate(progressSummaryProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final nextPending =
          await ref.read(latestPendingProvider(completedPrayer).future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            nextPending == null
                ? l10n.completeSuccess(completedPrayer.localizedLabel(l10n))
                : l10n
                    .completeSuccessNext(completedPrayer.localizedLabel(l10n)),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeFailed)),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = selectedState;
    final record = state.valueOrNull;
    final l10n = AppLocalizations.of(context);
    // The same aggregate Home reads; the counts are never recomputed here.
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    return AppScaffold(
      title: l10n.completeTitle,
      onBack: () => Navigator.pop(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(l10n.completeHeading,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.completeIntro),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ListView(
                  key: const Key('complete_prayer_pills'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    // One pill per prayer, in the Qaza page's own chip style.
                    // No "All" pill: this page completes one prayer at a time,
                    // so there is no unfiltered state to offer.
                    for (final item in PrayerType.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          key: Key('complete_prayer_pill_${item.name}'),
                          label: Text(item.localizedLabel(l10n)),
                          selected: prayer == item,
                          onSelected: working || state.isLoading
                              ? null
                              : (_) => setState(() => prayer = item),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: state.when(
                    loading: () => LoadingState(
                        message: l10n.completeLoading, padding: 24),
                    error: (_, __) => ErrorState(
                        message: l10n.completeLoadError, onRetry: _refresh),
                    data: (_) {
                      if (record == null) {
                        return EmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            title: l10n.completeNoPendingTitle,
                            message: l10n.completeNoPendingMessage);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const CircleAvatar(
                                child: Icon(Icons.mosque_outlined)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      l10n.completePrayerQaza(
                                          prayer.localizedLabel(l10n)),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  Text(l10n.completeOldestSubtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                          ]),
                          const SizedBox(height: 18),
                          Text(l10n.completeOriginalDate),
                          const SizedBox(height: 4),
                          Text(formatAppDate(record.originalDate),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(l10n.completeTimestampNote),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                key: const Key('complete_oldest_pending'),
                label: working ? l10n.completeInProgress : l10n.completeAction,
                icon: working
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_rounded,
                onPressed: record == null || state.isLoading || working
                    ? null
                    : _complete,
                expand: true,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.homeProgressTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // The same list Home shows, from the same widget.
              for (final item in PrayerType.values)
                PrayerProgressRow(
                  keyPrefix: 'complete',
                  prayer: item,
                  progress: summary?.byPrayer[item]?.progress ??
                      const QazaProgress(pending: 0, completed: 0),
                  onTap: () => _openPrayer(item),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
