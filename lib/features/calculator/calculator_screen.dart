import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../domain/services/qaza_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'calculator_controller.dart';

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
            _ProgressIndicator(step: state.step),
            if (state.restoring) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (state.step) {
                  0 => _AboutYouStep(state: state, controller: controller),
                  1 => _PrayerHistoryStep(state: state, controller: controller),
                  _ => _ResultStep(state: state, controller: controller),
                },
              ),
            ),
            _StepActions(
              step: state.step,
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
    final preflight = await controller.loadPreflight();
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
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.calcEstimateAdded),
        content: Text(
          l10n.calcEstimateAddedMessage(
            DateFormatters.formatCount(preflight.newCount),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
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
    if (dob == null) return;
    final today = CalculatorState.today;
    final current = state.balighDate;
    final initial =
        current != null && !current.isBefore(dob) && !current.isAfter(today)
            ? current
            : dob;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: dob,
      lastDate: today,
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
                        value: state.balighAge,
                        decoration:
                            InputDecoration(labelText: l10n.calcBalighAgeLabel),
                        items: [
                          for (var value = 9; value <= 18; value++)
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
    final baligh = state.effectiveBalighDate;
    final today = CalculatorState.today;
    if (baligh == null || baligh.isAfter(today)) return;
    final current = state.prayerStartDate;
    final initial =
        current != null && !current.isBefore(baligh) && !current.isAfter(today)
            ? current
            : baligh;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: baligh,
      lastDate: today,
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
                      DropdownButtonFormField<int>(
                        key: const Key('calculator_prayer_start_age'),
                        value: state.prayerStartAge,
                        decoration: InputDecoration(
                          labelText: l10n.calcPrayerStartAgeLabel,
                        ),
                        items: [
                          for (var value = 12; value <= 60; value++)
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
                      OutlinedButton.icon(
                        key: const Key('calculator_prayer_start_date_picker'),
                        onPressed: baligh == null
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
  const _ResultStep({required this.state, required this.controller});

  final CalculatorState state;
  final CalculatorController controller;

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
    final busy = state.addingToTracker || state.loadingPreflight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final pad = compact ? 16.0 : 20.0;
        final editButtons = [
          OutlinedButton.icon(
            key: const Key('calculator_edit_about'),
            onPressed: busy ? null : () => controller.editStep(0),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.calcEditAboutYou),
          ),
          OutlinedButton.icon(
            key: const Key('calculator_edit_prayer_history'),
            onPressed: busy ? null : () => controller.editStep(1),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(l10n.calcEditPrayerHistory),
          ),
        ];

        return ListView(
          key: const ValueKey('calculator_step_2'),
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
          children: [
            Text(l10n.calcStepOf(3), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(l10n.calcStepResult, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            _SourceChip(exact: state.usesExactDates),
            if (state.keptAsEstimate)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text(l10n.calcKeptAsEstimate)),
                ),
              ),
            const SizedBox(height: 10),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: editButtons,
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: editButtons),
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
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('calculator_keep_estimate'),
              onPressed: busy ? null : controller.keepAsEstimate,
              child: Text(l10n.calcKeepAsEstimate),
            ),
          ],
        );
      },
    );
  }
}

/// Shows the shared preflight result before anything is written.
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

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.exact});
  final bool exact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          exact ? Icons.event_available_rounded : Icons.auto_awesome_rounded,
          color: colors.onSecondaryContainer,
        ),
        label: Text(exact ? 'Based on exact dates' : 'Estimated calculation'),
        backgroundColor: colors.secondaryContainer,
        labelStyle: TextStyle(color: colors.onSecondaryContainer),
      ),
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

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 2,
                color: index <= step ? colors.primary : colors.outlineVariant,
              ),
            ),
          Semantics(
            label: AppLocalizations.of(context).calcStepSemantics(
              index + 1,
              calculatorStepNames(AppLocalizations.of(context))[index],
            ),
            selected: index == step,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: index <= step
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: index <= step
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          if (index < 2) const SizedBox(width: 6),
        ],
      ]),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({
    required this.step,
    required this.canContinue,
    required this.onBack,
    required this.onContinue,
  });
  final int step;
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
                      : 'Add to Tracker'),
            ),
          ),
        ]),
      );
}
