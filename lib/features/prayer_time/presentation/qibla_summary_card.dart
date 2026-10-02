import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/qibla_providers.dart';
import 'qibla_visuals.dart';

class QiblaSummaryCard extends ConsumerWidget {
  const QiblaSummaryCard({
    super.key,
    required this.bearing,
    required this.onTap,
  });

  final double? bearing;
  final VoidCallback onTap;

  String _bearingText() {
    final value = bearing;
    if (value == null || !value.isFinite) return '—';
    return '${value.round()}°';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final value = bearing;
    final sensorState = ref.watch(compassSensorAvailableProvider);
    final reading = ref.watch(compassReadingProvider).valueOrNull;
    final declination = ref.watch(magneticDeclinationProvider).valueOrNull;

    double? trueHeading;
    if (value != null &&
        value.isFinite &&
        sensorState.valueOrNull == true &&
        reading?.heading != null &&
        declination != null) {
      trueHeading = ref
          .read(qiblaDirectionServiceProvider)
          .trueHeadingFromMagnetic(
            magneticHeading: reading!.heading!,
            declination: declination,
          );
    }

    final live = trueHeading != null;
    final semanticState = live ? 'live compass' : 'static direction';
    final valueText = _bearingText();

    return Semantics(
      button: true,
      label: '${valueText}, ${l10n.qiblaDirection}, ${semanticState}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qiblaTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 86,
                  child: Center(
                    child: value == null || !value.isFinite
                        ? Icon(
                            Icons.explore_off_rounded,
                            size: 40,
                            color: scheme.onSurfaceVariant,
                          )
                        : SizedBox.square(
                            key: const Key('qibla_summary_compass'),
                            dimension: 86,
                            child: CustomPaint(
                              painter: QiblaDialPainter(
                                qiblaBearing: value,
                                heading: trueHeading ?? 0,
                                showRelativeQibla: live,
                                surfaceColor: scheme.surfaceContainerLow,
                                outlineColor: scheme.outlineVariant,
                                onSurfaceColor: scheme.onSurface,
                                onSurfaceVariantColor:
                                    scheme.onSurfaceVariant,
                                primaryColor: scheme.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.qiblaDirection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
