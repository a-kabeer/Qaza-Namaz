import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/prayer_progress_row.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/qaza/complete_qaza_section.dart';
import 'package:qaza_namaz/features/qaza/qaza_navigation.dart';

/// Mounts the Complete Qaza section and the prayer list the way a screen does.
///
/// The standalone Complete Qaza screen was removed once Home took over
/// hosting the section. The tests that used to pump that screen are about
/// [CompleteQazaSection] and [PrayerProgressRow] themselves, so they mount
/// them through this host instead. The `complete` key prefix is the one the
/// removed screen used, and the one those tests still address.
class CompleteQazaHost extends ConsumerWidget {
  const CompleteQazaHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The same aggregate Home reads; the counts are never recomputed here.
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const CompleteQazaSection(),
            const SizedBox(height: 24),
            for (final prayer in PrayerType.values)
              PrayerProgressRow(
                keyPrefix: 'complete',
                prayer: prayer,
                progress: summary?.byPrayer[prayer]?.progress ??
                    const QazaProgress(pending: 0, completed: 0),
                onTap: () => openQazaForPrayer(ref, prayer),
              ),
          ],
        ),
      ),
    );
  }
}
