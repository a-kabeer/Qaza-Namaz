import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/hijri_date_service.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_selection_grid.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_picker.dart';
import '../home/home_controller.dart';
import '../prayer_time/application/prayer_time_providers.dart';
import '../prayer_time/presentation/prayer_timeline_row.dart';
import 'add_qaza_controller.dart';
import 'qaza_import_controller.dart';
import 'qaza_import_progress_dialog.dart';
import 'qaza_tracker_controller.dart';
import 'qaza_navigation.dart';
import 'widgets/qaza_addition_date_summary.dart';

class AddQazaScreen extends ConsumerStatefulWidget {
  const AddQazaScreen({super.key, this.editAddition});

  final QazaAddition? editAddition;

  @override
  ConsumerState<AddQazaScreen> createState() => _AddQazaScreenState();
}

class _AddQazaScreenState extends ConsumerState<AddQazaScreen> {
  int _lastExistingCount = 0;

  @override
  void initState() {
    super.initState();
    final addition = widget.editAddition;
    if (addition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(addQazaControllerProvider.notifier).restoreFromSnapshot(
              addition.currentInputSnapshot,
              editingAdditionId: addition.id,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final state = ref.watch(addQazaControllerProvider);
    final restricted = ref.watch(qazaCompletionRestrictedProvider);

    if (profile == null) {
      return AppScaffold(
        title: l10n.addQazaTitle,
        body: const LoadingState(),
      );
    }

    return AppScaffold(
      title: l10n.addQazaTitle,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text(
              l10n.addQazaAvailabilityNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (restricted)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: _RestrictedTimeAddQazaRow(),
              ),
            _ModeSelector(
              mode: state.mode,
              onChanged: (mode) => ref
                  .read(addQazaControllerProvider.notifier)
                  .setMode(mode),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: CalendarPicker(
                  availablePrayersByDate: state.calendarAvailability,
                  availabilityLoading: state.calendarLoading,
                  dateSelectablePredicate: ref
                      .read(addQazaControllerProvider.notifier)
                      .isDateAllowed,
                  onMonthChanged: (month) => ref
                      .read(addQazaControllerProvider.notifier)
                      .refreshCalendarMonth(month),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SelectionSummary(
              mode: state.mode,
              dates: state.selectedDates,
            ),
            const SizedBox(height: AppSpacing.md),
            _PrayerSelection(
              selected: state.selectedPrayers,
              addablePrayers: state.addablePrayers,
              timeBlockedPrayers: state.timeBlockedPrayers,
              availabilityLoading: state.prayerAvailabilityLoading,
              hasSelectedDates: state.selectedDates.isNotEmpty,
              witrAllowed: ProfileRules.effectiveWitr(profile) ||
                  state.addablePrayers.contains(PrayerType.witr) ||
                  state.protectedPrayers.contains(PrayerType.witr),
              onToggle: (prayer) => ref
                  .read(addQazaControllerProvider.notifier)
                  .togglePrayer(prayer),
            ),
            const SizedBox(height: AppSpacing.md),
            _AnalysisSummary(
              analysis: state.analysis,
              loading: state.analysisLoading,
            ),
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.homeProgressError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _AddQazaBottomAction(
        enabled: state.canReview,
        onPressed: state.canReview ? _openReview : null,
      ),
    );
  }

  Future<void> _openReview() async {
    final controller = ref.read(addQazaControllerProvider.notifier);
    final initial = await controller.refreshAnalysis();
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddQazaReviewDialog(
        analysis: initial,
        mode: ref.read(addQazaControllerProvider).mode,
        selectedDates: ref.read(addQazaControllerProvider).selectedDates,
        allowEditWithoutNewRecords:
            widget.editAddition != null &&
            ref.read(addQazaControllerProvider).hasEditChanges,
        onAdd: _finalValidateAndStart,
      ),
    );

    if (result == true && mounted) {
      await _showImportProgress();
    }
  }

  Future<AddQazaAnalysis?> _finalValidateAndStart() async {
    final controller = ref.read(addQazaControllerProvider.notifier);

    try {
      final latest = await controller.refreshAnalysis();
      if (!mounted) return null;

      final currentState = ref.read(addQazaControllerProvider);
      if (latest.newCount == 0 &&
          (widget.editAddition == null || !currentState.hasEditChanges)) {
        return latest;
      }

      final current = ref.read(addQazaControllerProvider);
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile == null) return null;
      final prayerTimeContext =
          await controller.resolveCurrentPrayerTimeContextForQaza();

      final additionMode = switch (current.mode) {
        DateSelectionMode.single => QazaAdditionMode.single,
        DateSelectionMode.range => QazaAdditionMode.range,
        DateSelectionMode.multiple => QazaAdditionMode.multiple,
      };
      final started = ref.read(qazaImportProvider.notifier).start(
            userId: ref.read(requiredUserIdProvider),
            dates: current.selectedDates,
            prayers: current.selectedPrayers,
            mode: additionMode,
            additionId: widget.editAddition?.id,
            expectedRevision: widget.editAddition?.revision,
            earliestDate: controller.startPrayingDate,
            today: controller.today,
            witrAllowed: ProfileRules.effectiveWitr(profile),
            prayerTimeContext: prayerTimeContext,
          );

      if (!started) return null;
      _lastExistingCount = latest.existingCount;
      return latest;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showImportProgress() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QazaImportProgressDialog(),
    );

    if (!mounted) return;
    final result = ref.read(qazaImportProvider);

    if (result.phase == QazaImportTaskPhase.completed) {
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaTrackerControllerProvider(null));
      ref.read(homeControllerProvider).invalidateDashboard();

      if (widget.editAddition != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: Icon(
              Icons.check_circle_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Qaza addition updated'),
            content: Text(
              '${result.added} added • ${result.removed} removed • '
              '${result.protected} protected',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).commonDone),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: Icon(
            Icons.check_circle_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(AppLocalizations.of(context).addQazaCreatedTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)
                    .addQazaCreatedMessage(result.added),
                textAlign: TextAlign.center,
              ),
              if (_lastExistingCount + result.skipped > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_lastExistingCount + result.skipped} '
                  '${AppLocalizations.of(context).addQazaAlreadyAddedLabel}',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: result.additionId == null
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      await openQazaAdditionDetail(
                        context,
                        result.additionId!,
                      );
                    },
              child: const Text('Manage this addition'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).commonDone),
            ),
          ],
        ),
      );
      return;
    }
    if (result.phase == QazaImportTaskPhase.cancelled) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context).addQazaCancelledTitle),
          content: Text(
            AppLocalizations.of(context).addQazaCancelledMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).commonDone),
            ),
          ],
        ),
      );
      return;
    }

    if (result.phase == QazaImportTaskPhase.failed) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context).stateErrorTitle),
          content: Text(
            AppLocalizations.of(context).homeProgressError,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).commonClose),
            ),
          ],
        ),
      );
    }
  }
}

