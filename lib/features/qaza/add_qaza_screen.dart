import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/qaza_date.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_operation.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_picker.dart';
import '../home/home_controller.dart';
import 'add_qaza_controller.dart';
import 'qaza_import_controller.dart';
import 'qaza_tracker_controller.dart';

class AddQazaScreen extends ConsumerStatefulWidget {
  const AddQazaScreen({super.key});

  @override
  ConsumerState<AddQazaScreen> createState() => _AddQazaScreenState();
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _AddQazaScreenState extends ConsumerState<AddQazaScreen> {
  int _lastExistingCount = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final state = ref.watch(addQazaControllerProvider);

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
            AppSpacing.fabClearance,
          ),
          children: [
            Text(
              l10n.addQazaAvailabilityNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
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
                  onMonthChanged: (month) => ref
                      .read(addQazaControllerProvider.notifier)
                      .refreshCalendarMonth(month),
                  resolveAvailability: (start, end) => ref
                      .read(addQazaControllerProvider.notifier)
                      .resolveAvailability(start, end),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PrayerSelection(
              selected: state.selectedPrayers,
              witrAllowed: ProfileRules.effectiveWitr(profile),
              onToggle: (prayer) => ref
                  .read(addQazaControllerProvider.notifier)
                  .togglePrayer(prayer),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SummaryCard(
              state: state,
              onReview: state.canReview ? _openReview : null,
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

      if (latest.newCount == 0) return latest;

      final current = ref.read(addQazaControllerProvider);
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile == null) return null;

      final started = ref.read(qazaImportProvider.notifier).start(
            userId: ref.read(requiredUserIdProvider),
            dates: current.selectedDates,
            prayers: current.selectedPrayers,
            operationType: switch (current.mode) {
              DateSelectionMode.single => QazaOperationType.singleDateAdd,
              DateSelectionMode.range => QazaOperationType.rangeAdd,
              DateSelectionMode.multiple =>
                QazaOperationType.multipleDateAdd,
            },
            inputSnapshot: {
              'version': 1,
              'mode': current.mode.name,
              'dates': [
                for (final date in current.selectedDates)
                  QazaDate.normalize(date).toIso8601String(),
              ],
              'prayers': [
                for (final prayer in current.selectedPrayers) prayer.name,
              ],
            },
            earliestDate: controller.startPrayingDate,
            today: controller.today,
            witrAllowed: ProfileRules.effectiveWitr(profile),
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
      builder: (_) => const _AddQazaProgressDialog(),
    );

    if (!mounted) return;
    final result = ref.read(qazaImportProvider);

    if (result.phase == QazaImportTaskPhase.completed) {
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaTrackerControllerProvider);
      ref.read(homeControllerProvider).invalidateDashboard();

      final existing = _lastExistingCount + result.skipped;
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
              if (existing > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  existing.toString() +
                      ' ' +
                      AppLocalizations.of(context).addQazaAlreadyAddedLabel,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
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
    required this.witrAllowed,
    required this.onToggle,
  });

  final Set<PrayerType> selected;
  final bool witrAllowed;
  final ValueChanged<PrayerType> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayers = [
      (PrayerType.fajr, l10n.prayerFajr),
      (PrayerType.zuhr, l10n.prayerZuhr),
      (PrayerType.asr, l10n.prayerAsr),
      (PrayerType.maghrib, l10n.prayerMaghrib),
      (PrayerType.isha, l10n.prayerIsha),
      (PrayerType.witr, l10n.prayerWitr),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Text(
                l10n.addQazaPrayersHeading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final prayer in prayers)
              CheckboxListTile(
                title: Text(prayer.$2),
                value: selected.contains(prayer.$1),
                onChanged: prayer.$1 == PrayerType.witr && !witrAllowed
                    ? null
                    : (_) => onToggle(prayer.$1),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.onReview,
  });

  final AddQazaState state;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final analysis = state.analysis;

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
            if (state.analysisLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: LinearProgressIndicator(),
              ),
            _CountRow(
              label: l10n.addQazaDateCountLabel,
              value: state.selectedDates.length,
            ),
            _CountRow(
              label: l10n.addQazaPrayersLabel,
              value: state.selectedPrayers.length,
            ),
            _CountRow(
              label: l10n.addQazaCombinationCountLabel,
              value: analysis.total,
            ),
            _CountRow(
              label: l10n.addQazaNewRecordsLabel,
              value: analysis.newCount,
            ),
            _CountRow(
              label: l10n.addQazaExistingLabel,
              value: analysis.existingCount,
            ),
            _CountRow(
              label: l10n.addQazaUnavailableLabel,
              value: analysis.unavailableCount,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                analysis.newCount == 0
                    ? l10n.addQazaNothingNew
                    : l10n.addQazaAddCount(
                        analysis.newCount.toString(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _AddQazaReviewDialog extends StatefulWidget {
  const _AddQazaReviewDialog({
    required this.analysis,
    required this.onAdd,
  });

  final AddQazaAnalysis analysis;
  final Future<AddQazaAnalysis?> Function() onAdd;

  @override
  State<_AddQazaReviewDialog> createState() => _AddQazaReviewDialogState();
}

class _AddQazaReviewDialogState extends State<_AddQazaReviewDialog> {
  late AddQazaAnalysis _analysis = widget.analysis;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_analysis.newCount == 0) return;

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

      if (latest.newCount == 0) {
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
    final height = (size.height - 180).clamp(360.0, 640.0).toDouble();

    return AlertDialog(
      title: Text(l10n.addQazaReviewHeading),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatusCount(
                    label: l10n.addQazaNewLabel,
                    count: _analysis.newCount,
                  ),
                ),
                Expanded(
                  child: _StatusCount(
                    label: l10n.addQazaAlreadyAddedLabel,
                    count: _analysis.existingCount,
                  ),
                ),
                Expanded(
                  child: _StatusCount(
                    label: l10n.addQazaUnavailableLabel,
                    count: _analysis.unavailableCount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_analysis.newCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  l10n.addQazaNothingNew,
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _analysis.items.length,
                itemBuilder: (context, index) {
                  final item = _analysis.items[index];
                  final showDateHeader = index == 0 ||
                      !_sameDate(
                        _analysis.items[index - 1].key.date,
                        item.key.date,
                      );
                  final status = switch (item.status) {
                    AddQazaCandidateStatus.newRecord => l10n.addQazaNewLabel,
                    AddQazaCandidateStatus.alreadyAdded =>
                      l10n.addQazaAlreadyAddedLabel,
                    AddQazaCandidateStatus.unavailable =>
                      l10n.addQazaUnavailableLabel,
                  };
                  final prayer = switch (item.key.prayerType) {
                    PrayerType.fajr => l10n.prayerFajr,
                    PrayerType.zuhr => l10n.prayerZuhr,
                    PrayerType.asr => l10n.prayerAsr,
                    PrayerType.maghrib => l10n.prayerMaghrib,
                    PrayerType.isha => l10n.prayerIsha,
                    PrayerType.witr => l10n.prayerWitr,
                  };

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateHeader)
                        Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : AppSpacing.sm,
                            bottom: AppSpacing.xs,
                          ),
                          child: Text(
                            DateFormatters.formatGregorianFull(
                              item.key.date,
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(prayer),
                        subtitle: Text(status),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  );
                },
              ),
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
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonBack),
        ),
        FilledButton.icon(
          onPressed: _busy || _analysis.newCount == 0 ? null : _confirm,
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
                    ? l10n.addQazaNothingNew
                    : l10n.addQazaAddCount(
                        _analysis.newCount.toString(),
                      ),
          ),
        ),
      ],
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AddQazaProgressDialog extends ConsumerStatefulWidget {
  const _AddQazaProgressDialog();

  @override
  ConsumerState<_AddQazaProgressDialog> createState() =>
      _AddQazaProgressDialogState();
}

class _AddQazaProgressDialogState
    extends ConsumerState<_AddQazaProgressDialog> {
  ProviderSubscription<QazaImportTaskState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<QazaImportTaskState>(
      qazaImportProvider,
      (_, next) {
        if (next.isActive) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(qazaImportProvider);
    final progress = state.progress;

    return AlertDialog(
      title: Text(l10n.addQazaInProgress),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress == null)
            const LinearProgressIndicator()
          else ...[
            Text(
              ((progress * 100).round()).toString() + '%',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.processed.toString() + ' / ' + state.total.toString(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.isActive && !state.cancelRequested
              ? () => ref.read(qazaImportProvider.notifier).cancel()
              : null,
          child: Text(
            state.cancelRequested
                ? l10n.commonLoading
                : l10n.commonCancel,
          ),
        ),
      ],
    );
  }
}