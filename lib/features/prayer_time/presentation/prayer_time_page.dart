import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/prayer_time.dart';
import '../domain/restricted_time.dart';
import 'location_selector.dart';
import 'prayer_settings_page.dart';

class PrayerTimePage extends ConsumerStatefulWidget {
  const PrayerTimePage({super.key});

  @override
  ConsumerState<PrayerTimePage> createState() => _PrayerTimePageState();
}

class _PrayerTimePageState extends ConsumerState<PrayerTimePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(prayerTimeControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncSnapshot = ref.watch(prayerTimeControllerProvider);
    final snapshot = asyncSnapshot.valueOrNull;
    final refreshing = ref.watch(prayerTimeRefreshProvider);

    return AppScaffold(
      title: l10n.prayerTimeTitle,
      actions: [
        IconButton(
          key: const Key('prayer_time_settings'),
          tooltip: l10n.prayerTimeSettings,
          onPressed: snapshot == null
              ? null
              : () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrayerSettingsPage(),
                    ),
                  ),
          icon: const Icon(Icons.settings_outlined),
        ),
        if (snapshot != null)
          IconButton(
            key: const Key('prayer_time_refresh'),
            tooltip: l10n.prayerTimeRefresh,
            onPressed: refreshing
                ? null
                : () => ref
                    .read(prayerTimeControllerProvider.notifier)
                    .useCurrentLocation(),
            icon: const Icon(Icons.my_location_outlined),
          ),
      ],
      body: SafeArea(
        child: snapshot == null
            ? const _PrayerTimeSetup()
            : const _PrayerTimeContent(),
      ),
    );
  }
}

