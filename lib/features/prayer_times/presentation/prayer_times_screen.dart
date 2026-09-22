import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/location/city_search_provider.dart';
import '../data/location/prayer_location_service.dart';
import '../domain/prayer_schedule.dart';
import '../domain/prayer_times_models.dart';
import '../domain/qaza_restriction_service.dart';
import '../prayer_times_providers.dart';
import 'prayer_location_picker_screen.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_localizations.dart';

enum _EditLocationMode {
  current,
  city,
}

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (timer.tick % 30 == 0) {
        unawaited(
          ref.read(prayerTimesControllerProvider.notifier).tick(),
        );
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openLocationEditor() {
    final state = ref.read(prayerTimesControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PrayerLocationEditSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesControllerProvider);
    return AppScaffold(
      title: PrayerTimesStrings.title(context),
      actions: [
        if (state.hasData)
          IconButton(
            tooltip: PrayerTimesStrings.refresh(context),
            onPressed: state.status == PrayerTimesStatus.refreshing
                ? null
                : () => ref
                    .read(prayerTimesControllerProvider.notifier)
                    .refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, PrayerTimesState state) {
    if (state.hasData) {
      return _PrayerTimesContent(
        state: state,
        onEditLocation: _openLocationEditor,
      );
    }

    switch (state.status) {
      case PrayerTimesStatus.noLocation:
        return _NoLocationState(
          onUseLocation: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .useMyLocation(),
          onChooseManually: _openLocationEditor,
        );
      case PrayerTimesStatus.locating:
      case PrayerTimesStatus.loading:
        return const _PrayerTimesLoadingSkeleton();
      case PrayerTimesStatus.calculationError:
        return _PrayerErrorState(
          message:
              state.message ?? PrayerTimesStrings.calculationError(context),
          onRetry: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .refresh(),
          onChooseManually: _openLocationEditor,
        );
      case PrayerTimesStatus.locationError:
        return _LocationErrorState(
          state: state,
          onRetry: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .useMyLocation(),
          onChooseManually: _openLocationEditor,
          onOpenSettings: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .openRelevantSettings(),
        );
      case PrayerTimesStatus.loaded:
      case PrayerTimesStatus.refreshing:
        return const _PrayerTimesLoadingSkeleton();
    }
  }
}

class _PrayerTimesContent extends ConsumerWidget {
  const _PrayerTimesContent({
    required this.state,
    required this.onEditLocation,
  });

  final PrayerTimesState state;
  final VoidCallback onEditLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = state.today!;
    final schedule = PrayerSchedule.evaluate(
      today: day,
      tomorrow: state.tomorrow,
    );
    final countdown = PrayerSchedule.timeUntilNext(
      today: day,
      tomorrow: state.tomorrow,
    );
    final restrictionService = ref.read(qazaRestrictionServiceProvider);
    final periods = restrictionService.periodsForDay(day);
    final activeRestriction = _activeRestriction(periods, schedule.now);
    final prayers =
        PrayerName.values.where((item) => item.isCyclePrayer).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          if (state.status == PrayerTimesStatus.refreshing) ...[
            _InfoBanner(
              icon: Icons.sync_rounded,
              text: PrayerTimesStrings.refreshing(context),
            ),
            const SizedBox(height: 6),
          ],
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onEditLocation,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.location!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onEditLocation,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(PrayerTimesStrings.editLocation(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MaterialLocalizations.of(context).formatShortDate(
                            day.date,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          day.hijriDate.display,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (schedule.next != null) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PrayerTimesStrings.nextPrayer(context),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          '${PrayerTimesStrings.prayerName(context, schedule.next!)} • '
                          '${DateFormat.jm().format(PrayerSchedule.moment(day, schedule.next!))}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (countdown != null)
                          Text(
                            PrayerTimesStrings.countdown(countdown),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: _CompactSectionCard(
                    title: PrayerTimesStrings.prayerTimes(context),
                    child: Column(
                      children: [
                        for (var index = 0; index < prayers.length; index++)
                          Expanded(
                            child: _PrayerTimeRow(
                              prayer: prayers[index],
                              time: PrayerSchedule.moment(day, prayers[index]),
                              isCurrent: schedule.current == prayers[index],
                              reminderEnabled: state
                                  .notificationSettings.enabledPrayers
                                  .contains(prayers[index]),
                              onReminderChanged: (enabled) =>
                                  _togglePrayerReminder(
                                context,
                                ref,
                                prayers[index],
                                enabled,
                              ),
                              isLast: index == prayers.length - 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  flex: 3,
                  child: _CompactSectionCard(
                    title: PrayerTimesStrings.restrictedTimes(context),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeRestriction != null)
                          _StatusPill(
                            text: PrayerTimesStrings.restrictedNow(context),
                          ),
                        PopupMenuButton<int>(
                          tooltip: PrayerTimesStrings.notifyBefore(context),
                          icon: const Icon(Icons.more_horiz_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context) => [
                            PopupMenuItem<int>(
                              value: 0,
                              child: Text(PrayerTimesStrings.atStart(context)),
                            ),
                            PopupMenuItem<int>(
                              value: 5,
                              child:
                                  Text(PrayerTimesStrings.fiveMinutes(context)),
                            ),
                            PopupMenuItem<int>(
                              value: 10,
                              child:
                                  Text(PrayerTimesStrings.tenMinutes(context)),
                            ),
                          ],
                          onSelected: (value) => unawaited(
                            ref
                                .read(prayerTimesControllerProvider.notifier)
                                .setRestrictedLeadMinutes(value),
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < periods.length; index++)
                          Expanded(
                            child: _RestrictedTimeRow(
                              period: periods[index],
                              isActive: periods[index] == activeRestriction,
                              now: schedule.now,
                              isLast: index == periods.length - 1,
                              reminderEnabled: _restrictionEnabled(
                                state.notificationSettings,
                                periods[index].type,
                              ),
                              onReminderChanged: (enabled) =>
                                  _toggleRestrictionReminder(
                                context,
                                ref,
                                periods[index].type,
                                enabled,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _restrictionEnabled(
    PrayerNotificationSettings settings,
    RestrictionType type,
  ) {
    return switch (type) {
      RestrictionType.sunrise => settings.sunrise,
      RestrictionType.zawal => settings.zawal,
      RestrictionType.sunset => settings.sunset,
      RestrictionType.otherConfiguredRestriction => false,
    };
  }

  QazaRestrictionPeriod? _activeRestriction(
    List<QazaRestrictionPeriod> periods,
    DateTime now,
  ) {
    for (final period in periods) {
      if (period.contains(now)) return period;
    }
    return null;
  }

  Future<void> _togglePrayerReminder(
    BuildContext context,
    WidgetRef ref,
    PrayerName prayer,
    bool enabled,
  ) async {
    final granted = await ref
        .read(prayerTimesControllerProvider.notifier)
        .setPrayerNotification(prayer, enabled);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              PrayerTimesStrings.notificationPermissionDenied(context),
            ),
          ),
        );
    }
  }

  Future<void> _toggleRestrictionReminder(
    BuildContext context,
    WidgetRef ref,
    RestrictionType type,
    bool enabled,
  ) async {
    final granted = await ref
        .read(prayerTimesControllerProvider.notifier)
        .setRestrictedNotification(type, enabled);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              PrayerTimesStrings.notificationPermissionDenied(context),
            ),
          ),
        );
    }
  }
}

class _CompactSectionCard extends StatelessWidget {
  const _CompactSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 6, 1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.prayer,
    required this.time,
    required this.isCurrent,
    required this.reminderEnabled,
    required this.onReminderChanged,
    required this.isLast,
  });

  final PrayerName prayer;
  final tz.TZDateTime time;
  final bool isCurrent;
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? scheme.secondaryContainer : null,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          Icon(
            _icon(prayer),
            size: 19,
            color: isCurrent
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PrayerTimesStrings.prayerName(context, prayer),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            DateFormat.jm().format(time),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
          IconButton(
            tooltip: PrayerTimesStrings.notifications(context),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            onPressed: () => onReminderChanged(!reminderEnabled),
            icon: Icon(
              reminderEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(PrayerName prayer) => switch (prayer) {
        PrayerName.fajr => Icons.nightlight_outlined,
        PrayerName.sunrise => Icons.wb_twilight_rounded,
        PrayerName.dhuhr => Icons.wb_sunny_outlined,
        PrayerName.asr => Icons.wb_sunny_outlined,
        PrayerName.maghrib => Icons.wb_twilight,
        PrayerName.isha => Icons.dark_mode_outlined,
      };
}

class _RestrictedTimeRow extends StatelessWidget {
  const _RestrictedTimeRow({
    required this.period,
    required this.isActive,
    required this.now,
    required this.isLast,
    required this.reminderEnabled,
    required this.onReminderChanged,
  });

  final QazaRestrictionPeriod period;
  final bool isActive;
  final DateTime now;
  final bool isLast;
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final remaining = period.end.difference(now).inMinutes.clamp(0, 9999);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? scheme.tertiaryContainer : null,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          Icon(
            switch (period.type) {
              RestrictionType.sunrise => Icons.wb_twilight_rounded,
              RestrictionType.zawal => Icons.wb_sunny_outlined,
              RestrictionType.sunset => Icons.wb_twilight,
              RestrictionType.otherConfiguredRestriction => Icons.schedule,
            },
            size: 19,
            color: isActive
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PrayerTimesStrings.restrictionType(context, period.type),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            PrayerTimesStrings.timeWindow(
              context,
              DateFormat.jm().format(period.start),
              DateFormat.jm().format(period.end),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (isActive && remaining > 0)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(
                '${remaining}m',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onTertiaryContainer,
                    ),
              ),
            ),
          IconButton(
            tooltip: PrayerTimesStrings.notifications(context),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            onPressed: () => onReminderChanged(!reminderEnabled),
            icon: Icon(
              reminderEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _PrayerLocationEditSheet extends ConsumerStatefulWidget {
  const _PrayerLocationEditSheet({
    required this.state,
  });

  final PrayerTimesState state;

  @override
  ConsumerState<_PrayerLocationEditSheet> createState() =>
      _PrayerLocationEditSheetState();
}

class _PrayerLocationEditSheetState
    extends ConsumerState<_PrayerLocationEditSheet> {
  late _EditLocationMode _mode;
  PrayerCountryOption? _country;
  CitySearchResult? _selectedCity;
  late AsrMethod _asrMethod;
  final TextEditingController _citySearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.state.location?.source == LocationSource.device
        ? _EditLocationMode.current
        : _EditLocationMode.city;
    _asrMethod = widget.state.settings.asrMethod;
    final location = widget.state.location;

    if (location?.countryCode != null && location?.country != null) {
      _country = PrayerCountryOption(
        name: location!.country!,
        iso2: location.countryCode!,
      );
    }

    if (location?.city != null &&
        location!.countryCode != null &&
        location.country != null) {
      _selectedCity = CitySearchResult(
        name: location.city!,
        country: location.country!,
        latitude: location.latitude,
        longitude: location.longitude,
        region: location.region,
        countryCode: location.countryCode,
        timezone: location.timezone,
      );
      _citySearchController.text = location.city!;
    }
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesControllerProvider);
    final canSaveCity = _selectedCity != null;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          2,
          14,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      PrayerTimesStrings.editLocation(context),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<_EditLocationMode>(
                segments: [
                  ButtonSegment<_EditLocationMode>(
                    value: _EditLocationMode.current,
                    label: Text(PrayerTimesStrings.currentLocation(context)),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                  ),
                  ButtonSegment<_EditLocationMode>(
                    value: _EditLocationMode.city,
                    label: Text(PrayerTimesStrings.city(context)),
                    icon: const Icon(Icons.location_city_outlined, size: 18),
                  ),
                ],
                selected: <_EditLocationMode>{_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.single;
                  });
                  if (_mode == _EditLocationMode.city &&
                      _country != null) {
                    ref
                        .read(prayerTimesControllerProvider.notifier)
                        .searchCities(
                          _citySearchController.text,
                          countryCode: _country!.iso2,
                        );
                  }
                },
              ),
              const SizedBox(height: 8),
              if (_mode == _EditLocationMode.current)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.my_location_rounded),
                  title: Text(PrayerTimesStrings.useMyLocation(context)),
                  subtitle: Text(
                    PrayerTimesStrings.privacyNote(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else ...[
                Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    leading: const Icon(Icons.public_rounded),
                    title: Text(
                      _country?.name ??
                          PrayerTimesStrings.selectCountry(context),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickCountry,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _citySearchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    ref
                        .read(prayerTimesControllerProvider.notifier)
                        .searchCities(
                          value,
                          countryCode: _country?.iso2,
                        );
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: PrayerTimesStrings.selectCity(context),
                    hintText: _country == null
                        ? PrayerTimesStrings.chooseCityFirst(context)
                        : PrayerTimesStrings.searchCity(context),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _citySearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _citySearchController.clear();
                              ref
                                  .read(
                                    prayerTimesControllerProvider.notifier,
                                  )
                                  .searchCities(
                                    '',
                                    countryCode: _country?.iso2,
                                  );
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded, size: 20),
                          ),
                  ),
                  enabled: _country != null,
                ),
                if (state.citySearchLoading) ...[
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_selectedCity != null &&
                    _citySearchController.text == _selectedCity!.name)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${_selectedCity!.name}, ${_selectedCity!.country}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (state.cityResults.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  for (final result in state.cityResults.take(8))
                    ListTile(
                      dense: true,
                      minVerticalPadding: 0,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(
                        Icons.location_city_outlined,
                        size: 19,
                      ),
                      title: Text(result.name),
                      subtitle: result.region == null || result.region!.isEmpty
                          ? null
                          : Text(result.region!),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCity = result;
                          _citySearchController.text = result.name;
                        });
                        FocusScope.of(context).unfocus();
                        ref
                            .read(prayerTimesControllerProvider.notifier)
                            .searchCities(
                              result.name,
                              countryCode: result.countryCode,
                            );
                      },
                    ),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                PrayerTimesStrings.asrMethod(context),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SegmentedButton<AsrMethod>(
                segments: [
                  ButtonSegment<AsrMethod>(
                    value: AsrMethod.standard,
                    label: Text(PrayerTimesStrings.standard(context)),
                  ),
                  ButtonSegment<AsrMethod>(
                    value: AsrMethod.hanafi,
                    label: Text(PrayerTimesStrings.hanafi(context)),
                  ),
                ],
                selected: <AsrMethod>{_asrMethod},
                onSelectionChanged: (selection) {
                  setState(() => _asrMethod = selection.single);
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: PrayerTimesStrings.save(context),
                icon: Icons.check_rounded,
                expand: true,
                onPressed: state.status == PrayerTimesStatus.locating ||
                        (_mode == _EditLocationMode.city && !canSaveCity)
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<PrayerCountryOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (!mounted || selected == null) return;

    setState(() {
      _country = selected;
      _selectedCity = null;
      _citySearchController.clear();
    });

    ref.read(prayerTimesControllerProvider.notifier).searchCities(
          '',
          countryCode: selected.iso2,
        );
  }

  Future<void> _save() async {
    final controller = ref.read(prayerTimesControllerProvider.notifier);
    final previousSettings = controller.state.settings;
    final nextSettings =
        previousSettings.copyWith(asrMethod: _asrMethod);

    if (_mode == _EditLocationMode.current) {
      await controller.useMyLocation();
    } else if (_selectedCity != null) {
      await controller.selectCity(_selectedCity!);
    }

    final latest = ref.read(prayerTimesControllerProvider);
    if (latest.status == PrayerTimesStatus.locationError ||
        latest.status == PrayerTimesStatus.calculationError) {
      return;
    }

    if (nextSettings.asrMethod != previousSettings.asrMethod) {
      await controller.saveSettings(nextSettings);
    }

    if (mounted) Navigator.pop(context);
  }
}

class _CountryPickerSheet extends ConsumerStatefulWidget {
  const _CountryPickerSheet();

  @override
  ConsumerState<_CountryPickerSheet> createState() =>
      _CountryPickerSheetState();
}

class _CountryPickerSheetState extends ConsumerState<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(prayerCountriesProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              PrayerTimesStrings.selectCountry(context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: PrayerTimesStrings.searchCountry(context),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: countriesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => Center(
                child: Text(PrayerTimesStrings.noResults(context)),
              ),
              data: (countries) {
                final query = _query.toLowerCase();
                final filtered = countries.where((country) {
                  return query.isEmpty ||
                      country.name.toLowerCase().contains(query) ||
                      country.iso2.toLowerCase().contains(query) ||
                      (country.nativeName?.toLowerCase().contains(query) ??
                          false);
                }).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final country = filtered[index];
                    return ListTile(
                      leading: Text(
                        country.emoji ?? '🌐',
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(country.name),
                      subtitle: country.nativeName == null
                          ? null
                          : Text(country.nativeName!),
                      onTap: () => Navigator.pop(context, country),
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _NoLocationState extends StatelessWidget {
  const _NoLocationState({
    required this.onUseLocation,
    required this.onChooseManually,
  });

  final VoidCallback onUseLocation;
  final VoidCallback onChooseManually;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              PrayerTimesStrings.locationUnavailable(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: PrayerTimesStrings.useMyLocation(context),
              icon: Icons.my_location_rounded,
              expand: true,
              onPressed: onUseLocation,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: PrayerTimesStrings.chooseManually(context),
              icon: Icons.location_searching_rounded,
              secondary: true,
              expand: true,
              onPressed: onChooseManually,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimesLoadingSkeleton extends StatelessWidget {
  const _PrayerTimesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AppCard(
          child: Column(
            children: const [
              SkeletonText(width: 180, height: 24),
              SizedBox(height: 10),
              SkeletonText(width: 210, height: 16),
              SizedBox(height: 22),
              SkeletonText(width: 100, height: 14),
              SizedBox(height: 8),
              SkeletonText(width: 120, height: 26),
              SizedBox(height: 10),
              SkeletonText(width: 110, height: 32),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: const [
              SkeletonCircle(size: 36),
              SizedBox(width: 12),
              Expanded(child: SkeletonText(width: 160, height: 18)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
              SizedBox(height: 10),
              _SkeletonRow(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SkeletonCircle(size: 22),
        SizedBox(width: 12),
        Expanded(child: SkeletonText(width: 100, height: 16)),
        SkeletonText(width: 62, height: 18),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerErrorState extends StatelessWidget {
  const _PrayerErrorState({
    required this.message,
    required this.onRetry,
    required this.onChooseManually,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onChooseManually;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              PrayerTimesStrings.calculationError(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            AppButton(
              label: PrayerTimesStrings.tryAgain(context),
              icon: Icons.refresh_rounded,
              expand: true,
              onPressed: onRetry,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: PrayerTimesStrings.chooseManually(context),
              secondary: true,
              expand: true,
              onPressed: onChooseManually,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationErrorState extends StatelessWidget {
  const _LocationErrorState({
    required this.state,
    required this.onRetry,
    required this.onChooseManually,
    required this.onOpenSettings,
  });

  final PrayerTimesState state;
  final VoidCallback onRetry;
  final VoidCallback onChooseManually;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final kind = state.locationErrorKind;
    final isPermanent =
        kind == PrayerLocationErrorKind.permissionPermanentlyDenied;
    final isServiceDisabled =
        kind == PrayerLocationErrorKind.serviceDisabled;

    final message = switch (kind) {
      PrayerLocationErrorKind.serviceDisabled =>
        PrayerTimesStrings.locationServiceDisabled(context),
      PrayerLocationErrorKind.permissionDenied =>
        PrayerTimesStrings.permissionDenied(context),
      PrayerLocationErrorKind.permissionPermanentlyDenied =>
        PrayerTimesStrings.permissionPermanentlyDenied(context),
      _ => PrayerTimesStrings.locationError(context),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            if (isPermanent || isServiceDisabled)
              AppButton(
                label: isPermanent
                    ? PrayerTimesStrings.openSettings(context)
                    : PrayerTimesStrings.location(context),
                icon: Icons.settings_outlined,
                expand: true,
                onPressed: onOpenSettings,
              )
            else
              AppButton(
                label: PrayerTimesStrings.tryAgain(context),
                icon: Icons.refresh_rounded,
                expand: true,
                onPressed: onRetry,
              ),
            const SizedBox(height: 10),
            AppButton(
              label: PrayerTimesStrings.chooseManually(context),
              secondary: true,
              expand: true,
              onPressed: onChooseManually,
            ),
          ],
        ),
      ),
    );
  }
}
