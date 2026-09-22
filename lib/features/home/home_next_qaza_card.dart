import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'home_plan.dart';
import 'home_qaza_completion.dart';
import '../qaza/qaza_undo_banner.dart';

class HomeOldestQazaCard extends ConsumerStatefulWidget {
  const HomeOldestQazaCard({super.key});

  @override
  ConsumerState<HomeOldestQazaCard> createState() => _HomeOldestQazaCardState();
}

class _HomeOldestQazaCardState extends ConsumerState<HomeOldestQazaCard> {
  bool working = false;

  Future<void> _complete(PrayerType prayer, QazaRecord record) async {
    if (working) return;
    final l10n = AppLocalizations.of(context);
    setState(() => working = true);

    HomeDailyProgress? before;
    try {
      before = await ref.read(homeDailyProgressProvider.future);
    } catch (_) {
      // Completion remains valid even when today's aggregate cannot be read.
    }

    try {
      final userId = ref.read(requiredUserIdProvider);
      final completedAt = ref.read(homeNowProvider);
      await ref.read(qazaServiceProvider).completeRecord(
        userId: userId,
        recordId: record.id,
        completedAt: completedAt,
      );

      ref.invalidate(oldestPendingProvider(prayer));
      ref.invalidate(sahibAlTartibProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(homeDailyProgressProvider);

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      HomeDailyProgress? after;
      try {
        after = await ref.read(homeDailyProgressProvider.future);
      } catch (_) {
        after = null;
      }

      if (before != null &&
          after != null &&
          before.completed < before.target &&
          after.completed >= after.target) {
        final shouldCelebrate = await ref
            .read(homeQazaPlanProvider.notifier)
            .claimDailyTargetCelebration(
              userId: userId,
              date: ref.read(homeNowProvider),
              target: after.target,
            );

        if (shouldCelebrate && mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (_) => const _DailyTargetReachedDialog(),
          );
        }
      }

      if (!mounted) return;
      await showQazaUndoSnackBar(
        context: context,
        ref: ref,
        userId: userId,
        recordIds: [record.id],
        completedAt: completedAt,
        onUndone: () async {
          ref.invalidate(homeDailyProgressProvider);
        },
      );
    } on QazaTartibViolationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.qazaTartibBlocked(
                error.requiredPrayer.localizedLabel(l10n),
              ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.completeFailed)),
        );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(homePrayerSelectionProvider);
    final selected = ref.watch(homeSelectedPrayerProvider);
    final tartib = ref.watch(sahibAlTartibProvider).valueOrNull;
    final lockedPrayer =
        tartib?.requiresOrder == true ? tartib?.nextPrayer : null;
    final prayer = lockedPrayer ?? selected.prayer;

    return AppCard(
      key: const Key('home_oldest_qaza'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeCompleteOldestQaza,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _PrayerChoiceChips(
            selection: selection,
            lockedPrayer: lockedPrayer,
            onAutomatic: () => ref
                .read(homePrayerSelectionProvider.notifier)
                .useAutomatic(),
            onPrayerSelected: (selectedPrayer) => ref
                .read(homePrayerSelectionProvider.notifier)
                .selectPrayer(selectedPrayer),
          ),
          const SizedBox(height: 12),
          if (prayer == null)
            const _AutomaticPrayerUnavailable()
          else
            _OldestPrayerBody(
              prayer: prayer,
              working: working,
              onComplete: _complete,
            ),
        ],
      ),
    );
  }
}

class _PrayerChoiceChips extends StatelessWidget {
  const _PrayerChoiceChips({
    required this.selection,
    required this.lockedPrayer,
    required this.onAutomatic,
    required this.onPrayerSelected,
  });

  final HomePrayerSelectionState selection;
  final PrayerType? lockedPrayer;
  final VoidCallback onAutomatic;
  final ValueChanged<PrayerType> onPrayerSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        key: const Key('home_qaza_prayer_chips'),
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            key: const Key('home_qaza_auto_chip'),
            label: Text(l10n.homeAuto),
            selected: selection.mode == HomePrayerSelectionMode.automatic &&
                lockedPrayer == null,
            onSelected: lockedPrayer == null ? (_) => onAutomatic() : null,
          ),
          for (final prayer in PrayerType.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: Key('home_qaza_chip_' + prayer.name),
              label: Text(prayer.localizedLabel(l10n)),
              selected: (lockedPrayer ?? selection.manualPrayer) == prayer,
              onSelected: lockedPrayer != null && lockedPrayer != prayer
                  ? null
                  : (_) => onPrayerSelected(prayer),
            ),
          ],
        ],
      ),
    );
  }
}

class _AutomaticPrayerUnavailable extends StatelessWidget {
  const _AutomaticPrayerUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const Key('home_qaza_prayer_time_unavailable'),
      liveRegion: true,
      child: Text(l10n.homePrayerTimeUnavailable),
    );
  }
}

class _OldestPrayerBody extends ConsumerWidget {
  const _OldestPrayerBody({
    required this.prayer,
    required this.working,
    required this.onComplete,
  });

  final PrayerType prayer;
  final bool working;
  final Future<void> Function(PrayerType prayer, QazaRecord record) onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(oldestPendingProvider(prayer));

    return state.when(
      loading: () => const _HomeOldestQazaSkeleton(),
      error: (_, __) => ErrorState(
        key: const Key('home_oldest_qaza_error'),
        message: l10n.completeLoadError,
        onRetry: () => ref.invalidate(oldestPendingProvider(prayer)),
      ),
      data: (record) {
        if (record == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                prayer.localizedLabel(l10n),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.completeNoPendingTitle,
                key: const Key('home_oldest_qaza_empty'),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.mosque_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer.localizedLabel(l10n),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        DateFormatters.formatGregorianDatePadded(
                          record.originalDate,
                        ),
                        key: const Key('home_oldest_qaza_date'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        DateFormatters.hijriLabel(record.originalDate),
                        key: const Key('home_oldest_qaza_date_hijri'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              key: const Key('home_complete_oldest_qaza'),
              expand: true,
              label: working
                  ? l10n.completeInProgress
                  : l10n.homeCompleteOldestQaza,
              onPressed: working ? null : () => onComplete(prayer, record),
            ),
          ],
        );
      },
    );
  }
}

class _HomeOldestQazaSkeleton extends StatelessWidget {
  const _HomeOldestQazaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(
          width: double.infinity,
          height: 58,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        SizedBox(height: 14),
        SkeletonBox(
          width: double.infinity,
          height: 44,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ],
    );
  }
}

class _DailyTargetReachedDialog extends StatefulWidget {
  const _DailyTargetReachedDialog();

  @override
  State<_DailyTargetReachedDialog> createState() =>
      _DailyTargetReachedDialogState();
}

class _DailyTargetReachedDialogState extends State<_DailyTargetReachedDialog> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('home_qaza_plan_complete_dialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      title: Row(
        children: [
          Expanded(child: Text(l10n.homeQazaTargetReachedTitle)),
          IconButton(
            key: const Key('home_qaza_plan_complete_close'),
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: Text(l10n.homeQazaTargetReachedMessage),
    );
  }
}