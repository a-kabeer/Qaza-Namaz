import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'qaza_tracker_screen.dart';

class CompleteQazaScreen extends ConsumerStatefulWidget {
  const CompleteQazaScreen({super.key});
  @override
  ConsumerState<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends ConsumerState<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;

  AsyncValue<QazaRecord?> get oldestState =>
      ref.watch(oldestPendingProvider(prayer));
  QazaRecord? get oldest => oldestState.valueOrNull;

  Future<void> _refresh() async {
    ref.invalidate(oldestPendingProvider(prayer));
    ref.invalidate(progressSummaryProvider);
    await ref.read(oldestPendingProvider(prayer).future);
  }

  Future<void> _complete() async {
    final record = oldest;
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
      ref.invalidate(oldestPendingProvider(completedPrayer));
      ref.invalidate(progressSummaryProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final nextPending =
          await ref.read(oldestPendingProvider(completedPrayer).future);
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
    final state = oldestState;
    final record = state.valueOrNull;
    final l10n = AppLocalizations.of(context);
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
              DropdownButtonFormField<PrayerType>(
                value: prayer,
                decoration: InputDecoration(
                    labelText: l10n.completePrayerLabel,
                    prefixIcon: const Icon(Icons.mosque_outlined)),
                items: [
                  for (final item in PrayerType.values)
                    DropdownMenuItem(
                        value: item, child: Text(item.localizedLabel(l10n)))
                ],
                onChanged: working || state.isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => prayer = value);
                      },
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
              const SizedBox(height: 12),
              AppButton(
                  label: l10n.completeOpenWorkspace,
                  icon: Icons.checklist_rounded,
                  secondary: true,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QazaTrackerScreen())),
                  expand: true),
            ],
          ),
        ),
      ),
    );
  }
}
