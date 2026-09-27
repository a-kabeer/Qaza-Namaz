import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/hijri_date_service.dart';
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
            AppSpacing.lg,
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
            const SizedBox(height: AppSpacing.md),
            _SelectionSummary(
              mode: state.mode,
              dates: state.selectedDates,
            ),
            const SizedBox(height: AppSpacing.md),
            _PrayerSelection(
              selected: state.selectedPrayers,
              witrAllowed: ProfileRules.effectiveWitr(profile),
              onToggle: (prayer) => ref
                  .read(addQazaControllerProvider.notifier)
                  .togglePrayer(prayer),
            ),
            const SizedBox(height: AppSpacing.md),
            _AnalysisSummary(
              analysis: state.analysis,
              selectedPrayers: state.selectedPrayers,
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
                  '$existing ${AppLocalizations.of(context).addQazaAlreadyAddedLabel}',
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
    const prayers = PrayerType.values;

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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prayers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 42,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemBuilder: (context, index) {
                final prayer = prayers[index];
                final enabled =
                    prayer != PrayerType.witr || witrAllowed;
                final isSelected = selected.contains(prayer);
                final label = _prayerLabel(l10n, prayer);

                return Semantics(
                  button: true,
                  enabled: enabled,
                  selected: isSelected,
                  label: label,
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected:
                        enabled ? (_) => onToggle(prayer) : null,
                    label: SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  ),
                );
              },
            ),
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

  String _modeLabel(AppLocalizations l10n) => switch (mode) {
        DateSelectionMode.single => l10n.addQazaModeSingleTitle,
        DateSelectionMode.range => l10n.addQazaModeRangeTitle,
        DateSelectionMode.multiple => l10n.addQazaModeMultipleTitle,
      };

  String _gregorianSummary(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (dates.isEmpty) {
      return switch (mode) {
        DateSelectionMode.single => l10n.addQazaChooseSingle,
        DateSelectionMode.range => l10n.addQazaChooseRange,
        DateSelectionMode.multiple => l10n.addQazaChooseMultiple,
      };
    }

    final materialL10n = MaterialLocalizations.of(context);
    if (mode == DateSelectionMode.multiple && dates.length > 1) {
      return l10n.addQazaDateCount(dates.length);
    }

    final first = materialL10n.formatMediumDate(dates.first);
    if (mode != DateSelectionMode.range || dates.length == 1) {
      return first;
    }

    return l10n.qazaDateFilterRange(
      first,
      materialL10n.formatMediumDate(dates.last),
    );
  }

  String? _hijriSummary(
    AppLocalizations l10n,
  ) {
    if (dates.isEmpty || (mode == DateSelectionMode.multiple && dates.length > 1)) {
      return null;
    }

    final first = HijriDateService.format(dates.first, l10n);
    if (mode != DateSelectionMode.range || dates.length == 1) {
      return first;
    }

    return l10n.qazaDateFilterRange(
      first,
      HijriDateService.format(dates.last, l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hijri = _hijriSummary(l10n);

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
                  _modeLabel(l10n),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _gregorianSummary(context, l10n),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (hijri != null)
              Text(
                hijri,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (dates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.addQazaDateCount(dates.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisSummary extends StatelessWidget {
  const _AnalysisSummary({
    required this.analysis,
    required this.selectedPrayers,
    required this.loading,
  });

  final AddQazaAnalysis analysis;
  final Set<PrayerType> selectedPrayers;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayers = PrayerType.values
        .where(selectedPrayers.contains)
        .toList(growable: false);

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
    required this.onAdd,
  });

  final AddQazaAnalysis analysis;
  final DateSelectionMode mode;
  final List<DateTime> selectedDates;
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
                selectedPrayers: {
                  for (final item in _analysis.items) item.key.prayerType,
                },
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

String _prayerLabel(AppLocalizations l10n, PrayerType prayer) =>
    switch (prayer) {
      PrayerType.fajr => l10n.prayerFajr,
      PrayerType.zuhr => l10n.prayerZuhr,
      PrayerType.asr => l10n.prayerAsr,
      PrayerType.maghrib => l10n.prayerMaghrib,
      PrayerType.isha => l10n.prayerIsha,
      PrayerType.witr => l10n.prayerWitr,
    };

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
    if (!ref.read(qazaImportProvider).isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
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
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${state.processed} / ${state.total}',
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