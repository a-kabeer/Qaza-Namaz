import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/services/qaza_service.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../prayer_times/prayer_times_providers.dart';
import '../prayer_times/presentation/prayer_times_localizations.dart';
import 'completion/qaza_completion_controller.dart';
import 'completion/qaza_completion_state.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'qaza_undo_banner.dart';

class _CompleteSkeleton extends StatelessWidget {
  const _CompleteSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkeletonCircle(size: 48),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 150, height: 18),
                  SizedBox(height: 8),
                  SkeletonText(width: 190, height: 12),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        SkeletonText(width: 110, height: 14),
        SizedBox(height: 8),
        SkeletonText(width: 190, height: 24),
        SizedBox(height: 8),
        SkeletonText(width: 130, height: 12),
        SizedBox(height: 10),
        SkeletonText(width: 230, height: 12),
      ],
    );
  }
}

/// Pick a prayer, see its latest pending record, complete it.
///
/// The Complete Qaza page and Home both offer this, so the pills, the record
/// card and the completion call live here once. Everything it needs is its
/// own: the selected prayer and the in-flight flag are local, and the record
/// comes from [oldestPendingProvider], so a host only has to place it.
class CompleteQazaSection extends ConsumerStatefulWidget {
  const CompleteQazaSection({super.key, this.keyPrefix = 'complete'});

  /// Namespaces the section's widget keys, so a host that shows it while
  /// another one is also mounted stays unambiguous in tests.
  final String keyPrefix;

  /// Reloads what the section shows, for a host's pull-to-refresh.
  ///
  /// Every prayer is invalidated rather than only the selected one, because
  /// the host does not know which that is; the others are auto-disposed and
  /// invalidating them is free.
  static Future<void> refresh(WidgetRef ref) async {
    for (final prayer in PrayerType.values) {
      ref.invalidate(oldestPendingProvider(prayer));
    }
    ref.invalidate(progressSummaryProvider);
    await ref.read(progressSummaryProvider.future);
  }

  @override
  ConsumerState<CompleteQazaSection> createState() =>
      _CompleteQazaSectionState();
}