class _RestrictedTimeAddQazaRow extends ConsumerWidget {
  const _RestrictedTimeAddQazaRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RestrictedTimeTimelineRow(
      onTap: () => openPrayerTimeFromRoute(context, ref),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final DateSelectionMode mode;
  final ValueChanged<DateSelectionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<DateSelectionMode>(
      segments: [
        ButtonSegment<DateSelectionMode>(
          value: DateSelectionMode.single,
          label: Text(l10n.addQazaModeSingle),
          icon: const Icon(Icons.event_outlined),
        ),
        ButtonSegment<DateSelectionMode>(
          value: DateSelectionMode.range,
          label: Text(l10n.addQazaModeRange),
          icon: const Icon(Icons.date_range_outlined),
        ),
        ButtonSegment<DateSelectionMode>(
          value: DateSelectionMode.multiple,
          label: Text(l10n.addQazaModeMultiple),
          icon: const Icon(Icons.event_available_outlined),
        ),
      ],
      selected: <DateSelectionMode>{mode},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) onChanged(selected.first);
      },
    );
  }
}

class _PrayerSelection extends StatelessWidget {
  const _PrayerSelection({
    required this.selected,
    required this.addablePrayers,
    required this.timeBlockedPrayers,
    required this.availabilityLoading,
    required this.hasSelectedDates,
    required this.witrAllowed,
    required this.onToggle,
  });

