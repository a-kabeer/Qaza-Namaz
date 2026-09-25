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
    final witrAllowed = ref.watch(effectiveWitrProvider);
    final selectable = <PrayerType>[
      for (final prayer in PrayerType.values)
        if ((prayer != PrayerType.witr || witrAllowed) &&
            (flow.prayerAvailability[prayer] ?? true))
          prayer,
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
          if (prayer != PrayerType.witr || witrAllowed)
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