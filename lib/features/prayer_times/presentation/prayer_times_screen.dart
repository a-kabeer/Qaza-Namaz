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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (state.status == PrayerTimesStatus.refreshing) ...[
          _InfoBanner(
            icon: Icons.sync_rounded,
            text: PrayerTimesStrings.refreshing(context),
          ),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(
            children: [
              Text(
                day.hijriDate.display,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                MaterialLocalizations.of(context).formatFullDate(day.date),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                schedule.current == null
                    ? PrayerTimesStrings.nextPrayer(context)
                    : PrayerTimesStrings.currentPrayer(context),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 5),
              Text(
                schedule.current != null
                    ? PrayerTimesStrings.prayerName(
                        context,
                        schedule.current!,
                      )
                    : '—',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (schedule.next != null) ...[
                const SizedBox(height: 3),
                Text(
                  PrayerTimesStrings.nextPrayer(context) +
                      ': ' +
                      PrayerTimesStrings.prayerName(context, schedule.next!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (countdown != null) ...[
                const SizedBox(height: 8),
                Text(
                  PrayerTimesStrings.countdown(countdown),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              Icons.location_on_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              state.location!.displayName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              state.settings.asrMethod == AsrMethod.hanafi
                  ? PrayerTimesStrings.hanafi(context)
                  : PrayerTimesStrings.standard(context),
            ),
            trailing: TextButton.icon(
              onPressed: onEditLocation,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(PrayerTimesStrings.editLocation(context)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          PrayerTimesStrings.prayerTimes(context),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final prayer
                  in PrayerName.values.where((item) => item.isCyclePrayer))
                _PrayerTimeRow(
                  prayer: prayer,
                  time: PrayerSchedule.moment(day, prayer),
                  isCurrent: schedule.current == prayer,
                  reminderEnabled:
                      state.notificationSettings.enabledPrayers.contains(
                    prayer,
                  ),
                  onReminderChanged: (enabled) => _togglePrayerReminder(
                    context,
                    ref,
                    prayer,
                    enabled,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                PrayerTimesStrings.restrictedTimes(context),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (activeRestriction != null)
              _StatusPill(
                text: PrayerTimesStrings.restrictedNow(context),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < periods.length; index++)
                _RestrictedTimeRow(
                  period: periods[index],
                  isActive: periods[index] == activeRestriction,
                  now: schedule.now,
                  isLast: index == periods.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(PrayerTimesStrings.restrictedNotifications(context)),
            subtitle: Text(
              state.notificationSettings.anyRestrictedReminder
                  ? PrayerTimesStrings.notifications(context) + ': ON'
                  : PrayerTimesStrings.notifications(context) + ': OFF',
            ),
            children: [
              SwitchListTile(
                title: Text(
                  PrayerTimesStrings.restrictionType(
                    context,
                    RestrictionType.sunrise,
                  ),
                ),
                value: state.notificationSettings.sunrise,
                onChanged: (value) => _toggleRestrictionReminder(
                  context,
                  ref,
                  RestrictionType.sunrise,
                  value,
                ),
              ),
              SwitchListTile(
                title: Text(
                  PrayerTimesStrings.restrictionType(
                    context,
                    RestrictionType.zawal,
                  ),
                ),
                value: state.notificationSettings.zawal,
                onChanged: (value) => _toggleRestrictionReminder(
                  context,
                  ref,
                  RestrictionType.zawal,
                  value,
                ),
              ),
              SwitchListTile(
                title: Text(
                  PrayerTimesStrings.restrictionType(
                    context,
                    RestrictionType.sunset,
                  ),
                ),
                value: state.notificationSettings.sunset,
                onChanged: (value) => _toggleRestrictionReminder(
                  context,
                  ref,
                  RestrictionType.sunset,
                  value,
                ),
              ),
              ListTile(
                title: Text(PrayerTimesStrings.notifyBefore(context)),
                subtitle: Text(
                  switch (
                      state.notificationSettings.restrictedLeadMinutes) {
                    0 => PrayerTimesStrings.atStart(context),
                    5 => PrayerTimesStrings.fiveMinutes(context),
                    _ => PrayerTimesStrings.tenMinutes(context),
                  },
                ),
                trailing: DropdownButton<int>(
                  value: state.notificationSettings.restrictedLeadMinutes,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem<int>(
                      value: 0,
                      child: Text(PrayerTimesStrings.atStart(context)),
                    ),
                    DropdownMenuItem<int>(
                      value: 5,
                      child: Text(PrayerTimesStrings.fiveMinutes(context)),
                    ),
                    DropdownMenuItem<int>(
                      value: 10,
                      child: Text(PrayerTimesStrings.tenMinutes(context)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    unawaited(
                      ref
                          .read(
                            prayerTimesControllerProvider.notifier,
                          )
                          .setRestrictedLeadMinutes(value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.prayer,
    required this.time,
    required this.isCurrent,
    required this.reminderEnabled,
    required this.onReminderChanged,
  });

  final PrayerName prayer;
  final tz.TZDateTime time;
  final bool isCurrent;
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? scheme.secondaryContainer : null,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            _icon(prayer),
            size: 22,
            color: isCurrent
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              PrayerTimesStrings.prayerName(context, prayer),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            DateFormat.jm().format(time),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: PrayerTimesStrings.notifications(context),
            onPressed: () => onReminderChanged(!reminderEnabled),
            icon: Icon(
              reminderEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
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
  });

  final QazaRestrictionPeriod period;
  final bool isActive;
  final DateTime now;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final duration = period.end.difference(period.start).inMinutes;
    final remaining = period.end.difference(now).inMinutes.clamp(0, 9999);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? scheme.tertiaryContainer : null,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant,
                ),
              ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Icon(
            switch (period.type) {
              RestrictionType.sunrise => Icons.wb_twilight_rounded,
              RestrictionType.zawal => Icons.wb_sunny_outlined,
              RestrictionType.sunset => Icons.wb_twilight,
              RestrictionType.otherConfiguredRestriction => Icons.schedule,
            },
            size: 22,
            color: isActive
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PrayerTimesStrings.restrictionType(context, period.type),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  PrayerTimesStrings.timeWindow(
                    context,
                    DateFormat.jm().format(period.start),
                    DateFormat.jm().format(period.end),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PrayerTimesStrings.restrictedFor(context, duration),
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.end,
              ),
              if (isActive) ...[
                const SizedBox(height: 3),
                Text(
                  PrayerTimesStrings.restrictionRemaining(
                    context,
                    Duration(minutes: remaining),
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.end,
                ),
              ],
            ],
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
  late CalculationMethod _calculationMethod;
  final TextEditingController _citySearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.state.location?.source == LocationSource.device
        ? _EditLocationMode.current
        : _EditLocationMode.city;
    _asrMethod = widget.state.settings.asrMethod;
    _calculationMethod = widget.state.settings.calculationMethod;
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

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PrayerTimesStrings.editLocation(context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            SegmentedButton<_EditLocationMode>(
              segments: [
                ButtonSegment<_EditLocationMode>(
                  value: _EditLocationMode.current,
                  label: Text(PrayerTimesStrings.currentLocation(context)),
                  icon: const Icon(Icons.my_location_rounded),
                ),
                ButtonSegment<_EditLocationMode>(
                  value: _EditLocationMode.city,
                  label: Text(
                    PrayerTimesStrings.selectCountryAndCity(context),
                  ),
                  icon: const Icon(Icons.location_city_outlined),
                ),
              ],
              selected: <_EditLocationMode>{_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.single;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_mode == _EditLocationMode.city) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_rounded),
                title: Text(
                  _country?.name ??
                      PrayerTimesStrings.selectCountry(context),
                ),
                subtitle: Text(PrayerTimesStrings.selectCountry(context)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickCountry,
              ),
              TextField(
                controller: _citySearchController,
                enabled: _country != null,
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
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _citySearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _citySearchController.clear();
                            ref
                                .read(
                                  prayerTimesControllerProvider.notifier,
                                )
                                .searchCities('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              if (state.citySearchLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_selectedCity != null) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: PrayerTimesStrings.selectCity(context),
                  ),
                  child: Text(_selectedCity!.name),
                ),
              ],
              if (state.cityResults.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final result in state.cityResults)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(result.name),
                    subtitle: Text(
                      [
                        if (result.region != null && result.region!.isNotEmpty)
                          result.region!,
                        result.country,
                      ].join(', '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      setState(() {
                        _selectedCity = result;
                        _citySearchController.text = result.name;
                      });
                      FocusScope.of(context).unfocus();
                      ref
                          .read(prayerTimesControllerProvider.notifier)
                          .searchCities('');
                    },
                  ),
              ],
            ],
            const SizedBox(height: 18),
            Text(
              PrayerTimesStrings.asrMethod(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
                setState(() {
                  _asrMethod = selection.single;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calculate_outlined),
              title: Text(PrayerTimesStrings.calculationMethod(context)),
              subtitle: Text(
                _calculationMethod == CalculationMethod.recommended
                    ? PrayerTimesStrings.recommended(context)
                    : PrayerTimesStrings.methodName(
                        context,
                        _calculationMethod,
                      ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickCalculationMethod,
            ),
            const SizedBox(height: 12),
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
    ref.read(prayerTimesControllerProvider.notifier).searchCities('');
  }

  Future<void> _pickCalculationMethod() async {
    final selected = await showModalBottomSheet<CalculationMethod>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                PrayerTimesStrings.calculationMethod(context),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final method in CalculationMethod.values)
                ListTile(
                  title: Text(
                    PrayerTimesStrings.methodOption(context, method),
                  ),
                  trailing: method == _calculationMethod
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, method),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _calculationMethod = selected);
  }

  Future<void> _save() async {
    final controller = ref.read(prayerTimesControllerProvider.notifier);
    final previousSettings = controller.state.settings;
    final nextSettings = previousSettings.copyWith(
      asrMethod: _asrMethod,
      calculationMethod: _calculationMethod,
    );

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

    if (nextSettings.asrMethod != previousSettings.asrMethod ||
        nextSettings.calculationMethod != previousSettings.calculationMethod) {
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
