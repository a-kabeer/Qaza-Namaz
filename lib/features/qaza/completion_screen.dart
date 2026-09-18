import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_progress_row.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';
import 'complete_qaza_section.dart';
import 'qaza_navigation.dart';

class CompleteQazaScreen extends ConsumerStatefulWidget {
  const CompleteQazaScreen({super.key});
  @override
  ConsumerState<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends ConsumerState<CompleteQazaScreen> {
  /// Leaves this page for the Qaza tab, filtered to [item].
  ///
  /// Complete Qaza is a pushed route, so it has to pop itself or the tab
  /// change would happen out of sight behind it.
  void _openPrayer(PrayerType item) {
    openQazaForPrayer(ref, item);
    Navigator.of(context).pop();
  }

  Future<void> _refresh() => CompleteQazaSection.refresh(ref);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The same aggregate Home reads; the counts are never recomputed here.
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    return AppScaffold(
      title: l10n.completeTitle,
      onBack: () => Navigator.pop(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(l10n.completeHeading,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.completeIntro),
              const SizedBox(height: 20),
              const CompleteQazaSection(),
              const SizedBox(height: 24),
              Text(
                l10n.homeProgressTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // The same list Home shows, from the same widget.
              for (final item in PrayerType.values)
                PrayerProgressRow(
                  keyPrefix: 'complete',
                  prayer: item,
                  progress: summary?.byPrayer[item]?.progress ??
                      const QazaProgress(pending: 0, completed: 0),
                  onTap: () => _openPrayer(item),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
