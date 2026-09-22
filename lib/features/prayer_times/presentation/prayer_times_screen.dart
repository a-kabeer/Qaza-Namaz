import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/location/prayer_location_service.dart';
import '../domain/prayer_schedule.dart';
import '../domain/prayer_times_models.dart';
import '../prayer_times_providers.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_localizations.dart';
import 'prayer_location_picker_screen.dart';

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

  void _openLocationPicker() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const PrayerLocationPickerScreen(),
      ),
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
    if (state.hasData &&
        (state.status == PrayerTimesStatus.loaded ||
            state.status == PrayerTimesStatus.loading ||
            state.status == PrayerTimesStatus.refreshing)) {
      return _PrayerTimesContent(
        state: state,
        onOpenLocationPicker: _openLocationPicker,
      );
    }

    switch (state.status) {
      case PrayerTimesStatus.noLocation:
        return _NoLocationState(
          onUseLocation: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .useMyLocation(),
          onChooseManually: _openLocationPicker,
        );
      case PrayerTimesStatus.locating:
        return const _PrayerTimesLoadingSkeleton();
      case PrayerTimesStatus.loading:
        return const _PrayerTimesLoadingSkeleton();
      case PrayerTimesStatus.calculationError:
        return _PrayerErrorState(
          message: state.message ?? PrayerTimesStrings.calculationError(context),
          onRetry: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .refresh(),
          onChooseManually: _openLocationPicker,
        );
      case PrayerTimesStatus.locationError:
        return _LocationErrorState(
          state: state,
          onRetry: () => ref
              .read(prayerTimesControllerProvider.notifier)
              .useMyLocation(),
          onChooseManually: _openLocationPicker,
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
    required this.onOpenLocationPicker,
  });

  final PrayerTimesState state;
  final VoidCallback onOpenLocationPicker;

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
    final method = state.settings.calculationMethod;
    final methodName = method == CalculationMethod.recommended
        ? (day.resolvedCalculationMethodName ??
            PrayerTimesStrings.recommended(context))
        : PrayerTimesStrings.methodName(context, method);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.location!.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        if (state.status == PrayerTimesStatus.refreshing) ...[
          const SizedBox(height: 10),
          _InfoBanner(
            icon: Icons.sync_rounded,
            text: PrayerTimesStrings.refreshing(context),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                MaterialLocalizations.of(context).formatFullDate(day.date),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                day.hijriDate.display,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final prayer in PrayerName.values)
                _PrayerTimeRow(
                  prayer: prayer,
                  time: day.times[prayer]!,
                  isCurrent: schedule.current == prayer,
                  isLast: prayer == PrayerName.isha,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PrayerTimesStrings.currentPrayer(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      schedule.current == null
                          ? '—'
                          : PrayerTimesStrings.prayerName(
                              context,
                              schedule.current!,
                            ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PrayerTimesStrings.nextPrayer(context),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      schedule.next == null
                          ? '—'
                          : PrayerTimesStrings.prayerName(
                              context,
                              schedule.next!,
                            ),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.end,
                    ),
                    if (countdown != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        PrayerTimesStrings.countdown(countdown),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PrayerTimesStrings.calculation(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calculate_outlined),
                title: Text(PrayerTimesStrings.calculationMethod(context)),
                subtitle: Text(methodName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCalculationMethodPicker(context, state, ref),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                PrayerTimesStrings.asrMethod(context),
                style: Theme.of(context).textTheme.labelLarge,
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
                selected: <AsrMethod>{state.settings.asrMethod},
                onSelectionChanged: (selection) {
                  unawaited(
                    ref
                        .read(prayerTimesControllerProvider.notifier)
                        .setAsrMethod(selection.single),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: PrayerTimesStrings.changeLocation(context),
          icon: Icons.location_searching_rounded,
          secondary: true,
          expand: true,
          onPressed: onOpenLocationPicker,
        ),
      ],
    );
  }

  Future<void> _showCalculationMethodPicker(
    BuildContext context,
    PrayerTimesState state,
    WidgetRef ref,
  ) async {
    final selected = await showModalBottomSheet<CalculationMethod>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
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
                  title: Text(PrayerTimesStrings.methodOption(context, method)),
                  trailing: method == state.settings.calculationMethod
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, method),
                ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || selected == null) return;
    await ref
        .read(prayerTimesControllerProvider.notifier)
        .setCalculationMethod(selected);
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.prayer,
    required this.time,
    required this.isCurrent,
    required this.isLast,
  });

  final PrayerName prayer;
  final PrayerTime time;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: isCurrent ? scheme.secondaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _icon(prayer),
                size: 20,
                color: isCurrent
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  PrayerTimesStrings.prayerName(context, prayer),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              Text(
                time.formatted,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
          if (!isLast) const Divider(height: 18),
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
        SkeletonShimmer(
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                const SkeletonCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 18,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: const [
              SkeletonText(width: 180, height: 18),
              SizedBox(height: 10),
              SkeletonText(width: 140, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              for (var index = 0; index < 6; index++) ...[
                const SizedBox(height: 38, child: _SkeletonRow()),
                if (index != 5) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonText(width: 110, height: 14),
              SizedBox(height: 12),
              SkeletonText(width: 180, height: 24),
              SizedBox(height: 8),
              SkeletonText(width: 140, height: 14),
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
        SkeletonText(width: 80),
        Spacer(),
        SkeletonText(width: 58),
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
