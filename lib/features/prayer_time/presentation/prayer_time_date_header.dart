import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shows the Gregorian date with its Hijri equivalent and adjustment action.
class PrayerTimeDateHeader extends StatelessWidget {
  const PrayerTimeDateHeader({
    required this.gregorianDate,
    required this.hijriDate,
    required this.onAdjust,
    super.key,
  });

  final String gregorianDate;
  final String hijriDate;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gregorianDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hijriDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('prayer_time_hijri_adjustment'),
          tooltip: AppLocalizations.of(context).hijriAdjustmentTitle,
          onPressed: onAdjust,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.tune_rounded, size: 20),
        ),
      ],
    );
  }
}
