import 'package:flutter/material.dart';

import '../constants/prayer_types.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';

/// Reusable Material 3 prayer grid used wherever prayers are selected.
class PrayerSelectionGrid extends StatelessWidget {
  const PrayerSelectionGrid({
    super.key,
    required this.selected,
    required this.onPrayerSelected,
    this.witrAllowed = true,
    this.disabledPrayers = const <PrayerType>{},
    this.disabledReasonBuilder,
  });

  final Set<PrayerType> selected;
  final ValueChanged<PrayerType> onPrayerSelected;
  final bool witrAllowed;

  /// Additional prayers that cannot currently be selected.
  ///
  /// Reusable consumers can keep the full six-prayer grid visible while
  /// feature-specific availability remains owned by the caller.
  final Set<PrayerType> disabledPrayers;

  /// Optional accessibility/context label for disabled prayers.
  final String Function(PrayerType prayer)? disabledReasonBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final prayers = PrayerType.values
        .where((prayer) => prayer != PrayerType.witr || witrAllowed)
        .toList(growable: false);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prayers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 42,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final prayer = prayers[index];
        final disabledByAvailability = disabledPrayers.contains(prayer);
        final enabled = !disabledByAvailability;
        final isSelected = selected.contains(prayer);
        final label = prayer.localizedLabel(l10n);
        final reason =
            disabledByAvailability ? disabledReasonBuilder?.call(prayer) : null;

        return Semantics(
          button: true,
          enabled: enabled,
          selected: isSelected,
          label: reason == null ? label : '$label, $reason',
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
