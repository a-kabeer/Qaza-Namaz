import 'package:flutter/material.dart';

import '../../../core/calendar/hijri_date_service.dart';
import '../../../l10n/app_localizations.dart';

/// The five display-only Hijri date offsets offered from the Prayer Time chip.
class HijriDateAdjustmentSheet extends StatelessWidget {
  const HijriDateAdjustmentSheet({
    required this.date,
    required this.selectedOffset,
    super.key,
  });

  final DateTime date;
  final int selectedOffset;

  static const offsets = <int>[-2, -1, 0, 1, 2];

  static Future<int?> show({
    required BuildContext context,
    required DateTime date,
    required int selectedOffset,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => HijriDateAdjustmentSheet(
        date: date,
        selectedOffset: selectedOffset,
      ),
    );
  }

  String _subtitle(AppLocalizations l10n, int offset) => switch (offset) {
        -2 => l10n.hijriAdjustmentEarlierTwo,
        -1 => l10n.hijriAdjustmentEarlierOne,
        0 => l10n.hijriAdjustmentNoChange,
        1 => l10n.hijriAdjustmentLaterOne,
        2 => l10n.hijriAdjustmentLaterTwo,
        _ => throw ArgumentError.value(offset, 'offset'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.hijriAdjustmentTitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final offset in offsets) ...[
              _AdjustmentOption(
                key: Key('hijri_adjustment_option_$offset'),
                dateLabel: HijriDateService.formatShort(
                  date,
                  l10n,
                  offsetDays: offset,
                ),
                subtitle: _subtitle(l10n, offset),
                selected: offset == selectedOffset,
                onTap: () => Navigator.of(context).pop(offset),
              ),
              if (offset != offsets.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdjustmentOption extends StatelessWidget {
  const _AdjustmentOption({
    required this.dateLabel,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String dateLabel;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
