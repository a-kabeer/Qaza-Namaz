import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/prayer_visuals.dart';
import '../calendar/calendar_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import '../calendar/calendar_picker.dart';
import 'add_qaza_flow_controller.dart';

/// Add Qaza — one screen, exactly three steps:
/// 1. Select Dates (mode + calendar merged), 2. Select Missed Prayers,
/// 3. Review & Add (the only step that can create records).
class AddQazaScreen extends ConsumerStatefulWidget {
  const AddQazaScreen({super.key});

  @override
  ConsumerState<AddQazaScreen> createState() => _AddQazaScreenState();
}

class _AddQazaScreenState extends ConsumerState<AddQazaScreen> {
  bool calendarLoading = false;
  Map<DateTime, Set<PrayerType>>? calendarAvailability;
  int request = 0;

  CalendarSelectionState get calendar => ref.watch(calendarControllerProvider);
  AddQazaFlowState get flow => ref.watch(addQazaFlowProvider);
  List<DateTime> get dates => calendar.datesForStorage.toList(growable: false);

  /// Availability for an arbitrary span, for a range that crosses months or
  /// years. Same rule, same service call — only the window differs.
  Future<Map<DateTime, Set<PrayerType>>> loadSpan(
      DateTime start, DateTime end) async {
    final today = ref.read(calendarTodayProvider);
    final last = end.isAfter(today) ? today : end;
    if (last.isBefore(start)) return const {};
    return ref.read(qazaServiceProvider).getAvailablePrayersByDate(
      userId: ref.read(requiredUserIdProvider),
      dates: [
        for (var d = start;
            !d.isAfter(last);
            d = DateTime(d.year, d.month, d.day + 1))
          d
      ],
    );
  }

