import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/prayer_visuals.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../application/qibla_providers.dart';
import '../domain/prayer_location.dart';
import '../domain/prayer_time.dart';
import '../domain/restricted_time.dart';
import 'location_selector.dart';
import 'prayer_timeline_row.dart';
import 'qibla_screen.dart';
import 'qibla_summary_card.dart';

class PrayerTimePage extends ConsumerStatefulWidget {
  const PrayerTimePage({super.key});

  @override
  ConsumerState<PrayerTimePage> createState() => _PrayerTimePageState();
}

class _PrayerTimePageState extends ConsumerState<PrayerTimePage> {
  void _openAppSettings() {
    ref.read(prayerLocationRepositoryProvider).openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncSnapshot = ref.watch(prayerTimeControllerProvider);
    final snapshot = asyncSnapshot.valueOrNull;

    return AppScaffold(
      title: l10n.prayerTimeTitle,
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.schedule_rounded,
                  size: 32,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.prayerTimeSetupTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.prayerTimeSetupBody,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        LocationSelector(location: asyncState.valueOrNull?.location),
        if (failure != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('prayer_time_setup_failure'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.error.withValues(alpha: .2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        failure.message,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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

  IconData _prayerIcon(PrayerSlot prayer) =>
      prayer.qazaPrayerType?.icon ?? Icons.wb_twilight_rounded;

  IconData _restrictedIcon(RestrictedTimeType type) =>
      switch (type) {
        RestrictedTimeType.sunrise => Icons.wb_twilight_rounded,
        RestrictedTimeType.zawal => Icons.wb_sunny_outlined,
        RestrictedTimeType.sunset => Icons.nights_stay_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(prayerTimeControllerProvider).valueOrNull;
    final now = ref.watch(prayerTimeClockProvider).valueOrNull;
    final current = ref.watch(currentPrayerStateProvider);
    final restricted = ref.watch(restrictedTimeStateProvider);
    final refreshing = ref.watch(prayerTimeRefreshProvider);
    final qiblaBearing = ref.watch(qiblaBearingProvider);
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

      timeline.add(
        _PrayerTimelineItem(
          at: prayerTimeUtc,
          name: _prayerLabel(l10n, prayer),
          time: _formatTime(context, prayerTimeUtc, snapshot),
          icon: _prayerIcon(prayer),
          active: active,
          countdown: null,
          isRestricted: false,
          prayer: prayer,
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
          icon: _restrictedIcon(activeRestriction.type),
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

    String? focusName;
    String? focusTime;
    IconData? focusIcon;
    String? focusCountdown;

    if (activeRestriction != null && restrictedRemaining != null) {
      focusName = _restrictedLabel(l10n, activeRestriction.type);
      focusTime = _formatTime(
        context,
        activeRestriction.displayAt.toUtc(),
        snapshot,
      );
      focusIcon = _restrictedIcon(activeRestriction.type);
      focusCountdown =
          DateFormatters.formatDurationHhMmSs(restrictedRemaining);
    } else if (countdownPrayer != null) {
      for (final item in timeline) {
        if (!item.isRestricted && item.prayer == countdownPrayer) {
          focusName = item.name;
          focusTime = item.time;
          focusIcon = item.icon;
          focusCountdown = nextRemaining == null
              ? null
              : DateFormatters.formatDurationHhMmSs(nextRemaining);
          break;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(prayerTimeControllerProvider.notifier).refreshSchedule(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PrayerTimeHeader(
            location: snapshot.location,
            date: displayDate,
            hijri: l10n.formatHijriDate(displayDate),
            refreshing: refreshing,
            onUseCurrentLocation: refreshing
                ? null
                : () => ref
                    .read(prayerTimeControllerProvider.notifier)
                    .useCurrentLocation(),
          ),
          if (focusName != null &&
              focusTime != null &&
              focusIcon != null &&
              focusCountdown != null) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PrayerTimeFocusCard(
                      name: focusName,
                      time: focusTime,
                      icon: focusIcon,
                      countdown: focusCountdown,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QiblaSummaryCard(
                      bearing: qiblaBearing,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QiblaDirectionScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _PrayerSchedule(
            items: timeline,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${l10n.prayerTimeUpdated}: ${_formatTime(context, snapshot.updatedAt, snapshot)}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimeHeader extends StatelessWidget {
  const _PrayerTimeHeader({
    required this.location,
    required this.date,
    required this.hijri,
    required this.refreshing,
    required this.onUseCurrentLocation,
  });

  final PrayerLocation location;
  final DateTime date;
  final String hijri;
  final bool refreshing;
  final VoidCallback? onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconButton = IconButton(
      key: const Key('prayer_time_use_current_location'),
      tooltip: AppLocalizations.of(context).prayerTimeUseCurrentLocation,
      onPressed: onUseCurrentLocation,
      icon: refreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location_outlined),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LocationSelector(
                  location: location,
                  style: LocationSelectorStyle.header,
                ),
              ),
              iconButton,
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context).formatFullDate(date),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hijri,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerTimeFocusCard extends StatelessWidget {
  const _PrayerTimeFocusCard({
    required this.name,
    required this.time,
    required this.icon,
    required this.countdown,
  });

  final String name;
  final String time;
  final IconData icon;
  final String countdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('prayer_time_focus_card'),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: .16),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              countdown,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: AppTheme.numericLarge.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context).homeRemaining,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerSchedule extends StatelessWidget {
  const _PrayerSchedule({
    required this.items,
  });

  final List<_PrayerTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('prayer_time_schedule'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            PrayerTimelineRow(
              key: Key('prayer_timeline_row_$i'),
              name: items[i].name,
              time: items[i].time,
              active: items[i].active,
              icon: items[i].icon,
              restricted: items[i].isRestricted,
              variant: PrayerTimelineRowVariant.cohesive,
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 52),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant,
                ),
              ),
          ],
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
    required this.icon,
    required this.active,
    required this.countdown,
    required this.isRestricted,
    this.prayer,
  });

  final DateTime at;
  final String name;
  final String time;
  final IconData icon;
  final bool active;
  final String? countdown;
  final bool isRestricted;
  final PrayerSlot? prayer;
}