  final Set<PrayerType> selected;
  final Set<PrayerType> addablePrayers;
  final Set<PrayerType> timeBlockedPrayers;
  final bool availabilityLoading;
  final bool hasSelectedDates;
  final bool witrAllowed;
  final ValueChanged<PrayerType> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addQazaPrayersHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            PrayerSelectionGrid(
              selected: selected,
              witrAllowed: witrAllowed,
              disabledPrayers: availabilityLoading
                  ? PrayerType.values.toSet()
                  : !hasSelectedDates
                      ? const <PrayerType>{}
                      : PrayerType.values
                          .where(
                            (prayer) => !addablePrayers.contains(prayer),
                          )
                          .toSet(),
              disabledReasonBuilder: availabilityLoading
                  ? null
                  : (prayer) => timeBlockedPrayers.contains(prayer)
                      ? l10n.addQazaTimeBlocked
                      : l10n.addQazaAlreadyAddedLabel,
              onPrayerSelected: onToggle,
            ),
            if (availabilityLoading) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.mode,
    required this.dates,
  });

  final DateSelectionMode mode;
  final List<DateTime> dates;

  QazaAdditionInputSnapshot get _snapshot => QazaAdditionInputSnapshot(
        schemaVersion: 1,
        mode: switch (mode) {
          DateSelectionMode.single => QazaAdditionMode.single,
          DateSelectionMode.range => QazaAdditionMode.range,
          DateSelectionMode.multiple => QazaAdditionMode.multiple,
        },
        selectedDates: dates,
        selectedPrayers: const <PrayerType>[],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = QazaAdditionDateSummary(_snapshot);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.addQazaSelectionLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  summary.modeLabel(l10n),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (dates.isEmpty)
              Text(
                switch (mode) {
                  DateSelectionMode.single => l10n.addQazaChooseSingle,
                  DateSelectionMode.range => l10n.addQazaChooseRange,
                  DateSelectionMode.multiple => l10n.addQazaChooseMultiple,
                },
                style: Theme.of(context).textTheme.titleSmall,
              )
            else ...[
              _compactDateSummary(context, summary, l10n),
              if (_showDateDetails(summary)) ...[
                const SizedBox(height: AppSpacing.xs),
                _dateDetails(context, summary, l10n),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _showDateDetails(QazaAdditionDateSummary summary) =>
      dates.length > 1 &&
      (mode == DateSelectionMode.multiple ||
          (mode == DateSelectionMode.range && !summary.isContiguous));

  Widget _dateDetails(
    BuildContext context,
    QazaAdditionDateSummary summary,
    AppLocalizations l10n,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.addQazaDatesLabel),
      subtitle: Text(l10n.addQazaDateCount(dates.length)),
      children: [
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(summary.formatGregorian(context, date)),
                subtitle: Text(summary.formatHijri(l10n, date)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _compactDateSummary(
    BuildContext context,
    QazaAdditionDateSummary summary,
    AppLocalizations l10n,
  ) {
    final groups = summary.consecutiveGroups;
    final visibleGroups = groups.length > 6 ? groups.take(6) : groups;
    final labels = visibleGroups
        .map(
          (group) => summary.formatConsecutiveRange(
            context,
            l10n,
            group,
          ),
        )
        .join(' · ');
    final suffix = groups.length > visibleGroups.length ? ' …' : '';

    if (mode == DateSelectionMode.multiple || !summary.isContiguous) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addQazaDateCount(dates.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (labels.isNotEmpty)
            Text(
              labels + suffix,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      );
    }

    final first = summary.formatGregorian(context, dates.first);
    final last = summary.formatGregorian(context, dates.last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mode == DateSelectionMode.range && dates.length > 1
              ? l10n.qazaDateFilterRange(first, last)
              : first,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          dates.length == 1
              ? summary.formatHijri(l10n, dates.first)
              : l10n.qazaDateFilterRange(
                  summary.formatHijri(l10n, dates.first),
                  summary.formatHijri(l10n, dates.last),
                ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (dates.length > 1)
          Text(
            l10n.addQazaDateCount(dates.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _AnalysisSummary extends StatelessWidget {
  const _AnalysisSummary({
    required this.analysis,
    required this.loading,
  });

  final AddQazaAnalysis analysis;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep all six prayers visible so a zero count clearly communicates
    // that the prayer is not part of the current addable selection.
    final prayers = PrayerType.values.toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addQazaReviewHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (prayers.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prayers.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 44,
                  mainAxisSpacing: AppSpacing.xs,
                  crossAxisSpacing: AppSpacing.xs,
                ),
                itemBuilder: (context, index) {
                  final prayer = prayers[index];
                  return _PrayerCount(
                    label: _prayerLabel(l10n, prayer),
                    count: analysis.countForPrayer(prayer),
                  );
                },
              ),
            if (prayers.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _CompactStatusCount(
                  label: l10n.addQazaNewLabel,
                  count: analysis.newCount,
                ),
                _CompactStatusCount(
                  label: l10n.addQazaAlreadyAddedLabel,
                  count: analysis.existingCount,
                ),
                _CompactStatusCount(
                  label: l10n.addQazaUnavailableLabel,
                  count: analysis.unavailableCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerCount extends StatelessWidget {
  const _PrayerCount({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            count.toString(),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _CompactStatusCount extends StatelessWidget {
  const _CompactStatusCount({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AddQazaBottomAction extends StatelessWidget {
  const _AddQazaBottomAction({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.addQazaReviewHeading),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddQazaReviewDialog extends StatefulWidget {
  const _AddQazaReviewDialog({
    required this.analysis,
    required this.mode,
    required this.selectedDates,
    required this.allowEditWithoutNewRecords,
    required this.onAdd,
  });

  final AddQazaAnalysis analysis;
  final DateSelectionMode mode;
  final List<DateTime> selectedDates;
  final bool allowEditWithoutNewRecords;
  final Future<AddQazaAnalysis?> Function() onAdd;

  @override
  State<_AddQazaReviewDialog> createState() => _AddQazaReviewDialogState();
}

class _AddQazaReviewDialogState extends State<_AddQazaReviewDialog> {
  late AddQazaAnalysis _analysis = widget.analysis;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_analysis.newCount == 0 && !widget.allowEditWithoutNewRecords) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final latest = await widget.onAdd();
      if (!mounted) return;

      if (latest == null) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).homeProgressError;
        });
        return;
      }

      if (latest.newCount == 0 && !widget.allowEditWithoutNewRecords) {
        setState(() {
          _analysis = latest;
          _busy = false;
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).homeProgressError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 48).clamp(280.0, 560.0).toDouble();
    final height = (size.height * 0.62).clamp(360.0, 560.0).toDouble();

    return AlertDialog(
      title: Text(l10n.addQazaReviewHeading),
      content: SizedBox(
        width: width,
        height: height,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelectionSummary(
                mode: widget.mode,
                dates: widget.selectedDates,
              ),
              const SizedBox(height: AppSpacing.md),
              _AnalysisSummary(
                analysis: _analysis,
                loading: _busy,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.addQazaReviewNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonBack),
        ),
        FilledButton.icon(
          onPressed: _busy ||
                  (_analysis.newCount == 0 &&
                      !widget.allowEditWithoutNewRecords)
              ? null
              : _confirm,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(
            _busy
                ? l10n.addQazaChecking
                : _analysis.newCount == 0
                    ? l10n.qazaSaveChanges
                    : l10n.addQazaAddCount(
                        _analysis.newCount.toString(),
                      ),
          ),
        ),
      ],
    );
  }
}

String _prayerLabel(AppLocalizations l10n, PrayerType prayer) =>
    switch (prayer) {
      PrayerType.fajr => l10n.prayerFajr,
      PrayerType.zuhr => l10n.prayerZuhr,
      PrayerType.asr => l10n.prayerAsr,
      PrayerType.maghrib => l10n.prayerMaghrib,
      PrayerType.isha => l10n.prayerIsha,
      PrayerType.witr => l10n.prayerWitr,
    };
