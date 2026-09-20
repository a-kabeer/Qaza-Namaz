import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/services/qaza_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../shell/workspace_shell.dart';
import 'calculator_controller.dart';
import 'calculator_validation.dart';

/// Step names in display order, resolved for the active locale.
List<String> calculatorStepNames(AppLocalizations l10n) => [
      l10n.calcStepAboutYou,
      l10n.calcStepPrayerHistory,
      l10n.calcStepResult,
    ];

/// Three-step Qaza calculator.
///
/// All workflow state lives in [CalculatorController]; this widget renders it
/// and dispatches user actions.
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorControllerProvider);
    final controller = ref.read(calculatorControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    // Nothing is left to do on Step 3 once the estimate has been added.
    final done = state.step == 2 && state.addCompleted;

    // The Result step's action says how many records it will actually add,
    // which is the preflight's count and nothing else.
    final newCount = state.preflight?.newCount;
    final addLabel = newCount == null
        ? l10n.calcAddToTracker
        : l10n.calcAddQazaCount(DateFormatters.formatCount(newCount));

    final canContinue = !state.restoring &&
        switch (state.step) {
          0 => state.step1Valid,
          1 => state.step2Valid,
          _ => state.calculation != null &&
              !state.addingToTracker &&
              !state.loadingPreflight,
        };

    return AppScaffold(
      title: l10n.calculatorTitle,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressIndicator(
              step: state.step,
              canOpen: state.canOpenStep,
              onSelect: controller.goToStep,
            ),
            if (state.restoring) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (state.step) {
                  0 => _AboutYouStep(state: state, controller: controller),
                  1 => _PrayerHistoryStep(state: state, controller: controller),
                  _ => done
                      ? _AddedStep(
                          addedCount: state.addedCount!,
                          onCalculateAgain: controller.startNewCalculation,
                          onDone: () => _finish(context, ref),
                        )
                      : _ResultStep(state: state),
                },
              ),
            ),
            // Persistent, in place, and determinate: a large estimate takes
            // seconds, and the screen has to keep saying so.
            if (state.step == 2 && !done)
              _AddStatusPanel(
                state: state,
                onRetry: () => _addToTracker(context, ref),
              ),
            // The finished state carries its own two actions.
            if (!done)
              _StepActions(
                step: state.step,
                addLabel: addLabel,
                canContinue: canContinue,
                onBack: state.step == 0 ? null : controller.back,
                onContinue: state.step == 2
                    ? () => _addToTracker(context, ref)
                    : controller.next,
              ),
          ],
        ),
      ),
    );
  }

  /// Runs the shared preflight, shows what will actually be created, and only
  /// then writes. Nothing is created before this confirmation.
  Future<void> _addToTracker(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(calculatorControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final preflight = ref.read(calculatorControllerProvider).preflight ??
        await controller.loadPreflight();
    if (!context.mounted) return;

    if (preflight == null) {
      final error = ref.read(calculatorControllerProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? l10n.calcPreflightErrorShort)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PreflightDialog(preflight: preflight),
    );
    if (confirmed != true || !context.mounted) return;

    final added = await controller.addToTracker();
    if (!context.mounted) return;

    if (!added) {
      final error = ref.read(calculatorControllerProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? l10n.calcAddErrorShort)),
      );
    }
    // Success speaks for itself: the step is now the success state, which
    // stays on screen with the count and the two ways out of it.
  }

  /// `Done`: finish with this calculation and go back to Home, whose progress
  /// is re-read on the way in.
  void _finish(BuildContext context, WidgetRef ref) {
    ref.read(calculatorControllerProvider.notifier).startNewCalculation();
    ref.invalidate(progressSummaryProvider);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Reached as a workspace page rather than a pushed route.
      ref.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.home;
    }
  }
}

/// Step 3, after a successful add: what was written, and the two ways on.
class _AddedStep extends StatelessWidget {
  const _AddedStep({
    required this.addedCount,
    required this.onCalculateAgain,
    required this.onDone,
  });

