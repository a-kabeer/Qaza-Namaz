import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/widgets/prayer_selection_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../home_state.dart';
import '../providers/home_providers.dart';

Future<void> showHomeQazaTargetSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const HomeQazaTargetSheet(),
  );
}

class HomeQazaTargetSheet extends ConsumerWidget {
  const HomeQazaTargetSheet({super.key});

  void _selectMode(
    BuildContext context,
    WidgetRef ref,
    HomePrayerSelectionMode mode,
  ) {
    final notifier = ref.read(homePrayerSelectionProvider.notifier);

    switch (mode) {
      case HomePrayerSelectionMode.prayerTime:
        notifier.usePrayerTime();
        Navigator.of(context).pop();
      case HomePrayerSelectionMode.autoSequence:
        notifier.useAutoSequence();
        Navigator.of(context).pop();
      case HomePrayerSelectionMode.prayerSelection:
        notifier.usePrayerSelection();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(homePrayerSelectionProvider);
    final witrAllowed = ref.watch(effectiveWitrProvider);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              key: const Key('home_qaza_target_sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeQazaTarget,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _ModeTile(
                  key: const Key('home_qaza_target_mode_prayer_time'),
                  icon: Icons.schedule_outlined,
                  title: l10n.prayerTimeTitle,
                  selected:
                      selection.mode == HomePrayerSelectionMode.prayerTime,
                  onTap: () => _selectMode(
                    context,
                    ref,
                    HomePrayerSelectionMode.prayerTime,
                  ),
                ),
                _ModeTile(
                  key: const Key('home_qaza_target_mode_auto_sequence'),
                  icon: Icons.repeat_rounded,
                  title: l10n.homeAutoSequence,
                  selected:
                      selection.mode == HomePrayerSelectionMode.autoSequence,
                  onTap: () => _selectMode(
                    context,
                    ref,
                    HomePrayerSelectionMode.autoSequence,
                  ),
                ),
                _ModeTile(
                  key: const Key('home_qaza_target_mode_prayer_selection'),
                  icon: Icons.touch_app_outlined,
                  title: l10n.homePrayerSelection,
                  selected: selection.mode ==
                      HomePrayerSelectionMode.prayerSelection,
                  onTap: () => _selectMode(
                    context,
                    ref,
                    HomePrayerSelectionMode.prayerSelection,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.topCenter,
                  child: selection.mode ==
                          HomePrayerSelectionMode.prayerSelection
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: PrayerSelectionGrid(
                            key: const Key('home_qaza_target_prayer_grid'),
                            selected: {
                              selection.selectedPrayer ?? PrayerType.fajr,
                            },
                            allowMultiple: false,
                            witrAllowed: witrAllowed,
                            onPrayerSelected: (prayer) {
                              ref
                                  .read(
                                    homePrayerSelectionProvider.notifier,
                                  )
                                  .selectPrayer(prayer);
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        selected ? Icons.check_circle_rounded : icon,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      selected: selected,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
    );
  }
}
