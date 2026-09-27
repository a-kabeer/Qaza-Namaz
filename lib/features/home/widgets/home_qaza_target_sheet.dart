import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/prayer_types.dart';
import '../../../core/widgets/prayer_selection_grid.dart';
import '../../../features/prayer_time/application/prayer_time_providers.dart';
import '../../../features/prayer_time/prayer_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../../shell/workspace_shell.dart';
import '../home_state.dart';
import '../providers/home_providers.dart';

Future<void> showHomeQazaTargetSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const HomeQazaTargetSheet(),
  );
}

class HomeQazaTargetSheet extends ConsumerStatefulWidget {
  const HomeQazaTargetSheet({super.key});

  @override
  ConsumerState<HomeQazaTargetSheet> createState() =>
      _HomeQazaTargetSheetState();
}

class _HomeQazaTargetSheetState
    extends ConsumerState<HomeQazaTargetSheet> {
  bool _showPrayerTimeSetup = false;

  void _openPrayerTimeSetup(BuildContext context) {
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.prayerTime;
    Navigator.of(context).pop();
  }

  void _selectMode(
    BuildContext context,
    HomePrayerSelectionMode mode,
    PrayerTimeTargetAvailability availability,
  ) {
    final notifier = ref.read(homePrayerSelectionProvider.notifier);

    switch (mode) {
      case HomePrayerSelectionMode.prayerTime:
        if (availability == PrayerTimeTargetAvailability.setupRequired) {
          setState(() => _showPrayerTimeSetup = true);
          return;
        }
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(homePrayerSelectionProvider);
    final witrAllowed = ref.watch(effectiveWitrProvider);
    final availability = ref.watch(prayerTimeTargetAvailabilityProvider);
    final showSetup = _showPrayerTimeSetup ||
        (selection.mode == HomePrayerSelectionMode.prayerTime &&
            availability == PrayerTimeTargetAvailability.setupRequired);

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
                    HomePrayerSelectionMode.prayerTime,
                    availability,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.topCenter,
                  child: showSetup
                      ? Card(
                          key: const Key('home_qaza_target_prayer_time_setup'),
                          margin: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.prayerTimeNoSchedule,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(l10n.prayerTimeSetupBody),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  key: const Key(
                                    'home_qaza_target_setup_prayer_times',
                                  ),
                                  onPressed: () => _openPrayerTimeSetup(context),
                                  icon: const Icon(Icons.settings_outlined),
                                  label: Text(l10n.prayerTimeSettings),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                _ModeTile(
                  key: const Key('home_qaza_target_mode_auto_sequence'),
                  icon: Icons.repeat_rounded,
                  title: l10n.homeAutoSequence,
                  selected:
                      selection.mode == HomePrayerSelectionMode.autoSequence,
                  onTap: () => _selectMode(
                    context,
                    HomePrayerSelectionMode.autoSequence,
                    availability,
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
                    HomePrayerSelectionMode.prayerSelection,
                    availability,
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
