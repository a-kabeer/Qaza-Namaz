import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../shell/workspace_shell.dart';
import 'qaza_tracker_controller.dart';

/// Opens the Qaza workspace filtered to one prayer's pending records.
///
/// Both Home and Complete Qaza offer the prayer list, so the hand-off lives
/// here rather than being written out at each call site: the tracker's own
/// filters do the work, and the workspace switches to the tab the user
/// already knows instead of a second tracker being pushed on top.
void openQazaForPrayer(WidgetRef ref, PrayerType prayer) {
  ref.read(qazaTrackerFilterRequestProvider.notifier).state =
      QazaTrackerFilterRequest(
    prayer: prayer,
    status: QazaStatusFilter.pending,
  );
  ref.read(workspaceDestinationProvider.notifier).state =
      WorkspaceDestination.qaza;
}