class _CompleteQazaSectionState extends ConsumerState<CompleteQazaSection> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;

  Future<void> refresh() async {
    ref.invalidate(sahibAlTartibProvider);
    ref.invalidate(oldestPendingProvider(prayer));
    ref.invalidate(progressSummaryProvider);
    await ref.read(oldestPendingProvider(prayer).future);
  }

  /// Completes one record through the shared completion controller.
  ///
  /// This used to be a second, independent implementation that called
  /// `QazaService` directly and wrapped persistence, refresh, haptics and the
  /// undo snackbar in a single try/catch. Anything failing after the record
  /// was already written — a refresh, a haptic, the undo bar — was caught by
  /// that one `catch` and shown as "Qaza cannot be completed", and the real
  /// exception was discarded. The stages are separated here, and the generic
  /// failure message now belongs to persistence alone.
  Future<void> _complete(
    PrayerType completedPrayer,
    QazaRecord record,
  ) async {
    if (working) return;
    if (ref.read(qazaCompletionControllerProvider).isWorking) return;

    final l10n = AppLocalizations.of(context);
    final diagnostics = ref.read(diagnosticsProvider);
    final String userId;
    final DateTime completedAt;
    try {
      userId = ref.read(requiredUserIdProvider);
      completedAt = ref.read(prayerTimesClockProvider).now();
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'completion_start',
        error,
        stack: stack,
      );
      return;
    }

    setState(() => working = true);

    QazaCompletionResult result;
    try {
      result = await ref
          .read(qazaCompletionControllerProvider.notifier)
          .completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: completedAt,
            restriction: ref.read(qazaRestrictionEvaluationProvider).valueOrNull,
          );
    } on QazaCompletionRestrictedException catch (error) {
      ref.invalidate(qazaRestrictionEvaluationProvider);
      if (mounted) {
        setState(() => working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PrayerTimesStrings.qazaRestricted(context, error.restriction.type!),
            ),
          ),
        );
      }
      return;
    } on QazaTartibViolationException catch (error) {
      ref.invalidate(sahibAlTartibProvider);
      if (mounted) {
        setState(() => working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.qazaTartibBlocked(error.requiredPrayer.localizedLabel(l10n)),
            ),
          ),
        );
      }
      return;
    } catch (error, stack) {
      // Reached only when persistence itself failed, which is the one case
      // that earns the generic message.
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'completion_failed',
        error,
        stack: stack,
      );
      if (mounted) {
        setState(() => working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.completeFailed)),
        );
      }
      return;
    }

    if (mounted) setState(() => working = false);

    if (result != QazaCompletionResult.completed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeNoPendingMessage)),
      );
      return;
    }

    // Written and durable. Nothing below may be reported as a completion
    // failure.
    try {
      ref.invalidate(oldestPendingProvider(completedPrayer));
      ref.invalidate(sahibAlTartibProvider);
      ref.invalidate(progressSummaryProvider);
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'post_completion_refresh_failed',
        error,
        stack: stack,
      );
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    try {
      final completedRecord = (await ref.read(qazaServiceProvider).getRecordsByIds(
        userId: userId,
        recordIds: [record.id],
      )).where(
        (item) =>
            item.status == QazaStatus.completed &&
            item.completionId != null &&
            item.completionId!.isNotEmpty,
      );
      await showQazaUndoSnackBar(
        context: context,
        ref: ref,
        userId: userId,
        records: completedRecord,
        onUndone: refresh,
      );
    } catch (error, stack) {
      diagnostics.recordFailure(
        DiagnosticArea.qazaCompletion,
        'undo_ui_failed',
        error,
        stack: stack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tartibState = ref.watch(sahibAlTartibProvider);
    final tartib = tartibState.valueOrNull;
    final lockedPrayer = tartib?.requiresOrder == true
        ? tartib?.nextPrayer
        : null;
    final effectivePrayer = lockedPrayer ?? prayer;
    final state = ref.watch(oldestPendingProvider(effectivePrayer));
    final record = state.valueOrNull;
    final l10n = AppLocalizations.of(context);
    final prefix = widget.keyPrefix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tartib?.requiresOrder == true && lockedPrayer != null) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.qazaTartibRequiredMessage(
                  tartib!.pendingFarzCount,
                  lockedPrayer.localizedLabel(l10n),
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 52,
          child: ListView(
            key: Key('${prefix}_prayer_pills'),
            scrollDirection: Axis.horizontal,
            children: [
              for (final item in PrayerType.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    key: Key('${prefix}_prayer_pill_${item.name}'),
                    label: Text(item.localizedLabel(l10n)),
                    selected: effectivePrayer == item,
                    onSelected: working ||
                            state.isLoading ||
                            (lockedPrayer != null && item != lockedPrayer)
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
              loading: () => const _CompleteSkeleton(),
              error: (_, __) =>
                  ErrorState(message: l10n.completeLoadError, onRetry: refresh),
              data: (_) {
                if (record == null) {
                  return EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: l10n.completeNoPendingTitle,
                    message: l10n.completeNoPendingMessage,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(child: Icon(Icons.mosque_outlined)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.completePrayerQaza(
                                  effectivePrayer.localizedLabel(l10n)),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              l10n.completeOldestSubtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(l10n.completeOriginalDate),
                    const SizedBox(height: 4),
                    Text(
                      formatAppDate(record.originalDate),
                      key: Key('${prefix}_original_date'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatters.hijriLabel(record.originalDate),
                      key: Key('${prefix}_original_date_hijri'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
          key: Key('${prefix}_oldest_pending'),
          label: working ? l10n.completeInProgress : l10n.completeAction,
          icon: working
              ? Icons.hourglass_top_rounded
              : Icons.check_circle_rounded,
          onPressed: record == null || state.isLoading || working
              ? null
              : () => _complete(effectivePrayer, record),
          expand: true,
        ),
      ],
    );
  }
}
