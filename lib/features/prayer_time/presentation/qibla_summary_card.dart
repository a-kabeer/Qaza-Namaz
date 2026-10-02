import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class QiblaSummaryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final valueText = _bearingText();

    return Semantics(
      button: true,
      label: '$valueText, ${l10n.qiblaDirection}',
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
                const SizedBox(height: 4),
                SizedBox(
                  height: 58,
                  child: Center(
                    child: Text(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.numericLarge.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
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
