import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Compact Hijri label and display-only adjustment action for date headers.
class HijriDateChip extends StatelessWidget {
  const HijriDateChip({
    required this.label,
    required this.onAdjust,
    super.key,
  });

  final String label;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 8,
        end: 4,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('prayer_time_hijri_adjustment'),
            tooltip: AppLocalizations.of(context).hijriAdjustmentTitle,
            onPressed: onAdjust,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(Icons.tune_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}
