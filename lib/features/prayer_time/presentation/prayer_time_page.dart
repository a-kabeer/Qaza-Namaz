import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/prayer_location.dart';
import '../domain/prayer_time.dart';
import '../domain/restricted_time.dart';
import 'location_selector.dart';
import 'prayer_timeline_row.dart';

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
    if (state != AppLifecycleState.resumed) return;

    ref.invalidate(prayerLocationRequirementProvider);
  }

  void _openAppSettings() {
    ref.read(prayerLocationRepositoryProvider).openAppSettings();
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
        if (snapshot != null)
          IconButton(
            key: const Key('prayer_time_use_current_location'),
            tooltip: l10n.prayerTimeUseCurrentLocation,
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
            ? _PrayerTimeSetup(
                onOpenAppSettings: _openAppSettings,
              )
            : const _PrayerTimeContent(),
      ),
    );
  }
}

class _PrayerTimeSetup extends ConsumerWidget {
  const _PrayerTimeSetup({
    required this.onOpenAppSettings,
  });

  final VoidCallback onOpenAppSettings;

  _SetupFailurePresentation _failurePresentation(
    BuildContext context,
    Object error,
  ) {
    final l10n = AppLocalizations.of(context);
    if (error is PrayerLocationSetupException) {
      return switch (error.failure) {
        PrayerLocationSetupFailure.permissionDeniedForever =>
          _SetupFailurePresentation(
            message: l10n.prayerTimeLocationPermission,
            actionLabel: l10n.commonOpenSettings,
            onAction: onOpenAppSettings,
          ),
        PrayerLocationSetupFailure.permissionDenied =>
          _SetupFailurePresentation(
            message: l10n.prayerTimeLocationPermission,
            actionLabel: l10n.commonRetry,
          ),
        PrayerLocationSetupFailure.locationServiceResolutionCancelled =>
          _SetupFailurePresentation(
            message: l10n.prayerTimeLocationServiceRequired,
            actionLabel: l10n.prayerTimeEnableLocation,
          ),
      };
    }

    return _SetupFailurePresentation(
      message: l10n.errorUnknown,
      actionLabel: l10n.commonRetry,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(prayerTimeControllerProvider);
    final refreshing = ref.watch(prayerTimeRefreshProvider);
    final failure = asyncState.hasError
        ? _failurePresentation(context, asyncState.error!)
        : null;

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
        if (failure != null) ...[
          const SizedBox(height: 12),
          Card(
            key: const Key('prayer_time_setup_failure'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    failure.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('prayer_time_setup_failure_action'),
                    onPressed: refreshing
                        ? null
                        : failure.onAction ??
                            () => ref
                                .read(
                                  prayerTimeControllerProvider.notifier,
                                )
                                .useCurrentLocation(),
                    child: Text(failure.actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SetupFailurePresentation {
  const _SetupFailurePresentation({
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
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
    return intl.DateFormat.jm(locale).format(local);
  }

  String _restrictedLabel(
    AppLocalizations l10n,
    RestrictedTimeType type,
  ) =>
      switch (type) {
        RestrictedTimeType.sunrise => l10n.prayerTimeSunrise,
        RestrictedTimeType.zawal => l10n.prayerTimeZawal,
        RestrictedTimeType.sunset => l10n.prayerTimeSunset,
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
    final countdownPrayer = currentPrayer ?? nextPrayer;
    final activeRestriction = restricted?.active;
    final restrictedRemaining = activeRestriction == null
        ? null
        : restricted?.remainingAt(localNow);

    final timeline = <_PrayerTimelineItem>[];

    for (final prayer in PrayerSlot.values) {
      final prayerTimeUtc = contentSchedule.utcFor(prayer);
      final isActiveRestrictedSunrise =
          activeRestriction?.type == RestrictedTimeType.sunrise &&
          prayer == PrayerSlot.sunrise;
      final active = activeRestriction != null
          ? isActiveRestrictedSunrise
          : prayer == currentPrayer;
      final countdown = activeRestriction != null
          ? isActiveRestrictedSunrise && restrictedRemaining != null
              ? DateFormatters.formatDurationHhMmSs(restrictedRemaining)
              : null
          : prayer == countdownPrayer && nextRemaining != null
              ? DateFormatters.formatDurationHhMmSs(nextRemaining)
              : null;

      timeline.add(
        _PrayerTimelineItem(
          at: prayerTimeUtc,
          name: _prayerLabel(l10n, prayer),
          time: _formatTime(context, prayerTimeUtc, snapshot),
          active: active,
          countdown: countdown,
          isRestricted: false,
        ),
      );
    }

    if (activeRestriction != null &&
        activeRestriction.type != RestrictedTimeType.sunrise &&
        restrictedRemaining != null) {
      final displayAt = activeRestriction.displayAt;
      timeline.add(
        _PrayerTimelineItem(
          at: displayAt.toUtc(),
          name: _restrictedLabel(l10n, activeRestriction.type),
          time: _formatTime(context, displayAt.toUtc(), snapshot),
          active: true,
          countdown: DateFormatters.formatDurationHhMmSs(restrictedRemaining),
          isRestricted: true,
        ),
      );
    }

    timeline.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      if (a.isRestricted == b.isRestricted) return 0;
      return a.isRestricted ? -1 : 1;
    });

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
          for (var i = 0; i < timeline.length; i++) ...[
            PrayerTimelineRow(
              key: Key('prayer_timeline_row_$i'),
              name: timeline[i].name,
              time: timeline[i].time,
              countdown: timeline[i].countdown,
              active: timeline[i].active,
            ),
            if (i != timeline.length - 1) const SizedBox(height: 8),
          ],
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

class _PrayerTimelineItem {
  const _PrayerTimelineItem({
    required this.at,
    required this.name,
    required this.time,
    required this.active,
    required this.countdown,
    required this.isRestricted,
  });

  final DateTime at;
  final String name;
  final String time;
  final bool active;
  final String? countdown;
  final bool isRestricted;
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