class _PrayerTimeSetup extends ConsumerWidget {
  const _PrayerTimeSetup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(prayerTimeControllerProvider);
    final refreshing = ref.watch(prayerTimeRefreshProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        Icon(
          Icons.schedule_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.prayerTimeSetupTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.prayerTimeSetupBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('prayer_time_use_current_location'),
          onPressed: refreshing
              ? null
              : () => ref
                  .read(prayerTimeControllerProvider.notifier)
                  .useCurrentLocation(),
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
          label: Text(l10n.prayerTimeUseCurrentLocation),
        ),
        const SizedBox(height: 8),
        LocationSelector(location: asyncState.valueOrNull?.location),
        if (asyncState.hasError) ...[
          const SizedBox(height: 12),
          Text(
            l10n.prayerTimeLocationUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _PrayerTimeContent extends ConsumerWidget {
  const _PrayerTimeContent();

  String _formatTime(
    BuildContext context,
    DateTime utc,
    PrayerTimeSnapshot snapshot,
  ) {
    final location = tz.getLocation(snapshot.location.timezoneId);
    final local = tz.TZDateTime.from(utc, location);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return snapshot.settings.use24HourFormat
        ? intl.DateFormat.Hm(locale).format(local)
        : intl.DateFormat.jm(locale).format(local);
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0s';
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes}m ${seconds % 60}s';
    }
    return '${duration.inHours}h ${minutes % 60}m';
  }

  PrayerSlot? _restrictionRow(RestrictedTimeType? type) => switch (type) {
        null => null,
        RestrictedTimeType.sunrise => PrayerSlot.sunrise,
        RestrictedTimeType.zawal => null,
        RestrictedTimeType.sunset => PrayerSlot.maghrib,
      };

  String _prayerLabel(AppLocalizations l10n, PrayerSlot prayer) =>
      switch (prayer) {
        PrayerSlot.fajr => l10n.prayerTimeFajr,
        PrayerSlot.sunrise => l10n.prayerTimeSunrise,
        PrayerSlot.dhuhr => l10n.prayerTimeDhuhr,
        PrayerSlot.asr => l10n.prayerTimeAsr,
        PrayerSlot.maghrib => l10n.prayerTimeMaghrib,
        PrayerSlot.isha => l10n.prayerTimeIsha,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
    final now = ref.watch(prayerTimeClockProvider).valueOrNull;
    final current = ref.watch(currentPrayerStateProvider);
    final restricted = ref.watch(restrictedTimeStateProvider);
    if (snapshot == null || now == null) return const SizedBox.shrink();

    final location = tz.getLocation(snapshot.location.timezoneId);
    final localNow = tz.TZDateTime.from(now, location);
    final displayDate = DateTime(localNow.year, localNow.month, localNow.day);
    final contentSchedule =
        snapshot.today.date == displayDate ? snapshot.today : snapshot.tomorrow;

    if (contentSchedule.date != displayDate) {
      Future.microtask(
        () => ref
            .read(prayerTimeControllerProvider.notifier)
            .refreshForDateIfNeeded(displayDate),
      );
    }

    final currentPrayer = current?.current;
    final nextPrayer = current?.next;
    final nextAt = current?.nextAt;
    final nextRemaining = nextAt?.difference(localNow);
    final activeRestriction = restricted?.active;
    final restrictedPrayer =
        _restrictionRow(activeRestriction?.type);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(prayerTimeControllerProvider.notifier).refreshSchedule(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          LocationSelector(location: snapshot.location),
          const SizedBox(height: 12),
          _DateHeader(
            date: displayDate,
            hijri: l10n.formatHijriDate(displayDate),
          ),
          const SizedBox(height: 12),
          if (currentPrayer != null)
            _CurrentPrayerCard(
              prayerName: _prayerLabel(l10n, currentPrayer),
              nextName:
                  nextPrayer == null ? null : _prayerLabel(l10n, nextPrayer),
              nextTime:
                  nextAt == null ? null : _formatTime(context, nextAt, snapshot),
              nextRemaining:
                  nextRemaining == null ? null : _formatDuration(nextRemaining),
            )
          else if (nextPrayer != null && nextAt != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(_prayerLabel(l10n, nextPrayer)),
                subtitle: Text(_formatTime(context, nextAt, snapshot)),
                trailing: Text(
                  nextRemaining == null
                      ? ''
                      : _formatDuration(nextRemaining),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final prayer in PrayerSlot.values)
            _PrayerTimeRow(
              name: _prayerLabel(l10n, prayer),
              time: _formatTime(
                context,
                contentSchedule.utcFor(prayer),
                snapshot,
              ),
              active: prayer == currentPrayer || prayer == restrictedPrayer,
              activeLabel: l10n.prayerTimeActive,
            ),
          const SizedBox(height: 12),
          _RestrictedTimesCard(
            state: restricted,
            formatDuration: _formatDuration,
            location: location,
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.prayerTimeUpdated}: '
            '${_formatTime(context, snapshot.updatedAt, snapshot)}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CurrentPrayerCard extends StatelessWidget {
  const _CurrentPrayerCard({
    required this.prayerName,
    required this.nextName,
    required this.nextTime,
    required this.nextRemaining,
  });

  final String prayerName;
  final String? nextName;
  final String? nextTime;
  final String? nextRemaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.access_time_filled_rounded,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayerName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                  if (nextName != null && nextTime != null)
                    Text(
                      '${nextName!} · ${nextTime!}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                ],
              ),
            ),
            if (nextRemaining != null)
              Text(
                nextRemaining!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.hijri});

  final DateTime date;
  final String hijri;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            MaterialLocalizations.of(context).formatFullDate(date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Text(
          hijri,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.name,
    required this.time,
    required this.active,
    required this.activeLabel,
  });

  final String name;
  final String time;
  final bool active;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: active ? scheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(
          active
              ? Icons.radio_button_checked_rounded
              : Icons.schedule_outlined,
          color: active ? scheme.onPrimaryContainer : null,
        ),
        title: Text(
          name,
          style: active
              ? Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  )
              : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Chip(
                  label: Text(activeLabel),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ),
            Text(
              time,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.onPrimaryContainer : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictedTimesCard extends StatelessWidget {
  const _RestrictedTimesCard({
    required this.state,
    required this.formatDuration,
    required this.location,
  });

  final RestrictedTimeState? state;
  final String Function(Duration) formatDuration;
  final tz.Location location;

  String _label(AppLocalizations l10n, RestrictedTimeType type) =>
      switch (type) {
        RestrictedTimeType.sunrise => l10n.prayerTimeSunrise,
        RestrictedTimeType.zawal => l10n.prayerTimeZawal,
        RestrictedTimeType.sunset => l10n.prayerTimeSunset,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = state?.active;
    final next = state?.next;
    final scheme = Theme.of(context).colorScheme;
    if (active == null && next == null) return const SizedBox.shrink();

    final isActive = active != null;
    final window = active ?? next!;
    final now = tz.TZDateTime.now(location);
    final remaining = isActive
        ? window.endsAt.difference(now)
        : window.startsAt.difference(now);

    return Card(
      color: isActive
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.lock_clock_rounded,
              color: isActive
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.prayerTimeRestrictedTimes,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _label(l10n, window.type),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? scheme.onSecondaryContainer
                                  : null,
                            ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(l10n.prayerTimeActive),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? l10n.prayerTimeEndsIn(formatDuration(remaining))
                        : l10n.prayerTimeStartsIn(formatDuration(remaining)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isActive
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
