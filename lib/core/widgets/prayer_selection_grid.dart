import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../features/home/providers/home_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';

/// Reusable Material 3 prayer grid used wherever prayers are selected.
class PrayerSelectionGrid extends StatelessWidget {
  const PrayerSelectionGrid({
    super.key,
    required this.selected,
    required this.onPrayerSelected,
    this.allowMultiple = false,
    this.witrAllowed = true,
  });

  final Set<PrayerType> selected;
  final ValueChanged<PrayerType> onPrayerSelected;
  final bool allowMultiple;
  final bool witrAllowed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: PrayerType.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 42,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final prayer = PrayerType.values[index];
        final enabled = prayer != PrayerType.witr || witrAllowed;
        final isSelected = selected.contains(prayer);
        final label = prayer.localizedLabel(l10n);

        return Semantics(
          button: true,
          enabled: enabled,
          selected: isSelected,
          label: label,
          child: FilterChip(
            selected: isSelected,
            showCheckmark: false,
            onSelected: enabled ? (_) => onPrayerSelected(prayer) : null,
            label: SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );
      },
    );
  }
}
