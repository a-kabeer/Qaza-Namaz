import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
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
              _Header(step.index),
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
                (flow.prayerAvailability[prayer] ?? true)
                    ? prayer.localizedRakats(l10n)
                    : l10n
                        .addQazaUnavailablePrayer(prayer.localizedRakats(l10n)),
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
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('qaza_review_button'),
          onPressed: flow.checking || prayers.isEmpty
              ? null
              : () => ref.read(addQazaFlowProvider.notifier).openReviewStep(),
          child: Text(l10n.addQazaNextPrayers),
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
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('qaza_add_button'),
          onPressed: flow.canAdd ? _add : null,
          child: Text(flow.saving ? l10n.addQazaInProgress : l10n.addQazaTitle),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  Future<void> _add() async {
    final created = await ref.read(addQazaFlowProvider.notifier).addQaza();
    if (!mounted || created <= 0) return;
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

class _Header extends StatelessWidget {
  const _Header(this.step);
  final int step;
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          for (var i = 0; i < 3; i++) ...[
            CircleAvatar(
                radius: 14,
                backgroundColor:
                    i <= step ? s.primary : s.surfaceContainerHighest,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: i <= step ? s.onPrimary : s.onSurfaceVariant))),
            if (i < 2)
              Expanded(
                  child: Container(
                      height: 2,
                      color: i < step ? s.primary : s.outlineVariant))
          ]
        ]));
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