  final int addedCount;
  final VoidCallback onCalculateAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: const Key('calc_add_success'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Icon(Icons.check_circle_rounded, size: 64, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.calcEstimateAdded,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calcAddedResult(addedCount),
          key: const Key('calc_add_success_count'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calcAddedDoneHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const Key('calculator_done'),
          onPressed: onDone,
          icon: const Icon(Icons.home_outlined),
          label: Text(l10n.commonDone),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('calculator_calculate_again'),
          onPressed: onCalculateAgain,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.calcCalculateAgain),
        ),
      ],
    );
  }
}

/// Step 1 — date of birth and Baligh information, Gregorian with Hijri shown
/// alongside as secondary information.
class _AboutYouStep extends StatelessWidget {
  const _AboutYouStep({required this.state, required this.controller});

  final CalculatorState state;
  final CalculatorController controller;

  Future<void> _pickDob(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final today = CalculatorState.today;
    final date = await showDatePicker(
      context: context,
      initialDate:
          state.dob ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: l10n.calcSelectDobHelp,
    );
    if (date != null) controller.setDob(date);
  }

  Future<void> _pickBalighDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final dob = state.dob;
    final first = state.balighDateMin;
    final last = state.balighDateMax;
    if (dob == null || first == null || last == null) return;
    // The picker offers exactly the range the rules allow, which reaches into
    // the future for anyone whose Baligh years have not passed yet.
    final current = state.balighDate ??
        DateTime(dob.year + state.balighAge, dob.month, dob.day);
    final initial = current.isBefore(first)
        ? first
        : current.isAfter(last)
            ? last
            : current;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: l10n.calcSelectBalighHelp,
    );
    if (date != null) controller.setBalighDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effectiveBaligh = state.effectiveBalighDate;
    final age = state.currentAge;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 360 ? 16.0 : 20.0;
        return ListView(
          key: const ValueKey('calculator_step_0'),
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
          children: [
            Text(l10n.calcStepOf(1), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(l10n.calcStepAboutYou, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.calcAboutYouIntro),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calcDateOfBirth,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('calculator_dob_picker'),
                      onPressed: () => _pickDob(context),
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(state.dob == null
                          ? l10n.calcSelectDate
                          : _formatDate(state.dob!)),
                    ),
                    if (state.dob != null) ...[
                      const SizedBox(height: 8),
                      _DualDate(date: state.dob!),
                    ],
                    if (state.dobError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        state.dobError!,
                        key: const Key('calculator_dob_error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    if (age != null) ...[
                      const SizedBox(height: 10),
                      _InfoRow(
                          label: l10n.calcCurrentAge,
                          value: l10n.calcAgeYears(age)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calcBalighInformation,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    SegmentedButton<BalighInputMode>(
                      key: const Key('calculator_baligh_mode'),
                      segments: [
                        ButtonSegment(
                          value: BalighInputMode.age,
                          label: Text(l10n.calcModeAge),
                          icon: const Icon(Icons.numbers_rounded),
                        ),
                        ButtonSegment(
                          value: BalighInputMode.exactDate,
                          label: Text(l10n.calcModeExactDate),
                          icon: const Icon(Icons.event_rounded),
                        ),
                      ],
                      selected: {state.balighMode},
                      onSelectionChanged: (value) =>
                          controller.setBalighMode(value.first),
                    ),
                    const SizedBox(height: 14),
                    if (state.balighMode == BalighInputMode.age)
                      DropdownButtonFormField<int>(
                        key: const Key('calculator_baligh_age'),
                        initialValue: state.balighAge,
                        decoration:
                            InputDecoration(labelText: l10n.calcBalighAgeLabel),
                        items: [
                          for (var value = CalculatorBounds.minBalighAge;
                              value <= CalculatorBounds.maxBalighAge;
                              value++)
                            DropdownMenuItem(
                                value: value, child: Text('$value years')),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setBalighAge(value);
                        },
                      )
                    else
                      OutlinedButton.icon(
                        key: const Key('calculator_baligh_date_picker'),
                        onPressed: state.dob == null
                            ? null
                            : () => _pickBalighDate(context),
                        icon: const Icon(Icons.event_rounded),
                        label: Text(state.balighDate == null
                            ? l10n.calcSelectExactDate
                            : _formatDate(state.balighDate!)),
                      ),
                    if (state.balighError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        state.balighError!,
                        key: const Key('calculator_baligh_error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    if (effectiveBaligh != null) ...[
                      const SizedBox(height: 12),
                      _DateInfoBox(
                        text: state.balighMode == BalighInputMode.age
                            ? l10n.calcEstimatedBalighDate(
                                _formatDate(effectiveBaligh))
                            : l10n.calcExactBalighDate(
                                _formatDate(effectiveBaligh)),
                      ),
                      const SizedBox(height: 8),
                      _DualDate(date: effectiveBaligh),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Step 2 — when regular prayer started, plus the Witr rule. Witr is configured
/// here, before the result, never on the Result step.
class _PrayerHistoryStep extends StatelessWidget {
  const _PrayerHistoryStep({required this.state, required this.controller});

  final CalculatorState state;
  final CalculatorController controller;

  Future<void> _pickPrayerStartDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final first = state.prayerStartDateMin;
    final last = state.prayerStartDateMax;
    // Never before Baligh, never after today.
    if (first == null || first.isAfter(last)) return;
    final current = state.prayerStartDate;
    final initial =
        current != null && !current.isBefore(first) && !current.isAfter(last)
            ? current
            : first;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: l10n.calcSelectPrayerStartHelp,
    );
    if (date != null) controller.setPrayerStartDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final baligh = state.effectiveBalighDate;
    final prayerStart = state.effectivePrayerStartDate;
    final valid =
        baligh != null && prayerStart != null && !prayerStart.isBefore(baligh);
    final years = valid ? _calendarYearsBetween(baligh, prayerStart) : null;
    final days = valid ? prayerStart.difference(baligh).inDays : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 360 ? 16.0 : 20.0;
        return ListView(
          key: const ValueKey('calculator_step_1'),
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
          children: [
            Text(l10n.calcStepOf(2), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(l10n.calcStepPrayerHistory,
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Tell us when regular prayer started so we can calculate the '
              'Qaza period.',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calcRegularPrayerStart,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    SegmentedButton<PrayerStartInputMode>(
                      key: const Key('calculator_prayer_start_mode'),
                      segments: [
                        ButtonSegment(
                          value: PrayerStartInputMode.age,
                          label: Text(l10n.calcModeAge),
                          icon: const Icon(Icons.numbers_rounded),
                        ),
                        ButtonSegment(
                          value: PrayerStartInputMode.exactDate,
                          label: Text(l10n.calcModeExactDate),
                          icon: const Icon(Icons.event_rounded),
                        ),
                      ],
                      selected: {state.prayerStartMode},
                      onSelectionChanged: (value) =>
                          controller.setPrayerStartMode(value.first),
                    ),
                    const SizedBox(height: 14),
                    if (state.prayerStartMode == PrayerStartInputMode.age)
                      if (state.hasPrayerStartAgeRange)
                        DropdownButtonFormField<int>(
                          key: const Key('calculator_prayer_start_age'),
                          // Never before Baligh, never beyond today's age.
                          initialValue: state.prayerStartAge
                              .clamp(state.prayerStartAgeMin!,
                                  state.prayerStartAgeMax!)
                              .toInt(),
                          decoration: InputDecoration(
                            labelText: l10n.calcPrayerStartAgeLabel,
                          ),
                          items: [
                            for (var value = state.prayerStartAgeMin!;
                                value <= state.prayerStartAgeMax!;
                                value++)
                              DropdownMenuItem(
                                  value: value, child: Text('$value years')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.setPrayerStartAge(value);
                            }
                          },
                        )
                      else
                        Text(
                          l10n.calcPrayerStartAgeUnavailable,
                          key: const Key('calculator_prayer_start_age_empty'),
                          style: TextStyle(color: theme.colorScheme.error),
                        )
                    else
                      OutlinedButton.icon(
                        key: const Key('calculator_prayer_start_date_picker'),
                        onPressed: state.prayerStartDateMin == null
                            ? null
                            : () => _pickPrayerStartDate(context),
                        icon: const Icon(Icons.event_rounded),
                        label: Text(state.prayerStartDate == null
                            ? l10n.calcSelectExactDate
                            : _formatDate(state.prayerStartDate!)),
                      ),
                    if (prayerStart != null) ...[
                      const SizedBox(height: 12),
                      _DateInfoBox(
                        text: state.prayerStartMode == PrayerStartInputMode.age
                            ? l10n.calcEstimatedPrayerStartDate(
                                _formatDate(prayerStart))
                            : l10n.calcExactPrayerStartDate(
                                _formatDate(prayerStart)),
                      ),
                      const SizedBox(height: 8),
                      _DualDate(date: prayerStart),
                    ],
                    if (state.prayerStartError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.prayerStartError!,
                        key: const Key('calculator_prayer_start_error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const Divider(height: 24),
                    SwitchListTile.adaptive(
                      key: const Key('calculator_include_witr'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.calcIncludeWitr),
                      subtitle: const Text(
                        'Witr is counted independently from the five daily '
                        'prayers.',
                      ),
                      value: state.includeWitr,
                      onChanged: controller.setIncludeWitr,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              key: const Key('calculator_qaza_period_summary'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calcQazaPeriod,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (baligh != null) ...[
                      _InfoRow(
                          label: l10n.calcBalighDate,
                          value: _formatDate(baligh)),
                      _DualDate(date: baligh),
                    ],
                    if (prayerStart != null) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: l10n.calcPrayerStartDate,
                        value: _formatDate(prayerStart),
                      ),
                      _DualDate(date: prayerStart),
                    ],
                    if (years != null && days != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: l10n.calcCalendarPeriod,
                        value: '$years years • $days days',
                      ),
                    ] else
                      Text(
                        l10n.calcCompleteDatesPrompt,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Step 3 — the result. Read-only; the Witr rule belongs to Step 2.
class _ResultStep extends StatelessWidget {
  const _ResultStep({required this.state});

  final CalculatorState state;

  @override
  Widget build(BuildContext context) {
    final result = state.calculation;
    if (result == null) {
      return Center(
        child: Text(AppLocalizations.of(context).calcNoResultPrompt),
      );
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final pad = compact ? 16.0 : 20.0;

        return ListView(
          key: const ValueKey('calculator_step_2'),
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
          children: [
            Text(l10n.calcStepOf(3), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(l10n.calcStepResult, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultMetric(
                      label: l10n.calcQazaPeriod,
                      value: l10n.calcPeriodValue(
                          result.calendarYears, result.remainingDays),
                    ),
                    _ResultMetric(
                      label: l10n.calcElapsedDays,
                      value: DateFormatters.formatCount(result.totalDays),
                    ),
                    _ResultMetric(
                      label: l10n.calcEstimatedPrayers,
                      value: DateFormatters.formatCount(result.totalPrayers),
                      prominent: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calcPrayerBreakdown,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    for (final prayer in result.prayerBreakdown.keys)
                      _InfoRow(
                        label: prayer.localizedLabel(l10n),
                        value: DateFormatters.formatCount(
                            result.prayerBreakdown[prayer]!),
                      ),
                    if (result.includeWitr)
                      _InfoRow(
                        label: PrayerType.witr.localizedLabel(l10n),
                        value: DateFormatters.formatCount(result.witrCount),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.calcWitrNotIncluded,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PreflightLoadingPanel extends StatelessWidget {
  const _PreflightLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const Key('calc_preflight_loading'),
      background: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 180, height: 17),
          SizedBox(height: 12),
          SkeletonText(width: double.infinity, height: 13),
          SizedBox(height: 8),
          SkeletonText(width: 230, height: 13),
        ],
      ),
    );
  }
}

/// Shows the shared preflight result before anything is written.
/// Progress, success and failure for the tracker insert, in the page itself.
class _AddStatusPanel extends StatelessWidget {
  const _AddStatusPanel({required this.state, required this.onRetry});

  final CalculatorState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final numbers =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString());

    if (state.loadingPreflight) {
      return const _PreflightLoadingPanel();
    }

    if (state.addingToTracker) {
      return _Panel(
        key: const Key('calc_add_progress'),
        background: scheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.calcAddingTitle,
                      style: theme.textTheme.titleSmall),
                ),
                Text('${(state.addProgress * 100).round()}%',
                    key: const Key('calc_add_percent'),
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                key: const Key('calc_add_bar'),
                value: state.addProgress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.calcAddingProgress(
                numbers.format(state.addProcessed),
                numbers.format(state.addTotal),
              ),
              key: const Key('calc_add_counts'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final error = state.error;
    if (error == null) return const SizedBox.shrink();
    return _Panel(
      key: const Key('calc_add_error'),
      background: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.calcAddFailedTitle,
                    style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600)),
                Text(error,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onErrorContainer)),
              ],
            ),
          ),
          TextButton(
            key: const Key('calc_add_retry'),
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, required this.background});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      );
}

class _PreflightDialog extends StatelessWidget {
  const _PreflightDialog({required this.preflight});

  final QazaAvailabilityAnalysis preflight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.calcPreflightTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: l10n.calcCalculated,
            value: DateFormatters.formatCount(preflight.requestedCount),
          ),
          _InfoRow(
            label: l10n.calcAlreadyRecorded,
            value: DateFormatters.formatCount(preflight.alreadyRecorded),
          ),
          _InfoRow(
            label: l10n.calcAlreadyCompleted,
            value: DateFormatters.formatCount(preflight.alreadyCompleted),
          ),
          const Divider(height: 20),
          _InfoRow(
            label: l10n.calcNewToAdd,
            value: DateFormatters.formatCount(preflight.newCount),
          ),
          const SizedBox(height: 10),
          Text(l10n.calcExistingUntouched),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('calculator_confirm_add_to_tracker'),
          onPressed: preflight.newCount == 0
              ? null
              : () => Navigator.pop(context, true),
          child: Text(
            l10n.calcAddCountToTracker(
              DateFormatters.formatCount(preflight.newCount),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gregorian primary, Hijri secondary.
class _DualDate extends StatelessWidget {
  const _DualDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          DateFormatters.hijriLabel(date),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

int _calendarYearsBetween(DateTime start, DateTime end) {
  var years = end.year - start.year;
  final anniversary = DateTime(end.year, start.month, start.day);
  if (anniversary.isAfter(end)) years--;
  return years;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleSmall),
          ),
        ]),
      );
}

class _DateInfoBox extends StatelessWidget {
  const _DateInfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: colors.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child:
              Text(text, style: TextStyle(color: colors.onSecondaryContainer)),
        ),
      ]),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: prominent
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ]),
      );
}

/// The 1-2-3 step indicator, and the primary way to move between steps.
///
/// Every dot is a button: the ones whose requirements are met can be opened,
/// the rest are inert and say so to assistive technology. The row is laid out
/// with `Row`, so it mirrors with the text direction.
class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({
    required this.step,
    required this.canOpen,
    required this.onSelect,
  });

  final int step;
  final bool Function(int index) canOpen;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 17),
                  child: Container(
                    height: 2,
                    color:
                        index <= step ? colors.primary : colors.outlineVariant,
                  ),
                ),
              ),
            _StepDot(
              index: index,
              current: step,
              enabled: canOpen(index),
              onTap: () => onSelect(index),
            ),
          ],
        ],
      ),
    );
  }
}

