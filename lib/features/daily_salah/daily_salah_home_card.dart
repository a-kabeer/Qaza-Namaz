import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../l10n/app_localizations.dart';
import 'daily_salah_tracking_providers.dart';
import 'daily_salah_tracking_service.dart';

class DailySalahHomeCard extends ConsumerWidget {
  const DailySalahHomeCard({
    super.key,
    required this.date,
    required this.onOpen,
  });

  final DateTime date;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(dailySalahTrackingEnabledProvider);
    final logs = ref.watch(dailySalahTrackingLogsProvider(date));
    final includeWitr = ref.watch(effectiveWitrProvider);

    return enabled.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isEnabled) {
        if (!isEnabled) {
          return Card(
            key: const Key('daily_salah_home_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.dailySalahTrackingEnableTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.dailySalahTrackingEnableSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton(
                      key: const Key('daily_salah_enable_tracking'),
                      onPressed: () async {
                        try {
                          await ref
                              .read(dailySalahTrackingServiceProvider)
                              .setEnabled(true);
                          ref.invalidate(dailySalahTrackingEnabledProvider);
                        } catch (_) {
                          if (!context.mounted) return;
                          ref
                              .read(appSnackbarServiceProvider)
                              .error(AppLocalizations.of(context).errorStorage);
                        }
                      },
                      child: Text(l10n.dailySalahTrackingEnableAction),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return logs.when(
          loading: () => Card(
            key: const Key('daily_salah_home_card'),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (dailyLogs) {
            final prayers = PrayerType.values
                .where((prayer) => includeWitr || prayer != PrayerType.witr)
                .toList(growable: false);
            final prayed = prayers
                .where((p) => dailyLogs[p]?.status == DailySalahStatus.prayed)
                .length;
            final missed = prayers
                .where((p) => dailyLogs[p]?.status == DailySalahStatus.missed)
                .length;
            final unrecorded = prayers.length - prayed - missed;
            final theme = Theme.of(context);
            return Card(
              key: const Key('daily_salah_home_card'),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dailySalahTrackingTitle,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$prayed ' + l10n.dailySalahTrackingPrayed + '  •  ' +
                                  '$missed ' + l10n.dailySalahTrackingMissed + '  •  ' +
                                  '$unrecorded ' + l10n.dailySalahTrackingUnrecorded,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
