import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';
import 'add_qaza_screen.dart';
import 'qaza_tracker_controller.dart';

/// Opens the Add Qaza flow from any workspace entry point.
Future<void> openAddQaza(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const AddQazaScreen(),
    ),
  );
}

/// Shared Add Qaza FAB used by Home and the Qaza workspace.
class AddQazaFab extends StatelessWidget {
  const AddQazaFab({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).homeAddQaza;
    return Semantics(
      button: true,
      label: label,
      child: FloatingActionButton(
        onPressed: () => openAddQaza(context),
        tooltip: label,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// Opens the Qaza workspace filtered to one prayer's pending records.
void openQazaForPrayer(WidgetRef ref, PrayerType prayer) {
  ref.read(qazaTrackerFilterRequestProvider.notifier).state =
      QazaTrackerFilterRequest(
    prayer: prayer,
    status: QazaStatusFilter.pending,
  );
  ref.read(workspaceDestinationProvider.notifier).state =
      WorkspaceDestination.qaza;
}

/// Opens the unfiltered Qaza tracker tab without pushing a duplicate screen.
void openQazaAll(WidgetRef ref) {
  ref.read(qazaTrackerFilterRequestProvider.notifier).state = null;
  ref.read(workspaceDestinationProvider.notifier).state =
      WorkspaceDestination.qaza;
}