  /// Loads the per date + prayer availability for the visible month so the
  /// calendar can disable a date only when zero prayers remain eligible.
  Future<void> loadMonth(DateTime month) async {
    final token = ++request;
    setState(() {
      calendarLoading = true;
      calendarAvailability = null;
    });
    try {
      final first = DateTime(month.year, month.month, 1);
      final last0 = DateTime(month.year, month.month + 1, 0);
      final today = ref.read(calendarTodayProvider);
      final last = last0.isAfter(today) ? today : last0;
      if (last.isBefore(first)) {
        if (mounted && token == request) {
          setState(() => calendarAvailability = {});
        }
        return;
      }
      final map = await ref.read(qazaServiceProvider).getAvailablePrayersByDate(
        userId: ref.read(requiredUserIdProvider),
        dates: [
          for (var d = first;
              !d.isAfter(last);
              d = d.add(const Duration(days: 1)))
            d
        ],
      );
      if (mounted && token == request) {
        setState(() => calendarAvailability = map);
      }
    } finally {
      if (mounted && token == request) setState(() => calendarLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = flow.step;
    return PopScope(
      canPop: step == AddQazaStep.selectDates,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && step != AddQazaStep.selectDates) {
          ref.read(addQazaFlowProvider.notifier).back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).addQazaTitle),
          leading: IconButton(
            onPressed: step == AddQazaStep.selectDates
                ? () => Navigator.pop(context)
                : () => ref.read(addQazaFlowProvider.notifier).back(),
            icon: Icon(step == AddQazaStep.selectDates
                ? Icons.close
                : Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                step: step.index,
                canOpen: (index) => ref
                    .read(addQazaFlowProvider.notifier)
                    .canOpenStep(AddQazaStep.values[index]),
                onSelect: (index) => ref
                    .read(addQazaFlowProvider.notifier)
                    .goToStep(AddQazaStep.values[index]),
              ),
              Expanded(
                child: switch (step) {
                  AddQazaStep.selectDates => _datesStep(),
                  AddQazaStep.selectMissedPrayers => _prayersStep(),
                  AddQazaStep.reviewAndAdd => _reviewStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1 — Select Dates: the mode selector and the calendar live on the
  /// same step; there is no separate date-selection screen.
  Widget _datesStep() {
    final mode = calendar.selectionMode;
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const ValueKey('qaza-step-dates'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.addQazaStep1,
          key: const Key('qaza_flow_step'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addQazaTitle,
          key: const Key('qaza_flow_heading'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        SegmentedButton<DateSelectionMode>(
          key: const Key('qaza_date_mode_selector'),
          segments: [
            ButtonSegment(
                value: DateSelectionMode.single,
                label: Text(l10n.addQazaModeSingle)),
            ButtonSegment(
                value: DateSelectionMode.range,
                label: Text(l10n.addQazaModeRange)),
            ButtonSegment(
                value: DateSelectionMode.multiple,
                label: Text(l10n.addQazaModeMultiple)),
          ],
          selected: {mode},
          onSelectionChanged: (value) => ref
              .read(calendarControllerProvider.notifier)
              .setSelectionMode(value.first),
        ),
        const SizedBox(height: 20),
        Text(
          switch (mode) {
            DateSelectionMode.single => l10n.addQazaChooseSingle,
            DateSelectionMode.range => l10n.addQazaChooseRange,
            DateSelectionMode.multiple => l10n.addQazaChooseMultiple,
          },
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addQazaAvailabilityNote,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          key: const Key('qaza_calendar_picker'),
          child: CalendarPicker(
            availablePrayersByDate: calendarAvailability,
            availabilityLoading: calendarLoading,
            onMonthChanged: loadMonth,
            resolveAvailability: loadSpan,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('qaza_continue_button'),
          onPressed: dates.isEmpty
              ? null
              : () => ref.read(addQazaFlowProvider.notifier).openPrayersStep(),
          child: Text(l10n.commonContinue),
        ),
      ],
    );
  }

  /// What a prayer's availability across the selected dates amounts to:
  /// nothing left, some dates, or all of them.
  String _availabilityText(AppLocalizations l10n, PrayerType prayer) {
    final rakats = prayer.localizedRakats(l10n);
    if (!flow.isPrayerAvailable(prayer)) {
      return l10n.addQazaUnavailablePrayer(rakats);
    }
    if (flow.isPartiallyAvailable(prayer)) {
      return '$rakats • '
          '${l10n.addQazaPartialAvailability(flow.availableDateCount(prayer), flow.selectedDateCount)}';
    }
    return rakats;
  }

  /// Step 2 — Select Missed Prayers: receives the Step 1 dates unchanged and
  /// applies availability per date + prayer. No date-selection duties here.
  Widget _prayersStep() {
    final l10n = AppLocalizations.of(context);
    final prayers = flow.prayers;
    final selectable = <PrayerType>[
      for (final prayer in PrayerType.values)
        if (flow.prayerAvailability[prayer] ?? true) prayer,
    ];
    final allSelected =
        selectable.isNotEmpty && selectable.every(prayers.contains);
    return ListView(
      key: const ValueKey('qaza-step-prayers'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          l10n.addQazaStep2,
          key: const Key('qaza_flow_step'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addQazaPrayersHeading,
          key: const Key('qaza_prayers_heading'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.addQazaSelectedCount(dates.length)),
        const SizedBox(height: 12),
        // The rule, said plainly, where the choice is actually made.
        _Info(text: l10n.addQazaEligibleOnlyNote),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('qaza_select_all_button'),
                onPressed: flow.checking || allSelected
                    ? null
                    : () => ref.read(addQazaFlowProvider.notifier).selectAll(),
                child: Text(allSelected
                    ? l10n.addQazaAllSelected
                    : l10n.addQazaSelectAll),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const Key('qaza_clear_prayers_button'),
                onPressed: flow.checking || prayers.isEmpty
                    ? null
                    : () =>
                        ref.read(addQazaFlowProvider.notifier).clearPrayers(),
                child: Text(l10n.commonClear),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final prayer in PrayerType.values)
          Card(
            child: CheckboxListTile(
              key: Key('qaza_prayer_${prayer.name}'),
              value: prayers.contains(prayer),
              onChanged: flow.checking ||
                      flow.saving ||
                      !(flow.prayerAvailability[prayer] ?? true)
                  ? null
                  : (value) => ref
                      .read(addQazaFlowProvider.notifier)
                      .togglePrayer(prayer, selected: value == true),
              secondary: CircleAvatar(child: Icon(prayer.icon)),
              title: Text(prayer.localizedLabel(l10n)),
              subtitle: Text(
                key: Key('qaza_prayer_subtitle_${prayer.name}'),
                _availabilityText(l10n, prayer),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row(l10n.addQazaDatesLabel, '${dates.length}'),
                _Row(l10n.addQazaPrayersPerDateLabel, '${prayers.length}'),
                _Row(l10n.addQazaExistingLabel, '${flow.existingCount}'),
                _Row(l10n.addQazaNewRecordsLabel, '${flow.newCount}',
                    bold: true),
              ],
            ),
          ),
        ),
        const _Busy(),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              key: const Key('qaza_back_button'),
              onPressed: () => ref.read(addQazaFlowProvider.notifier).back(),
              child: Text(l10n.commonBack),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('qaza_review_button'),
                onPressed: flow.checking || prayers.isEmpty
                    ? null
                    : () =>
                        ref.read(addQazaFlowProvider.notifier).openReviewStep(),
                child: Text(l10n.addQazaNextPrayers),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Step 3 — Review & Add: read-only summary; records are only created here,
  /// after explicit confirmation.
  Widget _reviewStep() {
    final l10n = AppLocalizations.of(context);
    final selectedDates = calendar.selectedDates;
    final prayers = flow.prayers;
    final mode = calendar.selectionMode;
    final datesSummary = switch (mode) {
      DateSelectionMode.range when selectedDates.length == 2 =>
        '${_formatDate(selectedDates.first)} – ${_formatDate(selectedDates.last)}',
      _ when selectedDates.length == 1 => _formatDate(selectedDates.single),
      _ => l10n.addQazaDateCount(selectedDates.length),
    };
    return ListView(
      key: const ValueKey('qaza-step-review'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          l10n.addQazaStep3,
          key: const Key('qaza_flow_step'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addQazaReviewHeading,
          key: const Key('qaza_review_heading'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.addQazaReviewNote),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(
                  l10n.addQazaSelectionLabel,
                  switch (mode) {
                    DateSelectionMode.single => l10n.addQazaModeSingleTitle,
                    DateSelectionMode.range => l10n.addQazaModeRangeTitle,
                    DateSelectionMode.multiple => l10n.addQazaModeMultipleTitle,
                  },
                ),
                _Row(l10n.addQazaDatesLabel, datesSummary),
                _Row(l10n.addQazaDateCountLabel, '${dates.length}'),
                _Row(
                  l10n.addQazaPrayersLabel,
                  prayers.isEmpty
                      ? l10n.commonNone
                      : prayers
                          .map((prayer) => prayer.localizedLabel(l10n))
                          .join(', '),
                ),
                _Row(l10n.addQazaExistingLabel, '${flow.existingCount}'),
                _Row(l10n.addQazaNewQazaLabel, '${flow.newCount}', bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Info(text: l10n.addQazaCombinationNote),
        const _Busy(),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              key: const Key('qaza_back_button'),
              onPressed: flow.saving
                  ? null
                  : () => ref.read(addQazaFlowProvider.notifier).back(),
              child: Text(l10n.commonBack),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('qaza_add_button'),
                onPressed: flow.canAdd ? _add : null,
                child: Text(flow.saving
                    ? l10n.addQazaInProgress
                    : l10n.addQazaAddCount(
                        DateFormatters.formatCount(flow.newCount))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The same complete Gregorian date the calendar shows, for single dates
  /// and for both ends of a range alike.
  String _formatDate(DateTime date) => DateFormatters.formatGregorianFull(date);

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await ref.read(addQazaFlowProvider.notifier).addQaza();
    if (!mounted) return;
    if (created <= 0) {
      // The revalidation found nothing left to write; say so rather than
      // leaving the tap looking ignored.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).addQazaNothingNew),
        ));
      return;
    }
    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.addQazaCreatedTitle),
        content: Text(l10n.addQazaCreatedMessage(created)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonDone)),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, created);
  }
}

/// The 1-2-3 indicator, and a way to move between steps.
///
/// A step is offered only when its own requirements are already met, so the
/// indicator can shorten the walk but never skip a rule. It is laid out with
/// `Row`, so it mirrors with the text direction.
class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.canOpen,
    required this.onSelect,
  });

  final int step;
  final bool Function(int index) canOpen;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            _StepTab(
              index: i,
              current: step,
              enabled: canOpen(i),
              onTap: () => onSelect(i),
            ),
            if (i < 2)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    height: 2,
                    color: i < step ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = [
      l10n.addQazaStepNameDates,
      l10n.addQazaStepNamePrayers,
      l10n.addQazaStepNameReview,
    ][index];
    final selected = index == current;
    final reached = index <= current;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: l10n.addQazaStepSemantics(index + 1, name),
      child: InkWell(
        key: Key('qaza_step_tab_$index'),
        onTap: enabled && !selected ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: reached
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: reached
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
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
                              ? scheme.primary
                              : scheme.onSurfaceVariant)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.45),
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

/// A quiet line of progress while the ledger is being checked or written.
class _Busy extends ConsumerWidget {
  const _Busy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(addQazaFlowProvider);
    if (!flow.checking && !flow.saving) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            flow.saving
                ? AppLocalizations.of(context).addQazaInProgress
                : AppLocalizations.of(context).addQazaChecking,
            key: const Key('qaza_busy_label'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          const LinearProgressIndicator(
            key: Key('qaza_busy_indicator'),
            minHeight: 2,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: s.primaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(color: s.onPrimaryContainer)));
  }
}

class _Row extends StatelessWidget {
  const _Row(this.a, this.b, {this.bold = false});
  final String a, b;
  final bool bold;
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(a)),
        Text(b, style: bold ? Theme.of(c).textTheme.titleMedium : null)
      ]));
}
