import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../application/qibla_providers.dart';
import 'qibla_visuals.dart';

class QiblaDirectionScreen extends ConsumerWidget {
  const QiblaDirectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bearing = ref.watch(qiblaBearingProvider);
    final sensors = ref.watch(compassSensorAvailableProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: l10n.qiblaTitle,
      body: SafeArea(
        child: bearing == null
            ? _UnavailableState(
                title: l10n.qiblaUnavailable,
                body: l10n.qiblaLocationRequired,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    _BearingSummary(
                      bearing: bearing,
                      title: l10n.qiblaBearing,
                      subtitle: l10n.qiblaFromTrueNorth,
                    ),
                    const SizedBox(height: 16),
                    switch (sensors) {
                      AsyncData(:final value) when value => _LiveCompass(
                          bearing: bearing,
                          textTheme: textTheme,
                        ),
                      AsyncData() => _StaticCompass(
                          bearing: bearing,
                          textTheme: textTheme,
                        ),
                      AsyncError() => _StaticCompass(
                          bearing: bearing,
                          textTheme: textTheme,
                        ),
                      _ => const SizedBox(
                          height: 300,
                          child: Center(
                            child: SkeletonCircle(size: 280),
                          ),
                        ),
                    },
                    if (sensors is AsyncData<bool> && sensors.value) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          l10n.qiblaCompassBody,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(
                          l10n.qiblaSensorUnavailableBody,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _BearingSummary extends StatelessWidget {
  const _BearingSummary({
    required this.bearing,
    required this.title,
    required this.subtitle,
  });

  final double bearing;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: .16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${bearing.round()}°',
              style: AppTheme.numericLarge.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCompass extends ConsumerWidget {
  const _LiveCompass({
    required this.bearing,
    required this.textTheme,
  });

  final double bearing;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(compassReadingProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final heading = reading?.heading;
    final declination = ref.watch(magneticDeclinationProvider);

    if (heading == null || declination == null) {
      return Column(
        children: [
          _StaticCompass(
            bearing: bearing,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.qiblaHeadingUnavailable,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final service = ref.read(qiblaDirectionServiceProvider);
    final trueHeading = service.trueHeadingFromMagnetic(
      magneticHeading: heading,
      declination: declination,
    );
    final relativeAngle = service.relativeQiblaAngle(
      qiblaBearing: bearing,
      trueHeading: trueHeading,
    );
    final accuracy = reading?.accuracy;
    final needsCalibration = accuracy == null || accuracy > 20;

    return Column(
      children: [
        SizedBox.square(
          dimension: 290,
          child: CustomPaint(
            painter: QiblaDialPainter(
              qiblaBearing: bearing,
              heading: trueHeading,
              showRelativeQibla: true,
              surfaceColor: scheme.surfaceContainerLow,
              outlineColor: scheme.outlineVariant,
              onSurfaceColor: scheme.onSurface,
              onSurfaceVariantColor: scheme.onSurfaceVariant,
              primaryColor: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${relativeAngle.abs().round()}°',
          style: AppTheme.numericMedium.copyWith(
            color: scheme.onSurface,
          ),
        ),
        Text(
          l10n.qiblaTurnToDirection,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (accuracy != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.qiblaCompassAccuracy(accuracy.round().toString()),
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (needsCalibration) ...[
          const SizedBox(height: 8),
          Text(
            l10n.qiblaCalibrationHint,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _StaticCompass extends StatelessWidget {
  const _StaticCompass({
    required this.bearing,
    required this.textTheme,
  });

  final double bearing;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox.square(
          dimension: 290,
          child: CustomPaint(
            painter: QiblaDialPainter(
              qiblaBearing: bearing,
              heading: 0,
              showRelativeQibla: false,
              surfaceColor: scheme.surfaceContainerLow,
              outlineColor: scheme.outlineVariant,
              onSurfaceColor: scheme.onSurface,
              onSurfaceVariantColor: scheme.onSurfaceVariant,
              primaryColor: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).qiblaFromTrueNorth,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