/// One numbered step: a button that opens it when its rules are satisfied.
class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final int current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = calculatorStepNames(l10n)[index];
    final selected = index == current;
    final reached = index <= current;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: l10n.calcStepSemantics(index + 1, name),
      child: InkWell(
        key: Key('calculator_step_tab_$index'),
        onTap: enabled && !selected ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SizedBox(
              width: 78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: reached
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: reached
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: enabled
                          ? (selected
                              ? colors.primary
                              : colors.onSurfaceVariant)
                          : colors.onSurfaceVariant.withValues(alpha: 0.45),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({
    required this.step,
    required this.addLabel,
    required this.canContinue,
    required this.onBack,
    required this.onContinue,
  });
  final int step;

  /// The Result step's primary label, which carries the count to be added.
  final String addLabel;
  final bool canContinue;
  final VoidCallback? onBack;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(children: [
          if (onBack != null) ...[
            OutlinedButton(
              key: const Key('calculator_back'),
              onPressed: onBack,
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              key: Key(step == 0
                  ? 'calculator_continue'
                  : step == 1
                      ? 'calculator_calculate'
                      : 'calculator_add_to_tracker'),
              onPressed: canContinue ? onContinue : null,
              child: Text(step == 0
                  ? 'Continue'
                  : step == 1
                      ? 'Calculate'
                      : addLabel),
            ),
          ),
        ]),
      );
}
