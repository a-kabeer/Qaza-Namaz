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
import 'prayer_settings_page.dart';
import 'restricted_times_status.dart';

class PrayerTimePage extends ConsumerStatefulWidget {
  const PrayerTimePage({super.key});

  @override
  ConsumerState<PrayerTimePage> createState() => _PrayerTimePageState();
}

class _PrayerTimePageState extends ConsumerState<PrayerTimePage>
    with WidgetsBindingObserver {
  bool _resumeCurrentLocationAfterSettings = false;
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
    if (_resumeCurrentLocationAfterSettings) {
      _resumeCurrentLocationAfterSettings = false;
      Future<void>.microtask(
        () => ref
            .read(prayerTimeControllerProvider.notifier)
            .useCurrentLocation(),
      );
    } else {
      ref.read(prayerTimeControllerProvider.notifier).refresh();
    }
  }

  void _openAppSettings() {
    _resumeCurrentLocationAfterSettings = true;
    ref
        .read(prayerLocationRepositoryProvider)
        .openAppSettings()
        .then((opened) {
      if (!opened && mounted) {
        _resumeCurrentLocationAfterSettings = false;
      }
    });
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
    return snapshot.settings.use24HourFormat
        ? intl.DateFormat.Hm(locale).format(local)
        : intl.DateFormat.jm(locale).format(local);
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
    final countdownPrayer = currentPrayer ?? nextPrayer;
    final activeRestriction = restricted?.active;
    final restrictedPrayer = _restrictionRow(activeRestriction?.type);

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
          const SizedBox(height: 8),
          for (final prayer in PrayerSlot.values) ...[
            _PrayerTimeRow(
              name: _prayerLabel(l10n, prayer),
              time: _formatTime(
                context,
                contentSchedule.utcFor(prayer),
                snapshot,
              ),
              active: prayer == currentPrayer || prayer == restrictedPrayer,
              countdown: prayer == countdownPrayer && nextRemaining != null
                  ? DateFormatters.formatDurationHhMmSs(nextRemaining)
                  : null,
            ),
            if (prayer != PrayerSlot.values.last)
              const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const RestrictedTimesStatusCard(showUpcomingWhenInactive: true),
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
    this.countdown,
  });

  final String name;
  final String time;
  final bool active;
  final String? countdown;

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
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.onPrimaryContainer : null,
                  ),
            ),
            if (countdown != null)
              Text(
                countdown!,
                key: const Key('prayer_time_countdown'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: active ? scheme.onPrimaryContainer : null,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
